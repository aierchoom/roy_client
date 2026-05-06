import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';
import '../theme/app_layout.dart';

/// 设置页列表项，支持图标、标题、副标题、尾部操作和桌面端悬停反馈。
class AppSettingsTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showChevron;
  final Widget? trailing;

  const AppSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.showChevron = true,
    this.trailing,
  });

  @override
  State<AppSettingsTile> createState() => _AppSettingsTileState();
}

class _AppSettingsTileState extends State<AppSettingsTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final layout = AppLayout.of(context);
    final isPointer = layout.isPointerDevice;

    Widget tile = ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withAlpha(100),
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Icon(widget.icon, color: colors.primary, size: 22),
      ),
      title: Text(
        widget.title,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: widget.subtitle != null
          ? Text(
              widget.subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            )
          : null,
      trailing: widget.trailing ??
          (widget.showChevron
              ? Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colors.onSurfaceVariant,
                )
              : null),
      onTap: widget.onTap,
    );

    if (isPointer && widget.onTap != null) {
      tile = MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovering
                ? colors.onSurface.withAlpha(8)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: tile,
        ),
      );
    }

    return tile;
  }
}
