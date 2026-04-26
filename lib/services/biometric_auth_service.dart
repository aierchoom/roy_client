import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

enum BiometricAuthStatus {
  enabled,
  available,
  notSupported,
  notEnrolled,
  disabled,
}

class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage;

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _plaintextMasterKeyKey = 'master_key_biometric_v1';
  static const String _biometricTypeKey = 'biometric_type';

  BiometricAuthService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

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

      await _secureStorage.write(
        key: _plaintextMasterKeyKey,
        value: masterPassword,
      );
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
      if (kDebugMode) {
        debugPrint('Failed to enable biometric auth: ${e.code} ${e.message}');
      }

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
      if (kDebugMode) {
        debugPrint('Failed to enable biometric auth: $e');
      }
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
      return await _secureStorage.read(key: _plaintextMasterKeyKey);
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to unlock with biometrics: ${e.code}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to unlock with biometrics: $e');
      }
      return null;
    }
  }

  Future<void> disableBiometric() async {
    try {
      await _secureStorage.delete(key: _biometricEnabledKey);
      await _secureStorage.delete(key: _plaintextMasterKeyKey);
      await _secureStorage.delete(key: _biometricTypeKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to disable biometric auth: $e');
      }
    }
  }

  Future<bool> _isBiometricEnabled() async {
    final value = await _secureStorage.read(key: _biometricEnabledKey);
    return value == 'true';
  }
}

enum BiometricSetupResult {
  success,
  cancelled,
  invalidPassword,
  notSupported,
  notEnrolled,
  lockedOut,
  passcodeNotSet,
  error,
}
