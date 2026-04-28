import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';

void main() {
  group('built-in account templates', () {
    test('keeps the default template surface intentionally small', () {
      expect(basicAccountTemplates.map((template) => template.templateId), [
        'generic_info',
      ]);
    });

    test('generic info keeps content hidden by default', () {
      final contentField = genericInfoTemplate.fields.firstWhere(
        (field) => field.fieldKey == 'content',
      );

      expect(genericInfoTemplate.isCustom, isFalse);
      expect(genericInfoTemplate.fields, hasLength(1));
      expect(contentField.attributes.isSecret, isTrue);
      expect(contentField.attributes.isRequired, isTrue);
      expect(contentField.attributes.type, AccountFieldType.text);
    });

    test('uses a safe sync status fallback for unreadable template data', () {
      final template = AccountTemplate.fromJson({
        'templateId': 'custom-template',
        'title': 'Custom',
        'fields': const [],
        'syncStatus': 'removed_status',
      });

      expect(template.syncStatus, SyncStatus.synchronized);
    });
  });
}
