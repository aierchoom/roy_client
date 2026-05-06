import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/theme/app_layout.dart';
import 'package:secret_roy/widgets/app_hero_card.dart';

void main() {
  group('AppHeroCard', () {
    Widget buildCard({double width = 400}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: const Scaffold(
            body: AppHeroCard(
              icon: Icons.shield,
              title: 'Test Title',
              subtitle: 'Test Subtitle',
            ),
          ),
        ),
      );
    }

    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Subtitle'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);
    });

    testWidgets('adapts padding for compact layout', (tester) async {
      await tester.pumpWidget(buildCard(width: 600));
      await tester.pumpAndSettle();
      final layout = AppLayout.isCompact(tester.element(find.byType(AppHeroCard)));
      expect(layout, isTrue);
    });

    testWidgets('adapts padding for expanded layout', (tester) async {
      await tester.pumpWidget(buildCard(width: 1200));
      await tester.pumpAndSettle();
      final layout = AppLayout.isExpanded(tester.element(find.byType(AppHeroCard)));
      expect(layout, isTrue);
    });

    testWidgets('renders metrics when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppHeroCard(
              icon: Icons.shield,
              title: 'Metrics Test',
              metrics: [
                Chip(label: Text('M1')),
                Chip(label: Text('M2')),
              ],
            ),
          ),
        ),
      );
      expect(find.text('M1'), findsOneWidget);
      expect(find.text('M2'), findsOneWidget);
    });
  });
}
