import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart'
    show AuthMessages;
import 'package:secret_roy/services/biometric_auth_service.dart';
import 'package:secret_roy/services/identity_service.dart';

class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values;

  _MemorySecureKeyValueStore([Map<String, String>? initialValues])
    : values = Map<String, String>.from(initialValues ?? const {});

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

class _MockLocalAuthentication extends LocalAuthentication {
  final bool _authenticateResult;

  _MockLocalAuthentication({bool authenticateResult = true})
    : _authenticateResult = authenticateResult;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    return _authenticateResult;
  }

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    return [BiometricType.fingerprint];
  }
}

void main() {
  test('enableBiometric encrypts and stores master password', () async {
    final store = _MemorySecureKeyValueStore();
    final service = BiometricAuthService(
      secureStorage: store,
      localAuth: _MockLocalAuthentication(authenticateResult: true),
    );

    final result = await service.enableBiometric('my_secret_password');
    expect(result, BiometricSetupResult.success);

    // Verify the legacy plaintext key is gone
    expect(store.values.containsKey('master_key_biometric'), isFalse);

    // Verify encrypted keys exist
    expect(store.values.containsKey('biometric_wrapping_key'), isTrue);
    expect(store.values.containsKey('biometric_wrapped_key'), isTrue);
    expect(store.values['biometric_wrapped_key'], contains('ciphertext'));
  });

  test('unlockWithBiometric decrypts stored master password', () async {
    final store = _MemorySecureKeyValueStore();
    final service = BiometricAuthService(
      secureStorage: store,
      localAuth: _MockLocalAuthentication(authenticateResult: true),
    );

    await service.enableBiometric('my_secret_password');
    final unlocked = await service.unlockWithBiometric();
    expect(unlocked, 'my_secret_password');
  });

  test('unlockWithBiometric falls back to legacy plaintext', () async {
    final store = _MemorySecureKeyValueStore({
      'biometric_enabled': 'true',
      'master_key_biometric': 'legacy_password',
    });
    final service = BiometricAuthService(
      secureStorage: store,
      localAuth: _MockLocalAuthentication(authenticateResult: true),
    );

    final unlocked = await service.unlockWithBiometric();
    expect(unlocked, 'legacy_password');
  });

  test('disableBiometric deletes all keys', () async {
    final store = _MemorySecureKeyValueStore();
    final service = BiometricAuthService(
      secureStorage: store,
      localAuth: _MockLocalAuthentication(authenticateResult: true),
    );

    await service.enableBiometric('my_secret_password');
    await service.disableBiometric();

    expect(store.values.containsKey('biometric_enabled'), isFalse);
    expect(store.values.containsKey('biometric_wrapping_key'), isFalse);
    expect(store.values.containsKey('biometric_wrapped_key'), isFalse);
    expect(store.values.containsKey('master_key_biometric'), isFalse);
  });
}
