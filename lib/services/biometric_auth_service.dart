import 'dart:convert';
import 'dart:math';

import 'package:secret_roy/core/app_logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:cryptography/cryptography.dart';

import 'identity_service.dart' show SecureKeyValueStore;

enum BiometricAuthStatus {
  enabled,
  available,
  notSupported,
  notEnrolled,
  disabled,
}

class BiometricAuthService {
  final LocalAuthentication _localAuth;
  final SecureKeyValueStore _secureStorage;

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _plaintextMasterKeyKey = 'master_key_biometric';
  static const String _biometricTypeKey = 'biometric_type';

  static const String _wrappingKeyKey = 'biometric_wrapping_key';
  static const String _wrappedKeyKey = 'biometric_wrapped_key';

  BiometricAuthService({
    SecureKeyValueStore? secureStorage,
    LocalAuthentication? localAuth,
  }) : _secureStorage = secureStorage ?? _FlutterSecureStorageAdapter(),
       _localAuth = localAuth ?? LocalAuthentication();

  Future<BiometricAuthStatus> getStatus() async {
    try {
      final isAvailable = await _localAuth.isDeviceSupported();
      if (!isAvailable) return BiometricAuthStatus.notSupported;

      final canCheck = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (!canCheck || availableBiometrics.isEmpty) {
        return BiometricAuthStatus.notEnrolled;
      }

      return await _isBiometricEnabled()
          ? BiometricAuthStatus.enabled
          : BiometricAuthStatus.available;
    } catch (_) {
      return BiometricAuthStatus.notSupported;
    }
  }

  Future<List<BiometricType>> getAvailableTypes() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<String> getBiometricName() async {
    final types = await getAvailableTypes();

    if (types.contains(BiometricType.face)) return 'Face ID';
    if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
    if (types.contains(BiometricType.iris)) return 'Iris';
    return 'Biometrics';
  }

  Future<BiometricSetupResult> enableBiometric(String masterPassword) async {
    try {
      final status = await getStatus();
      if (status == BiometricAuthStatus.notSupported) {
        return BiometricSetupResult.notSupported;
      }
      if (status == BiometricAuthStatus.notEnrolled) {
        return BiometricSetupResult.notEnrolled;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to enable biometric unlock',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );

      if (!authenticated) {
        return BiometricSetupResult.cancelled;
      }

      await _storeEncryptedMasterKey(masterPassword);
      await _secureStorage.write(key: _biometricEnabledKey, value: 'true');

      final types = await getAvailableTypes();
      if (types.isNotEmpty) {
        await _secureStorage.write(
          key: _biometricTypeKey,
          value: types.first.toString(),
        );
      }

      return BiometricSetupResult.success;
    } on PlatformException catch (e) {
      AppLogger.d('Failed to enable biometric auth: ${e.code} ${e.message}');

      switch (e.code) {
        case auth_error.notAvailable:
          return BiometricSetupResult.notSupported;
        case auth_error.notEnrolled:
          return BiometricSetupResult.notEnrolled;
        case auth_error.lockedOut:
          return BiometricSetupResult.lockedOut;
        case auth_error.passcodeNotSet:
          return BiometricSetupResult.passcodeNotSet;
        default:
          return BiometricSetupResult.error;
      }
    } catch (e) {
      AppLogger.d('Failed to enable biometric auth: $e');
      return BiometricSetupResult.error;
    }
  }

  Future<String?> unlockWithBiometric() async {
    try {
      if (!await _isBiometricEnabled()) return null;

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Use biometrics to unlock the vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );

      if (!authenticated) return null;
      return await _retrieveMasterKey();
    } on PlatformException catch (e) {
      AppLogger.d('Failed to unlock with biometrics: ${e.code}');
      return null;
    } catch (e) {
      AppLogger.d('Failed to unlock with biometrics: $e');
      return null;
    }
  }

  Future<void> disableBiometric() async {
    try {
      await _secureStorage.delete(key: _biometricEnabledKey);
      await _secureStorage.delete(key: _plaintextMasterKeyKey);
      await _secureStorage.delete(key: _biometricTypeKey);
      await _secureStorage.delete(key: _wrappingKeyKey);
      await _secureStorage.delete(key: _wrappedKeyKey);
    } catch (e) {
      AppLogger.d('Failed to disable biometric auth: $e');
    }
  }

  Future<void> _storeEncryptedMasterKey(String masterPassword) async {
    final wrappingKey = _randomBytes(32);
    final secretBox = await AesGcm.with256bits().encrypt(
      utf8.encode(masterPassword),
      secretKey: SecretKey(wrappingKey),
    );
    final envelope = {
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
    await _secureStorage.write(
      key: _wrappingKeyKey,
      value: base64Encode(wrappingKey),
    );
    await _secureStorage.write(
      key: _wrappedKeyKey,
      value: jsonEncode(envelope),
    );
    // Delete any legacy plaintext key
    await _secureStorage.delete(key: _plaintextMasterKeyKey);
  }

  Future<String?> _retrieveMasterKey() async {
    // Try encrypted format first
    final wrappingKeyB64 = await _secureStorage.read(key: _wrappingKeyKey);
    final wrappedKeyJson = await _secureStorage.read(key: _wrappedKeyKey);
    if (wrappingKeyB64 != null && wrappedKeyJson != null) {
      try {
        final wrappingKey = base64Decode(wrappingKeyB64);
        final envelope = jsonDecode(wrappedKeyJson) as Map<String, dynamic>;
        final nonce = base64Decode(envelope['nonce'] as String);
        final cipherText = base64Decode(envelope['ciphertext'] as String);
        final macBytes = base64Decode(envelope['mac'] as String);
        final plainBytes = await AesGcm.with256bits().decrypt(
          SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
          secretKey: SecretKey(wrappingKey),
        );
        return utf8.decode(plainBytes);
      } catch (e) {
        AppLogger.d('Failed to decrypt biometric master key: $e');
        return null;
      }
    }

    // Fall back to legacy plaintext (migration path)
    return _secureStorage.read(key: _plaintextMasterKeyKey);
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  Future<bool> _isBiometricEnabled() async {
    final value = await _secureStorage.read(key: _biometricEnabledKey);
    return value == 'true';
  }
}

class _FlutterSecureStorageAdapter implements SecureKeyValueStore {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

enum BiometricSetupResult {
  success,
  cancelled,
  invalidPassword,
  notSupported,
  notEnrolled,
  lockedOut,
  passcodeNotSet,
  noPasswordMode,
  error,
}
