import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 三档跨平台布局档位。
///
/// - [compact]：窄屏（<720px），手机竖屏为主。
/// - [medium]：中屏（720~1080px），平板横屏、小尺寸桌面窗口。
/// - [expanded]：宽屏（>1080px），桌面端全屏、大屏 Web。
enum AppLayoutType { compact, medium, expanded }

/// 当前布局的完整数据快照。
///
/// 通过 [AppLayout.of] 获取，所有字段均为计算后的常量，可直接用于 build。
@immutable
class AppLayoutData {
  final AppLayoutType type;
  final double screenWidth;
  final double contentMaxWidth;
  final double horizontalPadding;
  final bool isTouchDevice;
  final bool useCompactDensity;

  const AppLayoutData._({
    required this.type,
    required this.screenWidth,
    required this.contentMaxWidth,
    required this.horizontalPadding,
    required this.isTouchDevice,
    required this.useCompactDensity,
  });

  bool get isCompact => type == AppLayoutType.compact;
  bool get isMedium => type == AppLayoutType.medium;
  bool get isExpanded => type == AppLayoutType.expanded;
  bool get isPointerDevice => !isTouchDevice;
}

/// 跨平台布局工具类。
///
/// 提供断点判断、内容宽度约束、平台交互方式检测等。
///
/// 使用方式：
/// ```dart
/// final layout = AppLayout.of(context);
/// if (layout.isExpanded) { ... }
/// ```
abstract final class AppLayout {
  // --------------------------------------------------------------------------
  // Breakpoint helpers
  // --------------------------------------------------------------------------

  static AppLayoutType typeOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1080) return AppLayoutType.expanded;
    if (width >= 720) return AppLayoutType.medium;
    return AppLayoutType.compact;
  }

  static bool isCompact(BuildContext context) =>
      typeOf(context) == AppLayoutType.compact;

  static bool isMedium(BuildContext context) =>
      typeOf(context) == AppLayoutType.medium;

  static bool isExpanded(BuildContext context) =>
      typeOf(context) == AppLayoutType.expanded;

  // --------------------------------------------------------------------------
  // Full layout data
  // --------------------------------------------------------------------------

  static AppLayoutData of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final type = typeOf(context);
    return AppLayoutData._(
      type: type,
      screenWidth: width,
      contentMaxWidth: switch (type) {
        AppLayoutType.compact => double.infinity,
        AppLayoutType.medium => 820,
        AppLayoutType.expanded => 1080,
      },
      horizontalPadding: switch (type) {
        AppLayoutType.compact => 16,
        AppLayoutType.medium => 24,
        AppLayoutType.expanded => 32,
      },
      isTouchDevice: _isTouchDevice,
      useCompactDensity: type == AppLayoutType.compact,
    );
  }

  // --------------------------------------------------------------------------
  // Platform / input detection
  // --------------------------------------------------------------------------

  /// 当前目标平台是否为触摸优先设备。
  ///
  /// Android、iOS、Fuchsia 返回 true；
  /// Windows、macOS、Linux 返回 false。
  static bool get _isTouchDevice {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia =>
        true,
      _ => false,
    };
  }

  static bool isTouchDeviceOf(BuildContext context) => of(context).isTouchDevice;

  static bool isPointerDeviceOf(BuildContext context) =>
      !of(context).isTouchDevice;

  // --------------------------------------------------------------------------
  // Legacy compatibility (matches old AppBreakpoints)
  // --------------------------------------------------------------------------

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 720;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1080;
}
