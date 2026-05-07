import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';
import '../theme/app_layout.dart';
import '../theme/app_text_styles.dart';

/// 可复用的 Hero Card，用于页面顶部视觉焦点区域。
///
/// 支持渐变背景、图标、标题、副标题、指标 chips 和尾部操作区。
/// 自动根据 [AppLayout] 调整内边距和尺寸。
class AppHeroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget>? metrics;
  final Widget? trailing;
  final List<Color>? gradientColors;
  final EdgeInsetsGeometry? padding;

  const AppHeroCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.metrics,
    this.trailing,
    this.gradientColors,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final layout = AppLayout.of(context);

    final effectivePadding =
        padding ??
        EdgeInsets.all(layout.isCompact ? AppSpacing.lg : AppSpacing.xxl);

    final effectiveGradient =
        gradientColors ?? [colors.primaryContainer, colors.tertiaryContainer];

    return Container(
      padding: effectivePadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: effectiveGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(
          color: colors.primary.withAlpha(layout.isCompact ? 32 : 48),
        ),
        boxShadow: AppShadows.low(theme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(
                  layout.isCompact ? AppSpacing.md : AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withAlpha(layout.isCompact ? 210 : 230),
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
                child: Icon(
                  icon,
                  size: layout.isCompact ? 24 : 28,
                  color: colors.primary,
                ),
              ),
              SizedBox(width: layout.isCompact ? AppSpacing.md : AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heroTitle(
                        context,
                      ).copyWith(color: colors.onPrimaryContainer),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heroSubtitle(context).copyWith(
                          color: colors.onPrimaryContainer.withAlpha(160),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(
                  width: layout.isCompact ? AppSpacing.md : AppSpacing.lg,
                ),
                trailing!,
              ],
            ],
          ),
          if (metrics != null && metrics!.isNotEmpty) ...[
            SizedBox(height: layout.isCompact ? AppSpacing.md : AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: metrics!,
            ),
          ],
        ],
      ),
    );
  }
}
