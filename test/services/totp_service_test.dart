import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/totp_service.dart';

void main() {
  group('RFC 6238 vectors', () {
    const sha1Secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
    const sha256Secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA';
    const sha512Secret =
        'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBV'
        'GY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA';

    final vectors =
        <({int seconds, String sha1, String sha256, String sha512})>[
          (
            seconds: 59,
            sha1: '94287082',
            sha256: '46119246',
            sha512: '90693936',
          ),
          (
            seconds: 1111111109,
            sha1: '07081804',
            sha256: '68084774',
            sha512: '25091201',
          ),
          (
            seconds: 1111111111,
            sha1: '14050471',
            sha256: '67062674',
            sha512: '99943326',
          ),
          (
            seconds: 1234567890,
            sha1: '89005924',
            sha256: '91819424',
            sha512: '93441116',
          ),
          (
            seconds: 2000000000,
            sha1: '69279037',
            sha256: '90698825',
            sha512: '38618901',
          ),
          (
            seconds: 20000000000,
            sha1: '65353130',
            sha256: '77737706',
            sha512: '47863826',
          ),
        ];

    for (final vector in vectors) {
      test('generates expected codes at ${vector.seconds}', () {
        final at = DateTime.fromMillisecondsSinceEpoch(
          vector.seconds * 1000,
          isUtc: true,
        );

        expect(
          const TotpService()
              .generate(
                const TotpConfig(
                  secret: sha1Secret,
                  algorithm: TotpAlgorithm.sha1,
                  digits: 8,
                ),
                at: at,
              )
              .value,
          vector.sha1,
        );
        expect(
          const TotpService()
              .generate(
                const TotpConfig(
                  secret: sha256Secret,
                  algorithm: TotpAlgorithm.sha256,
                  digits: 8,
                ),
                at: at,
              )
              .value,
          vector.sha256,
        );
        expect(
          const TotpService()
              .generate(
                const TotpConfig(
                  secret: sha512Secret,
                  algorithm: TotpAlgorithm.sha512,
                  digits: 8,
                ),
                at: at,
              )
              .value,
          vector.sha512,
        );
      });
    }
  });

  group('Base32 parsing', () {
    test('normalizes lowercase, spaces, hyphens, and padding', () {
      expect(
        TotpService.normalizeSecret('jbsw y3dp-ehpk 3pxp===='),
        'JBSWY3DPEHPK3PXP',
      );
      expect(TotpService.decodeBase32('jbsw y3dp-ehpk 3pxp===='), [
        72,
        101,
        108,
        108,
        111,
        33,
        222,
        173,
        190,
        239,
      ]);
    });

    test('parses a raw Base32 secret with defaults', () {
      final config = TotpService.parseConfig('jbsw y3dp-ehpk 3pxp====');

      expect(config.secret, 'JBSWY3DPEHPK3PXP');
      expect(config.algorithm, TotpAlgorithm.sha1);
      expect(config.digits, 6);
      expect(config.period, 30);
    });
  });

  group('structured config parsing', () {
    test('parses JSON config and emits canonical JSON', () {
      final config = TotpService.parseConfig(
        jsonEncode({
          'secret': 'jbsw y3dp-ehpk 3pxp',
          'issuer': 'Example',
          'account': 'alice@example.com',
          'algorithm': 'sha-512',
          'digits': '8',
          'period': '45',
        }),
      );

      expect(config.secret, 'JBSWY3DPEHPK3PXP');
      expect(config.issuer, 'Example');
      expect(config.account, 'alice@example.com');
      expect(config.algorithm, TotpAlgorithm.sha512);
      expect(config.digits, 8);
      expect(config.period, 45);
      expect(config.toJson(), {
        'secret': 'JBSWY3DPEHPK3PXP',
        'issuer': 'Example',
        'account': 'alice@example.com',
        'algorithm': 'SHA512',
        'digits': 8,
        'period': 45,
      });
    });

    test('parses otpauth URI fields', () {
      final config = TotpService.parseConfig(
        'otpauth://totp/Example:alice%40example.com?'
        'secret=jbsw-y3dp-ehpk-3pxp&issuer=Example&'
        'algorithm=SHA256&digits=8&period=45',
      );

      expect(config.secret, 'JBSWY3DPEHPK3PXP');
      expect(config.issuer, 'Example');
      expect(config.account, 'alice@example.com');
      expect(config.algorithm, TotpAlgorithm.sha256);
      expect(config.digits, 8);
      expect(config.period, 45);
    });

    test('encodes pasted config as canonical JSON', () {
      final encoded = TotpService.encodeConfig(
        'otpauth://totp/Example:alice%40example.com?'
        'secret=jbsw-y3dp-ehpk-3pxp&issuer=Example&'
        'algorithm=SHA256&digits=8&period=45',
      );
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded, {
        'secret': 'JBSWY3DPEHPK3PXP',
        'issuer': 'Example',
        'account': 'alice@example.com',
        'algorithm': 'SHA256',
        'digits': 8,
        'period': 45,
      });
    });

    test('uses label issuer when query issuer is absent', () {
      final config = TotpService.parseConfig(
        'otpauth://totp/Example:alice%40example.com?secret=JBSWY3DPEHPK3PXP',
      );

      expect(config.issuer, 'Example');
      expect(config.account, 'alice@example.com');
    });
  });

  group('code timing', () {
    test('reports seconds remaining in the active period', () {
      final service = const TotpService();
      const config = TotpConfig(secret: 'JBSWY3DPEHPK3PXP');

      final lastSecond = service.generate(
        config,
        at: DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true),
      );
      final firstSecond = service.generate(
        config,
        at: DateTime.fromMillisecondsSinceEpoch(60000, isUtc: true),
      );

      expect(lastSecond.secondsRemaining, 1);
      expect(firstSecond.secondsRemaining, 30);
      expect(firstSecond.counter, 2);
    });
  });

  group('validation', () {
    test('rejects invalid configs', () {
      final invalidInputs = [
        '',
        '{}',
        'otpauth://hotp/Example:alice?secret=JBSWY3DPEHPK3PXP',
        'ABC1',
        '{"secret":"JBSWY3DPEHPK3PXP","digits":5}',
        '{"secret":"JBSWY3DPEHPK3PXP","digits":"abc"}',
        '{"secret":"JBSWY3DPEHPK3PXP","period":0}',
        '{"secret":"JBSWY3DPEHPK3PXP","period":"abc"}',
      ];

      for (final input in invalidInputs) {
        expect(
          () => TotpService.parseConfig(input),
          throwsA(isA<TotpException>()),
          reason: input,
        );
      }
    });
  });
}
