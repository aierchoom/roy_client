// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'sync_service.dart';

extension SyncServicePull on SyncService {
  Future<Map<String, dynamic>> _fetchRemoteChanges(
    String serverUrl, {
    required int since,
    int cursor = 0,
    int limit = 100,
  }) async {
    final vaultId = _identityService.vaultId;
    final url =
        '$serverUrl/vaults/$vaultId/sync?since=$since&cursor=$cursor&limit=$limit';
    final headers = <String, String>{};
    headers['X-Vault-Generation'] = '$_serverGeneration';
    final token = _identityService.vaultApiToken;
    if (token != null && token.isNotEmpty) {
      headers['X-Vault-Token'] = token;
    }

    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 304) {
      final generationHeader = response.headers['x-vault-generation'];
      final generation = generationHeader != null
          ? int.tryParse(generationHeader)
          : null;
      return {
        'max_version': since,
        'items': const <dynamic>[],
        if (generation != null) 'generation': generation,
      };
    }
    _throwIfSyncHttpError(response, phase: 'pull');

    final newToken = response.headers['x-vault-token'];
    if (newToken != null && newToken.isNotEmpty) {
      await _identityService.setVaultApiToken(newToken);
    }

    return _decodeSyncResponse(response, phase: 'pull');
  }

  /// Fetches all remote changes paginated, aggregating items across pages.
  ///
  /// Transaction principle: all pages are fetched first, then returned as a
  /// single batch. If any page fails, the exception propagates and no items
  /// are applied — the caller must not persist partial results.
  Future<Map<String, dynamic>> _fetchAllRemoteChanges(
    String serverUrl, {
    required int since,
  }) async {
    final allItems = <dynamic>[];
    var cursor = 0;
    const limit = 100;
    var finalMaxVersion = since;
    int? finalGeneration;
    int? totalCount;

    while (true) {
      final data = await _fetchRemoteChanges(
        serverUrl,
        since: since,
        cursor: cursor,
        limit: limit,
      );
      final itemsList = _readRemoteItems(data);
      allItems.addAll(itemsList);
      finalMaxVersion = _readOptionalVersion(
        data,
        'max_version',
        fallback: since,
        label: 'pull response max_version',
      );
      finalGeneration = data['generation'] as int?;
      totalCount ??= data['total_count'] as int?;

      final hasMore = data['has_more'] == true;
      final nextCursor = data['next_cursor'] as int?;

      if (totalCount != null && totalCount > 0) {
        final progress = ((cursor + itemsList.length) / totalCount * 100)
            .clamp(0, 99)
            .round();
        if (hasMore) {
          _statusNote = 'Pulling remote updates ($progress%)...';
          if (!_disposed) notifyListeners();
        }
      }

      if (!hasMore || nextCursor == null) break;
      cursor = nextCursor;
    }

    return {
      'max_version': finalMaxVersion,
      if (finalGeneration != null) 'generation': finalGeneration,
      'items': allItems,
    };
  }

  Future<int> _runPullPhase(String serverUrl) async {
    final vaultId = _identityService.vaultId;
    AppLogger.d(
      '[Sync] >>> Pull Phase Start (Vault: $vaultId, Since: $_localVersion)',
    );

    final data = await _fetchAllRemoteChanges(serverUrl, since: _localVersion);
    final mergedCount = await _applyRemoteChanges(data);
    AppLogger.d(
      '[Sync] <<< Pull Phase Completed. Processed: $mergedCount, Version: $_localVersion',
    );
    return mergedCount;
  }

  List<dynamic> _readRemoteItems(Map<String, dynamic> data) {
    final value = data['items'];
    if (value == null) return const <dynamic>[];
    if (value is List<dynamic>) return value;
    if (value is List) return List<dynamic>.from(value);
    throw const SyncProtocolException('pull response items must be a list.');
  }

  Map<String, dynamic> _readRemoteRecord(Object? value) {
    return _asStringKeyedMap(value, 'remote sync item');
  }

  int _readRemoteVersion(Map<String, dynamic> remoteRecord) {
    final value = remoteRecord['version'];
    if (value is int && value >= 0) return value;
    throw const SyncProtocolException(
      'remote sync item version must be a non-negative integer.',
    );
  }

  String _readEncryptedPayload(Map<String, dynamic> remoteRecord) {
    final value = remoteRecord['encrypted_signed_payload'];
    if (value is String && value.isNotEmpty) return value;
    throw const SyncProtocolException(
      'remote sync item encrypted payload is missing.',
    );
  }

  Future<int> _applyRemoteChanges(Map<String, dynamic> data) async {
    final maxVersion = _readOptionalVersion(
      data,
      'max_version',
      fallback: _localVersion,
      label: 'pull response max_version',
    );
    final serverGeneration = (data['generation'] as int?) ?? _serverGeneration;
    final itemsList = _readRemoteItems(data);
    final vaultId = _identityService.vaultId;

    if (_serverGeneration != 0 && serverGeneration != _serverGeneration) {
      AppLogger.d(
        '[Sync] Server generation changed from $_serverGeneration to $serverGeneration. Triggering reset recovery.',
      );
      await _handleServerReset();
    }
    _serverGeneration = serverGeneration;
    await _storageService.setSetting(
      _syncGenerationKey(vaultId),
      '$_serverGeneration',
    );

    AppLogger.d(
      '[Sync] Received ${itemsList.length} items. Server Max Version: $maxVersion',
    );

    if (itemsList.isEmpty) {
      // 没有任何更新项，直接对齐版本号并退出
      _localVersion = maxVersion;
      await _storageService.setSetting(
        _syncVersionKey(vaultId),
        '$_localVersion',
      );
      return 0;
    }

    var mergedCount = 0;
    for (final item in itemsList) {
      final remoteEncoded = _readRemoteRecord(item);
      final remoteVersion = _readRemoteVersion(remoteEncoded);
      final isRemoteDeleted = remoteEncoded['is_deleted'] == true;

      final payload = await _decryptAndVerifyPayload(remoteEncoded);
      final type = payload['_type'] as String?;

      if (type == 'totp_credential') {
        final remoteCredential = TotpCredential.fromJson(payload).copyWith(
          serverVersion: remoteVersion,
          syncStatus: SyncStatus.synchronized,
          isDeleted: isRemoteDeleted,
        );

        final maybeLocal = await _storageService.getTotpCredentialById(
          remoteCredential.id,
          includeDeleted: true,
        );
        if (maybeLocal == null) {
          await _storageService.saveTotpCredential(
            remoteCredential,
            isSyncMerge: true,
          );
        } else if (maybeLocal.syncStatus == SyncStatus.pendingPush ||
            maybeLocal.syncStatus == SyncStatus.conflict) {
          final merged = TotpCredentialMergeEngine.merge(
            maybeLocal,
            remoteCredential,
          );
          await _storageService.saveTotpCredential(
            merged.copyWith(
              syncStatus: _totpCredentialContentEquals(merged, remoteCredential)
                  ? SyncStatus.synchronized
                  : SyncStatus.pendingPush,
            ),
            isSyncMerge: true,
          );
        } else {
          await _storageService.saveTotpCredential(
            remoteCredential,
            isSyncMerge: true,
          );
        }
      } else if (type == 'template') {
        final remoteTemplate = AccountTemplate.fromJson(payload).copyWith(
          serverVersion: remoteVersion,
          syncStatus: SyncStatus.synchronized,
          isDeleted: isRemoteDeleted,
        );

        final maybeLocal = await _storageService.loadTemplateById(
          remoteTemplate.templateId,
        );
        if (maybeLocal == null) {
          await _storageService.saveTemplate(remoteTemplate, isSyncMerge: true);
        } else if (maybeLocal.syncStatus == SyncStatus.pendingPush) {
          await _storageService.saveTemplate(remoteTemplate, isSyncMerge: true);
        } else {
          await _storageService.saveTemplate(remoteTemplate, isSyncMerge: true);
        }
      } else {
        // Default to account
        final remoteAccount = AccountItem.fromJson(payload).copyWith(
          serverVersion: remoteVersion,
          syncStatus: SyncStatus.synchronized,
          isDeleted: isRemoteDeleted,
        );

        final maybeLocal = await _storageService.getAccountById(
          remoteAccount.id,
          includeDeleted: true,
        );

        if (maybeLocal == null) {
          await _storageService.saveAccount(remoteAccount, isSyncMerge: true);
        } else if (maybeLocal.syncStatus == SyncStatus.pendingPush ||
            maybeLocal.syncStatus == SyncStatus.conflict) {
          final mergeResult = CrdtMergeEngine.merge(maybeLocal, remoteAccount);
          await _storageService.saveAccount(
            mergeResult.mergedItem,
            isSyncMerge: true,
          );
          if (mergeResult.conflictLogs.isNotEmpty) {
            await _storageService.saveConflictLogs(mergeResult.conflictLogs);
          }
        } else {
          await _storageService.saveAccount(remoteAccount, isSyncMerge: true);
        }
      }
      mergedCount++;
    }

    // 只有在所有项目都成功处理后，才推进全局版本号
    _localVersion = maxVersion;
    final currentVaultId = _identityService.vaultId;
    await _storageService.setSetting(
      _syncVersionKey(currentVaultId),
      '$_localVersion',
    );
    await _recordSyncTime();

    return mergedCount;
  }

  Future<void> _pullLatestSnapshot(String serverUrl) async {
    final data = await _fetchAllRemoteChanges(serverUrl, since: 0);
    final maxVersion = _readOptionalVersion(
      data,
      'max_version',
      fallback: 0,
      label: 'snapshot response max_version',
    );
    final itemsList = _readRemoteItems(data);

    for (final item in itemsList) {
      final remoteEncoded = _readRemoteRecord(item);
      final remoteVersion = _readRemoteVersion(remoteEncoded);
      final isRemoteDeleted = remoteEncoded['is_deleted'] == true;
      final payload = await _decryptAndVerifyPayload(remoteEncoded);
      final type = payload['_type'] as String?;

      if (type == 'totp_credential') {
        final remoteCredential = TotpCredential.fromJson(payload).copyWith(
          serverVersion: remoteVersion,
          syncStatus: SyncStatus.synchronized,
          isDeleted: isRemoteDeleted,
        );
        await _storageService.saveTotpCredential(
          remoteCredential,
          isSyncMerge: true,
        );
      } else if (type == 'template') {
        final remoteTemplate = AccountTemplate.fromJson(payload).copyWith(
          serverVersion: remoteVersion,
          syncStatus: SyncStatus.synchronized,
          isDeleted: isRemoteDeleted,
        );
        await _storageService.saveTemplate(remoteTemplate, isSyncMerge: true);
      } else {
        final remoteAccount = AccountItem.fromJson(payload).copyWith(
          serverVersion: remoteVersion,
          syncStatus: SyncStatus.synchronized,
          isDeleted: isRemoteDeleted,
        );
        await _storageService.saveAccount(remoteAccount, isSyncMerge: true);
      }
    }

    _localVersion = maxVersion;
    await _storageService.setSetting(
      _syncVersionKey(_identityService.vaultId),
      '$_localVersion',
    );
  }

  Future<int> _pullAndMergeLatestSnapshot(String serverUrl) async {
    final data = await _fetchAllRemoteChanges(serverUrl, since: 0);
    return _applyRemoteChanges(data);
  }

  Future<int> _pullFromVersion(String serverUrl, int sinceVersion) async {
    final data = await _fetchAllRemoteChanges(serverUrl, since: sinceVersion);
    return _applyRemoteChanges(data);
  }
}
