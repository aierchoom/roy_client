// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get tabAccounts => '账户';

  @override
  String get tabTemplates => '模板';

  @override
  String get tabSettings => '设置';

  @override
  String get accountsTitle => '账户管理';

  @override
  String get searchAccountsHint => '搜索账户或邮箱...';

  @override
  String get noAccounts => '暂无账户';

  @override
  String get unknownTemplate => '未知';

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get deleteAccount => '删除账户';

  @override
  String get deleteAccountConfirm => '确认删除此账户吗？操作不可逆。';

  @override
  String get cancel => '取消';

  @override
  String get addAccount => '新增账户';

  @override
  String get editAccount => '编辑账户';

  @override
  String get accountNameLabel => '账户名称';

  @override
  String get accountNameRequired => '请填写名称';

  @override
  String get accountEmailLabel => '绑定邮箱/账号说明';

  @override
  String get templateType => '模板类型';

  @override
  String fillRequiredField(String fieldName) {
    return '请填写必填字段：$fieldName';
  }

  @override
  String get templatesTitle => '模板管理';

  @override
  String get builtinTag => '内置';

  @override
  String get addTemplate => '新建模板';

  @override
  String get editTemplate => '编辑模板';

  @override
  String get templateTitleField => '标题';

  @override
  String get templateSubtitleField => '副标题';

  @override
  String get requireTemplateTitle => '请输入模板标题';

  @override
  String get fieldsList => '字段列表';

  @override
  String get addField => '添加字段';

  @override
  String get customField => '自定义字段';

  @override
  String fieldTypeText(String type) {
    return '类型: $type';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get securitySettingsTitle => '安全设置';

  @override
  String get securitySettingsSubtitle => '开启二次验证、修改主密码等';

  @override
  String get dataSyncTitle => '数据同步';

  @override
  String get dataSyncSubtitle => '同步数据到云端';

  @override
  String get aboutSecretRoy => '关于 SecretRoy';

  @override
  String get versionNumber => '版本 1.0.0';

  @override
  String get btnSave => '保存';

  @override
  String get btnClose => '关闭';
}
