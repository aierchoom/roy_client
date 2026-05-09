import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @tabAccounts.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get tabAccounts;

  /// No description provided for @tabTemplates.
  ///
  /// In zh, this message translates to:
  /// **'模板'**
  String get tabTemplates;

  /// No description provided for @tabSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get tabSettings;

  /// No description provided for @accountsTitle.
  ///
  /// In zh, this message translates to:
  /// **'账户管理'**
  String get accountsTitle;

  /// No description provided for @searchAccountsHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索账户或邮箱...'**
  String get searchAccountsHint;

  /// No description provided for @noAccounts.
  ///
  /// In zh, this message translates to:
  /// **'暂无账户'**
  String get noAccounts;

  /// No description provided for @unknownTemplate.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknownTemplate;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @deleteAccount.
  ///
  /// In zh, this message translates to:
  /// **'删除账户'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认删除此账户吗？操作不可逆。'**
  String get deleteAccountConfirm;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @addAccount.
  ///
  /// In zh, this message translates to:
  /// **'新增账户'**
  String get addAccount;

  /// No description provided for @editAccount.
  ///
  /// In zh, this message translates to:
  /// **'编辑账户'**
  String get editAccount;

  /// No description provided for @accountNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'账户名称'**
  String get accountNameLabel;

  /// No description provided for @accountNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写名称'**
  String get accountNameRequired;

  /// No description provided for @accountEmailLabel.
  ///
  /// In zh, this message translates to:
  /// **'绑定邮箱/账号说明'**
  String get accountEmailLabel;

  /// No description provided for @templateType.
  ///
  /// In zh, this message translates to:
  /// **'模板类型'**
  String get templateType;

  /// No description provided for @fillRequiredField.
  ///
  /// In zh, this message translates to:
  /// **'请填写必填字段：{fieldName}'**
  String fillRequiredField(String fieldName);

  /// No description provided for @templatesTitle.
  ///
  /// In zh, this message translates to:
  /// **'模板管理'**
  String get templatesTitle;

  /// No description provided for @builtinTag.
  ///
  /// In zh, this message translates to:
  /// **'内置'**
  String get builtinTag;

  /// No description provided for @addTemplate.
  ///
  /// In zh, this message translates to:
  /// **'新建模板'**
  String get addTemplate;

  /// No description provided for @editTemplate.
  ///
  /// In zh, this message translates to:
  /// **'编辑模板'**
  String get editTemplate;

  /// No description provided for @templateTitleField.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get templateTitleField;

  /// No description provided for @templateSubtitleField.
  ///
  /// In zh, this message translates to:
  /// **'副标题'**
  String get templateSubtitleField;

  /// No description provided for @requireTemplateTitle.
  ///
  /// In zh, this message translates to:
  /// **'请输入模板标题'**
  String get requireTemplateTitle;

  /// No description provided for @fieldsList.
  ///
  /// In zh, this message translates to:
  /// **'字段列表'**
  String get fieldsList;

  /// No description provided for @addField.
  ///
  /// In zh, this message translates to:
  /// **'添加字段'**
  String get addField;

  /// No description provided for @customField.
  ///
  /// In zh, this message translates to:
  /// **'自定义字段'**
  String get customField;

  /// No description provided for @fieldTypeText.
  ///
  /// In zh, this message translates to:
  /// **'类型: {type}'**
  String fieldTypeText(String type);

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @securitySettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'安全设置'**
  String get securitySettingsTitle;

  /// No description provided for @securitySettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启二次验证、修改主密码等'**
  String get securitySettingsSubtitle;

  /// No description provided for @dataSyncTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据同步'**
  String get dataSyncTitle;

  /// No description provided for @dataSyncSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'同步数据到云端'**
  String get dataSyncSubtitle;

  /// No description provided for @aboutSecretRoy.
  ///
  /// In zh, this message translates to:
  /// **'关于 SecretRoy'**
  String get aboutSecretRoy;

  /// No description provided for @versionNumber.
  ///
  /// In zh, this message translates to:
  /// **'版本 1.0.0'**
  String get versionNumber;

  /// No description provided for @btnSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get btnSave;

  /// No description provided for @btnClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get btnClose;

  /// No description provided for @importTemplate.
  ///
  /// In zh, this message translates to:
  /// **'导入模板'**
  String get importTemplate;

  /// No description provided for @exportTemplate.
  ///
  /// In zh, this message translates to:
  /// **'导出模板'**
  String get exportTemplate;

  /// No description provided for @export.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get export;

  /// No description provided for @import.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get import;

  /// No description provided for @importSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功导入 {count} 个模板'**
  String importSuccess(int count);

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：格式无效'**
  String get importFailed;

  /// No description provided for @exportCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get exportCopied;

  /// No description provided for @importHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴模板 JSON 文本'**
  String get importHint;

  /// No description provided for @batchExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量导出模板'**
  String get batchExportTitle;

  /// No description provided for @selectTemplates.
  ///
  /// In zh, this message translates to:
  /// **'选择要导出的模板'**
  String get selectTemplates;

  /// No description provided for @noTemplatesToExport.
  ///
  /// In zh, this message translates to:
  /// **'没有可导出的自定义模板'**
  String get noTemplatesToExport;

  /// No description provided for @noTemplatesToImport.
  ///
  /// In zh, this message translates to:
  /// **'没有可导入的模板'**
  String get noTemplatesToImport;

  /// No description provided for @notificationCenter.
  ///
  /// In zh, this message translates to:
  /// **'通知中心'**
  String get notificationCenter;

  /// No description provided for @notifications.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get notifications;

  /// No description provided for @markAllRead.
  ///
  /// In zh, this message translates to:
  /// **'全部已读'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In zh, this message translates to:
  /// **'暂无通知'**
  String get noNotifications;

  /// No description provided for @noNotificationsHint.
  ///
  /// In zh, this message translates to:
  /// **'密码安全提醒会在这里显示'**
  String get noNotificationsHint;

  /// No description provided for @notificationItems.
  ///
  /// In zh, this message translates to:
  /// **'条通知'**
  String get notificationItems;

  /// No description provided for @notificationUnread.
  ///
  /// In zh, this message translates to:
  /// **'未读'**
  String get notificationUnread;

  /// No description provided for @passwordExpiryReminder.
  ///
  /// In zh, this message translates to:
  /// **'密码过期提醒'**
  String get passwordExpiryReminder;

  /// No description provided for @passwordExpiryBody.
  ///
  /// In zh, this message translates to:
  /// **'的密码已 {days} 天未修改，建议尽快更新。'**
  String passwordExpiryBody(int days);

  /// No description provided for @notificationSettings.
  ///
  /// In zh, this message translates to:
  /// **'通知设置'**
  String get notificationSettings;

  /// No description provided for @notificationSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'密码过期提醒阈值与推送'**
  String get notificationSettingsSubtitle;

  /// No description provided for @passwordExpiryDays.
  ///
  /// In zh, this message translates to:
  /// **'密码过期提醒天数'**
  String get passwordExpiryDays;

  /// No description provided for @passwordExpiryDaysDesc.
  ///
  /// In zh, this message translates to:
  /// **'超过此天数未修改密码时发送提醒'**
  String get passwordExpiryDaysDesc;

  /// No description provided for @pushNotification.
  ///
  /// In zh, this message translates to:
  /// **'推送通知'**
  String get pushNotification;

  /// No description provided for @pushNotificationDesc.
  ///
  /// In zh, this message translates to:
  /// **'每日定时检查并发送系统推送'**
  String get pushNotificationDesc;

  /// No description provided for @daysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{days} 天前'**
  String daysAgo(int days);

  /// No description provided for @hoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时前'**
  String hoursAgo(int hours);

  /// No description provided for @justNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get justNow;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
