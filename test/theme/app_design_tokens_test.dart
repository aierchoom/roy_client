import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/theme/app_design_tokens.dart';

void main() {
  group('AppRadii', () {
    test('values are monotonically increasing', () {
      final values = [
        AppRadii.chip,
        AppRadii.sm,
        AppRadii.control,
        AppRadii.button,
        AppRadii.card,
        AppRadii.panel,
        AppRadii.dialog,
        AppRadii.xl,
        AppRadii.xxl,
        AppRadii.pill,
      ];
      for (var i = 0; i < values.length - 1; i++) {
        expect(
          values[i] <= values[i + 1],
          isTrue,
          reason: '${values[i]} should be <= ${values[i + 1]}',
        );
      }
    });

    test('pill is 999 for full rounding', () {
      expect(AppRadii.pill, equals(999));
    });
  });

  group('AppSpacing', () {
    test('values are monotonically increasing', () {
      final values = [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ];
      for (var i = 0; i < values.length - 1; i++) {
        expect(values[i] < values[i + 1], isTrue);
      }
    });
  });

  group('AppAlphas', () {
    test('values are within valid alpha range 0-255', () {
      final values = [
        AppAlphas.tint,
        AppAlphas.subtle,
        AppAlphas.low,
        AppAlphas.medium,
        AppAlphas.high,
        AppAlphas.strong,
        AppAlphas.divider,
        AppAlphas.outline,
        AppAlphas.surfaceOverlay,
        AppAlphas.surface,
      ];
      for (final v in values) {
        expect(v >= 0 && v <= 255, isTrue, reason: '$v out of range');
      }
    });

    test('values are monotonically increasing', () {
      final values = [
        AppAlphas.tint,
        AppAlphas.subtle,
        AppAlphas.low,
        AppAlphas.medium,
        AppAlphas.high,
        AppAlphas.strong,
        AppAlphas.divider,
        AppAlphas.outline,
        AppAlphas.surfaceOverlay,
        AppAlphas.surface,
      ];
      for (var i = 0; i < values.length - 1; i++) {
        expect(values[i] <= values[i + 1], isTrue);
      }
    });
  });

  group('AppShadows', () {
    test('low returns non-empty list', () {
      final shadows = AppShadows.low(ThemeData.light());
      expect(shadows, isNotEmpty);
    });

    test('card returns non-empty list', () {
      final shadows = AppShadows.card(ThemeData.light());
      expect(shadows, isNotEmpty);
    });

    test('hero returns non-empty list', () {
      final shadows = AppShadows.hero(ThemeData.light());
      expect(shadows, isNotEmpty);
    });
  });
}
