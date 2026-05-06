import 'package:flutter/material.dart';

import '../../../theme/app_design_tokens.dart';
import '../../../widgets/app_nav_rail.dart';

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
              AppNavRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                destinations: [
                  AppNavDestination(
                    icon: Icons.inventory_2_outlined,
                    selectedIcon: Icons.inventory_2,
                    label: _text(context, '\u8d26\u6237', 'Accounts'),
                    description: _text(context, '\u67e5\u770b\u5168\u90e8\u8d26\u6237', 'Browse your vault'),
                  ),
                  AppNavDestination(
                    icon: Icons.search_outlined,
                    selectedIcon: Icons.search,
                    label: _text(context, '\u641c\u7d22', 'Search'),
                    description: _text(context, '\u5feb\u901f\u5b9a\u4f4d\u8d26\u6237', 'Search and jump fast'),
                  ),
                  AppNavDestination(
                    icon: Icons.verified_user_outlined,
                    selectedIcon: Icons.verified_user,
                    label: '2FA',
                    description: _text(context, '\u67e5\u770b\u52a8\u6001\u9a8c\u8bc1\u7801\u8d26\u6237', 'Accounts with codes'),
                  ),
                  AppNavDestination(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: _text(context, '\u8bbe\u7f6e', 'Settings'),
                    description: _text(context, '\u4e3b\u9898\u3001\u5b89\u5168\u4e0e\u6a21\u677f', 'Theme, security, templates'),
                  ),
                ],
                header: Container(
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
                      const SizedBox(width: AppSpacing.md),
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
                              _text(context, '\u5b89\u5168\u5e93\u5de5\u4f5c\u533a', 'Secure workspace'),
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
                footer: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(82),
                    borderRadius: BorderRadius.circular(AppRadii.panel),
                  ),
                  child: Text(
                    _text(
                      context,
                      '\u5bfc\u822a\u4fdd\u6301\u7a33\u5b9a\uff0c\u9ad8\u9891\u5de5\u5177\u5165\u53e3\u4e0d\u518d\u5f3a\u8c03\u60ac\u6d6e\u88c5\u9970\u3002',
                      'Navigation stays stable, with less decorative chrome around frequent tools.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
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
