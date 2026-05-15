import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/theme/app_design_tokens.dart';
import 'package:secret_roy/widgets/inbox/inbox_action_card.dart';
import 'package:secret_roy/widgets/inbox/inbox_models.dart';

void main() {
  group('ActionSummaryCard', () {
    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [AppVisualTokens.fromBrightness(Brightness.light)],
          ),
          home: Scaffold(
            body: ActionSummaryCard(
              title: '3 conflicts',
              subtitle: 'Tap to review',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('3 conflicts'), findsOneWidget);
      expect(find.text('Tap to review'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [AppVisualTokens.fromBrightness(Brightness.light)],
          ),
          home: Scaffold(
            body: ActionSummaryCard(
              title: 'Title',
              subtitle: 'Subtitle',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Title'));
      await tester.pump();
      expect(tapped, true);
    });

    testWidgets('renders custom leading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [AppVisualTokens.fromBrightness(Brightness.light)],
          ),
          home: Scaffold(
            body: ActionSummaryCard(
              title: 'Title',
              subtitle: 'Subtitle',
              leading: const Icon(Icons.star),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('renders default icon when no leading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [AppVisualTokens.fromBrightness(Brightness.light)],
          ),
          home: Scaffold(
            body: ActionSummaryCard(
              title: 'Title',
              subtitle: 'Subtitle',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  group('ActionItemCard', () {
    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [AppVisualTokens.fromBrightness(Brightness.light)],
          ),
          home: Scaffold(
            body: ActionItemCard(
              severity: InboxSeverity.warning,
              title: 'Weak password',
              subtitle: 'Account X',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Weak password'), findsOneWidget);
      expect(find.text('Account X'), findsOneWidget);
    });

    testWidgets('shows chevron by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [AppVisualTokens.fromBrightness(Brightness.light)],
          ),
          home: Scaffold(
            body: ActionItemCard(
              severity: InboxSeverity.info,
              title: 'Title',
              subtitle: 'Subtitle',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('hides chevron when showChevron is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [AppVisualTokens.fromBrightness(Brightness.light)],
          ),
          home: Scaffold(
            body: ActionItemCard(
              severity: InboxSeverity.info,
              title: 'Title',
              subtitle: 'Subtitle',
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
          theme: ThemeData(
            extensions: [AppVisualTokens.fromBrightness(Brightness.light)],
          ),
          home: Scaffold(
            body: ActionItemCard(
              severity: InboxSeverity.critical,
              title: 'Title',
              subtitle: 'Subtitle',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Title'));
      await tester.pump();
      expect(tapped, true);
    });

    testWidgets('renders trailing widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [AppVisualTokens.fromBrightness(Brightness.light)],
          ),
          home: Scaffold(
            body: ActionItemCard(
              severity: InboxSeverity.success,
              title: 'Title',
              subtitle: 'Subtitle',
              trailing: const Icon(Icons.check),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });
}
