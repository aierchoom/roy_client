import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/widgets/app_nav_bar.dart';
import 'package:secret_roy/widgets/app_nav_rail.dart';

void main() {
  final destinations = [
    const AppNavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    const AppNavDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  group('AppNavRail', () {
    testWidgets('renders destinations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AppNavRail(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  destinations: destinations,
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('calls onDestinationSelected when tapped', (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AppNavRail(
                  selectedIndex: 0,
                  onDestinationSelected: (index) => selected = index,
                  destinations: destinations,
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(selected, equals(1));
    });

    testWidgets('renders header and footer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AppNavRail(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  destinations: destinations,
                  header: const Text('Header'),
                  footer: const Text('Footer'),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Footer'), findsOneWidget);
    });
  });

  group('AppNavBar', () {
    testWidgets('renders destinations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppNavBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: destinations,
            ),
          ),
        ),
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('calls onDestinationSelected when tapped', (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppNavBar(
              selectedIndex: 0,
              onDestinationSelected: (index) => selected = index,
              destinations: destinations,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(selected, equals(1));
    });
  });
}
