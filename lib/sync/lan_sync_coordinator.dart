import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:secret_roy/core/app_logger.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/lan_pairing_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';

import 'lan_sync_client.dart';
import 'lan_sync_host_handler.dart';
import 'lan_sync_session.dart';
import 'sync_service.dart';

/// Central coordinator for LAN account data synchronization.
///
/// Manages the lifecycle of LAN sync sessions and enforces the
/// three red-line boundaries:
/// 1. Never reads or writes `_localVersion` / `serverVersion` settings.
/// 2. Never writes `syncStatus = synchronized` (LAN sync only produces `pendingPush`).
/// 3. Mutual exclusion with server sync channel.
class LanSyncCoordinator extends ChangeNotifier {
  final SecureStorageService _storage;
  final IdentityService _identity;
  final LanPairingService _pairing;
  final SyncService _syncService;

  LanSyncHostHandler? _hostHandler;
  LanSyncClient? _client;

  LanSyncSessionState? _currentSession;
  String? _currentRole; // 'host' or 'requester'

  bool _isBusy = false;

  LanSyncCoordinator({
    required SecureStorageService storage,
    required IdentityService identity,
    required LanPairingService pairing,
    required SyncService syncService,
  })  : _storage = storage,
        _identity = identity,
        _pairing = pairing,
        _syncService = syncService;

  bool get isBusy => _isBusy;
  LanSyncSessionState? get currentSession => _currentSession;
  String? get currentRole => _currentRole;

  /// Returns the conflict preview for the current host session.
  /// Each entry contains: {'account_id', 'field_key', 'field_value'}.
  List<Map<String, dynamic>>? get currentConflictPreview {
    if (_hostHandler == null || _currentSession == null) return null;
    final sessionId = _currentSession!.sessionId;
    // Access internal session state via handleResultQuery
    // Since handleResultQuery is async and we need sync getter,
    // we expose a direct method on hostHandler instead.
    return _hostHandler!.getConflictPreview(sessionId);
  }

  /// Starts LAN sync as the Host (A device).
  ///
  /// Must be called after successful LAN pairing claim.
  /// Returns the session ID if started successfully.
  Future<String?> startAsHost() async {
    if (_isBusy) {
      AppLogger.d('[LAN-Coord] Already busy, cannot start as host');
      return null;
    }
    if (_syncService.isSyncing) {
      AppLogger.d('[LAN-Coord] Server sync in progress, deferring LAN sync');
      return null;
    }

    _isBusy = true;
    _currentRole = 'host';
    notifyListeners();

    try {
      _hostHandler = LanSyncHostHandler(
        storage: _storage,
        identity: _identity,
      );

      // Register with LanPairingService's HTTP server
      _pairing.attachSyncHandler(_hostHandler!);

      final sessionResult = await _hostHandler!.handleStart(_identity.deviceId);
      _currentSession = LanSyncSessionState(
        sessionId: sessionResult['session_id'] as String,
        phase: LanSyncPhase.connecting,
        startedAt: DateTime.now(),
      );

      AppLogger.d('[LAN-Coord] Started as host, session=${_currentSession!.sessionId}');
      notifyListeners();
      return _currentSession!.sessionId;
    } catch (e) {
      _isBusy = false;
      _currentRole = null;
      AppLogger.d('[LAN-Coord] Failed to start as host: $e');
      notifyListeners();
      return null;
    }
  }

  /// Starts and runs the full LAN sync as the Requester (B device).
  ///
  /// Discovers the host via LanPairingService and runs the complete flow.
  Future<LanSyncResult> startAndRunAsRequester() async {
    if (_isBusy) {
      AppLogger.d('[LAN-Coord] Already busy, cannot start as requester');
      return LanSyncResult(success: false, error: 'Another LAN sync is in progress');
    }
    if (_syncService.isSyncing) {
      AppLogger.d('[LAN-Coord] Server sync in progress, deferring LAN sync');
      return LanSyncResult(success: false, error: 'Server sync is in progress');
    }

    _isBusy = true;
    _currentRole = 'requester';
    notifyListeners();

    try {
      final hostInfo = await _pairing.discoverHost();
      if (hostInfo == null) {
        throw const LanSyncException('HOST_NOT_FOUND', 'No LAN host discovered');
      }

      _client = LanSyncClient(
        storage: _storage,
        identity: _identity,
        syncService: _syncService,
      );

      final result = await _client!.startSync(
        hostAddress: hostInfo.address,
        hostPort: hostInfo.port,
        onProgress: (phase, message) {
          _currentSession = LanSyncSessionState(
            sessionId: _client!.sessionId ?? 'unknown',
            phase: phase,
            startedAt: _currentSession?.startedAt ?? DateTime.now(),
          );
          notifyListeners();
        },
      );

      _isBusy = false;
      if (result.success) {
        _currentSession = _currentSession?.copyWith(phase: LanSyncPhase.completed);
      } else {
        _currentSession = _currentSession?.copyWith(phase: LanSyncPhase.failed);
      }
      notifyListeners();
      return result;
    } catch (e) {
      _isBusy = false;
      _currentSession = _currentSession?.copyWith(phase: LanSyncPhase.failed);
      AppLogger.d('[LAN-Coord] Failed to start as requester: $e');
      notifyListeners();
      return LanSyncResult(success: false, error: e.toString());
    }
  }

  /// Host triggers merge after receiving all peer data.
  Future<void> hostTriggerMerge(String sessionId) async {
    if (_hostHandler == null) return;
    try {
      await _hostHandler!.triggerMerge(sessionId);
      // Re-query session state
      final phase = _hostHandler!.getSessionPhase(sessionId);
      if (phase != null) {
        _currentSession = _currentSession?.copyWith(phase: phase);
      }
      notifyListeners();
    } catch (e) {
      AppLogger.d('[LAN-Coord] Host merge failed: $e');
    }
  }

  /// Host commits merged data after conflict resolution.
  Future<void> hostCommit(String sessionId) async {
    if (_hostHandler == null) return;
    try {
      await _hostHandler!.commit(sessionId);
      _isBusy = false;
      _currentSession = _currentSession?.copyWith(phase: LanSyncPhase.completed);
      notifyListeners();

      // Stop hosting after sync completes
      _pairing.detachSyncHandler();
    } catch (e) {
      AppLogger.d('[LAN-Coord] Host commit failed: $e');
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Aborts the current session.
  Future<void> abort() async {
    if (_currentSession == null) return;

    final sessionId = _currentSession!.sessionId;

    if (_hostHandler != null) {
      await _hostHandler!.handleAbort(sessionId);
      _pairing.detachSyncHandler();
    }
    if (_client != null) {
      await _client!.abort();
    }

    _updatePhase(LanSyncPhase.interrupted);
    _isBusy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _hostHandler?.dispose();
    _client?.reset();
    super.dispose();
  }

  // === Private ===

  void _updatePhase(LanSyncPhase phase) {
    _currentSession = _currentSession!.copyWith(phase: phase);
    notifyListeners();
  }
}
