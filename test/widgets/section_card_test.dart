import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/widgets/section_card.dart';

void main() {
  group('SectionCard', () {
    testWidgets('renders title and child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionCard(
              title: 'Section Title',
              child: Text('Child content'),
            ),
          ),
        ),
      );

      expect(find.text('Section Title'), findsOneWidget);
      expect(find.text('Child content'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionCard(
              title: 'Title',
              subtitle: 'Subtitle text',
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.text('Subtitle text'), findsOneWidget);
    });

    testWidgets('does not render subtitle when empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionCard(
              title: 'Title',
              subtitle: '',
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.text(''), findsNothing);
    });

    testWidgets('uses Card when useOutlinedBorder is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionCard(
              title: 'Title',
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('uses Container with border when useOutlinedBorder is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionCard(
              title: 'Title',
              useOutlinedBorder: true,
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsNothing);
      expect(find.byType(Container), findsWidgets);
    });
  });
}
