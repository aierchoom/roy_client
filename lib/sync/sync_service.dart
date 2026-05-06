import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:secret_roy/core/app_logger.dart';
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
export 'sync_service_types.dart';
import 'sync_service_types.dart';
import 'totp_credential_merge_engine.dart';

part 'sync_service_pull.dart';
part 'sync_service_push.dart';
part 'sync_service_conflict.dart';

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
  int _serverGeneration = 0;
  bool _isDirty = false;
  String _lastConflictMsg = '';
  int _queuedConflictCount = 0;
  String? _queuedConflictNotice;
  SyncRecoveryMarker? _pendingRecovery;
  bool _disposed = false;

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
      _state == SyncState.idle ||
      _state == SyncState.connecting ||
      _state == SyncState.pulling ||
      _state == SyncState.pushing ||
      _state == SyncState.conflictRecovery;
  bool get isSyncing =>
      _state == SyncState.connecting ||
      _state == SyncState.pulling ||
      _state == SyncState.pushing ||
      _state == SyncState.conflictRecovery;
  int get localVersion => _localVersion;
  bool get isDirty => _isDirty;

  String _syncVersionKey(String vaultId) => 'sync_version_$vaultId';

  String _syncLastTimeKey(String vaultId) => 'sync_last_time_$vaultId';

  String _syncDirtyKey(String vaultId) => 'sync_dirty_$vaultId';

  String _syncRecoveryKey(String vaultId) => 'sync_recovery_$vaultId';

  String _syncServerUrlKey(String vaultId) => 'sync_server_url_$vaultId';

  String _syncGenerationKey(String vaultId) => 'sync_generation_$vaultId';

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

    final generationStr = await _readVaultScopedSetting(
      vaultId: vaultId,
      scopedKey: _syncGenerationKey(vaultId),
      legacyKey: 'sync_generation',
    );
    _serverGeneration = int.tryParse(generationStr ?? '') ?? 0;

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

    AppLogger.d('[Sync] Initialized. Vault: $vaultId, Version: $_localVersion');
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
        SyncState.networkUnreachable,
        'Sync server URL not configured.',
        statusNote: 'Set a sync server address before trying again.',
      );
      return SyncResult.failure('Sync server URL not configured.');
    }
    if (!_identityService.hasIdentity) {
      _setError(
        SyncState.authError,
        'Identity not established.',
        statusNote:
            'Unlock the vault and recreate local identity before syncing.',
      );
      return SyncResult.failure('Identity not established.');
    }
    if (_isMobileLoopbackUrl(serverUrl)) {
      _setError(
        SyncState.networkUnreachable,
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
          _updateState(SyncState.connecting);
          await _writeRecoveryMarker(SyncRecoveryPhase.pull);
          _updateState(SyncState.pulling);
          final pullCount = await _runPullPhase(serverUrl);
          await _writeRecoveryMarker(SyncRecoveryPhase.push);
          _updateState(SyncState.pushing);
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
          _updateState(SyncState.idle);

          return SyncResult.success(
            pulled: recoveredCount > 0 || pullCount > 0,
            pushed: pushCount > 0,
            version: _localVersion,
            conflictCount: _queuedConflictCount,
            notice: _queuedConflictNotice,
          );
        } on ConflictException catch (ce) {
          _lastConflictMsg = ce.serverResponse;
          await _writeRecoveryMarker(
            SyncRecoveryPhase.conflictRecovery,
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
        SyncState.protocolError,
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
      _updateState(SyncState.networkUnreachable);
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
        _updateState(SyncState.networkUnreachable);
        return SyncResult.failure('offline');
      }

      if (_looksLikeCleartextBlock(message)) {
        _setError(
          SyncState.protocolError,
          'Cleartext HTTP blocked: $message',
          statusNote:
              'Use HTTPS or allow local HTTP traffic for this device build.',
        );
        return SyncResult.failure('cleartext_blocked');
      }
      _setError(
        SyncState.networkUnreachable,
        'Sync failed: $message',
        statusNote: message,
      );
      return SyncResult.failure(message);
    }

    if (e is SyncHttpException) {
      if (e.conflictType == 'generation_mismatch') {
        _statusNote =
            'Server vault has been reset. A full sync will recover your data on the next attempt.';
        _updateState(SyncState.protocolError);
        return SyncResult.failure('generation_mismatch');
      }
      if (e.conflictType == 'invalid_payload') {
        _setError(
          SyncState.protocolError,
          'Sync payload rejected: ${e.logMessage}',
          statusNote:
              'The sync server rejected a local encrypted payload. Reopen the item and retry; inspect client logs if it repeats.',
        );
        return SyncResult.failure(e.userMessage);
      }
      if (e.statusCode >= 500) {
        _setError(
          SyncState.serverError,
          'Sync failed: ${e.logMessage}',
          statusNote: e.userMessage,
        );
      } else {
        _setError(
          SyncState.protocolError,
          'Sync failed: ${e.logMessage}',
          statusNote: e.userMessage,
        );
      }
      return SyncResult.failure(e.userMessage);
    }

    if (e is SyncProtocolException) {
      _setError(
        SyncState.protocolError,
        'Sync protocol invalid: ${e.message}',
        statusNote:
            'The sync server returned data this client could not safely process. Check server version and logs.',
      );
      return SyncResult.failure(e.message);
    }

    if (e is SyncPayloadException) {
      _setError(
        SyncState.protocolError,
        'Sync payload invalid: ${e.message}',
        statusNote:
            'The remote payload could not be verified. Check key consistency across devices.',
      );
      return SyncResult.failure(e.message);
    }

    // Default fallback for unexpected errors
    AppLogger.d('Sync loop failed: $e\n$stack');
    _setError(
      SyncState.protocolError,
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

  Map<String, dynamic> _decodeSyncResponse(
    http.Response response, {
    required String phase,
  }) {
    try {
      final decoded = jsonDecode(response.body);
      return _asStringKeyedMap(decoded, '$phase response');
    } on SyncProtocolException {
      rethrow;
    } catch (_) {
      throw SyncProtocolException('$phase response is not valid JSON.');
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
    throw SyncProtocolException('$label must be a JSON object.');
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
    throw SyncProtocolException('$label must be a non-negative integer.');
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
      _pendingRecovery = SyncRecoveryMarker.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      _pendingRecovery = null;
      await _storageService.setSetting(_syncRecoveryKey(vaultId), '');
    }
  }

  Future<void> _writeRecoveryMarker(
    SyncRecoveryPhase phase, {
    String? itemId,
    String? conflictType,
  }) async {
    final marker = SyncRecoveryMarker(
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

    AppLogger.d(
      '[Sync] Recovering interrupted ${marker.phase.name} phase from version ${marker.localVersion}.',
    );
    final recoveredCount = marker.phase == SyncRecoveryPhase.pull
        ? await _pullFromVersion(serverUrl, marker.localVersion)
        : await _pullAndMergeLatestSnapshot(serverUrl);
    _queuedConflictNotice ??=
        'Recovered from an interrupted ${marker.phase.name} cycle before continuing sync.';
    await _clearRecoveryMarker();
    return recoveredCount;
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
      url = 'https://$url';
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
      AppLogger.d(
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
    throw SyncHttpException(
      phase: phase,
      statusCode: response.statusCode,
      serverMessage: serverError.message,
      conflictType: serverError.conflictType,
      itemId: serverError.itemId,
    );
  }

  SyncServerErrorPayload _extractServerErrorPayload(String body) {
    if (body.isEmpty) {
      return const SyncServerErrorPayload();
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        final conflictType = decoded['conflict_type'];
        final itemId = decoded['item_id'];
        return SyncServerErrorPayload(
          message: error is String && error.isNotEmpty ? error : null,
          conflictType: conflictType is String ? conflictType : null,
          itemId: itemId is String ? itemId : null,
        );
      }
    } catch (_) {
      // Ignore non-JSON error bodies and fall back to generic status text.
    }

    return const SyncServerErrorPayload();
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
    if (!newState.isError) {
      _errorMessage = null;
    }
    if (!_disposed) notifyListeners();
  }

  void _setError(SyncState errorState, String message, {String? statusNote}) {
    assert(errorState.isError);
    _statusNote = statusNote ?? message;
    _errorMessage = message;
    _updateState(errorState);
  }

  @override
  void dispose() {
    _disposed = true;
    _stopPeriodicSync();
    super.dispose();
  }
}

