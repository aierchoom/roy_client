import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/account_template.dart';

/// Time field parsing and formatting utilities for account editing.
class AccountTimeFieldUtils {
  static DateTime? tryParseDateTime(String raw, TimeFieldFormat format) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (format == TimeFieldFormat.monthYear) {
      if (trimmed.length == 5 && trimmed.contains('/')) {
        final parts = trimmed.split('/');
        final month = int.tryParse(parts[0]);
        final year = int.tryParse(parts[1]);
        if (month != null && year != null) {
          final fullYear = year > 50 ? 1900 + year : 2000 + year;
          return DateTime(fullYear, month);
        }
      }
      return null;
    }

    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    final normalized = trimmed.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  static String formatDateTime(DateTime value, TimeFieldFormat format) {
    switch (format) {
      case TimeFieldFormat.monthYear:
        return DateFormat('MM/yy').format(value);
      case TimeFieldFormat.date:
        return DateFormat('yyyy-MM-dd').format(value);
      case TimeFieldFormat.time:
        return DateFormat('HH:mm').format(value);
      case TimeFieldFormat.full:
        return DateFormat('yyyy-MM-dd HH:mm').format(value);
    }
  }

  static bool isTimeField(AccountField field) {
    return field.attributes.type == AccountFieldType.time;
  }
}

/// Text input formatter for month/year format (MM/YY).
class MonthYearInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) return newValue;

    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 4) text = text.substring(0, 4);

    var formatted = '';
    for (var i = 0; i < text.length; i++) {
      if (i == 2) formatted += '/';
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Styling utilities for account edit view.
class AccountEditStyle {
  /// Returns a soft surface color with optional tint.
  static Color softSurface(ThemeData theme, {Color? tint, int tintAlpha = 18}) {
    final base = theme.colorScheme.surface;
    if (tint == null) {
      return base;
    }
    if (theme.brightness != Brightness.light) {
      return theme.colorScheme.surfaceContainerHigh;
    }
    return Color.alphaBlend(tint.withAlpha(tintAlpha), base);
  }

  /// Returns a list of box shadows for card elevation effect.
  static List<BoxShadow> softCardShadows(ThemeData theme, {double depth = 1}) {
    return [
      BoxShadow(
        color: theme.shadowColor.withAlpha((10 * depth).round().clamp(0, 255)),
        blurRadius: 16 * depth,
        offset: Offset(0, 4 * depth),
      ),
      BoxShadow(
        color: theme.colorScheme.primary.withAlpha(
          (6 * depth).round().clamp(0, 255),
        ),
        blurRadius: 12 * depth,
        offset: Offset(0, 6 * depth),
      ),
    ];
  }

  /// Returns an accent color based on field attributes.
  static Color fieldAccentColor(ThemeData theme, AccountField field) {
    if (field.attributes.isSecret) {
      return theme.colorScheme.tertiary;
    }
    if (field.attributes.type == AccountFieldType.time) {
      return theme.colorScheme.secondary;
    }
    if (field.attributes.isRequired) {
      return theme.colorScheme.primary;
    }
    return theme.colorScheme.secondary;
  }
}
