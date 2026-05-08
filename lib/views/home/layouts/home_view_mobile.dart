import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_text_extension.dart';
import '../../../providers/enhanced_app_provider.dart';
import '../../../widgets/app_nav_bar.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncBadgeCount = context
        .watch<EnhancedAppProvider>()
        .localSyncChanges
        .length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: selectedIndex, children: pages),
      ),
      bottomNavigationBar: AppNavBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          AppNavDestination(
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2,
            label: context.text( '\u8d26\u6237', 'Accounts'),
          ),
          AppNavDestination(
            icon: Icons.search_outlined,
            selectedIcon: Icons.search,
            label: context.text( '\u641c\u7d22', 'Search'),
            badgeCount: syncBadgeCount,
          ),
          AppNavDestination(
            icon: Icons.verified_user_outlined,
            selectedIcon: Icons.verified_user,
            label: '2FA',
          ),
          AppNavDestination(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: context.text( '\u8bbe\u7f6e', 'Settings'),
          ),
        ],
      ),
    );
  }
}
