import 'package:flutter/material.dart';

import '../../widgets/app_layout_builder.dart';
import '../accounts/account_list_view.dart';
import '../accounts/totp_account_list_view.dart';
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

  final List<Widget> _pages = const [
    AccountListView(),
    HomeSearchView(),
    TotpAccountListView(),
    SettingsView(),
  ];

  void _onItemTapped(int idx) {
    setState(() => _selectedIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return AppLayoutBuilder(
      compactBuilder: (context) => HomeViewMobile(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        pages: _pages,
      ),
      mediumBuilder: (context) => HomeViewDesktop(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        pages: _pages,
      ),
      expandedBuilder: (context) => HomeViewDesktop(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        pages: _pages,
      ),
    );
  }
}
