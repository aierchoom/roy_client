import 'package:flutter/foundation.dart';

/// Lightweight logger that no-ops in release builds.
///
/// Replaces raw [debugPrint] calls to satisfy the `avoid_print` lint
/// while keeping debug output available in development.
abstract final class AppLogger {
  static void d(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
