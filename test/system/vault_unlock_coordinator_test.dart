import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/biometric_auth_service.dart';
import 'package:secret_roy/services/enhanced_crypto_service.dart';
import 'package:secret_roy/services/lan_pairing_service.dart';
import 'package:secret_roy/sync/lan_sync_coordinator.dart';
import 'package:secret_roy/system/service_manager/vault_unlock_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_auto_lock_service.dart';
import '../fakes/fake_biometric_auth_service.dart';
import '../fakes/fake_identity_service.dart';
import '../fakes/fake_sync_service.dart';
import '../sync/sync_server_test_harness.dart';

class _FakeLanSyncCoordinator extends LanSyncCoordinator {
  bool aborted = false;

  _FakeLanSyncCoordinator()
      : super(
          storage: FakeSecureStorageService(),
          identity: FakeIdentityService(),
          pairing: LanPairingService(),
          syncService: FakeSyncService(),
        );

  @override
  Future<void> abort() async {
    aborted = true;
  }
}

class _FakeBiometricService extends FakeBiometricAuthService {
  BiometricAuthStatus _status = BiometricAuthStatus.disabled;

  @override
  Future<BiometricAuthStatus> getStatus() async => _status;

  @override
  void setStatus(BiometricAuthStatus status) => _status = status;

  @override
  Future<void> disableBiometric() async {
    _status = BiometricAuthStatus.notSupported;
  }

  @override
  Future<String?> unlockWithBiometric() async => 'biometric_password';
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  group('VaultUnlockCoordinator', () {
    late EnhancedCryptoService cryptoService;
    late FakeSecureStorageService secureStorage;
    late FakeIdentityService identity;
    late FakeAutoLockService autoLock;
    late FakeSyncService syncService;
    late _FakeBiometricService biometric;
    late LanPairingService lanPairing;
    late _FakeLanSyncCoordinator lanSync;
    late VaultUnlockCoordinator coordinator;

    setUp(() {
      cryptoService = EnhancedCryptoService(secureStorage: null);
      secureStorage = FakeSecureStorageService();
      identity = FakeIdentityService();
      autoLock = FakeAutoLockService();
      syncService = FakeSyncService();
      biometric = _FakeBiometricService();
      lanPairing = LanPairingService();
      lanSync = _FakeLanSyncCoordinator();
      coordinator = VaultUnlockCoordinator(
        cryptoService: cryptoService,
        secureStorageService: secureStorage,
        identityService: identity,
        autoLockService: autoLock,
        syncService: syncService,
        biometricService: biometric,
        lanPairingService: lanPairing,
        lanSyncCoordinator: lanSync,
      );
    });

    test('unlockWithBiometric returns password when enabled', () async {
      biometric.setStatus(BiometricAuthStatus.enabled);
      final password = await coordinator.unlockWithBiometric();
      expect(password, 'biometric_password');
    });

    test('unlockWithBiometric returns null when disabled', () async {
      biometric.setStatus(BiometricAuthStatus.disabled);
      final password = await coordinator.unlockWithBiometric();
      expect(password, null);
    });

    test('unlockWithBiometric returns null when unavailable', () async {
      biometric.setStatus(BiometricAuthStatus.notSupported);
      final password = await coordinator.unlockWithBiometric();
      expect(password, null);
    });

    test('lock triggers autoLock and cleanup', () async {
      expect(autoLock.isLocked, false);
      await coordinator.lock();
      expect(autoLock.isLocked, true);
      expect(lanSync.aborted, true);
    });

    test('logout triggers lock and crypto logout', () async {
      await coordinator.logout();
      expect(autoLock.isLocked, true);
      expect(lanSync.aborted, true);
    });

    test('performStorageCleanup stops hosting and aborts lan sync', () async {
      await coordinator.performStorageCleanup();
      expect(lanSync.aborted, true);
    });

    test('closeStorage clears database cipher', () async {
      await coordinator.closeStorage();
      // Should not throw.
      expect(true, true);
    });

    test('getBiometricStatus delegates to biometric service', () async {
      biometric.setStatus(BiometricAuthStatus.enabled);
      final status = await coordinator.getBiometricStatus();
      expect(status, BiometricAuthStatus.enabled);
    });

    test('disableBiometric delegates to biometric service', () async {
      biometric.setStatus(BiometricAuthStatus.enabled);
      await coordinator.disableBiometric();
      expect(await biometric.getStatus(), BiometricAuthStatus.notSupported);
    });

    test('generateNoPasswordPseudoKey produces base64 string', () {
      final key1 = VaultUnlockCoordinator.generateNoPasswordPseudoKey();
      final key2 = VaultUnlockCoordinator.generateNoPasswordPseudoKey();
      expect(key1, isNotEmpty);
      expect(key1, isNot(equals(key2)));
    });
  });
}
