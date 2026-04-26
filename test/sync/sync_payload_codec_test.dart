import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/sync/sync_payload_codec.dart';

AccountItem _item() {
  return AccountItem(
    id: 'account_1',
    name: 'Primary Account',
    email: 'owner@example.com',
    templateId: 'web_account',
    data: {'password': 'super-secret', 'note': 'hello'},
    createdAt: 1,
    nameHlc: const Hlc(10, 0, 'device_a'),
    emailHlc: const Hlc(10, 1, 'device_a'),
    dataHlc: {
      'password': const Hlc(10, 2, 'device_a'),
      'note': const Hlc(10, 3, 'device_a'),
    },
  );
}

void main() {
  const vaultId = 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const otherVaultId = 'vault_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const deviceId = 'device_abcdef123456';
  const privateKey =
      'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const symmetricKey =
      'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  test('encodes and decodes a signed encrypted payload', () {
    final item = _item();

    final encoded = SyncPayloadCodec.encode(
      item: item,
      vaultId: vaultId,
      nodeId: deviceId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
    final decoded = SyncPayloadCodec.decode(
      encodedPayload: encoded,
      expectedVaultId: vaultId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );

    expect(decoded.toJson(), item.toJson());
    expect(encoded.contains(item.name), isFalse);
    expect(encoded.contains(item.data['password']!), isFalse);
  });

  test('rejects tampered payload envelope', () {
    final encoded = SyncPayloadCodec.encode(
      item: _item(),
      vaultId: vaultId,
      nodeId: deviceId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
    final envelope =
        jsonDecode(utf8.decode(base64Decode(encoded))) as Map<String, dynamic>;
    envelope['ciphertext'] = '${envelope['ciphertext']}tampered';
    final tampered = base64Encode(utf8.encode(jsonEncode(envelope)));

    expect(
      () => SyncPayloadCodec.decode(
        encodedPayload: tampered,
        expectedVaultId: vaultId,
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      ),
      throwsA(
        isA<SyncPayloadException>().having(
          (error) => error.message,
          'message',
          'Payload integrity check failed.',
        ),
      ),
    );
  });

  test('rejects payload from a different vault', () {
    final encoded = SyncPayloadCodec.encode(
      item: _item(),
      vaultId: vaultId,
      nodeId: deviceId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );

    expect(
      () => SyncPayloadCodec.decode(
        encodedPayload: encoded,
        expectedVaultId: otherVaultId,
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      ),
      throwsA(
        isA<SyncPayloadException>().having(
          (error) => error.message,
          'message',
          'Payload belongs to a different vault.',
        ),
      ),
    );
  });

  test('keeps compatibility with legacy base64 payloads', () {
    final item = _item();
    final legacyPayload = base64Encode(utf8.encode(jsonEncode(item.toJson())));

    final decoded = SyncPayloadCodec.decode(
      encodedPayload: legacyPayload,
      expectedVaultId: vaultId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );

    expect(decoded.toJson(), item.toJson());
  });
}
