import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

/// 导航目的地描述。
class AppNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? description;
  final int badgeCount;
  final String? badgeLabel;

  const AppNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.description,
    this.badgeCount = 0,
    this.badgeLabel,
  });
}

/// 桌面端侧边导航栏（NavRail）。
///
/// 支持 [header] 和 [footer] 插槽，自动处理选中态、悬停反馈和动画。
class AppNavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppNavDestination> destinations;
  final Widget? header;
  final Widget? footer;
  final double width;

  const AppNavRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.header,
    this.footer,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.panel),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(120),
          ),
          boxShadow: AppShadows.low(theme),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null) ...[
              header!,
              const SizedBox(height: AppSpacing.lg),
            ],
            for (var i = 0; i < destinations.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              _NavItem(
                destination: destinations[i],
                selected: selectedIndex == i,
                onTap: () => onDestinationSelected(i),
              ),
            ],
            const Spacer(),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

class NavBadgeIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int badgeCount;

  const NavBadgeIcon({
    required this.icon,
    required this.color,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget iconWidget = Icon(icon, color: color, size: 22);

    if (badgeCount > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: theme.colorScheme.surface,
                  width: 1.5,
                ),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return iconWidget;
  }
}

class _NavItem extends StatelessWidget {
  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.button),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primary.withAlpha(18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.button),
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary.withAlpha(48)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.surface
                          : theme.colorScheme.surfaceContainerHighest.withAlpha(72),
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                    child: NavBadgeIcon(
                      icon: selected
                          ? destination.selectedIcon
                          : destination.icon,
                      color: accentColor,
                      badgeCount: destination.badgeCount,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destination.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        if (destination.description != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            destination.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (destination.badgeLabel != null)
            Positioned(
              top: 4,
              right: 2,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 36,
                  height: 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                  ),
                  child: Text(
                    destination.badgeLabel!,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
