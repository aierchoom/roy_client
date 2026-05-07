import 'dart:convert';

import 'package:flutter/material.dart';

import '../utils/template_icons.dart';
import 'account_item.dart';
import 'hlc.dart';

export '../utils/template_icons.dart'
    show
        kTemplateIconOptions,
        templateIconFromStorageValue,
        templateIconStorageValue,
        templateBadgeText,
        iconForBuiltinTemplate;

enum AccountFieldType {
  text,
  password,
  number,
  email,
  phone,
  url,
  time,
  custom,
  accountLink,
  unknown,
}

enum TimeFieldFormat { full, date, monthYear, time }

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
    orElse: () => AccountFieldType.unknown,
  );
}

TemplateCategory templateCategoryFromString(String? value) {
  return TemplateCategory.values.firstWhere(
    (category) => category.name == value,
    orElse: () => TemplateCategory.custom,
  );
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
  int? iconCodePoint,
}) {
  if (explicitCategory != null && explicitCategory.isNotEmpty) {
    return templateCategoryFromString(explicitCategory);
  }

  switch (templateId) {
    case 'generic_info':
      return TemplateCategory.custom;
  }

  if (iconCodePoint == Icons.credit_card_outlined.codePoint) return TemplateCategory.payment;
  if (iconCodePoint == Icons.email_outlined.codePoint ||
      iconCodePoint == Icons.language_outlined.codePoint ||
      iconCodePoint == Icons.lock_outline.codePoint ||
      iconCodePoint == Icons.vpn_key_outlined.codePoint) {
    return TemplateCategory.login;
  }
  if (iconCodePoint == Icons.phone_outlined.codePoint) return TemplateCategory.contact;
  if (iconCodePoint == Icons.business_center_outlined.codePoint ||
      iconCodePoint == Icons.apartment_outlined.codePoint) {
    return TemplateCategory.work;
  }
  if (iconCodePoint == Icons.shopping_bag_outlined.codePoint) return TemplateCategory.shopping;

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
  final bool isReference;
  final TimeFieldFormat timeFormat;

  const AccountFieldAttributes({
    required this.type,
    this.isPrimary = false,
    this.isRequired = false,
    this.isSecret = false,
    this.isEditable = true,
    this.isSearchable = false,
    this.isCopyable = true,
    this.isReference = false,
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
      isReference: json['isReference'] == true,
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
      'isReference': isReference,
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
  final int? iconCodePoint;
  final TemplateCategory category;
  final List<AccountField> fields;
  final bool isCustom;

  final SyncStatus syncStatus;
  final Hlc? hlc;
  final Map<String, Hlc> fieldHlc;
  final int serverVersion;
  final bool isDeleted;
  final Hlc? deleteHlc;

  const AccountTemplate({
    required this.templateId,
    required this.title,
    required this.subTitle,
    this.iconCodePoint,
    required this.category,
    required this.fields,
    this.isCustom = false,
    this.syncStatus = SyncStatus.pendingPush,
    this.hlc,
    this.fieldHlc = const {},
    this.serverVersion = 0,
    this.isDeleted = false,
    this.deleteHlc,
  });

  IconData? get icon => templateIconFromStorageValue(iconCodePoint);
  IconData get displayIcon => templateCategoryIcon(category);
  String get badgeText => templateBadgeText(title);

  factory AccountTemplate.fromJson(
    Map<String, dynamic> json, {
    bool isCustom = true,
  }) {
    final rawIcon = json['icon'];
    final parsedIconCodePoint = rawIcon is int
        ? rawIcon
        : (rawIcon is String ? int.tryParse(rawIcon) : null);

    return AccountTemplate(
      templateId:
          json['templateId'] as String? ??
          'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Untitled Template',
      subTitle:
          json['subtitle'] as String? ?? json['subTitle'] as String? ?? '',
      iconCodePoint: parsedIconCodePoint,
      category: inferTemplateCategory(
        explicitCategory: json['category'] as String?,
        templateId: json['templateId'] as String?,
        title: json['title'] as String?,
        fields: (json['fields'] as List<dynamic>? ?? const [])
            .map(
              (field) => AccountField.fromJson(field as Map<String, dynamic>),
            )
            .toList(),
        iconCodePoint: parsedIconCodePoint,
      ),
      fields: (json['fields'] as List<dynamic>? ?? const [])
          .map((field) => AccountField.fromJson(field as Map<String, dynamic>))
          .toList(),
      isCustom: isCustom,
      syncStatus: syncStatusFromJson(
        json['syncStatus'],
        fallback: SyncStatus.synchronized,
      ),
      hlc: json['hlc'] != null ? Hlc.parse(json['hlc'] as String) : null,
      fieldHlc: AccountTemplate.parseFieldHlc(json['fieldHlc']),
      serverVersion: json['serverVersion'] as int? ?? 0,
      isDeleted: json['isDeleted'] == true,
      deleteHlc: json['deleteHlc'] != null
          ? Hlc.parse(json['deleteHlc'] as String)
          : null,
    );
  }

  static Map<String, Hlc> parseFieldHlc(dynamic value) {
    final dynamic decoded;
    if (value is String) {
      if (value.trim().isEmpty) return const {};
      try {
        decoded = jsonDecode(value);
      } catch (_) {
        return const {};
      }
    } else {
      decoded = value;
    }

    if (decoded is! Map) return const {};
    return decoded.map(
      (k, v) => MapEntry(k.toString(), Hlc.parse(v.toString())),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'templateId': templateId,
      'title': title,
      'subtitle': subTitle,
      'icon': iconCodePoint,
      'category': category.name,
      'fields': fields.map((field) => field.toJson()).toList(),
      'syncStatus': syncStatus.name,
      'hlc': hlc?.toString(),
      'fieldHlc': fieldHlc.map((k, v) => MapEntry(k, v.toString())),
      'serverVersion': serverVersion,
      'isDeleted': isDeleted,
      'deleteHlc': deleteHlc?.toString(),
    };
  }

  AccountTemplate copyWith({
    String? title,
    String? subTitle,
    int? iconCodePoint,
    TemplateCategory? category,
    List<AccountField>? fields,
    bool? isCustom,
    SyncStatus? syncStatus,
    Hlc? hlc,
    Map<String, Hlc>? fieldHlc,
    int? serverVersion,
    bool? isDeleted,
    Hlc? deleteHlc,
  }) {
    return AccountTemplate(
      templateId: templateId,
      title: title ?? this.title,
      subTitle: subTitle ?? this.subTitle,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      category: category ?? this.category,
      fields: fields ?? this.fields,
      isCustom: isCustom ?? this.isCustom,
      syncStatus: syncStatus ?? this.syncStatus,
      hlc: hlc ?? this.hlc,
      fieldHlc: fieldHlc ?? this.fieldHlc,
      serverVersion: serverVersion ?? this.serverVersion,
      isDeleted: isDeleted ?? this.isDeleted,
      deleteHlc: deleteHlc ?? this.deleteHlc,
    );
  }
}

final AccountTemplate websiteTemplate = AccountTemplate(
  templateId: 'generic_info',
  title: '\u7f51\u7ad9\u6a21\u677f',
  subTitle:
      '\u4fdd\u5b58\u7f51\u7ad9\u3001\u767b\u5f55\u8d26\u53f7\u3001\u5bc6\u7801\u548c\u5907\u6ce8',
  iconCodePoint: Icons.language_outlined.codePoint,
  category: TemplateCategory.login,
  fields: [
    AccountField(
      fieldKey: 'website',
      label: '\u7f51\u7ad9',
      description:
          '\u7f51\u7ad9\u540d\u79f0\u6216\u767b\u5f55\u5730\u5740\u3002',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.url,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
        hint: 'https://example.com',
      ),
    ),
    AccountField(
      fieldKey: 'username',
      label: '\u8d26\u53f7',
      description:
          '\u767b\u5f55\u7528\u6237\u540d\u3001\u90ae\u7bb1\u6216\u624b\u673a\u53f7\u3002',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.text,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
        hint: '\u7528\u6237\u540d / \u90ae\u7bb1 / \u624b\u673a\u53f7',
      ),
    ),
    AccountField(
      fieldKey: 'password',
      label: '\u5bc6\u7801',
      description: '\u8be5\u7f51\u7ad9\u7684\u767b\u5f55\u5bc6\u7801\u3002',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.password,
        isRequired: true,
        isSecret: true,
        hint: '\u8f93\u5165\u6216\u751f\u6210\u5bc6\u7801',
      ),
    ),
    AccountField(
      fieldKey: 'totp',
      label: '2FA',
      description:
          '\u5173\u8054\u72ec\u7acb\u7684 2FA/TOTP \u51ed\u636e\uff0c\u4e0d\u5728\u8d26\u6237\u5b57\u6bb5\u4e2d\u4fdd\u5b58\u52a8\u6001\u7801\u5bc6\u94a5\u3002',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.custom,
        isReference: true,
        isCopyable: false,
        hint: '\u9009\u62e9\u6216\u65b0\u5efa 2FA',
      ),
    ),
    AccountField(
      fieldKey: 'notes',
      label: '\u5907\u6ce8',
      description:
          '\u989d\u5916\u8bf4\u660e\u3001\u6062\u590d\u63d0\u793a\u6216\u5b89\u5168\u95ee\u9898\u7b49\u4fe1\u606f\u3002',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.text,
        hint: '\u53ef\u9009',
      ),
    ),
  ],
);

final List<AccountTemplate> basicAccountTemplates = [websiteTemplate];
