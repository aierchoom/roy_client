import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppBreakpoints {
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 720;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1080;

  static double contentWidth(
    BuildContext context, {
    double tabletMaxWidth = 820,
    double desktopMaxWidth = 1240,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1080) return math.min(width, desktopMaxWidth);
    if (width >= 720) return math.min(width, tabletMaxWidth);
    return width;
  }
}

class AppSectionWidths {
  static const double hero = 760;
  static const double panel = 860;
}

class AdaptivePage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double tabletMaxWidth;
  final double desktopMaxWidth;

  const AdaptivePage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.tabletMaxWidth = 820,
    this.desktopMaxWidth = 1240,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final targetWidth = width >= 1080
            ? math.min(width, desktopMaxWidth)
            : width >= 720
            ? math.min(width, tabletMaxWidth)
            : width;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: targetWidth),
            child: Padding(padding: padding, child: child),
          ),
        );
      },
    );
  }
}

class AdaptiveSection extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  const AdaptiveSection({
    super.key,
    required this.child,
    required this.maxWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
