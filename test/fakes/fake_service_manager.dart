import 'package:secret_roy/services/service_manager.dart';

import '../sync/sync_server_test_harness.dart';
import 'fake_auto_lock_service.dart';
import 'fake_biometric_auth_service.dart';
import 'fake_identity_service.dart';
import 'fake_sync_service.dart';

ServiceManager createFakeServiceManager({
  ServiceManagerState initialState = ServiceManagerState.unlocked,
  FakeSecureStorageService? secureStorage,
}) {
  return ServiceManager.testable(
    secureStorageService: secureStorage ?? FakeSecureStorageService(),
    identityService: FakeIdentityService(),
    syncService: FakeSyncService(),
    autoLockService: FakeAutoLockService(),
    biometricService: FakeBiometricAuthService(),
    initialState: initialState,
  );
}
