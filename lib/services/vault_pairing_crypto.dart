import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' show Hmac, sha256;
import 'package:cryptography/cryptography.dart' hide Hmac;

class VaultPairingCryptoException implements Exception {
  final String message;

  const VaultPairingCryptoException(this.message);

  @override
  String toString() => 'VaultPairingCryptoException($message)';
}

class VaultPairingKeyPair {
  final SimpleKeyPair keyPair;
  final String publicKey;

  const VaultPairingKeyPair({required this.keyPair, required this.publicKey});
}

class VaultPairingCrypto {
  static const String prefix = 'sroy-pairing-v2:';
  static const String _algorithmName = 'x25519-aesgcm-sha256';
  static const int _nonceLength = 12;
  static const int _saltLength = 16;

  const VaultPairingCrypto._();

  static Future<VaultPairingKeyPair> createKeyPair() async {
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return VaultPairingKeyPair(
      keyPair: keyPair,
      publicKey: _encodeBase64Url(publicKey.bytes),
    );
  }

  static Future<String> encryptBundle({
    required String plainBundle,
    required String requesterPublicKey,
  }) async {
    if (plainBundle.trim().isEmpty) {
      throw const VaultPairingCryptoException('Pairing bundle is empty.');
    }

    try {
      final recipientPublicKey = SimplePublicKey(
        _decodeBase64Url(requesterPublicKey),
        type: KeyPairType.x25519,
      );
      final sender = await X25519().newKeyPair();
      final senderPublicKey = await sender.extractPublicKey();
      final sharedSecret = await X25519().sharedSecretKey(
        keyPair: sender,
        remotePublicKey: recipientPublicKey,
      );
      final sharedBytes = await sharedSecret.extractBytes();
      final salt = _randomBytes(_saltLength);
      final nonce = _randomBytes(_nonceLength);
      final keyBytes = _deriveAesKey(sharedBytes: sharedBytes, salt: salt);
      final secretBox = await AesGcm.with256bits().encrypt(
        utf8.encode(plainBundle),
        secretKey: SecretKey(keyBytes),
        nonce: nonce,
      );

      final envelope = {
        'v': 2,
        'alg': _algorithmName,
        'epk': _encodeBase64Url(senderPublicKey.bytes),
        'salt': _encodeBase64Url(salt),
        'nonce': _encodeBase64Url(secretBox.nonce),
        'ciphertext': _encodeBase64Url(secretBox.cipherText),
        'mac': _encodeBase64Url(secretBox.mac.bytes),
      };

      return '$prefix${_encodeBase64Url(utf8.encode(jsonEncode(envelope)))}';
    } catch (error) {
      if (error is VaultPairingCryptoException) {
        rethrow;
      }
      throw VaultPairingCryptoException(
        'Failed to encrypt pairing bundle. ($error)',
      );
    }
  }

  static Future<String> decryptBundle({
    required String wrappedBundle,
    required VaultPairingKeyPair keyPair,
  }) async {
    final normalized = wrappedBundle.trim();
    if (!normalized.startsWith(prefix)) {
      throw const VaultPairingCryptoException(
        'Pairing bundle is not encrypted for this device.',
      );
    }

    try {
      final envelope = Map<String, dynamic>.from(
        jsonDecode(
              utf8.decode(
                _decodeBase64Url(normalized.substring(prefix.length)),
              ),
            )
            as Map,
      );

      if (envelope['v'] != 2 || envelope['alg'] != _algorithmName) {
        throw const VaultPairingCryptoException(
          'Unsupported pairing bundle version.',
        );
      }

      final senderPublicKey = SimplePublicKey(
        _decodeBase64Url(envelope['epk'] as String? ?? ''),
        type: KeyPairType.x25519,
      );
      final salt = _decodeBase64Url(envelope['salt'] as String? ?? '');
      final nonce = _decodeBase64Url(envelope['nonce'] as String? ?? '');
      final cipherText = _decodeBase64Url(
        envelope['ciphertext'] as String? ?? '',
      );
      final macBytes = _decodeBase64Url(envelope['mac'] as String? ?? '');
      final sharedSecret = await X25519().sharedSecretKey(
        keyPair: keyPair.keyPair,
        remotePublicKey: senderPublicKey,
      );
      final sharedBytes = await sharedSecret.extractBytes();
      final keyBytes = _deriveAesKey(sharedBytes: sharedBytes, salt: salt);

      final plainBytes = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: SecretKey(keyBytes),
      );
      return utf8.decode(plainBytes);
    } catch (error) {
      if (error is VaultPairingCryptoException) {
        rethrow;
      }
      throw VaultPairingCryptoException(
        'Failed to decrypt pairing bundle for this device. ($error)',
      );
    }
  }

  static List<int> _deriveAesKey({
    required List<int> sharedBytes,
    required List<int> salt,
  }) {
    return Hmac(sha256, sharedBytes).convert([
      ...utf8.encode('sroy-pairing-v2'),
      ...salt,
      ...utf8.encode(_algorithmName),
    ]).bytes;
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static String _encodeBase64Url(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static List<int> _decodeBase64Url(String value) {
    return base64Url.decode(base64Url.normalize(value));
  }
}
