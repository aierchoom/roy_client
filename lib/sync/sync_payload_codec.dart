import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/account_item.dart';
import '../models/account_template.dart';

class SyncPayloadException implements Exception {
  final String message;

  const SyncPayloadException(this.message);

  @override
  String toString() => 'SyncPayloadException($message)';
}

class SyncPayloadCodec {
  static const int _currentVersion = 1;
  static const int _nonceLength = 16;
  static final Random _random = Random.secure();

  static String encodePayload({
    required Map<String, dynamic> payloadJson,
    required String vaultId,
    required String nodeId,
    required String privateKey,
    required String symmetricKey,
  }) {
    final nonceBytes = _randomBytes(_nonceLength);
    final plaintextBytes = utf8.encode(jsonEncode(payloadJson));
    final encryptionKey = _deriveKey(
      label: 'sync-payload-encryption',
      vaultId: vaultId,
      secret: symmetricKey,
    );
    final macKey = _deriveKey(
      label: 'sync-payload-mac',
      vaultId: vaultId,
      secret: '$privateKey|$symmetricKey',
    );

    final ciphertextBytes = _xorWithKeystream(
      plaintextBytes,
      keyBytes: encryptionKey,
      nonceBytes: nonceBytes,
    );

    final nonce = base64Encode(nonceBytes);
    final ciphertext = base64Encode(ciphertextBytes);
    final mac = _computeMac(
      macKey: macKey,
      version: _currentVersion,
      vaultId: vaultId,
      nodeId: nodeId,
      nonce: nonce,
      ciphertext: ciphertext,
    );

    final envelope = {
      'v': _currentVersion,
      'vault_id': vaultId,
      'node_id': nodeId,
      'nonce': nonce,
      'ciphertext': ciphertext,
      'mac': mac,
    };

    return base64Encode(utf8.encode(jsonEncode(envelope)));
  }

  static String encodeAccount({
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

  static String encodeTemplate({
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

  static String encode({
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

  static Map<String, dynamic> decodePayload({
    required String encodedPayload,
    required String expectedVaultId,
    required String privateKey,
    required String symmetricKey,
  }) {
    late final Map<String, dynamic> decodedJson;
    try {
      final payloadBytes = base64Decode(encodedPayload);
      final payloadJson = jsonDecode(utf8.decode(payloadBytes));
      decodedJson = Map<String, dynamic>.from(payloadJson as Map);
    } catch (_) {
      throw const SyncPayloadException('Payload is not valid base64 JSON.');
    }

    if (!_looksLikeEnvelope(decodedJson)) {
      return decodedJson;
    }

    final version = decodedJson['v'];
    final vaultId = decodedJson['vault_id'];
    final nodeId = decodedJson['node_id'];
    final nonce = decodedJson['nonce'];
    final ciphertext = decodedJson['ciphertext'];
    final mac = decodedJson['mac'];

    if (version is! int || version != _currentVersion) {
      throw const SyncPayloadException('Unsupported payload version.');
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
    if (nonce is! String || ciphertext is! String || mac is! String) {
      throw const SyncPayloadException('Payload envelope is incomplete.');
    }

    final macKey = _deriveKey(
      label: 'sync-payload-mac',
      vaultId: vaultId,
      secret: '$privateKey|$symmetricKey',
    );
    final expectedMac = _computeMac(
      macKey: macKey,
      version: version,
      vaultId: vaultId,
      nodeId: nodeId,
      nonce: nonce,
      ciphertext: ciphertext,
    );
    if (!_constantTimeEquals(expectedMac, mac)) {
      throw const SyncPayloadException('Payload integrity check failed.');
    }

    try {
      final encryptionKey = _deriveKey(
        label: 'sync-payload-encryption',
        vaultId: vaultId,
        secret: symmetricKey,
      );
      final plaintextBytes = _xorWithKeystream(
        base64Decode(ciphertext),
        keyBytes: encryptionKey,
        nonceBytes: base64Decode(nonce),
      );
      final accountJson = jsonDecode(utf8.decode(plaintextBytes));
      return Map<String, dynamic>.from(accountJson as Map);
    } catch (_) {
      throw const SyncPayloadException('Payload decryption failed.');
    }
  }

  static AccountItem decode({
    required String encodedPayload,
    required String expectedVaultId,
    required String privateKey,
    required String symmetricKey,
  }) {
    final payloadJson = decodePayload(
      encodedPayload: encodedPayload,
      expectedVaultId: expectedVaultId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
    return AccountItem.fromJson(payloadJson);
  }

  static bool _looksLikeEnvelope(Map<String, dynamic> json) {
    return json.containsKey('v') &&
        json.containsKey('vault_id') &&
        json.containsKey('node_id') &&
        json.containsKey('nonce') &&
        json.containsKey('ciphertext') &&
        json.containsKey('mac');
  }

  static List<int> _deriveKey({
    required String label,
    required String vaultId,
    required String secret,
  }) {
    return sha256.convert(utf8.encode('$label|$vaultId|$secret')).bytes;
  }

  static String _computeMac({
    required List<int> macKey,
    required int version,
    required String vaultId,
    required String nodeId,
    required String nonce,
    required String ciphertext,
  }) {
    final input = '$version|$vaultId|$nodeId|$nonce|$ciphertext';
    final digest = Hmac(sha256, macKey).convert(utf8.encode(input));
    return base64Encode(digest.bytes);
  }

  static List<int> _xorWithKeystream(
    List<int> input, {
    required List<int> keyBytes,
    required List<int> nonceBytes,
  }) {
    final output = List<int>.filled(input.length, 0);
    var offset = 0;
    var blockIndex = 0;

    while (offset < input.length) {
      final block = sha256.convert([
        ...keyBytes,
        ...nonceBytes,
        ..._blockCounter(blockIndex),
      ]).bytes;
      for (var i = 0; i < block.length && offset < input.length; i++) {
        output[offset] = input[offset] ^ block[i];
        offset += 1;
      }
      blockIndex += 1;
    }

    return output;
  }

  static List<int> _blockCounter(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  static List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  static bool _constantTimeEquals(String left, String right) {
    final leftBytes = utf8.encode(left);
    final rightBytes = utf8.encode(right);
    if (leftBytes.length != rightBytes.length) {
      return false;
    }

    var diff = 0;
    for (var i = 0; i < leftBytes.length; i++) {
      diff |= leftBytes[i] ^ rightBytes[i];
    }
    return diff == 0;
  }
}
