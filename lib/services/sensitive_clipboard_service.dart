import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

/// 剪贴板内容风险等级。
///
/// - [high]: 密码、恢复码、配对码、TOTP 验证码等高度敏感内容，必须定时清理。
/// - [medium]: vault ID、服务器地址等中度敏感内容，可缩短清理时长。
/// - [low]: 普通 UI 文案、非敏感文本，不自动清理。
enum ClipboardRiskLevel { high, medium, low }

/// 管理敏感内容的剪贴板复制与定时清理。
///
/// 清理前会检查剪贴板当前内容是否仍是本服务写入的那条（通过 SHA-256 hash 比对），
/// 避免误删用户后续复制的其他内容。
class SensitiveClipboardService {
  static const defaultClearAfter = Duration(seconds: 45);
  static const mediumClearAfter = Duration(seconds: 30);

  static Timer? _clearTimer;
  static String? _lastHash;

  const SensitiveClipboardService._();

  /// 复制 [text] 到剪贴板，并根据 [level] 决定是否启动定时清理。
  ///
  /// [clearAfter] 可覆盖默认时长；[level] 为 [ClipboardRiskLevel.low] 时不清理。
  static Future<void> copy({
    required String text,
    ClipboardRiskLevel level = ClipboardRiskLevel.high,
    Duration? clearAfter,
  }) async {
    if (level == ClipboardRiskLevel.low) {
      await Clipboard.setData(ClipboardData(text: text));
      return;
    }

    _clearTimer?.cancel();
    await Clipboard.setData(ClipboardData(text: text));
    _lastHash = _hash(text);

    final effectiveClearAfter =
        clearAfter ??
        (level == ClipboardRiskLevel.medium
            ? mediumClearAfter
            : defaultClearAfter);

    if (effectiveClearAfter == Duration.zero) {
      await _clearIfUnchanged();
      return;
    }

    _clearTimer = Timer(effectiveClearAfter, () {
      unawaited(_clearIfUnchanged());
    });
  }

  /// 取消待执行的清理任务。
  static void cancelPendingClear() {
    _clearTimer?.cancel();
    _clearTimer = null;
    _lastHash = null;
  }

  static Future<void> _clearIfUnchanged() async {
    final lastHash = _lastHash;
    if (lastHash == null) return;

    final current = await Clipboard.getData(Clipboard.kTextPlain);
    final currentText = current?.text;
    if (currentText != null && _hash(currentText) == lastHash) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }

    _clearTimer = null;
    _lastHash = null;
  }

  static String _hash(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }
}
