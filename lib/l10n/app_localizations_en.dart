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

  @override
  String get importTemplate => 'Import Template';

  @override
  String get exportTemplate => 'Export Template';

  @override
  String get export => 'Export';

  @override
  String get import => 'Import';

  @override
  String importSuccess(int count) {
    return 'Successfully imported $count template(s)';
  }

  @override
  String get importFailed => 'Import failed: invalid format';

  @override
  String get exportCopied => 'Copied to clipboard';

  @override
  String get importHint => 'Paste template JSON text';

  @override
  String get batchExportTitle => 'Batch Export Templates';

  @override
  String get selectTemplates => 'Select templates to export';

  @override
  String get noTemplatesToExport => 'No custom templates to export';

  @override
  String get noTemplatesToImport => 'No templates to import';

  @override
  String get notificationCenter => 'Notifications';

  @override
  String get notifications => 'Alerts';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get noNotificationsHint =>
      'Password security reminders will appear here';

  @override
  String get notificationItems => 'Items';

  @override
  String get notificationUnread => 'Unread';

  @override
  String get passwordExpiryReminder => 'Password Expiry Reminder';

  @override
  String passwordExpiryBody(int days) {
    return 'has not been updated for $days day(s). Consider changing it soon.';
  }

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get notificationSettingsSubtitle => 'Password expiry threshold & push';

  @override
  String get passwordExpiryDays => 'Password Expiry Days';

  @override
  String get passwordExpiryDaysDesc =>
      'Remind when password hasn\'t changed for this many days';

  @override
  String get pushNotification => 'Push Notifications';

  @override
  String get pushNotificationDesc => 'Daily check with system push';

  @override
  String daysAgo(int days) {
    return '$days day(s) ago';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours hour(s) ago';
  }

  @override
  String get justNow => 'Just now';

  @override
  String today(String time) {
    return 'Today $time';
  }

  @override
  String yesterday(String time) {
    return 'Yesterday $time';
  }

  @override
  String minutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String get unknownDevice => 'Unknown device';

  @override
  String get thisDevice => 'This device';

  @override
  String get deviceLabel => 'Device';
}
