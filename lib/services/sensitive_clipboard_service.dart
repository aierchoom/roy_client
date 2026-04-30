import 'dart:async';

import 'package:flutter/services.dart';

class SensitiveClipboardService {
  static const defaultClearAfter = Duration(seconds: 45);

  static Timer? _clearTimer;

  const SensitiveClipboardService._();

  static Future<void> copy(
    String text, {
    Duration clearAfter = defaultClearAfter,
  }) async {
    _clearTimer?.cancel();
    await Clipboard.setData(ClipboardData(text: text));

    if (clearAfter == Duration.zero) {
      await _clearIfUnchanged(text);
      return;
    }

    _clearTimer = Timer(clearAfter, () {
      unawaited(_clearIfUnchanged(text));
    });
  }

  static void cancelPendingClear() {
    _clearTimer?.cancel();
    _clearTimer = null;
  }

  static Future<void> _clearIfUnchanged(String expectedText) async {
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == expectedText) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
    if (_clearTimer != null) {
      _clearTimer = null;
    }
  }
}
