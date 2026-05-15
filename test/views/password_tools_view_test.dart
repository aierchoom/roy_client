import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/views/password_tools_view.dart';

void main() {
  group('PasswordToolsView', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    Widget _buildSubject() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PasswordToolsView(),
      );
    }

    testWidgets('renders title and hero card', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Password Tools'), findsWidgets);
    });

    testWidgets('renders password generator section', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Password Generator'), findsOneWidget);
      expect(find.text('Open Generator'), findsWidgets);
    });

    testWidgets('tapping open generator does not throw', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Generator').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Bottom sheet should be on screen now.
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('renders latest password empty state', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('No Password Generated Yet'), findsOneWidget);
    });
  });
}
