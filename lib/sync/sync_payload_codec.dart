import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/totp_credential.dart';

class SyncPayloadException implements Exception {
  final String message;

  const SyncPayloadException(this.message);

  @override
  String toString() => 'SyncPayloadException($message)';
}

class SyncPayloadCodec {
  static const String prefix = 'sroy-sync:';
  static const int _currentVersion = 1;
  static const String _algorithmName = 'aes-256-gcm-hkdf-sha256';
  static const int _nonceLength = 12;
  static const int _saltLength = 16;
  static const int _keyLength = 32;
  static final Random _random = Random.secure();

  static Future<String> encodePayload({
    required Map<String, dynamic> payloadJson,
    required String vaultId,
    required String nodeId,
    required String privateKey,
    required String symmetricKey,
  }) async {
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final additionalData = _additionalData(
      version: _currentVersion,
      vaultId: vaultId,
      nodeId: nodeId,
    );
    final secretKey = await _derivePayloadKey(
      vaultId: vaultId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
      salt: salt,
    );
    final secretBox = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(payloadJson)),
      secretKey: secretKey,
      nonce: nonce,
      aad: additionalData,
    );

    final envelope = {
      'v': _currentVersion,
      'alg': _algorithmName,
      'vault_id': vaultId,
      'node_id': nodeId,
      'salt': _encodeBase64Url(salt),
      'nonce': _encodeBase64Url(secretBox.nonce),
      'ciphertext': _encodeBase64Url(secretBox.cipherText),
      'mac': _encodeBase64Url(secretBox.mac.bytes),
    };

    return '$prefix${_encodeBase64Url(utf8.encode(jsonEncode(envelope)))}';
  }

  static Future<String> encodeAccount({
    required AccountItem item,
    required String vaultId,
    required String nodeId,
    required String privateKey,
    required String symmetricKey,
  }) {
    final json = item.toJson();
    json['_type'] = 'account';
    return encodePayload(
      payloadJson: json,
      vaultId: vaultId,
      nodeId: nodeId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
  }

  static Future<String> encodeTemplate({
    required AccountTemplate template,
    required String vaultId,
    required String nodeId,
    required String privateKey,
    required String symmetricKey,
  }) {
    final json = template.toJson();
    json['_type'] = 'template';
    return encodePayload(
      payloadJson: json,
      vaultId: vaultId,
      nodeId: nodeId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
  }

  static Future<String> encodeTotpCredential({
    required TotpCredential credential,
    required String vaultId,
    required String nodeId,
    required String privateKey,
    required String symmetricKey,
  }) {
    final json = credential.toJson();
    json['_type'] = 'totp_credential';
    return encodePayload(
      payloadJson: json,
      vaultId: vaultId,
      nodeId: nodeId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
  }

  static Future<String> encode({
    required AccountItem item,
    required String vaultId,
    required String nodeId,
    required String privateKey,
    required String symmetricKey,
  }) {
    return encodeAccount(
      item: item,
      vaultId: vaultId,
      nodeId: nodeId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
  }

  static Future<Map<String, dynamic>> decodePayload({
    required String encodedPayload,
    required String expectedVaultId,
    required String privateKey,
    required String symmetricKey,
  }) async {
    final envelope = _decodeEnvelope(encodedPayload);
    final version = envelope['v'];
    final algorithm = envelope['alg'];
    final vaultId = envelope['vault_id'];
    final nodeId = envelope['node_id'];

    if (version is! int || version != _currentVersion) {
      throw const SyncPayloadException('Unsupported payload version.');
    }
    if (algorithm != _algorithmName) {
      throw const SyncPayloadException('Unsupported payload algorithm.');
    }
    if (vaultId is! String || vaultId.isEmpty) {
      throw const SyncPayloadException('Payload vault id is missing.');
    }
    if (vaultId != expectedVaultId) {
      throw const SyncPayloadException('Payload belongs to a different vault.');
    }
    if (nodeId is! String || nodeId.isEmpty) {
      throw const SyncPayloadException('Payload node id is missing.');
    }

    final salt = _readBase64UrlBytes(envelope, 'salt');
    final nonce = _readBase64UrlBytes(envelope, 'nonce');
    final ciphertext = _readBase64UrlBytes(envelope, 'ciphertext');
    final macBytes = _readBase64UrlBytes(envelope, 'mac');
    if (salt.length < _saltLength ||
        nonce.length != _nonceLength ||
        ciphertext.isEmpty ||
        macBytes.isEmpty) {
      throw const SyncPayloadException('Payload envelope is incomplete.');
    }

    try {
      final secretKey = await _derivePayloadKey(
        vaultId: vaultId,
        privateKey: privateKey,
        symmetricKey: symmetricKey,
        salt: salt,
      );
      final plaintextBytes = await AesGcm.with256bits().decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(macBytes)),
        secretKey: secretKey,
        aad: _additionalData(
          version: version,
          vaultId: vaultId,
          nodeId: nodeId,
        ),
      );
      final payloadJson = jsonDecode(utf8.decode(plaintextBytes));
      return Map<String, dynamic>.from(payloadJson as Map);
    } catch (_) {
      throw const SyncPayloadException('Payload decryption failed.');
    }
  }

  static Future<AccountItem> decode({
    required String encodedPayload,
    required String expectedVaultId,
    required String privateKey,
    required String symmetricKey,
  }) async {
    final payloadJson = await decodePayload(
      encodedPayload: encodedPayload,
      expectedVaultId: expectedVaultId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
    return AccountItem.fromJson(payloadJson);
  }

  static Map<String, dynamic> _decodeEnvelope(String encodedPayload) {
    final normalized = encodedPayload.trim();
    if (!normalized.startsWith(prefix)) {
      throw const SyncPayloadException(
        'Payload is not a SecretRoy encrypted sync envelope.',
      );
    }

    try {
      final envelopeJson = jsonDecode(
        utf8.decode(_decodeBase64Url(normalized.substring(prefix.length))),
      );
      return Map<String, dynamic>.from(envelopeJson as Map);
    } catch (_) {
      throw const SyncPayloadException('Payload is not valid envelope JSON.');
    }
  }

  static Future<SecretKey> _derivePayloadKey({
    required String vaultId,
    required String privateKey,
    required String symmetricKey,
    required List<int> salt,
  }) {
    return Hkdf(hmac: Hmac.sha256(), outputLength: _keyLength).deriveKey(
      secretKey: SecretKey(utf8.encode('$symmetricKey|$privateKey')),
      nonce: salt,
      info: utf8.encode('sroy-sync-payload|$_algorithmName|$vaultId'),
    );
  }

  static List<int> _additionalData({
    required int version,
    required String vaultId,
    required String nodeId,
  }) {
    return utf8.encode(
      'v=$version;alg=$_algorithmName;vault=$vaultId;node=$nodeId',
    );
  }

  static List<int> _readBase64UrlBytes(
    Map<String, dynamic> envelope,
    String key,
  ) {
    final value = envelope[key];
    if (value is! String || value.isEmpty) {
      throw const SyncPayloadException('Payload envelope is incomplete.');
    }
    try {
      return _decodeBase64Url(value);
    } catch (_) {
      throw const SyncPayloadException('Payload envelope is incomplete.');
    }
  }

  static List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  static String _encodeBase64Url(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static List<int> _decodeBase64Url(String value) {
    return base64Url.decode(base64Url.normalize(value));
  }
}
