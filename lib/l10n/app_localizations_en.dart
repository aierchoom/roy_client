// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabAccounts => 'Accounts';

  @override
  String get tabTemplates => 'Templates';

  @override
  String get tabSettings => 'Settings';

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get searchAccountsHint => 'Search accounts or emails...';

  @override
  String get noAccounts => 'No accounts';

  @override
  String get unknownTemplate => 'Unknown';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirm =>
      'Are you sure you want to delete this account? This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get addAccount => 'Add Account';

  @override
  String get editAccount => 'Edit Account';

  @override
  String get accountNameLabel => 'Account Name';

  @override
  String get accountNameRequired => 'Please enter a name';

  @override
  String get accountEmailLabel => 'Linked Email/Account Note';

  @override
  String get templateType => 'Template Type';

  @override
  String fillRequiredField(String fieldName) {
    return 'Required field missing: $fieldName';
  }

  @override
  String get templatesTitle => 'Templates';

  @override
  String get builtinTag => 'Built-in';

  @override
  String get addTemplate => 'New Template';

  @override
  String get editTemplate => 'Edit Template';

  @override
  String get templateTitleField => 'Title';

  @override
  String get templateSubtitleField => 'Subtitle';

  @override
  String get requireTemplateTitle => 'Please enter a template title';

  @override
  String get fieldsList => 'Fields List';

  @override
  String get addField => 'Add Field';

  @override
  String get customField => 'Custom Field';

  @override
  String fieldTypeText(String type) {
    return 'Type: $type';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get securitySettingsTitle => 'Security';

  @override
  String get securitySettingsSubtitle => '2FA, Master Password...';

  @override
  String get dataSyncTitle => 'Sync Data';

  @override
  String get dataSyncSubtitle => 'Sync to cloud';

  @override
  String get aboutSecretRoy => 'About SecretRoy';

  @override
  String get versionNumber => 'Version 1.0.0';

  @override
  String get btnSave => 'Save';

  @override
  String get btnClose => 'Close';
}
