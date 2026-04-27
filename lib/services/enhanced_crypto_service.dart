import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EnhancedCryptoService {
  static const String _masterPasswordKeyV1 = 'master_password_v1';
  static const String _masterPasswordKeyV2 = 'master_password_v2';
  static const int _pbkdf2Iterations = 100000;
  static const int _saltLength = 16;
  static const int _hashBits = 256;

  final FlutterSecureStorage _secureStorage;
  bool _isUnlocked = false;

  EnhancedCryptoService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  bool get hasMasterKey => _isUnlocked;

  Future<bool> initMasterKey(String masterPassword) async {
    final v2Hash = await _secureStorage.read(key: _masterPasswordKeyV2);
    if (v2Hash != null) {
      final verified = await _verifyPbkdf2(masterPassword, v2Hash);
      _isUnlocked = verified;
      return verified;
    }

    final v1Password = await _secureStorage.read(key: _masterPasswordKeyV1);
    if (v1Password != null) {
      if (v1Password != masterPassword) {
        _isUnlocked = false;
        return false;
      }
      await _storePbkdf2Hash(masterPassword);
      await _secureStorage.delete(key: _masterPasswordKeyV1);
      _isUnlocked = true;
      return true;
    }

    await _storePbkdf2Hash(masterPassword);
    _isUnlocked = true;
    return true;
  }

  Future<bool> updateMasterPassword(
    String oldPassword,
    String newPassword,
  ) async {
    final v2Hash = await _secureStorage.read(key: _masterPasswordKeyV2);
    if (v2Hash != null) {
      final verified = await _verifyPbkdf2(oldPassword, v2Hash);
      if (!verified) return false;
      await _storePbkdf2Hash(newPassword);
      return true;
    }

    final v1Password = await _secureStorage.read(key: _masterPasswordKeyV1);
    if (v1Password != null && v1Password == oldPassword) {
      await _storePbkdf2Hash(newPassword);
      await _secureStorage.delete(key: _masterPasswordKeyV1);
      return true;
    }
    return false;
  }

  Future<bool> verifyMasterPassword(String masterPassword) async {
    final v2Hash = await _secureStorage.read(key: _masterPasswordKeyV2);
    if (v2Hash != null) {
      return _verifyPbkdf2(masterPassword, v2Hash);
    }
    final v1Password = await _secureStorage.read(key: _masterPasswordKeyV1);
    return v1Password == masterPassword;
  }

  void logout() {
    _isUnlocked = false;
  }

  Future<void> _storePbkdf2Hash(String password) async {
    final salt = List<int>.generate(
      _saltLength,
      (_) => Random.secure().nextInt(256),
    );
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: _hashBits,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final hashBytes = await secretKey.extractBytes();
    final encoded =
        'pbkdf2\$$_pbkdf2Iterations\$${base64Encode(salt)}\$${base64Encode(hashBytes)}';
    await _secureStorage.write(key: _masterPasswordKeyV2, value: encoded);
  }

  Future<bool> _verifyPbkdf2(String password, String encoded) async {
    final parts = encoded.split('\$');
    if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
    final iterations = int.tryParse(parts[1]) ?? 0;
    if (iterations <= 0) return false;

    late final List<int> salt;
    late final List<int> expectedHash;
    try {
      salt = base64Decode(parts[2]);
      expectedHash = base64Decode(parts[3]);
    } on FormatException {
      return false;
    }
    if (salt.length < _saltLength || expectedHash.isEmpty) return false;

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: expectedHash.length * 8,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final hashBytes = await secretKey.extractBytes();
    return _constantTimeEquals(hashBytes, expectedHash);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
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
