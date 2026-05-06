// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'sync_service.dart';

extension SyncServicePush on SyncService {

  Map<String, dynamic> _readAcceptedVersions(Map<String, dynamic> response) {
    final value = response['accepted_versions'];
    if (value == null) return const <String, dynamic>{};
    return _asStringKeyedMap(value, 'push response accepted_versions');
  }
  Future<int> _runPushPhase(String serverUrl) async {
    final vaultId = _identityService.vaultId;
    final approvedChanges = await _storageService.loadApprovedLocalSyncChanges(
      vaultId: vaultId,
    );
    final approvedChangeKeys = approvedChanges
        .map(_localSyncChangeEntityKey)
        .toSet();

    final allPendingAccounts = await _storageService.loadPendingSyncAccounts();
    final dirtyAccounts = allPendingAccounts
        .where(
          (a) =>
              a.syncStatus == SyncStatus.pendingPush &&
              approvedChangeKeys.contains(
                _syncEntityKey(LocalSyncEntityType.account, a.id),
              ),
        )
        .toList();
    final dirtyTemplates = (await _storageService.loadDirtyTemplates())
        .where(
          (template) => approvedChangeKeys.contains(
            _syncEntityKey(LocalSyncEntityType.template, template.templateId),
          ),
        )
        .toList();
    final allDirtyTotpCredentials = await _storageService
        .loadDirtyTotpCredentials();
    final dirtyTotpCredentials = allDirtyTotpCredentials
        .where(
          (credential) => approvedChangeKeys.contains(
            _syncEntityKey(LocalSyncEntityType.totpCredential, credential.id),
          ),
        )
        .toList();

    final List<dynamic> dirtyItems = [
      ...dirtyAccounts,
      ...dirtyTemplates,
      ...dirtyTotpCredentials,
    ];

    if (dirtyItems.isEmpty) {
      if (allPendingAccounts.isNotEmpty ||
          allDirtyTotpCredentials.isNotEmpty ||
          approvedChanges.isNotEmpty) {
        AppLogger.d(
          '[Sync] Push Phase: local changes exist, but none are approved and pushable.',
        );
      }
      return 0;
    }

    final pushedItemKeys = dirtyItems.map(_syncItemEntityKey).toSet();
    final pushingChangeIds = approvedChanges
        .where(
          (change) =>
              pushedItemKeys.contains(_localSyncChangeEntityKey(change)),
        )
        .map((change) => change.id)
        .toList(growable: false);
    await _storageService.markLocalSyncChangesPushing(pushingChangeIds);

    AppLogger.d(
      '[Sync] >>> Push Phase Start. Items to push: ${dirtyItems.length}',
    );
    final pushPayloads = await Future.wait(
      dirtyItems.map((item) async {
        final ciphertext = await _encryptAndSign(item);

        return {
          'id': _syncItemId(item),
          'expected_base_version': _syncItemServerVersion(item),
          'is_deleted': _syncItemIsDeleted(item),
          'encrypted_signed_payload': ciphertext,
        };
      }).toList(),
    );

    late final Map<String, int> acceptedVersionByItemId;
    late final List<Map<String, dynamic>> conflicts;
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      final token = _identityService.vaultApiToken;
      if (token != null && token.isNotEmpty) {
        headers['X-Vault-Token'] = token;
      }

      final response = await http
          .post(
            Uri.parse('$serverUrl/vaults/$vaultId/sync'),
            headers: headers,
            body: jsonEncode({'pushes': pushPayloads}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 409) {
        await _storageService.markLocalSyncChangesConflict(
          pushingChangeIds,
          response.body,
        );
        throw ConflictException(response.body);
      }
      _throwIfSyncHttpError(response, phase: 'push');

      final newToken = response.headers['x-vault-token'];
      if (newToken != null && newToken.isNotEmpty) {
        await _identityService.setVaultApiToken(newToken);
      }

      final respData = _decodeSyncResponse(response, phase: 'push');
      final acceptedVersions = _readAcceptedVersions(respData);
      acceptedVersionByItemId = _extractAcceptedVersions(acceptedVersions);
      conflicts = _readConflicts(respData);

      // Validate every dirty item is accounted for (accepted or conflicted)
      final conflictItemIds = conflicts
          .map((c) => c['item_id'] as String?)
          .whereType<String>()
          .toSet();
      for (final item in dirtyItems) {
        final itemId = _syncItemId(item);
        if (acceptedVersionByItemId.containsKey(itemId)) continue;
        if (conflictItemIds.contains(itemId)) continue;
        throw SyncProtocolException(
          'push response missing accepted version for $itemId',
        );
      }
    } catch (e) {
      if (e is! ConflictException) {
        await _storageService.markLocalSyncChangesFailed(
          pushingChangeIds,
          e.toString(),
        );
      }
      rethrow;
    }

    // Apply accepted items
    final acceptedChangeIds = <String>[];
    for (final item in dirtyItems) {
      final itemId = _syncItemId(item);
      final newVersion = acceptedVersionByItemId[itemId];
      if (newVersion == null) continue;

      await _applyAcceptedPushVersion(item, newVersion);

      if (newVersion > _localVersion) {
        _localVersion = newVersion;
      }
      final itemKey = _syncItemEntityKey(item);
      acceptedChangeIds.addAll(
        approvedChanges
            .where((change) => _localSyncChangeEntityKey(change) == itemKey)
            .map((change) => change.id),
      );
    }
    await _storageService.markLocalSyncChangesPushed(acceptedChangeIds);

    // Handle partial conflicts
    if (conflicts.isNotEmpty) {
      final conflictItemIds = conflicts
          .map((c) => c['item_id'] as String?)
          .whereType<String>()
          .toSet();

      final conflictChangeIds = approvedChanges
          .where((change) => conflictItemIds.contains(change.entityId))
          .map((change) => change.id)
          .toList(growable: false);

      await _storageService.markLocalSyncChangesConflict(
        conflictChangeIds,
        jsonEncode({'conflicts': conflicts}),
      );

      _queuedConflictCount += conflicts.length;
      _queuedConflictNotice =
          '${conflicts.length} item(s) conflicted during push. Review the conflict inbox before retrying.';

      // Refresh local state before retry
      await _pullLatestSnapshot(serverUrl);
      throw ConflictException(jsonEncode(conflicts.first));
    }

    await _storageService.setSetting(
      _syncVersionKey(_identityService.vaultId),
      '$_localVersion',
    );
    AppLogger.d(
      '[Sync] <<< Push Phase Completed. Success items: ${acceptedVersionByItemId.length}',
    );
    return acceptedVersionByItemId.length;
  }

  Map<String, int> _extractAcceptedVersions(Map<String, dynamic> acceptedVersions) {
    final result = <String, int>{};
    for (final entry in acceptedVersions.entries) {
      final value = entry.value;
      if (value is int && value >= 0) {
        result[entry.key] = value;
      } else {
        throw SyncProtocolException(
          'push response contains invalid accepted version for ${entry.key}: $value',
        );
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _readConflicts(Map<String, dynamic> response) {
    final value = response['conflicts'];
    if (value == null) return const <Map<String, dynamic>>[];
    if (value is List<dynamic>) {
      return value
          .map((item) => _asStringKeyedMap(item, 'push response conflict'))
          .toList();
    }
    throw const SyncProtocolException(
      'push response conflicts must be a list.',
    );
  }

  Future<void> _applyAcceptedPushVersion(dynamic item, int newVersion) async {
    if (item is AccountItem) {
      final current = await _storageService.getAccountById(
        item.id,
        includeDeleted: true,
      );
      if (current == null) return;
      if (!_sameSyncPayload(item, current)) {
        await _storageService.saveAccount(
          current.copyWith(
            serverVersion: max(current.serverVersion, newVersion),
            syncStatus: current.syncStatus == SyncStatus.synchronized
                ? SyncStatus.pendingPush
                : current.syncStatus,
          ),
          isSyncMerge: true,
        );
        await _refreshOpenChangeBaseVersion(item, newVersion);
        return;
      }
      await _storageService.saveAccount(
        item.copyWith(
          syncStatus: SyncStatus.synchronized,
          serverVersion: newVersion,
        ),
        isSyncMerge: true,
      );
      return;
    }

    if (item is AccountTemplate) {
      final current = await _storageService.loadTemplateById(item.templateId);
      if (current == null) return;
      if (!_sameSyncPayload(item, current)) {
        await _storageService.saveTemplate(
          current.copyWith(
            serverVersion: max(current.serverVersion, newVersion),
            syncStatus: current.syncStatus == SyncStatus.synchronized
                ? SyncStatus.pendingPush
                : current.syncStatus,
          ),
          isSyncMerge: true,
        );
        await _refreshOpenChangeBaseVersion(item, newVersion);
        return;
      }
      await _storageService.saveTemplate(
        item.copyWith(
          syncStatus: SyncStatus.synchronized,
          serverVersion: newVersion,
        ),
        isSyncMerge: true,
      );
      return;
    }

    if (item is TotpCredential) {
      final current = await _storageService.getTotpCredentialById(
        item.id,
        includeDeleted: true,
      );
      if (current == null) return;
      if (!_sameSyncPayload(item, current)) {
        await _storageService.saveTotpCredential(
          current.copyWith(
            serverVersion: max(current.serverVersion, newVersion),
            syncStatus: current.syncStatus == SyncStatus.synchronized
                ? SyncStatus.pendingPush
                : current.syncStatus,
          ),
          isSyncMerge: true,
        );
        await _refreshOpenChangeBaseVersion(item, newVersion);
        return;
      }
      await _storageService.saveTotpCredential(
        item.copyWith(
          syncStatus: SyncStatus.synchronized,
          serverVersion: newVersion,
        ),
        isSyncMerge: true,
      );
      return;
    }

    throw ArgumentError('Unsupported sync item type: ${item.runtimeType}');
  }

  Future<void> _refreshOpenChangeBaseVersion(
    dynamic item,
    int baseServerVersion,
  ) {
    return _storageService.refreshOpenLocalSyncChangeBaseVersion(
      vaultId: _identityService.vaultId,
      entityType: _syncItemEntityType(item),
      entityId: _syncItemId(item),
      baseServerVersion: baseServerVersion,
    );
  }

  bool _sameSyncPayload(dynamic left, dynamic right) {
    if (left.runtimeType != right.runtimeType) return false;
    final leftJson = Map<String, dynamic>.from(left.toJson() as Map);
    final rightJson = Map<String, dynamic>.from(right.toJson() as Map);
    for (final key in const ['serverVersion', 'syncStatus']) {
      leftJson.remove(key);
      rightJson.remove(key);
    }
    return jsonEncode(leftJson) == jsonEncode(rightJson);
  }

  String _syncItemEntityKey(dynamic item) {
    if (item is AccountItem) {
      return _syncEntityKey(LocalSyncEntityType.account, item.id);
    }
    if (item is AccountTemplate) {
      return _syncEntityKey(LocalSyncEntityType.template, item.templateId);
    }
    if (item is TotpCredential) {
      return _syncEntityKey(LocalSyncEntityType.totpCredential, item.id);
    }
    throw ArgumentError('Unsupported sync item type: ${item.runtimeType}');
  }

  String _syncItemId(dynamic item) {
    if (item is AccountItem) return item.id;
    if (item is AccountTemplate) return item.templateId;
    if (item is TotpCredential) return item.id;
    throw ArgumentError('Unsupported sync item type: ${item.runtimeType}');
  }

  int _syncItemServerVersion(dynamic item) {
    if (item is AccountItem) return item.serverVersion;
    if (item is AccountTemplate) return item.serverVersion;
    if (item is TotpCredential) return item.serverVersion;
    throw ArgumentError('Unsupported sync item type: ${item.runtimeType}');
  }

  LocalSyncEntityType _syncItemEntityType(dynamic item) {
    if (item is AccountItem) return LocalSyncEntityType.account;
    if (item is AccountTemplate) return LocalSyncEntityType.template;
    if (item is TotpCredential) return LocalSyncEntityType.totpCredential;
    throw ArgumentError('Unsupported sync item type: ${item.runtimeType}');
  }

  bool _syncItemIsDeleted(dynamic item) {
    if (item is AccountItem) return item.isDeleted;
    if (item is AccountTemplate) return item.isDeleted;
    if (item is TotpCredential) return item.isDeleted;
    throw ArgumentError('Unsupported sync item type: ${item.runtimeType}');
  }

  bool _totpCredentialContentEquals(TotpCredential left, TotpCredential right) {
    return left.label == right.label &&
        jsonEncode(left.config.toJson()) == jsonEncode(right.config.toJson()) &&
        listEquals(left.linkedAccountIds, right.linkedAccountIds) &&
        left.isDeleted == right.isDeleted;
  }

  String _localSyncChangeEntityKey(LocalSyncChange change) {
    return _syncEntityKey(change.entityType, change.entityId);
  }

  String _syncEntityKey(LocalSyncEntityType type, String entityId) {
    return '${type.name}:$entityId';
  }

  Future<String> _encryptAndSign(dynamic item) {
    if (item is AccountItem) {
      return SyncPayloadCodec.encodeAccount(
        item: item,
        vaultId: _identityService.vaultId,
        nodeId: _identityService.deviceId,
        privateKey: _identityService.privateKey,
        symmetricKey: _identityService.symmetricKey,
      );
    } else if (item is AccountTemplate) {
      return SyncPayloadCodec.encodeTemplate(
        template: item,
        vaultId: _identityService.vaultId,
        nodeId: _identityService.deviceId,
        privateKey: _identityService.privateKey,
        symmetricKey: _identityService.symmetricKey,
      );
    } else if (item is TotpCredential) {
      return SyncPayloadCodec.encodeTotpCredential(
        credential: item,
        vaultId: _identityService.vaultId,
        nodeId: _identityService.deviceId,
        privateKey: _identityService.privateKey,
        symmetricKey: _identityService.symmetricKey,
      );
    }
    throw ArgumentError('Unsupported sync item type: ${item.runtimeType}');
  }

  Future<Map<String, dynamic>> _decryptAndVerifyPayload(
    Map<String, dynamic> remoteRecord,
  ) {
    final cipher = _readEncryptedPayload(remoteRecord);
    return SyncPayloadCodec.decodePayload(
      encodedPayload: cipher,
      expectedVaultId: _identityService.vaultId,
      privateKey: _identityService.privateKey,
      symmetricKey: _identityService.symmetricKey,
    );
  }
}
