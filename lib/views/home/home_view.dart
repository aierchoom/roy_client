import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/enhanced_app_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/app_layout_builder.dart';
import '../../widgets/lan_sync_conflict_sheet.dart';
import '../accounts/account_list_view.dart';
import '../notifications/notification_center_view.dart';
import '../settings_view.dart';
import 'home_search_view.dart';
import 'layouts/home_view_desktop.dart';
import 'layouts/home_view_mobile.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;
  bool _accountShowTemplates = false;
  bool _notificationsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_notificationsInitialized) {
      _notificationsInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final provider = context.read<NotificationProvider>();
        final appProvider = context.read<EnhancedAppProvider>();
        provider.loadNotifications();
        provider.generateNotifications(
          accounts: appProvider.accounts,
          templates: appProvider.allTemplates,
        );
        if (provider.pushEnabled) {
          provider.scheduleDailyReminder();
        }
      });
    }
  }

  void _onItemTapped(int idx) {
    if (_selectedIndex == idx && idx == 0) {
      setState(() => _accountShowTemplates = !_accountShowTemplates);
      return;
    }
    setState(() {
      _selectedIndex = idx;
      _accountShowTemplates = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      AccountListView(
        showTemplates: _accountShowTemplates,
        onShowTemplatesChanged: (v) => setState(() => _accountShowTemplates = v),
      ),
      const HomeSearchView(),
      const NotificationCenterView(),
      const SettingsView(),
    ];

    return Stack(
      children: [
        AppLayoutBuilder(
          compactBuilder: (context) => HomeViewMobile(
            selectedIndex: _selectedIndex,
            accountShowTemplates: _accountShowTemplates,
            onDestinationSelected: _onItemTapped,
            pages: pages,
          ),
          mediumBuilder: (context) => HomeViewDesktop(
            selectedIndex: _selectedIndex,
            accountShowTemplates: _accountShowTemplates,
            onDestinationSelected: _onItemTapped,
            pages: pages,
          ),
          expandedBuilder: (context) => HomeViewDesktop(
            selectedIndex: _selectedIndex,
            accountShowTemplates: _accountShowTemplates,
            onDestinationSelected: _onItemTapped,
            pages: pages,
          ),
        ),
        const LanSyncConflictOverlay(),
      ],
    );
  }
}
