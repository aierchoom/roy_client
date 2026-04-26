import 'dart:ui';

import 'package:flutter/material.dart';

class HomeViewDesktop extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> pages;

  const HomeViewDesktop({
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DesktopDock(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                labelBuilder: (zh, en) => _text(context, zh, en),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withAlpha(20),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withAlpha(178),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withAlpha(
                              90,
                            ),
                          ),
                        ),
                        child: IndexedStack(
                          index: selectedIndex,
                          children: pages,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final String Function(String zh, String en) labelBuilder;

  const _DesktopDock({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 244,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withAlpha(210),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withAlpha(110),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withAlpha(18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.tertiaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withAlpha(220),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.lock_outline,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SecretRoy',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              labelBuilder(
                                '\u5b89\u5168\u5e93\u5de5\u4f5c\u533a',
                                'Secure workspace',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withAlpha(170),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(82),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.dashboard_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        labelBuilder('\u4e3b\u5bfc\u822a', 'Navigation'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _DesktopNavItem(
                  icon: Icons.inventory_2_outlined,
                  selectedIcon: Icons.inventory_2,
                  label: labelBuilder('账户', 'Accounts'),
                  description: labelBuilder(
                    '查看全部账户',
                    'Browse your vault',
                  ),
                  isSelected: selectedIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
                const SizedBox(height: 8),
                _DesktopNavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: labelBuilder('主页', 'Home'),
                  description: labelBuilder(
                    '快速搜索与查看',
                    'Search and jump fast',
                  ),
                  isSelected: selectedIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
                const SizedBox(height: 8),
                _DesktopNavItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: labelBuilder('设置', 'Settings'),
                  description: labelBuilder(
                    '主题、安全与模板',
                    'Theme, security, templates',
                  ),
                  isSelected: selectedIndex == 2,
                  onTap: () => onDestinationSelected(2),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                      82,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    labelBuilder(
                      '\u684c\u9762\u7aef\u5df2\u5bf9\u9f50\u79fb\u52a8\u7aef\u7684\u5361\u7247\u5316\u4e0e\u60ac\u6d6e\u5bfc\u822a\u98ce\u683c\u3002',
                      'Desktop now follows the mobile card and floating navigation language.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _DesktopNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withAlpha(120)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withAlpha(40)
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
                  color: isSelected
                      ? theme.colorScheme.surface.withAlpha(210)
                      : theme.colorScheme.surfaceContainerHighest.withAlpha(72),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
