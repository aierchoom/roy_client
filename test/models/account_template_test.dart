import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';

void main() {
  group('AccountFieldAttributes', () {
    test('copyWith returns same values when no args provided', () {
      const attrs = AccountFieldAttributes(
        type: AccountFieldType.password,
        isPrimary: true,
        isRequired: true,
        isSecret: true,
        isEditable: false,
        isSearchable: true,
        isCopyable: false,
        isReference: true,
        maxLength: 32,
        minLength: 8,
        regex: r'^.*$',
        hint: 'hint',
        timeFormat: TimeFieldFormat.date,
      );
      final copied = attrs.copyWith();
      expect(copied.type, attrs.type);
      expect(copied.isPrimary, attrs.isPrimary);
      expect(copied.isRequired, attrs.isRequired);
      expect(copied.isSecret, attrs.isSecret);
      expect(copied.isEditable, attrs.isEditable);
      expect(copied.isSearchable, attrs.isSearchable);
      expect(copied.isCopyable, attrs.isCopyable);
      expect(copied.isReference, attrs.isReference);
      expect(copied.maxLength, attrs.maxLength);
      expect(copied.minLength, attrs.minLength);
      expect(copied.regex, attrs.regex);
      expect(copied.hint, attrs.hint);
      expect(copied.timeFormat, attrs.timeFormat);
    });

    test('copyWith overrides specified fields', () {
      const attrs = AccountFieldAttributes(
        type: AccountFieldType.text,
      );
      final copied = attrs.copyWith(
        type: AccountFieldType.email,
        isPrimary: true,
        isRequired: true,
        isSecret: true,
        isEditable: false,
        isSearchable: true,
        isCopyable: false,
        isReference: true,
        maxLength: 100,
        minLength: 1,
        regex: r'^\d+$',
        hint: 'new hint',
        timeFormat: TimeFieldFormat.time,
      );
      expect(copied.type, AccountFieldType.email);
      expect(copied.isPrimary, isTrue);
      expect(copied.isRequired, isTrue);
      expect(copied.isSecret, isTrue);
      expect(copied.isEditable, isFalse);
      expect(copied.isSearchable, isTrue);
      expect(copied.isCopyable, isFalse);
      expect(copied.isReference, isTrue);
      expect(copied.maxLength, 100);
      expect(copied.minLength, 1);
      expect(copied.regex, r'^\d+$');
      expect(copied.hint, 'new hint');
      expect(copied.timeFormat, TimeFieldFormat.time);
    });

    test('copyWith preserves default values for unspecified fields', () {
      const attrs = AccountFieldAttributes(
        type: AccountFieldType.text,
        isPrimary: true,
      );
      final copied = attrs.copyWith(isSecret: true);
      expect(copied.type, AccountFieldType.text);
      expect(copied.isPrimary, isTrue);
      expect(copied.isSecret, isTrue);
      expect(copied.isEditable, isTrue);
      expect(copied.isCopyable, isTrue);
      expect(copied.timeFormat, TimeFieldFormat.full);
    });
  });

  group('built-in account templates', () {
    test('includes website and secure note built-in templates', () {
      final ids = basicAccountTemplates.map((t) => t.templateId).toList();
      expect(ids, contains('builtin_generic_info'));
      expect(ids, contains('builtin_secure_note'));
      expect(ids, contains('builtin_mnemonic'));
      expect(ids, contains('builtin_api_service'));
      expect(ids.length, 4);
    });

    test('website template uses a 2FA link field without storing secrets', () {
      final passwordField = websiteTemplate.fields.firstWhere(
        (field) => field.fieldKey == 'password',
      );
      final totpField = websiteTemplate.fields.firstWhere(
        (field) => field.fieldKey == 'totp',
      );

      expect(websiteTemplate.isCustom, isFalse);
      expect(websiteTemplate.title, '网站模板');
      expect(websiteTemplate.fields.map((field) => field.fieldKey), [
        'website',
        'username',
        'password',
        'totp',
        'notes',
      ]);
      expect(passwordField.attributes.isSecret, isTrue);
      expect(passwordField.attributes.isRequired, isTrue);
      expect(passwordField.attributes.type, AccountFieldType.password);
      expect(totpField.attributes.type, AccountFieldType.custom);
      expect(totpField.attributes.isReference, isTrue);
      expect(totpField.attributes.isSecret, isFalse);
      expect(totpField.attributes.isCopyable, isFalse);
      expect(
        websiteTemplate.fields.any((field) => field.fieldKey == 'totp_secret'),
        isFalse,
      );
    });

    test('secure note templates use longText and list field types', () {
      final secureNote = secureNoteGenericTemplate;
      final mnemonic = secureNoteMnemonicTemplate;
      final apiService = apiServiceTemplate;

      expect(secureNote.category, TemplateCategory.custom);
      expect(
        secureNote.fields.first.attributes.type,
        AccountFieldType.longText,
      );
      expect(mnemonic.fields.first.attributes.type, AccountFieldType.list);
      expect(
        apiService.fields.any(
          (f) => f.attributes.type == AccountFieldType.list,
        ),
        isTrue,
      );
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
