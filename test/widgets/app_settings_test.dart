import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/widgets/app_settings_group.dart';
import 'package:secret_roy/widgets/app_settings_tile.dart';

void main() {
  group('AppSettingsTile', () {
    testWidgets('renders title and icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSettingsTile(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('shows chevron by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSettingsTile(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('hides chevron when showChevron is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSettingsTile(
              icon: Icons.settings,
              title: 'Settings',
              showChevron: false,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSettingsTile(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSettingsTile(
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'Detail text',
            ),
          ),
        ),
      );
      expect(find.text('Detail text'), findsOneWidget);
    });
  });

  group('AppSettingsGroup', () {
    testWidgets('renders children with dividers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSettingsGroup(
              children: [
                ListTile(title: Text('A')),
                ListTile(title: Text('B')),
                ListTile(title: Text('C')),
              ],
            ),
          ),
        ),
      );
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });
}
