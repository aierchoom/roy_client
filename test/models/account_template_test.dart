import 'package:flutter/material.dart';
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
      const attrs = AccountFieldAttributes(type: AccountFieldType.text);
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
    test('includes broad built-in template coverage', () {
      final ids = basicAccountTemplates.map((t) => t.templateId).toList();
      expect(ids, contains('builtin_generic_info'));
      expect(ids, contains('builtin_secure_note'));
      expect(ids, contains('builtin_mnemonic'));
      expect(ids, contains('builtin_api_service'));
      expect(ids, contains('builtin_payment_card'));
      expect(ids, contains('builtin_identity_document'));
      expect(ids, contains('builtin_wifi'));
      expect(ids, contains('builtin_server_ssh'));
      expect(ids, contains('builtin_software_license'));
      expect(ids.length, 9);
    });

    test('access credential template links 2FA without storing secrets', () {
      final passwordField = websiteTemplate.fields.firstWhere(
        (field) => field.fieldKey == 'password',
      );
      final totpField = websiteTemplate.fields.firstWhere(
        (field) => field.fieldKey == 'totp',
      );

      expect(websiteTemplate.isCustom, isFalse);
      expect(websiteTemplate.title, '登录凭据');
      expect(websiteTemplate.category, TemplateCategory.access);
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

    test('secure note and API templates use the current categories', () {
      expect(secureNoteGenericTemplate.category, TemplateCategory.secret);
      expect(
        secureNoteGenericTemplate.fields.first.attributes.type,
        AccountFieldType.longText,
      );
      expect(secureNoteMnemonicTemplate.category, TemplateCategory.secret);
      expect(
        secureNoteMnemonicTemplate.fields.first.attributes.type,
        AccountFieldType.list,
      );
      expect(apiServiceTemplate.category, TemplateCategory.access);
      expect(
        apiServiceTemplate.fields.any(
          (f) => f.attributes.type == AccountFieldType.list,
        ),
        isTrue,
      );
    });

    test('specialized built-ins use orthogonal categories', () {
      expect(paymentCardTemplate.category, TemplateCategory.payment);
      expect(identityDocumentTemplate.category, TemplateCategory.identity);
      expect(wifiCredentialTemplate.category, TemplateCategory.access);
      expect(serverCredentialTemplate.category, TemplateCategory.access);
      expect(softwareLicenseTemplate.category, TemplateCategory.license);
    });

    test('legacy category strings map onto the current taxonomy', () {
      expect(templateCategoryFromString('login'), TemplateCategory.access);
      expect(templateCategoryFromString('work'), TemplateCategory.access);
      expect(templateCategoryFromString('shopping'), TemplateCategory.access);
      expect(templateCategoryFromString('contact'), TemplateCategory.identity);
      expect(templateCategoryFromString('finance'), TemplateCategory.payment);
      expect(templateCategoryFromString('note'), TemplateCategory.secret);
    });

    test(
      'category inference prefers title and fields before icon fallback',
      () {
        expect(
          inferTemplateCategory(
            title: 'API Key',
            iconCodePoint: templateIconStorageValue(Icons.key_outlined),
          ),
          TemplateCategory.access,
        );
        expect(
          inferTemplateCategory(
            title: 'Wallet seed phrase',
            iconCodePoint: templateIconStorageValue(Icons.lock_outline),
          ),
          TemplateCategory.secret,
        );
        expect(
          inferTemplateCategory(
            title: 'Untitled',
            iconCodePoint: templateIconStorageValue(Icons.vpn_key_outlined),
          ),
          TemplateCategory.secret,
        );
        expect(
          inferTemplateCategory(
            title: 'Untitled',
            fields: const [
              AccountField(
                fieldKey: 'license_key',
                label: '授权码',
                attributes: AccountFieldAttributes(
                  type: AccountFieldType.text,
                  isSecret: true,
                ),
              ),
            ],
            iconCodePoint: templateIconStorageValue(Icons.lock_outline),
          ),
          TemplateCategory.license,
        );
      },
    );

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
