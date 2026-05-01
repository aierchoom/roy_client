import 'package:flutter/material.dart';

import '../../../theme/app_design_tokens.dart';

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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DesktopDock(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                labelBuilder: (zh, en) => _text(context, zh, en),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                  child: IndexedStack(index: selectedIndex, children: pages),
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
      width: 220,
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
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(14),
                borderRadius: BorderRadius.circular(AppRadii.panel),
                border: Border.all(
                  color: theme.colorScheme.primary.withAlpha(34),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadii.button),
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
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          labelBuilder(
                            '\u5b89\u5168\u5e93\u5de5\u4f5c\u533a',
                            'Secure workspace',
                          ),
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
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(AppRadii.button),
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
              description: labelBuilder('查看全部账户', 'Browse your vault'),
              isSelected: selectedIndex == 0,
              onTap: () => onDestinationSelected(0),
            ),
            const SizedBox(height: 8),
            _DesktopNavItem(
              icon: Icons.search_outlined,
              selectedIcon: Icons.search,
              label: labelBuilder('搜索', 'Search'),
              description: labelBuilder('快速定位账户', 'Search and jump fast'),
              isSelected: selectedIndex == 1,
              onTap: () => onDestinationSelected(1),
            ),
            const SizedBox(height: 8),
            _DesktopNavItem(
              icon: Icons.verified_user_outlined,
              selectedIcon: Icons.verified_user,
              label: '2FA',
              description: labelBuilder(
                '查看动态验证码账户',
                'Accounts with codes',
              ),
              isSelected: selectedIndex == 2,
              onTap: () => onDestinationSelected(2),
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
              isSelected: selectedIndex == 3,
              onTap: () => onDestinationSelected(3),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(82),
                borderRadius: BorderRadius.circular(AppRadii.panel),
              ),
              child: Text(
                labelBuilder(
                  '\u5bfc\u822a\u4fdd\u6301\u7a33\u5b9a\uff0c\u9ad8\u9891\u5de5\u5177\u5165\u53e3\u4e0d\u518d\u5f3a\u8c03\u60ac\u6d6e\u88c5\u9970\u3002',
                  'Navigation stays stable, with less decorative chrome around frequent tools.',
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
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withAlpha(18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(
              color: isSelected
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
                  color: isSelected
                      ? theme.colorScheme.surface
                      : theme.colorScheme.surfaceContainerHighest.withAlpha(72),
                  borderRadius: BorderRadius.circular(AppRadii.button),
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
