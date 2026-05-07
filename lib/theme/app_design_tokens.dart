import 'package:flutter/material.dart';

abstract final class AppBrandColors {
  static const Color defaultSeed = Color(0xFF176B87);

  static const List<Color> presets = [
    defaultSeed,
    Color(0xFF0F766E),
    Color(0xFF2563EB),
    Color(0xFF475569),
    Colors.deepPurple,
    Colors.teal,
    Colors.green,
    Colors.amber,
    Colors.orange,
    Colors.red,
    Colors.pink,
  ];
}

abstract final class AppRadii {
  static const double chip = 6;
  static const double sm = 8;
  static const double control = 10;
  static const double button = 12;
  static const double card = 12;
  static const double panel = 16;
  static const double dialog = 20;
  static const double sheet = 20;
  static const double nav = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double pill = 999;
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

abstract final class AppSurfaces {
  static Color lightBackground(ColorScheme colors) {
    return Color.alphaBlend(colors.primary.withAlpha(8), colors.surface);
  }

  static Color darkBackground(ColorScheme colors, {required bool trueBlack}) {
    if (trueBlack) return Colors.black;
    return Color.alphaBlend(colors.primary.withAlpha(10), colors.surface);
  }

  static Color lightInput(ColorScheme colors) {
    return Color.alphaBlend(
      colors.primary.withAlpha(6),
      colors.surfaceContainerHighest,
    );
  }

  static Color darkInput(ColorScheme colors, {required bool trueBlack}) {
    if (trueBlack) return const Color(0xFF0A0C0E);
    return colors.surfaceContainerHighest;
  }

  static Color darkCard(ColorScheme colors, {required bool trueBlack}) {
    if (trueBlack) return const Color(0xFF0D1012);
    return colors.surface;
  }

  /// 柔和的 Surface 色调混合。
  ///
  /// 在浅色模式下将 [tint] 以 [tintAlpha] 的不透明度混合到 surface 上；
  /// 在深色模式下回退到 [surfaceContainerHigh]，避免过亮。
  static Color soft(ColorScheme colors, {Color? tint, int tintAlpha = 18}) {
    final base = colors.surface;
    if (tint == null) return base;
    if (colors.brightness == Brightness.dark) {
      return colors.surfaceContainerHigh;
    }
    return Color.alphaBlend(tint.withAlpha(tintAlpha), base);
  }
}

abstract final class AppAlphas {
  static const int tint = 18;
  static const int subtle = 24;
  static const int low = 40;
  static const int medium = 60;
  static const int high = 80;
  static const int strong = 90;
  static const int divider = 100;
  static const int outline = 120;
  static const int emphasis = 180;
  static const int surfaceOverlay = 210;
  static const int surface = 232;
}

abstract final class AppBorders {
  static BorderSide subtle(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return BorderSide(color: color.withAlpha(80));
  }

  static BorderSide medium(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return BorderSide(color: color.withAlpha(120));
  }

  static BorderSide strong(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return BorderSide(color: color.withAlpha(160));
  }

  static BorderSide primary(BuildContext context, {int alpha = 48}) {
    final color = Theme.of(context).colorScheme.primary;
    return BorderSide(color: color.withAlpha(alpha));
  }

  static BorderSide tint(Color color, {int alpha = 48}) {
    return BorderSide(color: color.withAlpha(alpha));
  }
}

abstract final class AppShadows {
  static List<BoxShadow> low(ThemeData theme) {
    if (theme.brightness != Brightness.light) return const [];
    return [
      BoxShadow(
        color: theme.colorScheme.shadow.withAlpha(10),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// 柔和的卡片阴影，仅在浅色模式下生效。
  ///
  /// [depth] 控制阴影深度，1.0 为标准卡片，0.45 为轻量内嵌元素。
  static List<BoxShadow> card(ThemeData theme, {double depth = 1.0}) {
    if (theme.brightness != Brightness.light) return const [];
    return [
      BoxShadow(
        color: theme.colorScheme.shadow.withAlpha(
          (10 * depth).round().clamp(0, 255),
        ),
        blurRadius: 28 * depth,
        offset: Offset(0, 16 * depth),
      ),
      BoxShadow(
        color: theme.colorScheme.primary.withAlpha(
          (6 * depth).round().clamp(0, 255),
        ),
        blurRadius: 12 * depth,
        offset: Offset(0, 6 * depth),
      ),
    ];
  }

  /// Hero 区域专用阴影，默认深度略大于普通卡片。
  static List<BoxShadow> hero(ThemeData theme, {double depth = 1.15}) =>
      card(theme, depth: depth);
}

@immutable
class AppVisualTokens extends ThemeExtension<AppVisualTokens> {
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;

  const AppVisualTokens({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  factory AppVisualTokens.fromBrightness(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return AppVisualTokens(
      success: isDark ? const Color(0xFF7DD3A8) : const Color(0xFF14804A),
      successContainer: isDark
          ? const Color(0xFF123A27)
          : const Color(0xFFDDF7E8),
      onSuccessContainer: isDark
          ? const Color(0xFFDDF7E8)
          : const Color(0xFF0B3D25),
      warning: isDark ? const Color(0xFFFACC6B) : const Color(0xFFB7791F),
      warningContainer: isDark
          ? const Color(0xFF3E2E12)
          : const Color(0xFFFFF3CF),
      onWarningContainer: isDark
          ? const Color(0xFFFFF3CF)
          : const Color(0xFF4A3000),
      info: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
      infoContainer: isDark ? const Color(0xFF123246) : const Color(0xFFDDF4FF),
      onInfoContainer: isDark
          ? const Color(0xFFDDF4FF)
          : const Color(0xFF083344),
    );
  }

  @override
  AppVisualTokens copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return AppVisualTokens(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  AppVisualTokens lerp(ThemeExtension<AppVisualTokens>? other, double t) {
    if (other is! AppVisualTokens) return this;
    return AppVisualTokens(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}
