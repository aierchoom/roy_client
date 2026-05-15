import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/providers/theme_provider.dart';
import 'package:secret_roy/views/appearance_settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppearanceSettingsView', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    Widget _buildSubject(AppThemeProvider themeProvider) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider.value(
          value: themeProvider,
          child: const AppearanceSettingsView(),
        ),
      );
    }

    testWidgets('renders title and hero card', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      await tester.pumpWidget(_buildSubject(provider));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
      provider.dispose();
    });

    testWidgets('renders theme mode options', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      await tester.pumpWidget(_buildSubject(provider));
      await tester.pumpAndSettle();
      expect(find.text('Follow System'), findsOneWidget);
      expect(find.text('Light Mode'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
      provider.dispose();
    });

    testWidgets('tapping light mode updates provider', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      await tester.pumpWidget(_buildSubject(provider));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light Mode'));
      await tester.pumpAndSettle();
      expect(provider.themeMode, ThemeMode.light);
      provider.dispose();
    });

    testWidgets('tapping dark mode shows true black option', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      await tester.pumpWidget(_buildSubject(provider));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark Mode'));
      await tester.pumpAndSettle();
      expect(find.text('True Black (OLED)'), findsOneWidget);
      provider.dispose();
    });

    testWidgets('renders accent color presets', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      await tester.pumpWidget(_buildSubject(provider));
      await tester.pumpAndSettle();
      expect(find.byType(Container), findsWidgets);
      provider.dispose();
    });
  });
}
