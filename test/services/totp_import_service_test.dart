import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/totp_import_service.dart';
import 'package:secret_roy/services/totp_service.dart';

void main() {
  group('TotpImportService', () {
    test('normalizes a plain otpauth URI', () {
      final normalized = TotpImportService.normalizeImportValue(
        'otpauth://totp/Example:alice%40example.com?'
        'secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA256',
      );

      final config = TotpService.parseConfig(normalized);

      expect(config.secret, 'JBSWY3DPEHPK3PXP');
      expect(config.issuer, 'Example');
      expect(config.account, 'alice@example.com');
      expect(config.algorithm, TotpAlgorithm.sha256);
    });

    test('extracts an otpauth URI from copied QR text', () {
      final normalized = TotpImportService.normalizeImportValue(
        'Use this QR content: '
        'otpauth://totp/Example:bob%40example.com?'
        'secret=JBSWY3DPEHPK3PXP&issuer=Example.',
      );

      final config = TotpService.parseConfig(normalized);

      expect(config.secret, 'JBSWY3DPEHPK3PXP');
      expect(config.issuer, 'Example');
      expect(config.account, 'bob@example.com');
    });

    test('extracts a labeled Base32 secret from clipboard text', () {
      final normalized = TotpImportService.normalizeImportValue(
        'Secret: JBSW Y3DP-EHPK 3PXP',
      );

      final config = TotpService.parseConfig(normalized);

      expect(config.secret, 'JBSWY3DPEHPK3PXP');
      expect(config.digits, TotpService.defaultDigits);
      expect(config.period, TotpService.defaultPeriod);
    });

    test('rejects clipboard text without TOTP content', () {
      expect(
        () => TotpImportService.normalizeImportValue('hello world'),
        throwsA(isA<TotpException>()),
      );
    });
  });
}
