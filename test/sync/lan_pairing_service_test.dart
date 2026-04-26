import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/lan_pairing_service.dart';

void main() {
  test('normalizePairingCode accepts exactly 6 digits', () {
    expect(LanPairingService.normalizePairingCode('123456'), '123456');
    expect(LanPairingService.normalizePairingCode(' 123456 '), '123456');
  });

  test('normalizePairingCode rejects invalid values', () {
    expect(
      () => LanPairingService.normalizePairingCode('12345'),
      throwsA(isA<LanPairingServiceException>()),
    );
    expect(
      () => LanPairingService.normalizePairingCode('12A456'),
      throwsA(isA<LanPairingServiceException>()),
    );
  });

  test(
    'startHosting creates a 6-digit LAN session and can stop cleanly',
    () async {
      final service = LanPairingService();
      final session = await service.startHosting(
        transferCode: 'sroy-link-v1:test',
      );

      expect(session.pairingCode, matches(RegExp(r'^\d{6}$')));
      expect(service.isHosting, isTrue);

      await service.stopHosting();
      expect(service.isHosting, isFalse);
    },
  );

  test('claimTransferCodeByCode imports the host transfer code', () async {
    final host = LanPairingService();
    final requester = LanPairingService();
    const transferCode = 'sroy-link-v1:test';

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
  });
}
