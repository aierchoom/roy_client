import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/theme/app_layout.dart';

void main() {
  group('AppLayout', () {
    Widget buildWithWidth(double width) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Builder(
            builder: (context) {
              final layout = AppLayout.of(context);
              return Text(
                '${layout.type.name}|${layout.contentMaxWidth}|${layout.horizontalPadding}',
              );
            },
          ),
        ),
      );
    }

    testWidgets('compact below 720px', (tester) async {
      await tester.pumpWidget(buildWithWidth(600));
      expect(find.text('compact|Infinity|16.0'), findsOneWidget);
    });

    testWidgets('medium between 720-1080px', (tester) async {
      await tester.pumpWidget(buildWithWidth(800));
      expect(find.text('medium|820.0|24.0'), findsOneWidget);
    });

    testWidgets('expanded above 1080px', (tester) async {
      await tester.pumpWidget(buildWithWidth(1200));
      expect(find.text('expanded|1080.0|32.0'), findsOneWidget);
    });

    testWidgets('isPointerDevice false on mobile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: Builder(
              builder: (context) {
                return Text('${AppLayout.isPointerDeviceOf(context)}');
              },
            ),
          ),
        ),
      );
      // defaultTargetPlatform in tests is android (touch)
      expect(find.text('false'), findsOneWidget);
    });

    testWidgets('isExpanded matches type', (tester) async {
      await tester.pumpWidget(buildWithWidth(1200));
      final context = tester.element(find.byType(Text));
      expect(AppLayout.isExpanded(context), isTrue);
      expect(AppLayout.isMedium(context), isFalse);
      expect(AppLayout.isCompact(context), isFalse);
    });
  });
}
