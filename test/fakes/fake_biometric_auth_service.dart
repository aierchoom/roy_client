import 'package:secret_roy/services/biometric_auth_service.dart';

class FakeBiometricAuthService extends BiometricAuthService {
  BiometricAuthStatus _status = BiometricAuthStatus.notSupported;
  String? _storedPassword;

  @override
  Future<BiometricAuthStatus> getStatus() async => _status;

  @override
  Future<BiometricSetupResult> enableBiometric(String password) async {
    _storedPassword = password;
    _status = BiometricAuthStatus.enabled;
    return BiometricSetupResult.success;
  }

  @override
  Future<void> disableBiometric() async {
    _storedPassword = null;
    _status = BiometricAuthStatus.notSupported;
  }

  @override
  Future<String?> unlockWithBiometric() async => _storedPassword;

  @override
  Future<String> getBiometricName() async => 'Test Biometric';

  void setStatus(BiometricAuthStatus status) {
    _status = status;
  }
}
