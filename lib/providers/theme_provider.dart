import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_design_tokens.dart';

class AppThemeProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyColorSeed = 'app_color_seed';
  static const String _keyTrueBlack = 'app_true_black';

  ThemeMode _themeMode = ThemeMode.system;
  Color _colorSeed = AppBrandColors.defaultSeed;
  bool _trueBlack = false;
  bool _disposed = false;

  final SharedPreferences _prefs;

  AppThemeProvider(this._prefs) {
    _loadFromPrefs();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;
  Color get colorSeed => _colorSeed;
  bool get trueBlack => _trueBlack;

  void _loadFromPrefs() {
    final modeIndex = _prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[modeIndex];

    final colorValue =
        _prefs.getInt(_keyColorSeed) ?? AppBrandColors.defaultSeed.toARGB32();
    _colorSeed = Color(colorValue);

    _trueBlack = _prefs.getBool(_keyTrueBlack) ?? false;
    _notify();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _prefs.setInt(_keyThemeMode, mode.index);
    _notify();
  }

  void setColorSeed(Color color) {
    if (_colorSeed.toARGB32() == color.toARGB32()) return;
    _colorSeed = color;
    _prefs.setInt(_keyColorSeed, color.toARGB32());
    _notify();
  }

  void setTrueBlack(bool value) {
    if (_trueBlack == value) return;
    _trueBlack = value;
    _prefs.setBool(_keyTrueBlack, value);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
