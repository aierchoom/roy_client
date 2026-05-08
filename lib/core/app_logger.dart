import 'package:flutter/foundation.dart';

/// Lightweight logger that no-ops in release builds for debug messages
/// but always logs errors and warnings.
abstract final class AppLogger {
  static void d(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Warning-level log. Visible in debug mode.
  static void w(String message) {
    if (kDebugMode) {
      debugPrint('[W] $message');
    }
  }

  /// Error-level log. Always visible (including release builds)
  /// for critical issues like sync failures, data corruption, etc.
  static void e(String message) {
    debugPrint('[E] $message');
  }
}
