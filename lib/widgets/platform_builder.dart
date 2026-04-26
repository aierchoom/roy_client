import 'package:flutter/material.dart';
import 'adaptive_page.dart';

class PlatformBuilder extends StatelessWidget {
  final WidgetBuilder mobileBuilder;
  final WidgetBuilder? desktopBuilder;

  const PlatformBuilder({
    super.key,
    required this.mobileBuilder,
    this.desktopBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isDesktop(context) && desktopBuilder != null) {
      return desktopBuilder!(context);
    }
    return mobileBuilder(context);
  }
}
