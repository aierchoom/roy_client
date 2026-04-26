import 'package:flutter/material.dart';
import 'account_item.dart';
import 'hlc.dart';

enum AccountFieldType {
  text,
  password,
  number,
  email,
  phone,
  url,
  time,
  custom,
}

enum TimeFieldFormat {
  full,
  date,
  monthYear,
  time,
}

enum TemplateCategory {
  login,
  payment,
  contact,
  identity,
  work,
  shopping,
  finance,
  custom,
}

AccountFieldType fieldTypeFromString(String value) {
  return AccountFieldType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => AccountFieldType.text,
  );
}

TemplateCategory templateCategoryFromString(String? value) {
  return TemplateCategory.values.firstWhere(
    (category) => category.name == value,
    orElse: () => TemplateCategory.custom,
  );
}

String templateBadgeText(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return 'TM';

  final words = trimmed
      .split(RegExp(r'[\s\-_\/]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (words.length >= 2) {
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  final compact = trimmed.replaceAll(RegExp(r'\s+'), '');
  final isAscii = RegExp(r'^[A-Za-z0-9]+$').hasMatch(compact);
  if (isAscii) {
    return compact.substring(0, compact.length >= 2 ? 2 : 1).toUpperCase();
  }

  return compact.substring(0, compact.length >= 2 ? 2 : 1);
}

class AccountFieldAttributes {
  final AccountFieldType type;
  final bool isPrimary;
  final bool isRequired;
  final bool isSecret;
  final bool isEditable;
  final bool isSearchable;
  final bool isCopyable;
  final int? maxLength;
  final int? minLength;
  final String? regex;
  final String? hint;
  final TimeFieldFormat timeFormat;

  const AccountFieldAttributes({
    required this.type,
    this.isPrimary = false,
    this.isRequired = false,
    this.isSecret = false,
    this.isEditable = true,
    this.isSearchable = false,
    this.isCopyable = true,
    this.maxLength,
    this.minLength,
    this.regex,
    this.hint,
    this.timeFormat = TimeFieldFormat.full,
  });

  factory AccountFieldAttributes.fromJson(Map<String, dynamic> json) {
    return AccountFieldAttributes(
      type: fieldTypeFromString(json['type'] as String? ?? 'text'),
      isPrimary: json['isPrimary'] == true,
      isRequired: json['isRequired'] == true,
      isSecret: json['isSecret'] == true,
      isEditable: json['isEditable'] != false,
      isSearchable: json['isSearchable'] == true,
      isCopyable: json['isCopyable'] != false,
      maxLength: json['maxLength'] as int?,
      minLength: json['minLength'] as int?,
      regex: json['regex'] as String?,
      hint: json['hint'] as String?,
      timeFormat: TimeFieldFormat.values.firstWhere(
        (e) => e.name == (json['timeFormat'] as String? ?? 'full'),
        orElse: () => TimeFieldFormat.full,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'isPrimary': isPrimary,
      'isRequired': isRequired,
      'isSecret': isSecret,
      'isEditable': isEditable,
      'isSearchable': isSearchable,
      'isCopyable': isCopyable,
      'maxLength': maxLength,
      'minLength': minLength,
      'regex': regex,
      'hint': hint,
      'timeFormat': timeFormat.name,
    };
  }
}

class AccountField {
  final String fieldKey;
  final String label;
  final String? description;
  final AccountFieldAttributes attributes;

  const AccountField({
    required this.fieldKey,
    required this.label,
    this.description,
    required this.attributes,
  });

  factory AccountField.fromJson(Map<String, dynamic> json) {
    return AccountField(
      fieldKey: json['fieldKey'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String?,
      attributes: AccountFieldAttributes.fromJson(
        (json['attributes'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fieldKey': fieldKey,
      'label': label,
      'description': description,
      'attributes': attributes.toJson(),
    };
  }
}

class AccountTemplate {
  final String templateId;
  final String title;
  final String subTitle;
  final IconData? icon;
  final TemplateCategory category;
  final List<AccountField> fields;
  final bool isCustom;

  final SyncStatus syncStatus;
  final Hlc? hlc;
  final int serverVersion;
  final bool isDeleted;
  final Hlc? deleteHlc;

  const AccountTemplate({
    required this.templateId,
    required this.title,
    required this.subTitle,
    this.icon,
    required this.category,
    required this.fields,
    this.isCustom = false,
    this.syncStatus = SyncStatus.pendingPush,
    this.hlc,
    this.serverVersion = 0,
    this.isDeleted = false,
    this.deleteHlc,
  });

  IconData get displayIcon => templateCategoryIcon(category);
  String get badgeText => templateBadgeText(title);

  factory AccountTemplate.fromJson(
    Map<String, dynamic> json, {
    bool isCustom = true,
  }) {
    final rawIcon = json['icon'];
    final icon = templateIconFromStorageValue(rawIcon);

    return AccountTemplate(
      templateId:
          json['templateId'] as String? ??
          'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Untitled Template',
      subTitle:
          json['subtitle'] as String? ?? json['subTitle'] as String? ?? '',
      icon: icon,
      category: inferTemplateCategory(
        explicitCategory: json['category'] as String?,
        templateId: json['templateId'] as String?,
        title: json['title'] as String?,
        fields: (json['fields'] as List<dynamic>? ?? const [])
            .map(
              (field) => AccountField.fromJson(field as Map<String, dynamic>),
            )
            .toList(),
        icon: icon,
      ),
      fields: (json['fields'] as List<dynamic>? ?? const [])
          .map((field) => AccountField.fromJson(field as Map<String, dynamic>))
          .toList(),
      isCustom: isCustom,
      syncStatus: json['syncStatus'] != null 
          ? SyncStatus.values.firstWhere((e) => e.name == json['syncStatus'])
          : SyncStatus.synchronized,
      hlc: json['hlc'] != null ? Hlc.parse(json['hlc'] as String) : null,
      serverVersion: json['serverVersion'] as int? ?? 0,
      isDeleted: json['isDeleted'] == true,
      deleteHlc: json['deleteHlc'] != null ? Hlc.parse(json['deleteHlc'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'templateId': templateId,
      'title': title,
      'subtitle': subTitle,
      'icon': templateIconStorageValue(icon),
      'category': category.name,
      'fields': fields.map((field) => field.toJson()).toList(),
      'syncStatus': syncStatus.name,
      'hlc': hlc?.toString(),
      'serverVersion': serverVersion,
      'isDeleted': isDeleted,
      'deleteHlc': deleteHlc?.toString(),
    };
  }

  AccountTemplate copyWith({
    String? title,
    String? subTitle,
    IconData? icon,
    TemplateCategory? category,
    List<AccountField>? fields,
    bool? isCustom,
    SyncStatus? syncStatus,
    Hlc? hlc,
    int? serverVersion,
    bool? isDeleted,
    Hlc? deleteHlc,
  }) {
    return AccountTemplate(
      templateId: templateId,
      title: title ?? this.title,
      subTitle: subTitle ?? this.subTitle,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      fields: fields ?? this.fields,
      isCustom: isCustom ?? this.isCustom,
      syncStatus: syncStatus ?? this.syncStatus,
      hlc: hlc ?? this.hlc,
      serverVersion: serverVersion ?? this.serverVersion,
      isDeleted: isDeleted ?? this.isDeleted,
      deleteHlc: deleteHlc ?? this.deleteHlc,
    );
  }
}

const List<IconData> kTemplateIconOptions = [
  Icons.description_outlined,
  Icons.credit_card_outlined,
  Icons.lock_outline,
  Icons.language_outlined,
  Icons.email_outlined,
  Icons.phone_outlined,
  Icons.business_center_outlined,
  Icons.shopping_bag_outlined,
  Icons.apartment_outlined,
  Icons.vpn_key_outlined,
];

IconData? templateIconFromStorageValue(Object? rawValue) {
  if (rawValue is String) {
    return templateIconFromStorageValue(int.tryParse(rawValue));
  }

  if (rawValue is int &&
      rawValue >= 0 &&
      rawValue < kTemplateIconOptions.length) {
    return kTemplateIconOptions[rawValue];
  }

  return null;
}

int? templateIconStorageValue(IconData? icon) {
  if (icon == null) return null;
  final index = kTemplateIconOptions.indexOf(icon);
  return index >= 0 ? index : 0;
}

IconData templateCategoryIcon(TemplateCategory category) {
  switch (category) {
    case TemplateCategory.login:
      return Icons.lock_outline;
    case TemplateCategory.payment:
      return Icons.credit_card_outlined;
    case TemplateCategory.contact:
      return Icons.phone_outlined;
    case TemplateCategory.identity:
      return Icons.badge_outlined;
    case TemplateCategory.work:
      return Icons.business_center_outlined;
    case TemplateCategory.shopping:
      return Icons.shopping_bag_outlined;
    case TemplateCategory.finance:
      return Icons.account_balance_wallet_outlined;
    case TemplateCategory.custom:
      return Icons.description_outlined;
  }
}

TemplateCategory inferTemplateCategory({
  String? explicitCategory,
  String? templateId,
  String? title,
  List<AccountField>? fields,
  IconData? icon,
}) {
  if (explicitCategory != null && explicitCategory.isNotEmpty) {
    return templateCategoryFromString(explicitCategory);
  }

  switch (templateId) {
    case 'bank_card':
      return TemplateCategory.payment;
    case 'email_account':
    case 'web_account':
      return TemplateCategory.login;
    case 'phone_account':
      return TemplateCategory.contact;
  }

  if (icon == Icons.credit_card_outlined) return TemplateCategory.payment;
  if (icon == Icons.email_outlined ||
      icon == Icons.language_outlined ||
      icon == Icons.lock_outline ||
      icon == Icons.vpn_key_outlined) {
    return TemplateCategory.login;
  }
  if (icon == Icons.phone_outlined) return TemplateCategory.contact;
  if (icon == Icons.business_center_outlined ||
      icon == Icons.apartment_outlined) {
    return TemplateCategory.work;
  }
  if (icon == Icons.shopping_bag_outlined) return TemplateCategory.shopping;

  final normalizedTitle = (title ?? '').toLowerCase();
  if (normalizedTitle.contains('bank') ||
      normalizedTitle.contains('card') ||
      normalizedTitle.contains('payment') ||
      normalizedTitle.contains('wallet') ||
      normalizedTitle.contains('银行卡') ||
      normalizedTitle.contains('支付')) {
    return TemplateCategory.payment;
  }
  if (normalizedTitle.contains('email') ||
      normalizedTitle.contains('web') ||
      normalizedTitle.contains('website') ||
      normalizedTitle.contains('app') ||
      normalizedTitle.contains('login') ||
      normalizedTitle.contains('账号') ||
      normalizedTitle.contains('登录')) {
    return TemplateCategory.login;
  }
  if (normalizedTitle.contains('phone') ||
      normalizedTitle.contains('sim') ||
      normalizedTitle.contains('mobile') ||
      normalizedTitle.contains('电话') ||
      normalizedTitle.contains('手机')) {
    return TemplateCategory.contact;
  }
  if (normalizedTitle.contains('id') ||
      normalizedTitle.contains('passport') ||
      normalizedTitle.contains('identity') ||
      normalizedTitle.contains('证件') ||
      normalizedTitle.contains('身份')) {
    return TemplateCategory.identity;
  }
  if (normalizedTitle.contains('work') ||
      normalizedTitle.contains('company') ||
      normalizedTitle.contains('office') ||
      normalizedTitle.contains('business') ||
      normalizedTitle.contains('工作') ||
      normalizedTitle.contains('企业')) {
    return TemplateCategory.work;
  }
  if (normalizedTitle.contains('shop') ||
      normalizedTitle.contains('shopping') ||
      normalizedTitle.contains('store') ||
      normalizedTitle.contains('商城') ||
      normalizedTitle.contains('购物')) {
    return TemplateCategory.shopping;
  }

  final sourceFields = fields ?? const <AccountField>[];
  final hasEmailLike = sourceFields.any(
    (field) =>
        field.attributes.type == AccountFieldType.email ||
        field.attributes.type == AccountFieldType.url ||
        field.attributes.type == AccountFieldType.password,
  );
  final hasPhoneLike = sourceFields.any(
    (field) => field.attributes.type == AccountFieldType.phone,
  );
  final hasPaymentLike = sourceFields.any((field) {
    final normalized = '${field.fieldKey} ${field.label}'.toLowerCase();
    return normalized.contains('card') ||
        normalized.contains('cvv') ||
        normalized.contains('bank') ||
        normalized.contains('支付') ||
        normalized.contains('银行卡');
  });

  if (hasPaymentLike) return TemplateCategory.payment;
  if (hasPhoneLike) return TemplateCategory.contact;
  if (hasEmailLike) return TemplateCategory.login;

  return TemplateCategory.custom;
}

IconData iconForBuiltinTemplate(String id) {
  switch (id) {
    case 'bank_card':
      return Icons.credit_card_outlined;
    case 'email_account':
      return Icons.email_outlined;
    case 'web_account':
      return Icons.language_outlined;
    case 'phone_account':
      return Icons.phone_outlined;
    default:
      return Icons.description_outlined;
  }
}

final AccountTemplate bankCardTemplate = AccountTemplate(
  templateId: 'bank_card',
  title: '\u94f6\u884c\u5361',
  subTitle: '\u94f6\u884c\u5361\u4e0e\u652f\u4ed8\u4fe1\u606f',
  icon: Icons.credit_card_outlined,
  category: TemplateCategory.payment,
  fields: const [
    AccountField(
      fieldKey: 'card_holder',
      label: '\u6301\u5361\u4eba',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.text,
        isRequired: true,
        isSearchable: true,
      ),
    ),
    AccountField(
      fieldKey: 'card_number',
      label: '\u5361\u53f7',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.number,
        isPrimary: true,
        isRequired: true,
        isSecret: false,
        minLength: 16,
        maxLength: 19,
      ),
    ),
    AccountField(
      fieldKey: 'bank_name',
      label: '\u5f00\u6237\u884c',
      attributes: AccountFieldAttributes(type: AccountFieldType.text),
    ),
    AccountField(
      fieldKey: 'expiry_date',
      label: '\u5230\u671f\u65f6\u95f4',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.time,
        timeFormat: TimeFieldFormat.monthYear,
        hint: 'MM/YY',
      ),
    ),
    AccountField(
      fieldKey: 'cvv',
      label: 'CVV',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.password,
        isSecret: true,
        minLength: 3,
        maxLength: 4,
      ),
    ),
  ],
);

final AccountTemplate emailAccountTemplate = AccountTemplate(
  templateId: 'email_account',
  title: '\u90ae\u7bb1\u8d26\u53f7',
  subTitle: '\u90ae\u7bb1\u767b\u5f55\u4e0e\u5907\u6ce8\u4fe1\u606f',
  icon: Icons.email_outlined,
  category: TemplateCategory.login,
  fields: const [
    AccountField(
      fieldKey: 'email',
      label: '\u90ae\u7bb1\u5730\u5740',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.email,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
      ),
    ),
    AccountField(
      fieldKey: 'password',
      label: '\u5bc6\u7801',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.password,
        isRequired: true,
        isSecret: true,
        minLength: 8,
      ),
    ),
    AccountField(
      fieldKey: 'remark',
      label: '\u5907\u6ce8',
      attributes: AccountFieldAttributes(type: AccountFieldType.text),
    ),
  ],
);

final AccountTemplate webAccountTemplate = AccountTemplate(
  templateId: 'web_account',
  title: '\u7f51\u7ad9/\u5e94\u7528',
  subTitle: '\u5e38\u89c1\u7f51\u7ad9\u6216 App \u8d26\u53f7\u4fe1\u606f',
  icon: Icons.language_outlined,
  category: TemplateCategory.login,
  fields: const [
    AccountField(
      fieldKey: 'site_name',
      label: '\u7f51\u7ad9\u6216 App \u540d\u79f0',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.text,
        isRequired: true,
        isSearchable: true,
      ),
    ),
    AccountField(
      fieldKey: 'username',
      label: '\u8d26\u53f7',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.text,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
      ),
    ),
    AccountField(
      fieldKey: 'password',
      label: '\u5bc6\u7801',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.password,
        isRequired: true,
        isSecret: true,
      ),
    ),
    AccountField(
      fieldKey: 'login_url',
      label: '\u767b\u5f55\u94fe\u63a5',
      attributes: AccountFieldAttributes(type: AccountFieldType.url),
    ),
  ],
);

final AccountTemplate phoneAccountTemplate = AccountTemplate(
  templateId: 'phone_account',
  title: '\u624b\u673a\u53f7',
  subTitle: '\u624b\u673a\u53f7\u4e0e\u8fd0\u8425\u5546\u4fe1\u606f',
  icon: Icons.phone_outlined,
  category: TemplateCategory.contact,
  fields: const [
    AccountField(
      fieldKey: 'phone_number',
      label: '\u624b\u673a\u53f7',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.phone,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
      ),
    ),
    AccountField(
      fieldKey: 'carrier',
      label: '\u8fd0\u8425\u5546',
      attributes: AccountFieldAttributes(type: AccountFieldType.text),
    ),
    AccountField(
      fieldKey: 'pin',
      label: 'SIM PIN',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.password,
        isSecret: true,
      ),
    ),
  ],
);

final List<AccountTemplate> basicAccountTemplates = [
  bankCardTemplate,
  emailAccountTemplate,
  webAccountTemplate,
  phoneAccountTemplate,
];
