import 'package:secret_roy/sync/sync_service.dart';

import '../sync/sync_server_test_harness.dart';
import 'fake_identity_service.dart';

class FakeSyncService extends SyncService {
  FakeSyncService()
      : super(
          storageService: FakeSecureStorageService(),
          identityService: FakeIdentityService(),
          config: const SyncConfig(serverUrl: ''),
        );

  @override
  Future<SyncResult> syncNow() async => SyncResult.success();

  @override
  Future<bool> connect() async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> reconcileDirtyState() async {}

  @override
  Future<void> reset() async {}
}
