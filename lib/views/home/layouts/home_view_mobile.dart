import 'dart:ui';

import 'package:flutter/material.dart';

class HomeViewMobile extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> pages;

  const HomeViewMobile({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.pages,
  });

  String _text(BuildContext context, String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final navBottomPadding = bottomInset > 0
        ? 0.0
        : (bottomPadding > 0 ? 12.0 : 16.0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: selectedIndex, children: pages),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, navBottomPadding),
        child: Visibility(
          visible: bottomInset == 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withAlpha(26),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withAlpha(210),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withAlpha(110),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavItem(
                        icon: Icons.inventory_2_outlined,
                        selectedIcon: Icons.inventory_2,
                        label: _text(context, '账户', 'Accounts'),
                        isSelected: selectedIndex == 0,
                        onTap: () => onDestinationSelected(0),
                      ),
                      _NavItem(
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home,
                        label: _text(context, '主页', 'Home'),
                        isSelected: selectedIndex == 1,
                        onTap: () => onDestinationSelected(1),
                      ),
                      _NavItem(
                        icon: Icons.settings_outlined,
                        selectedIcon: Icons.settings,
                        label: _text(context, '设置', 'Settings'),
                        isSelected: selectedIndex == 2,
                        onTap: () => onDestinationSelected(2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer.withAlpha(130)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
