import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

/// 设置组容器，自动用 Card 包裹并在子项之间插入 Divider。
///
/// 用于替代各设置页重复的 `Column(children: [tile, Divider(), tile])` 模式。
class AppSettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const AppSettingsGroup({super.key, required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        padding ?? const EdgeInsets.symmetric(vertical: AppSpacing.sm);

    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(
          const Divider(
            height: 1,
            indent: AppSpacing.lg,
            endIndent: AppSpacing.lg,
            thickness: 0.5,
          ),
        );
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: effectivePadding,
        child: Column(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );
  }
}
