import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
import 'package:secret_roy/sync/sync_service.dart';

import 'sync_server_url_store.dart';

/// 同步协调器：封装 SyncService 的连接、断开、同步拉取与服务器 URL 管理。
///
/// 将 ServiceManager 中的同步职责拆分为独立的 coordinator，
/// 保持 ServiceManager 作为 facade 仅负责状态管理与通知。
class SyncCoordinator {
  final SyncService _syncService;
  final IdentityService _identityService;
  final SecureStorageService _secureStorageService;
  final SyncServerUrlStore _syncServerUrlStore;

  SyncCoordinator({
    required SyncService syncService,
    required IdentityService identityService,
    required SecureStorageService secureStorageService,
    required SyncServerUrlStore syncServerUrlStore,
  })  : _syncService = syncService,
        _identityService = identityService,
        _secureStorageService = secureStorageService,
        _syncServerUrlStore = syncServerUrlStore;

  Future<bool> connect() => _syncService.connect();

  Future<void> disconnect() => _syncService.disconnect();

  Future<SyncResult> syncNow() async {
    final result = await _syncService.syncNow();
    if (!result.success || !result.pulled) {
      return result;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    await _identityService.initialize();
    await _secureStorageService.initialize(
      deviceId: _identityService.deviceId,
    );
    await _syncService.initialize();

    return SyncResult.success(
      pulled: result.pulled,
      pushed: result.pushed,
      version: _syncService.localVersion,
      conflictCount: result.conflictCount,
      notice: result.notice,
    );
  }

  // === Sync state passthrough ===

  SyncState get state => _syncService.state;

  String? get errorMessage => _syncService.errorMessage;

  String? get statusNote => _syncService.statusNote;

  bool get isConnected => _syncService.isConnected;

  int get localVersion => _syncService.localVersion;

  bool get isDirty => _syncService.isDirty;

  SyncService get syncService => _syncService;

  // === Server URL ===

  Future<String?> getServerUrl() async {
    return _syncServerUrlStore.read(
      vaultId: _identityService.hasIdentity ? _identityService.vaultId : null,
    );
  }

  Future<void> setServerUrl(String url) async {
    await _syncServerUrlStore.write(
      url,
      vaultId: _identityService.vaultId,
    );
    await disconnect();
  }

  Future<String> resolveServerUrl({bool allowEmpty = false}) async {
    return _syncServerUrlStore.resolve(
      vaultId: _identityService.hasIdentity ? _identityService.vaultId : null,
      allowEmpty: allowEmpty,
    );
  }
}
