import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/theme/app_design_tokens.dart';
import 'package:secret_roy/widgets/password_generator_sheet.dart';

void main() {
  group('PasswordGeneratorSheet', () {
    Future<void> _openSheet(WidgetTester tester) async {
      await tester.view.physicalSize;
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [AppVisualTokens.fromBrightness(Brightness.light)],
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showPasswordGeneratorSheet(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders title and generated password', (tester) async {
      await _openSheet(tester);

      expect(find.text('密码生成器'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);

      final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(selectableText.data, isNotEmpty);
    });

    testWidgets('can toggle character options', (tester) async {
      await _openSheet(tester);

      expect(find.text('大写字母'), findsOneWidget);

      // Tap the uppercase option to toggle it off.
      await tester.tap(find.text('大写字母'));
      await tester.pumpAndSettle();

      // Password should regenerate.
      final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(selectableText.data, isNotEmpty);
    });

    testWidgets('copy button does not throw', (tester) async {
      await _openSheet(tester);

      await tester.tap(find.text('复制'));
      await tester.pump();
      // Should complete without throwing.
      expect(true, true);
    });

    testWidgets('apply button returns result', (tester) async {
      PasswordGeneratorResult? result;
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [AppVisualTokens.fromBrightness(Brightness.light)],
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showPasswordGeneratorSheet(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('使用密码'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.password, isNotEmpty);
      expect(result!.options.length, greaterThanOrEqualTo(8));
    });
  });
}
