import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';
import '../theme/app_layout.dart';

/// 可复用的选项列表项，支持单选/多选视觉状态。
///
/// 桌面端支持键盘 `Enter` / `Space` 触发（通过 [InkWell] 内置焦点支持）。
class AppOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  const AppOptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final layout = AppLayout.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: layout.isCompact ? AppSpacing.xs : AppSpacing.sm,
            vertical: layout.isCompact ? AppSpacing.md : AppSpacing.lg,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withAlpha(90),
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
                child: Icon(icon, color: colors.primary),
              ),
              SizedBox(width: layout.isCompact ? AppSpacing.md : AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: layout.isCompact ? AppSpacing.md : AppSpacing.lg),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? colors.primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? colors.primary : colors.outline,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, size: 14, color: colors.onPrimary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
