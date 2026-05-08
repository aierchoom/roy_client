import 'package:flutter/widgets.dart';

/// Shared i18n helper for bilingual zh/en strings.
/// Use this instead of duplicating _text() in every view.
extension AppTextExtension on BuildContext {
  String text(String zh, String en) {
    return Localizations.localeOf(this).languageCode == 'zh' ? zh : en;
  }
}
