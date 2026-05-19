import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:secret_roy/core/crypto_random.dart';

import 'database_file_cipher.dart';
import 'database_file_key_manager.dart';

/// 核心密码学服务，负责主密码验证、数据库密钥派生与加密信封管理。
///
/// [EnhancedCryptoService] 使用 PBKDF2-HMAC-SHA256（100,000 轮）对主密码进行哈希，
/// 并通过 [DatabaseFileKeyManager] 将随机生成的 32 字节数据库密钥用主密码包装存储。
/// 解锁成功后，可创建 [DatabaseFileCipher] 用于本地数据库的 AES-GCM-256 加解密。
///
/// 使用场景：
/// ```dart
/// final crypto = EnhancedCryptoService(secureStorage: secureStorage);
/// final ok = await crypto.initMasterKey('myPassword');
/// final cipher = crypto.createDatabaseFileCipher();
/// ```
///
/// 生命周期：
/// - [initMasterKey] / [verifyMasterPassword] → [createDatabaseFileCipher]
/// - [logout] 清除内存中的密钥，锁定数据库访问。
///
/// 安全注意：
/// - 不支持降低 PBKDF2 迭代次数。
/// - 主密码哈希使用恒定时间比较防止时序攻击。
class EnhancedCryptoService {
  static const String _masterPasswordKey = 'master_password';
  static const String _masterPasswordHashKey = 'master_password_hash';
  static const int _pbkdf2Iterations = 100000;
  static const int _saltLength = 16;
  static const int _hashBits = 256;

  final FlutterSecureStorage _secureStorage;
  bool _isUnlocked = false;
  Uint8List? _databaseKeyBytes;

  late final DatabaseFileKeyManager _databaseFileKeyManager = DatabaseFileKeyManager(
    read: ({required key}) => _readSecureValue(key),
    write: ({required key, required value}) => _writeSecureValue(key, value),
    delete: ({required key}) => _deleteSecureValue(key),
    pbkdf2Iterations: _pbkdf2Iterations,
  );

  EnhancedCryptoService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  bool get hasMasterKey => _isUnlocked;

  /// 初始化或验证主密码，解锁数据库密钥。
  ///
  /// [masterPassword] 为用户输入的明文主密码。
  /// 返回 true 表示验证/初始化成功，内存中已持有数据库密钥；
  /// 返回 false 表示密码与已存储哈希不匹配。
  ///
  /// 首次调用时会生成新的 PBKDF2 哈希并保存；
  /// 若存在遗留的明文密码（旧版本），会自动迁移到 PBKDF2。
  /// 验证失败时自动调用 [logout] 清除敏感状态。
  Future<bool> initMasterKey(String masterPassword) async {
    final storedHash = await _readSecureValue(_masterPasswordHashKey);
    AppLogger.d('initMasterKey: storedHash=${storedHash != null}');
    if (storedHash != null) {
      final verified = await _verifyPbkdf2(masterPassword, storedHash);
      AppLogger.d('initMasterKey: _verifyPbkdf2 returned $verified');
      if (verified) {
        await _unlockWithPassword(masterPassword);
      } else {
        logout();
      }
      return verified;
    }

    final storedPassword = await _readSecureValue(_masterPasswordKey);
    AppLogger.d('initMasterKey: storedPassword=${storedPassword != null}');
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

  /// 修改主密码，用新密码重新包装数据库密钥。
  ///
  /// [oldPassword] 为当前主密码，[newPassword] 为新主密码。
  /// 返回 true 表示修改成功；返回 false 表示旧密码验证失败。
  ///
  /// 成功后会：
  /// 1. 使用旧密码解密出数据库密钥；
  /// 2. 用新密码生成新的包装信封；
  /// 3. 更新 PBKDF2 哈希并重新解锁。
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

  /// 验证主密码是否正确，不修改任何存储状态。
  ///
  /// [masterPassword] 为待验证的明文密码。
  /// 返回 true 表示与已存储的哈希匹配；返回 false 表示不匹配。
  ///
  /// 仅用于密码确认场景（如修改密码前的旧密码校验），不会解锁数据库密钥。
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

  /// 清除内存中的数据库密钥并标记为锁定状态。
  ///
  /// 调用后 [hasMasterKey] 变为 false，[createDatabaseFileCipher] 将抛出 [StateError]。
  /// 不会删除 [FlutterSecureStorage] 中已持久化的任何数据。
  void logout() {
    _isUnlocked = false;
    _databaseKeyBytes = null;
  }

  /// 创建一个基于当前解锁状态的数据库文件加密器。
  ///
  /// 返回配置好的 [DatabaseFileCipher]，用于 [SecureStorageService] 的加解密。
  ///
  /// 抛出 [StateError] 当服务未解锁（即 [hasMasterKey] 为 false）。
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
    final salt = CryptoRandom.bytes(_saltLength);
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
    return _databaseFileKeyManager.unlock(password);
  }

  Future<void> _rotateDatabaseKeyEnvelope(
    String newPassword,
    Uint8List databaseKeyBytes,
  ) async {
    await _databaseFileKeyManager.rotateEnvelope(
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

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    // Always compare full length to avoid timing leaks.
    // If lengths differ, xor with a dummy to consume the same time.
    if (a.length != b.length) {
      // ignore: unused_local_variable
      var dummy = 0;
      for (var i = 0; i < b.length; i++) {
        dummy |= b[i] ^ b[i];
      }
      return false;
    }
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
