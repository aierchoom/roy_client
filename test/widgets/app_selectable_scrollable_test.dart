import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/widgets/app_selectable_scrollable.dart';

void main() {
  group('AppSelectableScrollable', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSelectableScrollable(
              child: ListView(children: const [Text('Hello')]),
            ),
          ),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('wraps with SelectionArea on pointer device', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Scaffold(
              body: AppSelectableScrollable(
                child: ListView(children: const [Text('Selectable')]),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SelectionArea), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('does not wrap when selectable is false', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Scaffold(
              body: AppSelectableScrollable(
                selectable: false,
                child: ListView(children: const [Text('Not Selectable')]),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SelectionArea), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('does not wrap on touch device', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: Scaffold(
              body: AppSelectableScrollable(
                child: ListView(children: const [Text('Touch')]),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SelectionArea), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
