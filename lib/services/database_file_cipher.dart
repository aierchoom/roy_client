import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:secret_roy/core/crypto_random.dart';

/// 数据库文件加密器，使用 AES-GCM-256 对 SQLite 数据库文件进行 envelope 加密/解密。
///
/// 加密后的文件头部包含 magic、版本号、nonce 与 MAC，可通过 [looksEncrypted] 识别。
class DatabaseFileCipher {
  static final List<int> _magic = ascii.encode('SROYDB');
  static const int _version = 1;
  static const int _keyLength = 32;
  static const int _nonceLength = 12;

  final Uint8List _keyBytes;
  final AesGcm _algorithm;
  final Random _random;

  DatabaseFileCipher({
    required List<int> keyBytes,
    AesGcm? algorithm,
    Random? random,
  }) : _keyBytes = Uint8List.fromList(keyBytes),
       _algorithm = algorithm ?? AesGcm.with256bits(),
       _random = random ?? Random.secure() {
    if (_keyBytes.length != _keyLength) {
      throw ArgumentError.value(
        _keyBytes.length,
        'keyBytes.length',
        'Database file encryption requires a 256-bit key.',
      );
    }
  }

  static Uint8List generateKeyBytes() {
    return CryptoRandom.bytes(_keyLength);
  }

  /// 判断给定字节流是否为 SecretRoy 加密数据库格式。
  static bool looksEncrypted(List<int> bytes) {
    if (bytes.length < _magic.length + 3) {
      return false;
    }
    for (var index = 0; index < _magic.length; index += 1) {
      if (bytes[index] != _magic[index]) {
        return false;
      }
    }
    return bytes[_magic.length] == _version;
  }

  /// 使用 AES-GCM-256 加密 [plaintext]，返回带 envelope 头的密文字节。
  Future<Uint8List> encrypt(Uint8List plaintext) async {
    final nonce = Uint8List.fromList(
      List<int>.generate(_nonceLength, (_) => _random.nextInt(256)),
    );
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: SecretKey(_keyBytes),
      nonce: nonce,
    );

    final output = BytesBuilder(copy: false)
      ..add(_magic)
      ..add([_version, box.nonce.length, box.mac.bytes.length])
      ..add(box.nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    return output.takeBytes();
  }

  /// 解密带 envelope 头的 [encrypted]，返回明文。验证版本与 MAC，失败时抛出异常。
  Future<Uint8List> decrypt(Uint8List encrypted) async {
    try {
      _validateHeader(encrypted);
      var offset = _magic.length;
      final version = encrypted[offset];
      offset += 1;
      final nonceLength = encrypted[offset];
      offset += 1;
      final macLength = encrypted[offset];
      offset += 1;

      if (version != _version) {
        throw DatabaseFileCipherException(
          'Unsupported encrypted database version: $version.',
        );
      }

      final nonceEnd = offset + nonceLength;
      final macEnd = nonceEnd + macLength;
      if (nonceLength == 0 ||
          macLength == 0 ||
          nonceEnd > encrypted.length ||
          macEnd > encrypted.length) {
        throw const DatabaseFileCipherException(
          'Encrypted database header is truncated.',
        );
      }

      final nonce = encrypted.sublist(offset, nonceEnd);
      final macBytes = encrypted.sublist(nonceEnd, macEnd);
      final cipherText = encrypted.sublist(macEnd);
      final box = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
      final plaintext = await _algorithm.decrypt(
        box,
        secretKey: SecretKey(_keyBytes),
      );
      return Uint8List.fromList(plaintext);
    } on DatabaseFileCipherException {
      rethrow;
    } catch (error) {
      throw DatabaseFileCipherException(
        'Failed to decrypt encrypted database.',
        cause: error,
      );
    }
  }

  static void _validateHeader(Uint8List encrypted) {
    if (!looksEncrypted(encrypted)) {
      throw const DatabaseFileCipherException(
        'File is not a SecretRoy encrypted database.',
      );
    }
  }
}

/// 数据库文件加密/解密过程中的异常。
class DatabaseFileCipherException implements Exception {
  final String message;
  final Object? cause;

  const DatabaseFileCipherException(this.message, {this.cause});

  @override
  String toString() {
    if (cause == null) {
      return 'DatabaseFileCipherException($message)';
    }
    return 'DatabaseFileCipherException($message, cause: $cause)';
  }
}
