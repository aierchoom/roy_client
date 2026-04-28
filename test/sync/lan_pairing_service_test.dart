import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:secret_roy/services/lan_pairing_service.dart';
import 'package:secret_roy/services/vault_pairing_crypto.dart';

void main() {
  test('normalizePairingCode accepts exactly 8 readable characters', () {
    expect(LanPairingService.normalizePairingCode('ABC234XY'), 'ABC234XY');
    expect(LanPairingService.normalizePairingCode(' abc234xy '), 'ABC234XY');
  });

  test('normalizePairingCode rejects invalid values', () {
    expect(
      () => LanPairingService.normalizePairingCode('ABC234X'),
      throwsA(isA<LanPairingServiceException>()),
    );
    expect(
      () => LanPairingService.normalizePairingCode('ABC23410'),
      throwsA(isA<LanPairingServiceException>()),
    );
  });

  test(
    'startHosting creates an 8-character LAN session and can stop cleanly',
    () async {
      final service = LanPairingService();
      final startedAt = DateTime.now();
      final session = await service.startHosting(
        transferCode: 'sroy-link:test',
      );
      final ttl = session.expiresAt.difference(startedAt);

      expect(session.pairingCode, matches(RegExp(r'^[A-Z2-9]{8}$')));
      expect(ttl, greaterThan(const Duration(minutes: 2, seconds: 50)));
      expect(ttl, lessThan(const Duration(minutes: 3, seconds: 10)));
      expect(service.isHosting, isTrue);

      await service.stopHosting();
      expect(service.isHosting, isFalse);
    },
  );

  test(
    'claimTransferCodeByCode imports the host transfer code',
    () async {
      final host = LanPairingService();
      final requester = LanPairingService();
      const transferCode = 'sroy-link:test';

      final session = await host.startHosting(transferCode: transferCode);

      try {
        final claimedTransferCode = await requester.claimTransferCodeByCode(
          pairingCode: session.pairingCode,
          requesterDeviceId: 'device_abcdef123456',
          discoveryTimeout: const Duration(seconds: 3),
          claimTimeout: const Duration(seconds: 2),
        );

        expect(claimedTransferCode, transferCode);
      } finally {
        await requester.stopHosting();
        await host.stopHosting();
      }
    },
    skip: Platform.isWindows
        ? 'UDP broadcast discovery is not stable in the Windows test runner.'
        : false,
  );

  test('successful direct claim destroys the hosted key bundle', () async {
    final host = LanPairingService();
    const transferCode = 'sroy-link:test';
    final session = await host.startHosting(transferCode: transferCode);

    final response = await _postClaim(
      port: session.serverPort,
      code: session.pairingCode,
    );

    expect(response.statusCode, HttpStatus.ok);
    expect(jsonDecode(response.body)['transfer_code'], transferCode);

    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(host.isHosting, isFalse);
    await host.stopHosting();
  });

  test(
    'direct claim can return a requester-encrypted transfer bundle',
    () async {
      final host = LanPairingService();
      const transferCode = 'sroy-link:test';
      final requesterKeyPair = await VaultPairingCrypto.createKeyPair();
      final session = await host.startHosting(transferCode: transferCode);

      final response = await _postClaim(
        port: session.serverPort,
        code: session.pairingCode,
        requesterPublicKey: requesterKeyPair.publicKey,
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final wrappedTransferCode = body['wrapped_transfer_code'] as String;
      final decryptedTransferCode = await VaultPairingCrypto.decryptBundle(
        wrappedBundle: wrappedTransferCode,
        keyPair: requesterKeyPair,
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(body.containsKey('transfer_code'), isFalse);
      expect(wrappedTransferCode, startsWith(VaultPairingCrypto.prefix));
      expect(wrappedTransferCode.contains(transferCode), isFalse);
      expect(decryptedTransferCode, transferCode);

      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(host.isHosting, isFalse);
      await host.stopHosting();
    },
  );

  test('expired LAN code destroys the hosted key bundle', () async {
    final host = LanPairingService();
    await host.startHosting(
      transferCode: 'sroy-link:test',
      ttl: const Duration(milliseconds: 80),
    );

    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(host.isHosting, isFalse);
    await host.stopHosting();
  });

  test(
    'too many wrong LAN code attempts destroy the hosted key bundle',
    () async {
      final host = LanPairingService();
      final session = await host.startHosting(transferCode: 'sroy-link:test');
      final wrongCode = session.pairingCode == 'ABCDEFGH'
          ? 'HGFEDCBA'
          : 'ABCDEFGH';

      for (var i = 0; i < 5; i++) {
        final response = await _postClaim(
          port: session.serverPort,
          code: wrongCode,
        );
        expect(response.statusCode, HttpStatus.forbidden);
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(host.isHosting, isFalse);
      await host.stopHosting();
    },
  );
}

Future<http.Response> _postClaim({
  required int port,
  required String code,
  String? requesterPublicKey,
}) {
  return http.post(
    Uri.parse('http://127.0.0.1:$port/lan-pairing/claim'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({
      'code': code,
      'requester_device_id': 'device_abcdef123456',
      if (requesterPublicKey != null)
        'requester_public_key': requesterPublicKey,
    }),
  );
}
