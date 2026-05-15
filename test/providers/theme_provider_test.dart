import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/providers/theme_provider.dart';
import 'package:secret_roy/theme/app_design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppThemeProvider', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('loads defaults from empty prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.colorSeed, AppBrandColors.defaultSeed);
      expect(provider.trueBlack, false);
      provider.dispose();
    });

    test('loads persisted values', () async {
      SharedPreferences.setMockInitialValues({
        'app_theme_mode': ThemeMode.dark.index,
        'app_color_seed': Colors.red.toARGB32(),
        'app_true_black': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.colorSeed.toARGB32(), Colors.red.toARGB32());
      expect(provider.trueBlack, true);
      provider.dispose();
    });

    test('setThemeMode updates and notifies', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      var notified = 0;
      provider.addListener(() => notified++);
      provider.setThemeMode(ThemeMode.light);
      expect(provider.themeMode, ThemeMode.light);
      expect(notified, greaterThanOrEqualTo(1));
      provider.dispose();
    });

    test('setThemeMode no-op when same', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      var notified = 0;
      provider.addListener(() => notified++);
      provider.setThemeMode(ThemeMode.system);
      expect(notified, 0);
      provider.dispose();
    });

    test('setColorSeed updates and notifies', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      provider.setColorSeed(Colors.blue);
      expect(provider.colorSeed, Colors.blue);
      provider.dispose();
    });

    test('setColorSeed no-op when same', () async {
      SharedPreferences.setMockInitialValues({
        'app_color_seed': Colors.green.toARGB32(),
      });
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      var notified = 0;
      provider.addListener(() => notified++);
      provider.setColorSeed(Colors.green);
      expect(notified, 0);
      provider.dispose();
    });

    test('setTrueBlack updates and notifies', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      provider.setTrueBlack(true);
      expect(provider.trueBlack, true);
      provider.dispose();
    });

    test('setTrueBlack no-op when same', () async {
      SharedPreferences.setMockInitialValues({'app_true_black': false});
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      var notified = 0;
      provider.addListener(() => notified++);
      provider.setTrueBlack(false);
      expect(notified, 0);
      provider.dispose();
    });

    test('invalid theme mode index falls back to system', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 99});
      final prefs = await SharedPreferences.getInstance();
      final provider = AppThemeProvider(prefs);
      expect(provider.themeMode, ThemeMode.system);
      provider.dispose();
    });
  });
}
