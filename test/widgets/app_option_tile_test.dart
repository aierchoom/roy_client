import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/widgets/app_option_tile.dart';

void main() {
  group('AppOptionTile', () {
    testWidgets('renders title and icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppOptionTile(
              icon: Icons.lightbulb,
              title: 'Option A',
              selected: false,
            ),
          ),
        ),
      );
      expect(find.text('Option A'), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb), findsOneWidget);
    });

    testWidgets('shows selected indicator when selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppOptionTile(
              icon: Icons.lightbulb,
              title: 'Option A',
              selected: true,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('hides selected indicator when not selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppOptionTile(
              icon: Icons.lightbulb,
              title: 'Option A',
              selected: false,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppOptionTile(
              icon: Icons.lightbulb,
              title: 'Option A',
              selected: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Option A'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('InkWell is present for tap and focus handling', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppOptionTile(
              icon: Icons.lightbulb,
              title: 'Option A',
              selected: false,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppOptionTile(
              icon: Icons.lightbulb,
              title: 'Option A',
              subtitle: 'Description',
              selected: false,
            ),
          ),
        ),
      );
      expect(find.text('Description'), findsOneWidget);
    });
  });
}
