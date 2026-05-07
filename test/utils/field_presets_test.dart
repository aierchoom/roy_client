import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/utils/field_presets.dart';

void main() {
  group('generateUniqueFieldKey', () {
    test('returns base key when no conflict', () {
      expect(generateUniqueFieldKey('username', <String>{}), 'username');
    });

    test('appends suffix when base key exists', () {
      expect(generateUniqueFieldKey('username', {'username'}), 'username_2');
    });

    test('increments suffix until unique', () {
      expect(
        generateUniqueFieldKey('username', {'username', 'username_2'}),
        'username_3',
      );
    });

    test('handles multiple collisions', () {
      expect(
        generateUniqueFieldKey('card', {'card', 'card_2', 'card_3'}),
        'card_4',
      );
    });
  });

  group('instantiatePresetFields', () {
    const preset = FieldPreset(
      id: 'test',
      name: 'Test',
      icon: Icons.abc,
      fields: [
        AccountField(
          fieldKey: 'a',
          label: 'A',
          attributes: AccountFieldAttributes(type: AccountFieldType.text),
        ),
        AccountField(
          fieldKey: 'b',
          label: 'B',
          attributes: AccountFieldAttributes(type: AccountFieldType.password),
        ),
      ],
    );

    test('creates fields with same keys when no conflicts', () {
      final fields = instantiatePresetFields(preset, existingKeys: {});
      expect(fields.length, 2);
      expect(fields[0].fieldKey, 'a');
      expect(fields[0].label, 'A');
      expect(fields[1].fieldKey, 'b');
      expect(fields[1].label, 'B');
    });

    test('renames conflicting keys while preserving labels', () {
      final fields = instantiatePresetFields(preset, existingKeys: {'a'});
      expect(fields.length, 2);
      expect(fields[0].fieldKey, 'a_2');
      expect(fields[0].label, 'A');
      expect(fields[1].fieldKey, 'b');
      expect(fields[1].label, 'B');
    });

    test('renames multiple conflicting keys', () {
      final fields = instantiatePresetFields(preset, existingKeys: {'a', 'b'});
      expect(fields[0].fieldKey, 'a_2');
      expect(fields[1].fieldKey, 'b_2');
    });

    test('handles conflict between preset fields themselves', () {
      const duplicatePreset = FieldPreset(
        id: 'dup',
        name: 'Dup',
        icon: Icons.abc,
        fields: [
          AccountField(
            fieldKey: 'x',
            label: 'First',
            attributes: AccountFieldAttributes(type: AccountFieldType.text),
          ),
          AccountField(
            fieldKey: 'x',
            label: 'Second',
            attributes: AccountFieldAttributes(type: AccountFieldType.number),
          ),
        ],
      );
      final fields = instantiatePresetFields(duplicatePreset, existingKeys: {});
      expect(fields.length, 2);
      expect(fields[0].fieldKey, 'x');
      expect(fields[1].fieldKey, 'x_2');
    });
  });

  group('kFieldPresets', () {
    test('contains at least one preset', () {
      expect(kFieldPresets.isNotEmpty, true);
    });

    test('all presets have non-empty id, name and fields', () {
      for (final preset in kFieldPresets) {
        expect(
          preset.id.isNotEmpty,
          true,
          reason: 'Preset id must not be empty',
        );
        expect(
          preset.name.isNotEmpty,
          true,
          reason: 'Preset name must not be empty',
        );
        expect(
          preset.fields.isNotEmpty,
          true,
          reason: 'Preset fields must not be empty',
        );
        for (final field in preset.fields) {
          expect(
            field.fieldKey.isNotEmpty,
            true,
            reason: 'Field key must not be empty',
          );
          expect(
            field.label.isNotEmpty,
            true,
            reason: 'Field label must not be empty',
          );
        }
      }
    });
  });
}
