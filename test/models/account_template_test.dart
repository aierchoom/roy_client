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

    test('website template keeps password and TOTP hidden by default', () {
      final passwordField = websiteTemplate.fields.firstWhere(
        (field) => field.fieldKey == 'password',
      );
      final totpField = websiteTemplate.fields.firstWhere(
        (field) => field.fieldKey == 'totp_secret',
      );

      expect(websiteTemplate.isCustom, isFalse);
      expect(websiteTemplate.title, '网站模板');
      expect(websiteTemplate.fields.map((field) => field.fieldKey), [
        'website',
        'username',
        'password',
        'totp_secret',
        'notes',
      ]);
      expect(passwordField.attributes.isSecret, isTrue);
      expect(passwordField.attributes.isRequired, isTrue);
      expect(passwordField.attributes.type, AccountFieldType.password);
      expect(totpField.label, '2FA 密钥');
      expect(totpField.attributes.type, AccountFieldType.totp);
      expect(totpField.attributes.isSecret, isTrue);
      expect(totpField.attributes.isRequired, isFalse);
      expect(totpField.attributes.isSearchable, isFalse);
      expect(totpField.attributes.isCopyable, isTrue);
      expect(totpField.attributes.hint, AccountFieldAttributes.totpDefaultHint);
    });

    test('serializes and parses TOTP field attributes', () {
      const attributes = AccountFieldAttributes(
        type: AccountFieldType.totp,
        isSecret: true,
        isSearchable: false,
        isCopyable: true,
        hint: 'Base32 密钥或 otpauth://totp URI',
      );

      final parsed = AccountFieldAttributes.fromJson(attributes.toJson());

      expect(parsed.type, AccountFieldType.totp);
      expect(parsed.isSecret, isTrue);
      expect(parsed.isSearchable, isFalse);
      expect(parsed.isCopyable, isTrue);
      expect(parsed.hint, AccountFieldAttributes.totpDefaultHint);
      expect(AccountFieldAttributes.totpDefaults.type, AccountFieldType.totp);
      expect(AccountFieldAttributes.totpDefaults.isSecret, isTrue);
      expect(AccountFieldAttributes.totpDefaults.isSearchable, isFalse);
      expect(AccountFieldAttributes.totpDefaults.isCopyable, isTrue);
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
