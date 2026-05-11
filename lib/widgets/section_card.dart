import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

/// A reusable section card with title, subtitle, and child content.
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double childGap;
  final bool useOutlinedBorder;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl2),
    this.childGap = AppSpacing.lg,
    this.useOutlinedBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm2),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: childGap),
          child,
        ],
      ),
    );

    if (useOutlinedBorder) {
      content = Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(AppAlphas.low),
          ),
        ),
        child: content,
      );
    } else {
      content = Card(child: content);
    }

    return content;
  }
}
