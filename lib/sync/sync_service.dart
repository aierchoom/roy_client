import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/totp_credential.dart';
import '../services/identity_service.dart';
import '../services/secure_storage_service.dart';
import '../models/local_sync_change.dart';
import 'crdt_merge_engine.dart';
import 'sync_payload_codec.dart';
import 'totp_credential_merge_engine.dart';

enum SyncState { offline, syncing, synced, error, conflictRecovery }

class SyncConfig {
  final String serverUrl;
  final Duration syncInterval;

  const SyncConfig({
    required this.serverUrl,
    this.syncInterval = const Duration(minutes: 5),
  });
}

enum _SyncRecoveryPhase { pull, push, conflictRecovery }

class _SyncRecoveryMarker {
  final _SyncRecoveryPhase phase;
  final int localVersion;
  final DateTime startedAt;
  final String? itemId;
  final String? conflictType;

  const _SyncRecoveryMarker({
    required this.phase,
    required this.localVersion,
    required this.startedAt,
    this.itemId,
    this.conflictType,
  });

  Map<String, dynamic> toJson() {
    return {
      'phase': phase.name,
      'local_version': localVersion,
      'started_at': startedAt.toIso8601String(),
      'item_id': itemId,
      'conflict_type': conflictType,
    };
  }

  factory _SyncRecoveryMarker.fromJson(Map<String, dynamic> json) {
    final phaseName = json['phase'] as String?;
    final phase = _SyncRecoveryPhase.values.firstWhere(
      (candidate) => candidate.name == phaseName,
      orElse: () => _SyncRecoveryPhase.pull,
    );

    return _SyncRecoveryMarker(
      phase: phase,
      localVersion: json['local_version'] as int? ?? 0,
      startedAt:
          DateTime.tryParse(json['started_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      itemId: json['item_id'] as String?,
      conflictType: json['conflict_type'] as String?,
    );
  }
}

class _SyncProtocolException implements Exception {
  final String message;

  const _SyncProtocolException(this.message);

  @override
  String toString() => 'SyncProtocolException($message)';
}

class SyncService extends ChangeNotifier {
  final SecureStorageService _storageService;
  final IdentityService _identityService;
  final SyncConfig _config;

  Timer? _syncTimer;
  Future<SyncResult>? _activeSync;
  SyncState _state = SyncState.offline;
  String? _errorMessage;
  String? _statusNote;
  DateTime? _lastSyncTime;
  int _localVersion = 0;
  bool _isDirty = false;
  String _lastConflictMsg = '';
  int _queuedConflictCount = 0;
  String? _queuedConflictNotice;
  _SyncRecoveryMarker? _pendingRecovery;

  SyncService({
    required SecureStorageService storageService,
    required IdentityService identityService,
    SyncConfig? config,
  }) : _storageService = storageService,
       _identityService = identityService,
       _config = config ?? const SyncConfig(serverUrl: '');

  SyncState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get statusNote => _statusNote;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isConnected =>
      _state == SyncState.synced ||
      _state == SyncState.syncing ||
      _state == SyncState.conflictRecovery;
  bool get isSyncing =>
      _state == SyncState.syncing || _state == SyncState.conflictRecovery;
  int get localVersion => _localVersion;
  bool get isDirty => _isDirty;

  String _syncVersionKey(String vaultId) => 'sync_version_$vaultId';

  String _syncLastTimeKey(String vaultId) => 'sync_last_time_$vaultId';

  String _syncDirtyKey(String vaultId) => 'sync_dirty_$vaultId';

  String _syncRecoveryKey(String vaultId) => 'sync_recovery_$vaultId';

  String _syncServerUrlKey(String vaultId) => 'sync_server_url_$vaultId';

  @visibleForTesting
  String? get recoveryPhase => _pendingRecovery?.phase.name;

  Future<void> initialize() async {
    if (!_identityService.hasIdentity) {
      _localVersion = 0;
      _lastSyncTime = null;
      _isDirty = false;
      _statusNote = null;
      return;
    }

    final vaultId = _identityService.vaultId;
    final versionStr = await _readVaultScopedSetting(
      vaultId: vaultId,
      scopedKey: _syncVersionKey(vaultId),
      legacyKey: 'sync_version',
    );
    _localVersion = int.tryParse(versionStr ?? '') ?? 0;

    final lastSyncStr = await _readVaultScopedSetting(
      vaultId: vaultId,
      scopedKey: _syncLastTimeKey(vaultId),
      legacyKey: 'sync_last_time',
    );
    _lastSyncTime = lastSyncStr == null ? null : DateTime.tryParse(lastSyncStr);

    final dirtyStr = await _readVaultScopedSetting(
      vaultId: vaultId,
      scopedKey: _syncDirtyKey(vaultId),
      legacyKey: 'sync_dirty',
    );
    _isDirty = dirtyStr == '1';

    await _storageService.ensurePendingSyncOutboxEntries(vaultId);
    await _loadRecoveryMarker(vaultId);

    debugPrint('[Sync] Initialized. Vault: $vaultId, Version: $_localVersion');
  }

  Future<void> markDirty() async {
    if (_isDirty) return;
    if (!_identityService.hasIdentity) return;
    _isDirty = true;
    _statusNote = 'Local changes are queued for the next sync.';
    await _storageService.setSetting(
      _syncDirtyKey(_identityService.vaultId),
      '1',
    );
    notifyListeners();
  }

  Future<void> reconcileDirtyState() async {
    if (!_identityService.hasIdentity) return;
    final hasOpenChanges = await _storageService.hasOpenLocalSyncChanges(
      _identityService.vaultId,
    );
    _isDirty = hasOpenChanges;
    await _storageService.setSetting(
      _syncDirtyKey(_identityService.vaultId),
      hasOpenChanges ? '1' : '0',
    );
    if (hasOpenChanges) {
      _statusNote ??= 'Local changes are waiting for review before push.';
    } else {
      _statusNote = null;
    }
    notifyListeners();
  }

  Future<void> reset() async {
    _stopPeriodicSync();
    _statusNote = null;
    _updateState(SyncState.offline);
  }

  Future<void> disconnect() async {
    _stopPeriodicSync();
    _statusNote = null;
    _updateState(SyncState.offline);
  }

  Future<bool> connect() async {
    _stopPeriodicSync();
    final result = await syncNow();
    if (result.success) {
      _startPeriodicSync();
    }
    return result.success;
  }

  Future<SyncResult> syncNow() async {
    final serverUrl = await _getSyncServerUrl();
    if (serverUrl.isEmpty) {
      _setError(
        'Sync server URL not configured.',
        statusNote: 'Set a sync server address before trying again.',
      );
      return SyncResult.failure('Sync server URL not configured.');
    }
    if (!_identityService.hasIdentity) {
      _setError(
        'Identity not established.',
        statusNote:
            'Unlock the vault and recreate local identity before syncing.',
      );
      return SyncResult.failure('Identity not established.');
    }
    if (_isMobileLoopbackUrl(serverUrl)) {
      _setError(
        'Mobile clients cannot use loopback sync URLs.',
        statusNote:
            'Replace localhost or 127.0.0.1 with the desktop machine LAN IP.',
      );
      return SyncResult.failure(
        'On mobile devices, 127.0.0.1/localhost points to the phone itself. Use your computer\'s LAN IP instead.',
      );
    }

    final inFlightSync = _activeSync;
    if (inFlightSync != null) {
      return inFlightSync;
    }

    final syncFuture = _runSyncLoop(serverUrl);
    _activeSync = syncFuture;
    try {
      return await syncFuture;
    } finally {
      if (identical(_activeSync, syncFuture)) {
        _activeSync = null;
      }
    }
  }

  Future<SyncResult> _runSyncLoop(String serverUrl) async {
    _queuedConflictCount = 0;
    _queuedConflictNotice = null;
    _statusNote = null;
    var recoveredCount = 0;

    try {
      if (_pendingRecovery != null) {
        _updateState(SyncState.conflictRecovery);
        recoveredCount = await _resumeInterruptedSync(serverUrl);
      }

      var retries = 0;
      while (retries < 3) {
        try {
          _updateState(SyncState.syncing);
          await _writeRecoveryMarker(_SyncRecoveryPhase.pull);
          final pullCount = await _runPullPhase(serverUrl);
          await _writeRecoveryMarker(_SyncRecoveryPhase.push);
          final pushCount = await _runPushPhase(serverUrl);

          await _recordSyncTime();
          final hasOpenLocalChanges = await _storageService
              .hasOpenLocalSyncChanges(_identityService.vaultId);
          _isDirty = hasOpenLocalChanges;
          await _storageService.setSetting(
            _syncDirtyKey(_identityService.vaultId),
            hasOpenLocalChanges ? '1' : '0',
          );
          await _clearRecoveryMarker();
          _statusNote = hasOpenLocalChanges
              ? _buildQueuedLocalChangesStatusNote(
                  pulled: recoveredCount > 0 || pullCount > 0,
                  pushed: pushCount > 0,
                  notice: _queuedConflictNotice,
                )
              : _buildSuccessStatusNote(
                  recovered: recoveredCount > 0,
                  pulled: pullCount > 0,
                  pushed: pushCount > 0,
                  notice: _queuedConflictNotice,
                );
          _updateState(SyncState.synced);

          return SyncResult.success(
            pulled: recoveredCount > 0 || pullCount > 0,
            pushed: pushCount > 0,
            version: _localVersion,
            conflictCount: _queuedConflictCount,
            notice: _queuedConflictNotice,
          );
        } on _ConflictException catch (ce) {
          _lastConflictMsg = ce.serverResponse;
          await _writeRecoveryMarker(
            _SyncRecoveryPhase.conflictRecovery,
            itemId: ce.itemId,
            conflictType: ce.conflictType,
          );
          await _handleConflict(serverUrl, ce);
          retries++;
          _updateState(SyncState.conflictRecovery);
          await Future.delayed(Duration(milliseconds: 500 * retries));
        }
      }

      _setError(
        'Max retries exceeded! Last Server Reject: $_lastConflictMsg',
        statusNote:
            'Conflict recovery did not converge automatically. Review the conflict inbox before retrying.',
      );
      return SyncResult.failure('Max retries exceeded: $_lastConflictMsg');
    } catch (e, stack) {
      return _handleGlobalSyncError(e, stack);
    }
  }

  SyncResult _handleGlobalSyncError(dynamic e, StackTrace stack) {
    if (e is SocketException || e is TimeoutException) {
      _statusNote =
          'Cannot reach the sync server. Verify the address and network path.';
      _updateState(SyncState.offline);
      return SyncResult.failure('offline');
    }

    if (e is http.ClientException) {
      final message = e.message;
      // Handle cases where ClientException wraps a SocketException (common in Flutter)
      if (message.contains('SocketException') ||
          message.contains('Connection failed') ||
          message.contains('OS Error')) {
        _statusNote =
            'Network unreachable. Sync will retry when connection is restored.';
        _updateState(SyncState.offline);
        return SyncResult.failure('offline');
      }

      if (_looksLikeCleartextBlock(message)) {
        _setError(
          'Cleartext HTTP blocked: $message',
          statusNote:
              'Use HTTPS or allow local HTTP traffic for this device build.',
        );
        return SyncResult.failure('cleartext_blocked');
      }
      _setError('Sync failed: $message', statusNote: message);
      return SyncResult.failure(message);
    }

    if (e is _SyncHttpException) {
      if (e.conflictType == 'invalid_payload') {
        _setError(
          'Sync payload rejected: ${e.logMessage}',
          statusNote:
              'The sync server rejected a local encrypted payload. Reopen the item and retry; inspect client logs if it repeats.',
        );
        return SyncResult.failure(e.userMessage);
      }
      _setError('Sync failed: ${e.logMessage}', statusNote: e.userMessage);
      return SyncResult.failure(e.userMessage);
    }

    if (e is _SyncProtocolException) {
      _setError(
        'Sync protocol invalid: ${e.message}',
        statusNote:
            'The sync server returned data this client could not safely process. Check server version and logs.',
      );
      return SyncResult.failure(e.message);
    }

    if (e is SyncPayloadException) {
      _setError(
        'Sync payload invalid: ${e.message}',
        statusNote:
            'The remote payload could not be verified. Check key consistency across devices.',
      );
      return SyncResult.failure(e.message);
    }

    // Default fallback for unexpected errors
    if (kDebugMode) {
      debugPrint('Sync loop failed: $e\n$stack');
    }
    _setError(
      'Sync failed: $e',
      statusNote:
          'An unexpected sync error occurred. Retry and inspect client/server logs if it repeats.',
    );
    return SyncResult.failure(e.toString());
  }

  String _buildSuccessStatusNote({
    required bool recovered,
    required bool pulled,
    required bool pushed,
    String? notice,
  }) {
    if (notice != null && notice.isNotEmpty) {
      return notice;
    }
    if (recovered && pulled && pushed) {
      return 'Recovered the last interrupted sync, pulled remote updates, and pushed local changes.';
    }
    if (recovered && pulled) {
      return 'Recovered the last interrupted sync and pulled remote updates.';
    }
    if (pulled && pushed) {
      return 'Pulled remote updates and pushed local changes.';
    }
    if (pulled) {
      return 'Pulled remote updates.';
    }
    if (pushed) {
      return 'Pushed local changes.';
    }
    return 'Already up to date.';
  }

  String _buildQueuedLocalChangesStatusNote({
    required bool pulled,
    required bool pushed,
    String? notice,
  }) {
    if (notice != null && notice.isNotEmpty) {
      return '$notice Local changes are still waiting for review.';
    }
    if (pulled && pushed) {
      return 'Pulled remote updates and pushed approved changes. Local changes are still waiting for review.';
    }
    if (pulled) {
      return 'Pulled remote updates. Local changes are waiting for review.';
    }
    if (pushed) {
      return 'Pushed approved changes. Local changes are still waiting for review.';
    }
    return 'Local changes are waiting for review before push.';
  }

  Future<Map<String, dynamic>> _fetchRemoteChanges(
    String serverUrl, {
    required int since,
  }) async {
    final vaultId = _identityService.vaultId;
    final url = '$serverUrl/vaults/$vaultId/sync?since=$since';

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 304) {
      return {'max_version': since, 'items': const <dynamic>[]};
    }
    _throwIfSyncHttpError(response, phase: 'pull');

    return _decodeSyncResponse(response, phase: 'pull');
  }

  Future<int> _runPullPhase(String serverUrl) async {
    final vaultId = _identityService.vaultId;
    debugPrint(
      '[Sync] >>> Pull Phase Start (Vault: $vaultId, Since: $_localVersion)',
    );

    final data = await _fetchRemoteChanges(serverUrl, since: _localVersion);
    final mergedCount = await _applyRemoteChanges(data);
    debugPrint(
      '[Sync] <<< Pull Phase Completed. Processed: $mergedCount, Version: $_localVersion',
    );
    return mergedCount;
  }

  Map<String, dynamic> _decodeSyncResponse(
    http.Response response, {
    required String phase,
  }) {
    try {
      final decoded = jsonDecode(response.body);
      return _asStringKeyedMap(decoded, '$phase response');
    } on _SyncProtocolException {
      rethrow;
    } catch (_) {
      throw _SyncProtocolException('$phase response is not valid JSON.');
    }
  }

  Map<String, dynamic> _asStringKeyedMap(Object? value, String label) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        // Fall through to the typed protocol error below.
      }
    }
    throw _SyncProtocolException('$label must be a JSON object.');
  }

  int _readOptionalVersion(
    Map<String, dynamic> data,
    String key, {
    required int fallback,
    required String label,
  }) {
    final value = data[key];
    if (value == null) return fallback;
    if (value is int && value >= 0) return value;
    throw _SyncProtocolException('$label must be a non-negative integer.');
  }

  List<dynamic> _readRemoteItems(Map<String, dynamic> data) {
    final value = data['items'];
    if (value == null) return const <dynamic>[];
    if (value is List<dynamic>) return value;
    if (value is List) return List<dynamic>.from(value);
    throw const _SyncProtocolException('pull response items must be a list.');
  }

  Map<String, dynamic> _readRemoteRecord(Object? value) {
    return _asStringKeyedMap(value, 'remote sync item');
  }

  int _readRemoteVersion(Map<String, dynamic> remoteRecord) {
    final value = remoteRecord['version'];
    if (value is int && value >= 0) return value;
    throw const _SyncProtocolException(
      'remote sync item version must be a non-negative integer.',
    );
  }

  String _readEncryptedPayload(Map<String, dynamic> remoteRecord) {
    final value = remoteRecord['encrypted_signed_payload'];
    if (value is String && value.isNotEmpty) return value;
    throw const _SyncProtocolException(
      'remote sync item encrypted payload is missing.',
    );
  }

  Map<String, dynamic> _readAcceptedVersions(Map<String, dynamic> response) {
    final value = response['accepted_versions'];
    if (value == null) return const <String, dynamic>{};
    return _asStringKeyedMap(value, 'push response accepted_versions');
  }

  int? _acceptedVersionFor(
    Map<String, dynamic> acceptedVersions,
    String itemId,
  ) {
    final value = acceptedVersions[itemId];
    if (value == null) return null;
    if (value is int && value >= 0) return value;
    throw _SyncProtocolException(
      'accepted version for $itemId must be a non-negative integer.',
    );
  }

  Future<int> _applyRemoteChanges(Map<String, dynamic> data) async {
    final maxVersion = _readOptionalVersion(
      data,
      'max_version',
      fallback: _localVersion,
      label: 'pull response max_version',
    );
    final itemsList = _readRemoteItems(data);
    final vaultId = _identityService.vaultId;

    debugPrint(
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
    final data = await _fetchRemoteChanges(serverUrl, since: 0);
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
    final data = await _fetchRemoteChanges(serverUrl, since: 0);
    return _applyRemoteChanges(data);
  }

  Future<void> _loadRecoveryMarker(String vaultId) async {
    final raw = await _readVaultScopedSetting(
      vaultId: vaultId,
      scopedKey: _syncRecoveryKey(vaultId),
      legacyKey: 'sync_recovery',
    );
    if (raw == null || raw.isEmpty) {
      _pendingRecovery = null;
      return;
    }

    try {
      _pendingRecovery = _SyncRecoveryMarker.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      _pendingRecovery = null;
      await _storageService.setSetting(_syncRecoveryKey(vaultId), '');
    }
  }

  Future<void> _writeRecoveryMarker(
    _SyncRecoveryPhase phase, {
    String? itemId,
    String? conflictType,
  }) async {
    final marker = _SyncRecoveryMarker(
      phase: phase,
      localVersion: _localVersion,
      startedAt: DateTime.now(),
      itemId: itemId,
      conflictType: conflictType,
    );
    _pendingRecovery = marker;
    await _storageService.setSetting(
      _syncRecoveryKey(_identityService.vaultId),
      jsonEncode(marker.toJson()),
    );
  }

  Future<void> _clearRecoveryMarker() async {
    _pendingRecovery = null;
    await _storageService.setSetting(
      _syncRecoveryKey(_identityService.vaultId),
      '',
    );
  }

  Future<int> _resumeInterruptedSync(String serverUrl) async {
    final marker = _pendingRecovery;
    if (marker == null) {
      return 0;
    }

    debugPrint(
      '[Sync] Recovering interrupted ${marker.phase.name} phase from version ${marker.localVersion}.',
    );
    final recoveredCount = marker.phase == _SyncRecoveryPhase.pull
        ? await _pullFromVersion(serverUrl, marker.localVersion)
        : await _pullAndMergeLatestSnapshot(serverUrl);
    _queuedConflictNotice ??=
        'Recovered from an interrupted ${marker.phase.name} cycle before continuing sync.';
    await _clearRecoveryMarker();
    return recoveredCount;
  }

  Future<int> _pullFromVersion(String serverUrl, int sinceVersion) async {
    final data = await _fetchRemoteChanges(serverUrl, since: sinceVersion);
    return _applyRemoteChanges(data);
  }

  Future<void> _handleConflict(
    String serverUrl,
    _ConflictException conflict,
  ) async {
    final itemId = conflict.itemId;
    if (itemId == null) {
      return;
    }

    final localAccount = await _storageService.getAccountById(
      itemId,
      includeDeleted: true,
    );
    if (localAccount == null) {
      final localCredential = await _storageService.getTotpCredentialById(
        itemId,
        includeDeleted: true,
      );
      if (localCredential != null) {
        await _handleTotpCredentialConflict(serverUrl, conflict);
        return;
      }
    }

    switch (conflict.conflictType) {
      case 'remote_missing':
        await _handleRemoteMissingConflict(serverUrl, itemId);
        return;
      case 'stale_base_version':
        await _handleStaleBaseConflict(serverUrl, itemId);
        return;
      case 'concurrent_edit':
        await _handleConcurrentEditConflict(serverUrl, itemId);
        return;
      case 'concurrent_delete':
        await _handleConcurrentDeleteConflict(serverUrl, itemId);
        return;
      default:
        if (conflict.serverActual == 0) {
          await _handleRemoteMissingConflict(serverUrl, itemId);
          return;
        }
        await _handleVersionConflict(
          serverUrl,
          itemId,
          conflict.serverIsDeleted == true
              ? 'concurrent_delete'
              : 'stale_base_version',
          fallbackNotice: conflict.serverIsDeleted == true
              ? 'Remote delete was accepted for this item. Restore from history only if this was unexpected.'
              : 'Remote changes were merged locally after a stale-base conflict.',
        );
        return;
    }
  }

  Future<void> _handleTotpCredentialConflict(
    String serverUrl,
    _ConflictException conflict,
  ) async {
    final itemId = conflict.itemId;
    if (itemId == null) return;

    final localCredential = await _storageService.getTotpCredentialById(
      itemId,
      includeDeleted: true,
    );
    if (localCredential == null) return;

    if (conflict.conflictType == 'remote_missing' ||
        conflict.serverActual == 0) {
      await _storageService.saveTotpCredential(
        localCredential.copyWith(
          serverVersion: 0,
          syncStatus: localCredential.isDeleted
              ? SyncStatus.synchronized
              : SyncStatus.pendingPush,
        ),
        isSyncMerge: true,
      );
      _queuedConflictNotice = localCredential.isDeleted
          ? 'Remote 2FA item was already missing. Local delete is marked synchronized.'
          : 'Remote 2FA item was missing. Sync will retry it as a new item.';
      return;
    }

    await _pullAndMergeLatestSnapshot(serverUrl);
    final mergedCredential = await _storageService.getTotpCredentialById(
      itemId,
      includeDeleted: true,
    );
    if (mergedCredential == null) return;

    _queuedConflictNotice =
        mergedCredential.syncStatus == SyncStatus.pendingPush
        ? 'Remote 2FA changes were merged locally. Sync will retry with the reconciled item.'
        : 'Remote 2FA changes were merged locally.';
  }

  Future<void> _handleRemoteMissingConflict(
    String serverUrl,
    String itemId,
  ) async {
    await _pullLatestSnapshot(serverUrl);

    final localItem = await _storageService.getAccountById(
      itemId,
      includeDeleted: true,
    );
    if (localItem == null) {
      return;
    }

    if (localItem.isDeleted) {
      await _storageService.saveAccount(
        localItem.copyWith(
          syncStatus: SyncStatus.synchronized,
          serverVersion: 0,
        ),
        isSyncMerge: true,
      );
      _queuedConflictNotice =
          'Remote record was already missing. Local delete is marked synchronized.';
      return;
    }

    final conflictLog = ConflictLog(
      id: 'remote-missing-${localItem.id}',
      accountId: localItem.id,
      fieldKey: 'record.remote_missing',
      fieldValue: '',
      hlc: localItem.nameHlc,
    );

    await _storageService.saveAccount(
      localItem.copyWith(syncStatus: SyncStatus.synchronized, serverVersion: 0),
      isSyncMerge: true,
    );
    await _storageService.saveConflictLogs([conflictLog]);

    _queuedConflictCount += 1;
    _queuedConflictNotice =
        'Remote record missing. Review the conflict inbox before overwriting.';
  }

  Future<void> _handleStaleBaseConflict(String serverUrl, String itemId) async {
    await _handleVersionConflict(
      serverUrl,
      itemId,
      'stale_base_version',
      fallbackNotice:
          'Remote changes were merged locally after a stale-base conflict.',
    );
  }

  Future<void> _handleConcurrentEditConflict(
    String serverUrl,
    String itemId,
  ) async {
    await _handleVersionConflict(
      serverUrl,
      itemId,
      'concurrent_edit',
      fallbackNotice:
          'Concurrent remote edits were merged locally. Review the conflict inbox before overwriting.',
    );
  }

  Future<void> _handleConcurrentDeleteConflict(
    String serverUrl,
    String itemId,
  ) async {
    await _handleVersionConflict(
      serverUrl,
      itemId,
      'concurrent_delete',
      fallbackNotice:
          'Remote delete was accepted for this item. Restore from history only if this was unexpected.',
    );
  }

  Future<void> _handleVersionConflict(
    String serverUrl,
    String itemId,
    String conflictType, {
    required String fallbackNotice,
  }) async {
    final beforeCount = (await _storageService.getConflictLogs(itemId)).length;
    await _pullAndMergeLatestSnapshot(serverUrl);

    final afterCount = (await _storageService.getConflictLogs(itemId)).length;
    final localItem = await _storageService.getAccountById(
      itemId,
      includeDeleted: true,
    );
    if (localItem == null) {
      return;
    }

    if (localItem.syncStatus == SyncStatus.conflict) {
      _queuedConflictCount += max(1, afterCount - beforeCount);
      _queuedConflictNotice = switch (conflictType) {
        'concurrent_delete' =>
          'Remote delete conflicted with local changes. Review the conflict inbox before restoring.',
        'concurrent_edit' =>
          'Concurrent remote edits were merged locally. Review the conflict inbox before overwriting.',
        _ =>
          'Remote changes were merged locally. Review the conflict inbox before overwriting.',
      };
      return;
    }

    if (localItem.syncStatus == SyncStatus.pendingPush) {
      _queuedConflictNotice = switch (conflictType) {
        'concurrent_delete' =>
          'Remote delete was merged with local data. Sync will retry with the reconciled record.',
        'concurrent_edit' =>
          'Concurrent remote edits were merged locally. Sync will retry with the reconciled record.',
        _ =>
          'Remote changes were merged locally. Sync will retry with the reconciled record.',
      };
      return;
    }

    if (_queuedConflictNotice == null || _queuedConflictNotice!.isEmpty) {
      _queuedConflictNotice = fallbackNotice;
    }
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
        debugPrint(
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

    debugPrint(
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
    try {
      final response = await http
          .post(
            Uri.parse('$serverUrl/vaults/$vaultId/sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pushes': pushPayloads}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 409) {
        await _storageService.markLocalSyncChangesConflict(
          pushingChangeIds,
          response.body,
        );
        throw _ConflictException(response.body);
      }
      _throwIfSyncHttpError(response, phase: 'push');

      final respData = _decodeSyncResponse(response, phase: 'push');
      final acceptedVersions = _readAcceptedVersions(respData);
      acceptedVersionByItemId = _validateAcceptedVersionsForItems(
        acceptedVersions,
        dirtyItems,
      );
    } catch (e) {
      if (e is! _ConflictException) {
        await _storageService.markLocalSyncChangesFailed(
          pushingChangeIds,
          e.toString(),
        );
      }
      rethrow;
    }

    final acceptedChangeIds = <String>[];
    for (final item in dirtyItems) {
      final itemId = _syncItemId(item);
      final newVersion = acceptedVersionByItemId[itemId]!;

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

    await _storageService.setSetting(
      _syncVersionKey(_identityService.vaultId),
      '$_localVersion',
    );
    debugPrint(
      '[Sync] <<< Push Phase Completed. Success items: ${acceptedVersionByItemId.length}',
    );
    return acceptedVersionByItemId.length;
  }

  Map<String, int> _validateAcceptedVersionsForItems(
    Map<String, dynamic> acceptedVersions,
    List<dynamic> dirtyItems,
  ) {
    final acceptedVersionByItemId = <String, int>{};
    for (final item in dirtyItems) {
      final itemId = _syncItemId(item);
      final newVersion = _acceptedVersionFor(acceptedVersions, itemId);
      if (newVersion == null) {
        throw _SyncProtocolException(
          'push response missing accepted version for $itemId.',
        );
      }
      acceptedVersionByItemId[itemId] = newVersion;
    }
    return acceptedVersionByItemId;
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

  Future<String> _getSyncServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    const legacyKey = 'sync_server_url';
    String? url;

    if (_identityService.hasIdentity) {
      final scopedKey = _syncServerUrlKey(_identityService.vaultId);
      url =
          prefs.getString(scopedKey) ??
          await _storageService.getSetting(scopedKey);
      if (url == null) {
        url =
            prefs.getString(legacyKey) ??
            await _storageService.getSetting(legacyKey);
        if (url != null) {
          await prefs.setString(scopedKey, url);
        }
      }
    } else {
      url =
          prefs.getString(legacyKey) ??
          await _storageService.getSetting(legacyKey);
    }

    url = (url ?? _config.serverUrl).trim();
    if (url.isEmpty) {
      return '';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.startsWith('http')) {
      url = 'http://$url';
    }
    return url;
  }

  Future<String?> _readVaultScopedSetting({
    required String vaultId,
    required String scopedKey,
    required String legacyKey,
  }) async {
    final scopedValue = await _storageService.getSetting(scopedKey);
    if (scopedValue != null) {
      return scopedValue;
    }

    final legacyValue = await _storageService.getSetting(legacyKey);
    if (legacyValue != null) {
      await _storageService.setSetting(scopedKey, legacyValue);
      debugPrint(
        '[Sync] Migrated $legacyKey to $scopedKey for vault $vaultId.',
      );
      return legacyValue;
    }

    return null;
  }

  Future<void> _recordSyncTime() async {
    _lastSyncTime = DateTime.now();
    await _storageService.setSetting(
      _syncLastTimeKey(_identityService.vaultId),
      _lastSyncTime!.toIso8601String(),
    );
  }

  bool _isMobileLoopbackUrl(String serverUrl) {
    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final host = Uri.tryParse(serverUrl)?.host.toLowerCase() ?? '';
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  bool _looksLikeCleartextBlock(String message) {
    final lower = message.toLowerCase();
    return lower.contains('cleartext') ||
        lower.contains('insecure http') ||
        lower.contains('not permitted');
  }

  void _throwIfSyncHttpError(http.Response response, {required String phase}) {
    if (response.statusCode == 200) {
      return;
    }

    final serverError = _extractServerErrorPayload(response.body);
    throw _SyncHttpException(
      phase: phase,
      statusCode: response.statusCode,
      serverMessage: serverError.message,
      conflictType: serverError.conflictType,
      itemId: serverError.itemId,
    );
  }

  _SyncServerErrorPayload _extractServerErrorPayload(String body) {
    if (body.isEmpty) {
      return const _SyncServerErrorPayload();
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        final conflictType = decoded['conflict_type'];
        final itemId = decoded['item_id'];
        return _SyncServerErrorPayload(
          message: error is String && error.isNotEmpty ? error : null,
          conflictType: conflictType is String ? conflictType : null,
          itemId: itemId is String ? itemId : null,
        );
      }
    } catch (_) {
      // Ignore non-JSON error bodies and fall back to generic status text.
    }

    return const _SyncServerErrorPayload();
  }

  void _startPeriodicSync() {
    _stopPeriodicSync();
    if (_config.syncInterval.inSeconds <= 0) return;
    _syncTimer = Timer.periodic(_config.syncInterval, (_) => syncNow());
  }

  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  void _updateState(SyncState newState) {
    _state = newState;
    if (newState != SyncState.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void _setError(String message, {String? statusNote}) {
    _statusNote = statusNote ?? message;
    _errorMessage = message;
    _updateState(SyncState.error);
  }

  @override
  void dispose() {
    _stopPeriodicSync();
    super.dispose();
  }
}

class _ConflictException implements Exception {
  final String serverResponse;
  final String? conflictType;
  final String? itemId;
  final int? yourBase;
  final int? serverActual;
  final bool? serverIsDeleted;

  _ConflictException._(
    this.serverResponse, {
    this.conflictType,
    this.itemId,
    this.yourBase,
    this.serverActual,
    this.serverIsDeleted,
  });

  factory _ConflictException(String serverResponse) {
    try {
      final json = jsonDecode(serverResponse) as Map<String, dynamic>;
      return _ConflictException._(
        serverResponse,
        conflictType: json['conflict_type'] as String?,
        itemId: json['item_id'] as String?,
        yourBase: json['your_base'] as int?,
        serverActual: json['server_actual'] as int?,
        serverIsDeleted: json['server_is_deleted'] as bool?,
      );
    } catch (_) {
      return _ConflictException._(serverResponse);
    }
  }
}

class _SyncServerErrorPayload {
  final String? message;
  final String? conflictType;
  final String? itemId;

  const _SyncServerErrorPayload({this.message, this.conflictType, this.itemId});
}

class _SyncHttpException implements Exception {
  final String phase;
  final int statusCode;
  final String? serverMessage;
  final String? conflictType;
  final String? itemId;

  const _SyncHttpException({
    required this.phase,
    required this.statusCode,
    this.serverMessage,
    this.conflictType,
    this.itemId,
  });

  String get userMessage {
    if (statusCode == 503) {
      return serverMessage ??
          'Sync server storage is temporarily unavailable. Retry later.';
    }
    if (serverMessage != null && serverMessage!.isNotEmpty) {
      return serverMessage!;
    }
    return '${phase[0].toUpperCase()}${phase.substring(1)} HTTP $statusCode';
  }

  String get logMessage {
    final prefix =
        '${phase[0].toUpperCase()}${phase.substring(1)} HTTP $statusCode';
    if (serverMessage == null || serverMessage!.isEmpty) {
      return prefix;
    }
    return '$prefix: $serverMessage';
  }
}

class SyncResult {
  final bool success;
  final bool pushed;
  final bool pulled;
  final String? error;
  final int version;
  final int conflictCount;
  final String? notice;

  SyncResult._({
    required this.success,
    this.pushed = false,
    this.pulled = false,
    this.error,
    this.version = 0,
    this.conflictCount = 0,
    this.notice,
  });

  factory SyncResult.success({
    bool pushed = false,
    bool pulled = false,
    int version = 0,
    int conflictCount = 0,
    String? notice,
  }) {
    return SyncResult._(
      success: true,
      pushed: pushed,
      pulled: pulled,
      version: version,
      conflictCount: conflictCount,
      notice: notice,
    );
  }

  factory SyncResult.failure(String error) {
    return SyncResult._(success: false, error: error);
  }
}
