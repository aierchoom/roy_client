import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  String _text(BuildContext context, String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncBadgeCount = context.watch<EnhancedAppProvider>().localSyncChanges.length;

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
            label: _text(context, '\u8d26\u6237', 'Accounts'),
          ),
          AppNavDestination(
            icon: Icons.search_outlined,
            selectedIcon: Icons.search,
            label: _text(context, '\u641c\u7d22', 'Search'),
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
            label: _text(context, '\u8bbe\u7f6e', 'Settings'),
          ),
        ],
      ),
    );
  }
}
