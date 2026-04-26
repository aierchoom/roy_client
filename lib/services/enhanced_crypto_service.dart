import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EnhancedCryptoService {
  static const String _masterPasswordKey = 'master_password_v1';

  final FlutterSecureStorage _secureStorage;
  bool _isUnlocked = false;

  EnhancedCryptoService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  bool get hasMasterKey => _isUnlocked;

  Future<bool> initMasterKey(String masterPassword) async {
    final storedPassword = await _secureStorage.read(key: _masterPasswordKey);
    if (storedPassword != null && storedPassword != masterPassword) {
      _isUnlocked = false;
      return false;
    }

    if (storedPassword == null) {
      await _secureStorage.write(
        key: _masterPasswordKey,
        value: masterPassword,
      );
    }

    _isUnlocked = true;
    return true;
  }

  Future<bool> updateMasterPassword(String oldPassword, String newPassword) async {
    final storedPassword = await _secureStorage.read(key: _masterPasswordKey);
    if (storedPassword != null && storedPassword != oldPassword) {
      return false;
    }

    await _secureStorage.write(
      key: _masterPasswordKey,
      value: newPassword,
    );
    return true;
  }

  Future<bool> verifyMasterPassword(String masterPassword) async {
    final storedPassword = await _secureStorage.read(key: _masterPasswordKey);
    return storedPassword == masterPassword;
  }

  void logout() {
    _isUnlocked = false;
  }

  static String generatePassword({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSpecial = true,
  }) {
    final pools = <String>[];

    if (includeLowercase) pools.add('abcdefghijklmnopqrstuvwxyz');
    if (includeUppercase) pools.add('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    if (includeNumbers) pools.add('0123456789');
    if (includeSpecial) pools.add(r'!@#$%^&*()_+-=[]{}|;:,.<>?');

    if (pools.isEmpty) {
      pools.add('abcdefghijklmnopqrstuvwxyz');
    }

    final random = Random.secure();
    final effectiveLength = length < pools.length ? pools.length : length;
    final chars = pools.join();
    final passwordChars = <String>[];

    for (final pool in pools) {
      passwordChars.add(pool[random.nextInt(pool.length)]);
    }

    while (passwordChars.length < effectiveLength) {
      passwordChars.add(chars[random.nextInt(chars.length)]);
    }

    for (int i = passwordChars.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final current = passwordChars[i];
      passwordChars[i] = passwordChars[j];
      passwordChars[j] = current;
    }

    return passwordChars.join();
  }

  static int calculatePasswordStrength(String password) {
    int score = 0;
    if (password.length >= 8) score += 10;
    if (password.length >= 12) score += 10;
    if (password.length >= 16) score += 10;
    if (password.contains(RegExp(r'[a-z]'))) score += 15;
    if (password.contains(RegExp(r'[A-Z]'))) score += 15;
    if (password.contains(RegExp(r'[0-9]'))) score += 15;
    if (password.contains(RegExp(r'[^a-zA-Z0-9]'))) score += 15;
    return score.clamp(0, 100);
  }

  static String getPasswordStrengthLevel(int score) {
    if (score >= 80) return 'Very strong';
    if (score >= 60) return 'Strong';
    if (score >= 40) return 'Medium';
    if (score >= 20) return 'Weak';
    return 'Very weak';
  }
}
