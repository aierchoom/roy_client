import 'package:flutter/material.dart';

import '../theme/app_layout.dart';

/// 跨平台可滚动容器包装器。
///
/// 在桌面端 / Web（指针设备）上自动包裹：
/// - [Scrollbar]：显式滚动条
/// - [SelectionArea]：文本可选中复制
///
/// 触摸设备上保持原生行为，不额外包裹。
///
/// 子 widget 必须是 Scrollable（如 [ListView]、[CustomScrollView]、[SingleChildScrollView]）。
class AppSelectableScrollable extends StatelessWidget {
  final Widget child;
  final bool showScrollbar;
  final bool selectable;
  final ScrollController? controller;

  const AppSelectableScrollable({
    super.key,
    required this.child,
    this.showScrollbar = true,
    this.selectable = true,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    Widget result = child;

    if (layout.isPointerDevice) {
      if (showScrollbar) {
        result = Scrollbar(
          controller: controller,
          child: result,
        );
      }
      if (selectable) {
        result = SelectionArea(child: result);
      }
    }

    return result;
  }
}
