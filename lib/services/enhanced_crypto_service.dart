import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'database_file_cipher.dart';
import 'database_file_key_manager.dart';

class EnhancedCryptoService {
  static const String _masterPasswordKey = 'master_password';
  static const String _masterPasswordHashKey = 'master_password_hash';
  static const int _pbkdf2Iterations = 100000;
  static const int _saltLength = 16;
  static const int _hashBits = 256;

  final FlutterSecureStorage _secureStorage;
  bool _isUnlocked = false;
  Uint8List? _databaseKeyBytes;

  EnhancedCryptoService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  bool get hasMasterKey => _isUnlocked;

  Future<bool> initMasterKey(String masterPassword) async {
    final storedHash = await _readSecureValue(_masterPasswordHashKey);
    if (storedHash != null) {
      final verified = await _verifyPbkdf2(masterPassword, storedHash);
      if (verified) {
        await _unlockWithPassword(masterPassword);
      } else {
        logout();
      }
      return verified;
    }

    final storedPassword = await _readSecureValue(_masterPasswordKey);
    if (storedPassword != null) {
      if (!_constantTimeEquals(
        utf8.encode(storedPassword),
        utf8.encode(masterPassword),
      )) {
        logout();
        return false;
      }
      await _storePbkdf2Hash(masterPassword);
      await _deleteSecureValue(_masterPasswordKey);
      await _unlockWithPassword(masterPassword);
      return true;
    }

    await _storePbkdf2Hash(masterPassword);
    await _unlockWithPassword(masterPassword);
    return true;
  }

  Future<bool> updateMasterPassword(
    String oldPassword,
    String newPassword,
  ) async {
    final storedHash = await _readSecureValue(_masterPasswordHashKey);
    if (storedHash != null) {
      final verified = await _verifyPbkdf2(oldPassword, storedHash);
      if (!verified) return false;
      final databaseKeyBytes = await _unlockDatabaseFileKey(oldPassword);
      await _rotateDatabaseKeyEnvelope(newPassword, databaseKeyBytes);
      await _storePbkdf2Hash(newPassword);
      await _unlockWithPassword(newPassword);
      return true;
    }

    final storedPassword = await _readSecureValue(_masterPasswordKey);
    if (storedPassword != null &&
        _constantTimeEquals(
          utf8.encode(storedPassword),
          utf8.encode(oldPassword),
        )) {
      final databaseKeyBytes = await _unlockDatabaseFileKey(oldPassword);
      await _rotateDatabaseKeyEnvelope(newPassword, databaseKeyBytes);
      await _storePbkdf2Hash(newPassword);
      await _deleteSecureValue(_masterPasswordKey);
      await _unlockWithPassword(newPassword);
      return true;
    }
    return false;
  }

  Future<bool> verifyMasterPassword(String masterPassword) async {
    final storedHash = await _readSecureValue(_masterPasswordHashKey);
    if (storedHash != null) {
      return _verifyPbkdf2(masterPassword, storedHash);
    }
    final storedPassword = await _readSecureValue(_masterPasswordKey);
    if (storedPassword == null) return false;
    return _constantTimeEquals(
      utf8.encode(storedPassword),
      utf8.encode(masterPassword),
    );
  }

  void logout() {
    _isUnlocked = false;
    _databaseKeyBytes = null;
  }

  DatabaseFileCipher createDatabaseFileCipher() {
    final keyBytes = _databaseKeyBytes;
    if (!_isUnlocked || keyBytes == null) {
      throw StateError('Master key is locked.');
    }
    return DatabaseFileCipher(keyBytes: keyBytes);
  }

  Future<void> _unlockWithPassword(String masterPassword) async {
    _databaseKeyBytes = await _unlockDatabaseFileKey(masterPassword);
    _isUnlocked = true;
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
    await _writeSecureValue(_masterPasswordHashKey, encoded);
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

  Future<Uint8List> _unlockDatabaseFileKey(String password) async {
    return _databaseFileKeyManager().unlock(password);
  }

  Future<void> _rotateDatabaseKeyEnvelope(
    String newPassword,
    Uint8List databaseKeyBytes,
  ) async {
    await _databaseFileKeyManager().rotateEnvelope(
      newPassword: newPassword,
      databaseKeyBytes: databaseKeyBytes,
    );
  }

  Future<String?> _readSecureValue(String key) {
    return _secureStorage.read(key: key);
  }

  Future<void> _writeSecureValue(String key, String value) {
    return _secureStorage.write(key: key, value: value);
  }

  Future<void> _deleteSecureValue(String key) {
    return _secureStorage.delete(key: key);
  }

  DatabaseFileKeyManager _databaseFileKeyManager() {
    return DatabaseFileKeyManager(
      read: ({required key}) => _readSecureValue(key),
      write: ({required key, required value}) => _writeSecureValue(key, value),
      delete: ({required key}) => _deleteSecureValue(key),
      pbkdf2Iterations: _pbkdf2Iterations,
    );
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

  static const int strengthThresholdVeryStrong = 80;
  static const int strengthThresholdStrong = 60;
  static const int strengthThresholdMedium = 40;
  static const int strengthThresholdWeak = 20;

  static String getPasswordStrengthLevel(int score) {
    if (score >= strengthThresholdVeryStrong) return 'Very strong';
    if (score >= strengthThresholdStrong) return 'Strong';
    if (score >= strengthThresholdMedium) return 'Medium';
    if (score >= strengthThresholdWeak) return 'Weak';
    return 'Very weak';
  }
}
