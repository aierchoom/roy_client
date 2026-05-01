import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:secret_roy/services/totp_qr_image_import_service.dart';
import 'package:secret_roy/services/totp_service.dart';
import 'package:zxing2/qrcode.dart';

void main() {
  group('TotpQrImageImportService', () {
    test('decodes a TOTP QR image from bytes', () {
      final uri = _totpUri('alice@example.com');
      final bytes = _qrPng(uri);

      final raw = TotpQrImageImportService.decodeQrImage(bytes);

      expect(raw, uri);
    });

    test('normalizes a clipboard QR image into stored TOTP config', () async {
      final bytes = _qrPng(_totpUri('bob@example.com'));

      final normalized =
          await TotpQrImageImportService.normalizeClipboardQrImage(
            imageReader: () async => bytes,
          );
      final config = TotpService.parseConfig(normalized);

      expect(config.secret, 'JBSWY3DPEHPK3PXP');
      expect(config.issuer, 'Example');
      expect(config.account, 'bob@example.com');
      expect(config.algorithm, TotpAlgorithm.sha1);
    });

    test('rejects clipboard without an image', () async {
      expect(
        TotpQrImageImportService.normalizeClipboardQrImage(
          imageReader: () async => null,
        ),
        throwsA(
          isA<TotpException>().having(
            (error) => error.message,
            'message',
            TotpQrImageImportService.noClipboardImageMessage,
          ),
        ),
      );
    });

    test('rejects image bytes that cannot be decoded', () {
      expect(
        () => TotpQrImageImportService.decodeQrImage(
          Uint8List.fromList([0, 1, 2, 3]),
        ),
        throwsA(
          isA<TotpException>().having(
            (error) => error.message,
            'message',
            TotpQrImageImportService.imageDecodeFailedMessage,
          ),
        ),
      );
    });

    test('rejects a readable image without a QR code', () {
      final image = image_lib.Image(width: 96, height: 96);
      image_lib.fill(image, color: image_lib.ColorRgb8(255, 255, 255));

      expect(
        () => TotpQrImageImportService.decodeQrImage(
          Uint8List.fromList(image_lib.encodePng(image)),
        ),
        throwsA(
          isA<TotpException>().having(
            (error) => error.message,
            'message',
            TotpQrImageImportService.noQrCodeFoundMessage,
          ),
        ),
      );
    });
  });
}

String _totpUri(String account) {
  final encodedAccount = Uri.encodeComponent(account);
  return 'otpauth://totp/Example:$encodedAccount'
      '?secret=JBSWY3DPEHPK3PXP&issuer=Example';
}

Uint8List _qrPng(String content) {
  final qr = Encoder.encode(content, ErrorCorrectionLevel.h);
  final matrix = qr.matrix!;
  const quietZone = 4;
  const scale = 8;
  final size = (matrix.width + quietZone * 2) * scale;
  final image = image_lib.Image(width: size, height: size);
  image_lib.fill(image, color: image_lib.ColorRgb8(255, 255, 255));

  for (var y = 0; y < matrix.height; y += 1) {
    for (var x = 0; x < matrix.width; x += 1) {
      if (matrix.get(x, y) != 1) continue;
      final x1 = (x + quietZone) * scale;
      final y1 = (y + quietZone) * scale;
      image_lib.fillRect(
        image,
        x1: x1,
        y1: y1,
        x2: x1 + scale - 1,
        y2: y1 + scale - 1,
        color: image_lib.ColorRgb8(0, 0, 0),
      );
    }
  }

  return Uint8List.fromList(image_lib.encodePng(image));
}
