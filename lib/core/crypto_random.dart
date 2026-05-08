import 'dart:math';
import 'dart:typed_data';

/// Shared cryptographic random utilities.
/// All services should use this instead of implementing their own _randomBytes.
abstract final class CryptoRandom {
  static Uint8List bytes(int length) {
    final random = Random.secure();
    final data = Uint8List(length);
    for (var i = 0; i < length; i++) {
      data[i] = random.nextInt(256);
    }
    return data;
  }
}
