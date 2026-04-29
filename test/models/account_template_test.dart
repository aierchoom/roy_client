import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';

void main() {
  group('built-in account templates', () {
    test('keeps website as the only built-in template', () {
      expect(basicAccountTemplates.map((template) => template.templateId), [
        'generic_info',
      ]);
    });

    test('website template keeps password hidden by default', () {
      final passwordField = websiteTemplate.fields.firstWhere(
        (field) => field.fieldKey == 'password',
      );

      expect(websiteTemplate.isCustom, isFalse);
      expect(websiteTemplate.title, '网站模板');
      expect(websiteTemplate.fields.map((field) => field.fieldKey), [
        'website',
        'username',
        'password',
        'notes',
      ]);
      expect(passwordField.attributes.isSecret, isTrue);
      expect(passwordField.attributes.isRequired, isTrue);
      expect(passwordField.attributes.type, AccountFieldType.password);
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
