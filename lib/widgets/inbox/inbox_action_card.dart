import 'package:flutter/material.dart';

import '../../theme/app_design_tokens.dart';
import 'inbox_models.dart';

/// A large tappable summary card with a leading icon container,
/// title, subtitle and a trailing chevron.
///
/// Used for category-level summaries (e.g. "3 sync conflicts").
class ActionSummaryCard extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? leading;

  const ActionSummaryCard({
    super.key,
    this.icon,
    this.iconColor,
    this.backgroundColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;
    final bg = backgroundColor ?? theme.colorScheme.surfaceContainerHighest.withAlpha(80);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(color: effectiveIconColor.withAlpha(AppAlphas.low)),
          ),
          child: Row(
            children: [
              leading ?? _IconContainer(icon: icon ?? Icons.info_outline, color: effectiveIconColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right,
                  size: 20, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// A smaller tappable item card with a leading severity icon,
/// title, subtitle and an optional chevron.
///
/// Used for individual inbox items (e.g. a single health issue
/// or a single notification).
class ActionItemCard extends StatelessWidget {
  final InboxSeverity severity;
  final String title;
  final String subtitle;
  final bool showChevron;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ActionItemCard({
    super.key,
    required this.severity,
    required this.title,
    required this.subtitle,
    this.showChevron = true,
    this.onTap,
    this.trailing,
  });

  static Color _severityColor(InboxSeverity severity, ThemeData theme) {
    return switch (severity) {
      InboxSeverity.critical => Colors.red,
      InboxSeverity.warning => Colors.orange,
      InboxSeverity.info => theme.colorScheme.primary,
      InboxSeverity.success => Colors.green,
    };
  }

  static IconData _severityIcon(InboxSeverity severity) {
    return switch (severity) {
      InboxSeverity.critical => Icons.error_outline,
      InboxSeverity.warning => Icons.warning_amber_rounded,
      InboxSeverity.info => Icons.info_outline,
      InboxSeverity.success => Icons.check_circle_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _severityColor(severity, theme);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withAlpha(AppAlphas.subtle),
            ),
          ),
          child: Row(
            children: [
              _IconContainer(icon: _severityIcon(severity), color: color, size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ] else if (showChevron) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconContainer extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _IconContainer({
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(size > 36 ? 12 : 10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size > 36 ? 20 : 18, color: color),
    );
  }
}
