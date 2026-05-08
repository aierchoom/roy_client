import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;
import 'package:pasteboard/pasteboard.dart';
import 'package:zxing2/qrcode.dart';

import 'totp_import_service.dart';
import 'totp_service.dart';

class TotpQrImageImportService {
  static const noClipboardImageMessage = 'No QR image was found in clipboard.';
  static const imageDecodeFailedMessage =
      'Clipboard QR image could not be decoded.';
  static const noQrCodeFoundMessage =
      'No QR code was found in clipboard image.';

  const TotpQrImageImportService._();

  static Future<String> normalizeClipboardQrImage({
    Future<Uint8List?> Function()? imageReader,
  }) async {
    final bytes = await (imageReader ?? (() => Pasteboard.image))();
    if (bytes == null || bytes.isEmpty) {
      throw const TotpException(noClipboardImageMessage);
    }
    return normalizeImageBytes(bytes);
  }

  static String normalizeImageBytes(Uint8List bytes) {
    final raw = decodeQrImage(bytes);
    return TotpImportService.normalizeImportValue(raw);
  }

  static String decodeQrImage(Uint8List bytes) {
    final image_lib.Image? image;
    try {
      image = image_lib.decodeImage(bytes);
    } catch (_) {
      // Image library decode failure is indistinguishable from unsupported format.
      throw const TotpException(imageDecodeFailedMessage);
    }
    if (image == null) {
      throw const TotpException(imageDecodeFailedMessage);
    }

    final pixels = _toRgbPixels(image);
    final source = RGBLuminanceSource(image.width, image.height, pixels);
    final bitmap = BinaryBitmap(HybridBinarizer(source));

    try {
      return QRCodeReader().decode(bitmap).text;
    } on ReaderException {
      throw const TotpException(noQrCodeFoundMessage);
    } catch (_) {
      // Non-ReaderException decode failure is treated the same way.
      throw const TotpException(noQrCodeFoundMessage);
    }
  }

  static Int32List _toRgbPixels(image_lib.Image image) {
    final pixels = Int32List(image.width * image.height);
    var offset = 0;
    for (var y = 0; y < image.height; y += 1) {
      for (var x = 0; x < image.width; x += 1) {
        final pixel = image.getPixel(x, y);
        final red = pixel.r.toInt() & 0xff;
        final green = pixel.g.toInt() & 0xff;
        final blue = pixel.b.toInt() & 0xff;
        pixels[offset] = (red << 16) | (green << 8) | blue;
        offset += 1;
      }
    }
    return pixels;
  }
}
