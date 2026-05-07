import 'package:flutter/material.dart';

/// 跨平台文本密度。
///
/// - [compact]：移动端（<720px），更紧凑的字号与行高。
/// - [comfortable]：平板、桌面端、Web（>=720px），更宽松的阅读体验。
enum AppTextDensity { compact, comfortable }

/// 跨平台排版系统。
///
/// 根据屏幕宽度自动在 [compact] 与 [comfortable] 之间切换，
/// 所有样式已针对中文内容优化行高（1.5~1.6），避免过紧。
///
/// 使用方式：
/// ```dart
/// // 1) 直接获取当前上下文的 TextTheme（已按密度自动选择）
/// final textTheme = AppTextStyles.theme(context);
///
/// // 2) 获取单一 TextStyle
/// final style = AppTextStyles.titleMedium(context);
/// ```
abstract final class AppTextStyles {
  static AppTextDensity density(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 720 ? AppTextDensity.comfortable : AppTextDensity.compact;
  }

  static bool isCompact(BuildContext context) =>
      density(context) == AppTextDensity.compact;

  static bool isComfortable(BuildContext context) =>
      density(context) == AppTextDensity.comfortable;

  // --------------------------------------------------------------------------
  // Material TextTheme (for ThemeData)
  // --------------------------------------------------------------------------

  static TextTheme theme(BuildContext context) =>
      themeForDensity(density(context));

  static TextTheme themeForDensity(AppTextDensity density) {
    final c = density == AppTextDensity.compact;
    return TextTheme(
      displayLarge: _s(
        fontSize: c ? 36 : 44,
        height: c ? 1.15 : 1.15,
        weight: FontWeight.w700,
      ),
      displayMedium: _s(
        fontSize: c ? 32 : 40,
        height: c ? 1.2 : 1.2,
        weight: FontWeight.w700,
      ),
      displaySmall: _s(
        fontSize: c ? 28 : 36,
        height: c ? 1.2 : 1.25,
        weight: FontWeight.w700,
      ),
      headlineLarge: _s(
        fontSize: c ? 28 : 32,
        height: c ? 1.2 : 1.25,
        weight: FontWeight.w700,
      ),
      headlineMedium: _s(
        fontSize: c ? 24 : 28,
        height: c ? 1.25 : 1.3,
        weight: FontWeight.w700,
      ),
      headlineSmall: _s(
        fontSize: c ? 20 : 24,
        height: c ? 1.25 : 1.3,
        weight: FontWeight.w700,
      ),
      titleLarge: _s(
        fontSize: c ? 18 : 20,
        height: c ? 1.3 : 1.35,
        weight: FontWeight.w700,
      ),
      titleMedium: _s(
        fontSize: c ? 16 : 17,
        height: c ? 1.35 : 1.4,
        weight: FontWeight.w700,
      ),
      titleSmall: _s(
        fontSize: c ? 14 : 15,
        height: c ? 1.35 : 1.4,
        weight: FontWeight.w600,
      ),
      bodyLarge: _s(
        fontSize: c ? 16 : 17,
        height: c ? 1.5 : 1.6,
        weight: FontWeight.w400,
      ),
      bodyMedium: _s(
        fontSize: c ? 14 : 15,
        height: c ? 1.5 : 1.6,
        weight: FontWeight.w400,
      ),
      bodySmall: _s(
        fontSize: c ? 12 : 13,
        height: c ? 1.45 : 1.55,
        weight: FontWeight.w400,
      ),
      labelLarge: _s(
        fontSize: c ? 14 : 15,
        height: c ? 1.3 : 1.35,
        weight: FontWeight.w600,
      ),
      labelMedium: _s(
        fontSize: c ? 12 : 13,
        height: c ? 1.3 : 1.35,
        weight: FontWeight.w500,
      ),
      labelSmall: _s(
        fontSize: c ? 11 : 12,
        height: c ? 1.3 : 1.35,
        weight: FontWeight.w500,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Semantic shortcuts (read from ThemeData, but convenience helpers)
  // --------------------------------------------------------------------------

  static TextStyle? displayLarge(BuildContext context) =>
      theme(context).displayLarge;
  static TextStyle? displayMedium(BuildContext context) =>
      theme(context).displayMedium;
  static TextStyle? displaySmall(BuildContext context) =>
      theme(context).displaySmall;

  static TextStyle? headlineLarge(BuildContext context) =>
      theme(context).headlineLarge;
  static TextStyle? headlineMedium(BuildContext context) =>
      theme(context).headlineMedium;
  static TextStyle? headlineSmall(BuildContext context) =>
      theme(context).headlineSmall;

  static TextStyle? titleLarge(BuildContext context) =>
      theme(context).titleLarge;
  static TextStyle? titleMedium(BuildContext context) =>
      theme(context).titleMedium;
  static TextStyle? titleSmall(BuildContext context) =>
      theme(context).titleSmall;

  static TextStyle? bodyLarge(BuildContext context) => theme(context).bodyLarge;
  static TextStyle? bodyMedium(BuildContext context) =>
      theme(context).bodyMedium;
  static TextStyle? bodySmall(BuildContext context) => theme(context).bodySmall;

  static TextStyle? labelLarge(BuildContext context) =>
      theme(context).labelLarge;
  static TextStyle? labelMedium(BuildContext context) =>
      theme(context).labelMedium;
  static TextStyle? labelSmall(BuildContext context) =>
      theme(context).labelSmall;

  // --------------------------------------------------------------------------
  // Extra semantic styles (not part of Material3 TextTheme)
  // --------------------------------------------------------------------------

  /// Hero 区域主标题（如账户名称、页面大标题）
  static TextStyle heroTitle(BuildContext context) {
    final c = isCompact(context);
    return _s(
      fontSize: c ? 22 : 26,
      height: c ? 1.3 : 1.35,
      weight: FontWeight.w800,
    );
  }

  /// Hero 区域副标题
  static TextStyle heroSubtitle(BuildContext context) {
    final c = isCompact(context);
    return _s(
      fontSize: c ? 14 : 15,
      height: c ? 1.4 : 1.5,
      weight: FontWeight.w500,
    );
  }

  /// Chip / Tag 文字
  static TextStyle chipLabel(BuildContext context) {
    final c = isCompact(context);
    return _s(
      fontSize: c ? 12 : 13,
      height: c ? 1.2 : 1.25,
      weight: FontWeight.w700,
    );
  }

  /// 统计数字 / 指标
  static TextStyle metricValue(BuildContext context) {
    final c = isCompact(context);
    return _s(
      fontSize: c ? 20 : 24,
      height: c ? 1.2 : 1.25,
      weight: FontWeight.w800,
    );
  }

  /// 辅助说明 / Caption
  static TextStyle caption(BuildContext context) {
    final c = isCompact(context);
    return _s(
      fontSize: c ? 11 : 12,
      height: c ? 1.4 : 1.5,
      weight: FontWeight.w400,
    );
  }

  // --------------------------------------------------------------------------
  // Private helper
  // --------------------------------------------------------------------------

  static TextStyle _s({
    required double fontSize,
    required double height,
    required FontWeight weight,
  }) {
    return TextStyle(
      fontSize: fontSize,
      height: height,
      fontWeight: weight,
      letterSpacing: 0,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }
}
