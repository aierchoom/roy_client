import 'package:flutter/material.dart';

import '../theme/app_layout.dart';

/// 三档断点布局构建器。
///
/// 根据屏幕宽度自动在 compact / medium / expanded 之间切换，
/// 向后兼容：若未提供某档位构建器，自动降级到前一档。
///
/// 用于替换原有的 `PlatformBuilder`（仅区分 mobile/desktop）。
class AppLayoutBuilder extends StatelessWidget {
  final WidgetBuilder compactBuilder;
  final WidgetBuilder? mediumBuilder;
  final WidgetBuilder? expandedBuilder;

  const AppLayoutBuilder({
    super.key,
    required this.compactBuilder,
    this.mediumBuilder,
    this.expandedBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final type = AppLayout.typeOf(context);
    return switch (type) {
      AppLayoutType.compact => compactBuilder(context),
      AppLayoutType.medium =>
        mediumBuilder?.call(context) ?? compactBuilder(context),
      AppLayoutType.expanded =>
        expandedBuilder?.call(context) ??
            mediumBuilder?.call(context) ??
            compactBuilder(context),
    };
  }
}
