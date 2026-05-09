import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_text_extension.dart';
import '../../../providers/enhanced_app_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/app_nav_bar.dart';

class HomeViewMobile extends StatelessWidget {
  final int selectedIndex;
  final bool accountShowTemplates;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> pages;

  const HomeViewMobile({
    super.key,
    required this.selectedIndex,
    required this.accountShowTemplates,
    required this.onDestinationSelected,
    required this.pages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appProvider = context.watch<EnhancedAppProvider>();
    final syncBadgeCount = appProvider.localSyncChanges.length;
    final conflictBadgeCount = appProvider.conflictCount;
    final notificationBadgeCount = context
        .watch<NotificationProvider>()
        .unreadCount;

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
            icon: accountShowTemplates
                ? Icons.dashboard_customize_outlined
                : Icons.inventory_2_outlined,
            selectedIcon: accountShowTemplates
                ? Icons.dashboard_customize
                : Icons.inventory_2,
            label: accountShowTemplates
                ? context.text('模板', 'Templates')
                : context.text('账户', 'Accounts'),
            badgeLabel: selectedIndex == 0
                ? (accountShowTemplates ? '账户' : '模板')
                : null,
          ),
          AppNavDestination(
            icon: Icons.search_outlined,
            selectedIcon: Icons.search,
            label: context.text( '搜索', 'Search'),
          ),
          AppNavDestination(
            icon: Icons.notifications_outlined,
            selectedIcon: Icons.notifications,
            label: context.text('通知', 'Alerts'),
            badgeCount: notificationBadgeCount + syncBadgeCount + conflictBadgeCount,
          ),
          AppNavDestination(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: context.text( '设置', 'Settings'),
          ),
        ],
      ),
    );
  }
}
