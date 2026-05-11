import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_auto_lock_service.dart';
import '../fakes/fake_biometric_auth_service.dart';
import '../fakes/fake_crypto_service.dart';
import '../fakes/fake_identity_service.dart';
import '../fakes/fake_sync_service.dart';
import '../sync/sync_server_test_harness.dart';

ServiceManager _createFakeManager({
  ServiceManagerState initialState = ServiceManagerState.uninitialized,
}) {
  return ServiceManager.testable(
    cryptoService: FakeCryptoService(),
    identityService: FakeIdentityService(),
    secureStorageService: FakeSecureStorageService(),
    syncService: FakeSyncService(),
    autoLockService: FakeAutoLockService(),
    biometricService: FakeBiometricAuthService(),
    initialState: initialState,
  );
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return null;
    });
  });

  group('ServiceManager state machine', () {
    testWidgets('initial state is uninitialized', (tester) async {
      final manager = _createFakeManager();
      expect(manager.state, ServiceManagerState.uninitialized);
    });

    testWidgets('initialize transitions to locked', (tester) async {
      final manager = _createFakeManager();
      await manager.initialize();
      expect(manager.state, ServiceManagerState.locked);
    });

    testWidgets('unlockWithPassword transitions to unlocked', (tester) async {
      final manager = _createFakeManager(initialState: ServiceManagerState.locked);
      final result = await manager.unlockWithPassword('password');
      expect(result, UnlockResult.success);
      expect(manager.state, ServiceManagerState.unlocked);
    });

    testWidgets('unlockWithPassword with empty password returns invalid', (
      tester,
    ) async {
      final manager = _createFakeManager(initialState: ServiceManagerState.locked);
      final result = await manager.unlockWithPassword('');
      expect(result, UnlockResult.invalidPassword);
      expect(manager.state, ServiceManagerState.locked);
    });

    testWidgets('lock transitions from unlocked to locked', (tester) async {
      final manager = _createFakeManager(initialState: ServiceManagerState.unlocked);
      manager.lock();
      expect(manager.state, ServiceManagerState.locked);
    });

    testWidgets('resetApplication transitions error to locked', (tester) async {
      final manager = _createFakeManager(initialState: ServiceManagerState.error);
      await manager.resetApplication();
      expect(manager.state, ServiceManagerState.locked);
    });

    testWidgets('unlocking is idempotent', (tester) async {
      final manager = _createFakeManager(initialState: ServiceManagerState.unlocking);
      final result = await manager.unlockWithPassword('password');
      expect(result, UnlockResult.alreadyInProgress);
    });

    testWidgets('notify listeners on state change', (tester) async {
      final manager = _createFakeManager();
      var notified = false;
      manager.addListener(() => notified = true);
      await manager.initialize();
      expect(notified, isTrue);
    });
  });
}
