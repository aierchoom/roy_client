import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_crypto_service.dart';
import '../fakes/fake_identity_service.dart';
import '../fakes/fake_sync_service.dart';
import '../fakes/fake_auto_lock_service.dart';
import '../fakes/fake_biometric_auth_service.dart';
import '../sync/sync_server_test_harness.dart';

final _mockStorage = <String, String?>{};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map<dynamic, dynamic>;
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return key != null ? _mockStorage[key] : null;
        case 'write':
          if (key != null) {
            _mockStorage[key] = args['value'] as String?;
          }
          return null;
        case 'delete':
          if (key != null) {
            _mockStorage.remove(key);
          }
          return null;
        case 'deleteAll':
          _mockStorage.clear();
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    _mockStorage.clear();
    ServiceManager.resetInstance();
  });

  group('no-password mode with pseudo key', () {
    test('enableNoPasswordMode generates and stores pseudo key', () async {
      final manager = ServiceManager.testable(
        cryptoService: FakeCryptoService(),
        secureStorageService: FakeSecureStorageService(),
        identityService: FakeIdentityService(),
        syncService: FakeSyncService(),
        autoLockService: FakeAutoLockService(),
        biometricService: FakeBiometricAuthService(),
        initialState: ServiceManagerState.locked,
      );
      ServiceManager.setInstanceForTesting(manager);

      await manager.enableNoPasswordMode();

      expect(await manager.isNoPasswordMode(), isTrue);
      const secureStorage = FlutterSecureStorage();
      final pseudoKey = await secureStorage.read(
        key: 'no_password_pseudo_key',
      );
      expect(pseudoKey, isNotNull);
      expect(pseudoKey!.isNotEmpty, isTrue);
    });

    test(
      'unlockWithPassword resolves empty password to pseudo key '
      'in no-password mode',
      () async {
        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(key: 'no_password_mode', value: 'true');
        await secureStorage.write(
          key: 'no_password_pseudo_key',
          value: 'test_pseudo_key_123',
        );

        final manager = ServiceManager.testable(
          cryptoService: FakeCryptoService(),
          secureStorageService: FakeSecureStorageService(),
          identityService: FakeIdentityService(),
          syncService: FakeSyncService(),
          autoLockService: FakeAutoLockService(),
          biometricService: FakeBiometricAuthService(),
          initialState: ServiceManagerState.locked,
        );
        ServiceManager.setInstanceForTesting(manager);

        final result = await manager.unlockWithPassword('');
        expect(result, UnlockResult.success);
      },
    );

    test('disableNoPasswordMode clears pseudo key', () async {
      const secureStorage = FlutterSecureStorage();
      await secureStorage.write(key: 'no_password_mode', value: 'true');
      await secureStorage.write(
        key: 'no_password_pseudo_key',
        value: 'test_key',
      );

      final manager = ServiceManager.testable(
        cryptoService: FakeCryptoService(),
        secureStorageService: FakeSecureStorageService(),
        identityService: FakeIdentityService(),
        syncService: FakeSyncService(),
        autoLockService: FakeAutoLockService(),
        biometricService: FakeBiometricAuthService(),
        initialState: ServiceManagerState.locked,
      );
      ServiceManager.setInstanceForTesting(manager);

      await manager.disableNoPasswordMode();

      expect(await manager.isNoPasswordMode(), isFalse);
      final pseudoKey = await secureStorage.read(
        key: 'no_password_pseudo_key',
      );
      expect(pseudoKey, isNull);
    });

    test(
      'legacy no-password mode without pseudo key still unlocks '
      'and migrates on success',
      () async {
        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(key: 'no_password_mode', value: 'true');
        // Intentionally omit no_password_pseudo_key to simulate legacy user.

        final cryptoService = FakeCryptoService()..setAllowEmptyPassword(true);
        final manager = ServiceManager.testable(
          cryptoService: cryptoService,
          secureStorageService: FakeSecureStorageService(),
          identityService: FakeIdentityService(),
          syncService: FakeSyncService(),
          autoLockService: FakeAutoLockService(),
          biometricService: FakeBiometricAuthService(),
          initialState: ServiceManagerState.locked,
        );
        ServiceManager.setInstanceForTesting(manager);

        final result = await manager.unlockWithPassword('');
        expect(result, UnlockResult.success);

        // Wait for async migration to complete.
        await Future.delayed(const Duration(milliseconds: 200));

        final pseudoKey = await secureStorage.read(
          key: 'no_password_pseudo_key',
        );
        expect(pseudoKey, isNotNull);
        expect(pseudoKey!.isNotEmpty, isTrue);
      },
    );

    test('normal password unlock bypasses pseudo-key resolution', () async {
      // Even if no_password_mode is false, a non-empty password should
      // be passed through directly.

      final manager = ServiceManager.testable(
        cryptoService: FakeCryptoService(),
        secureStorageService: FakeSecureStorageService(),
        identityService: FakeIdentityService(),
        syncService: FakeSyncService(),
        autoLockService: FakeAutoLockService(),
        biometricService: FakeBiometricAuthService(),
        initialState: ServiceManagerState.locked,
      );
      ServiceManager.setInstanceForTesting(manager);

      final result = await manager.unlockWithPassword('normal_password');
      expect(result, UnlockResult.success);
    });
  });
}
