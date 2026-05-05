import 'package:flutter/material.dart';

import '../theme/template_theme.dart';
import 'account_item.dart';
import 'hlc.dart';

export '../theme/template_theme.dart'
    show
        kTemplateIconOptions,
        templateIconFromStorageValue,
        templateIconStorageValue,
        templateCategoryIcon,
        inferTemplateCategory,
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
  totp,
  custom,
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
    orElse: () => AccountFieldType.text,
  );
}

TemplateCategory templateCategoryFromString(String? value) {
  return TemplateCategory.values.firstWhere(
    (category) => category.name == value,
    orElse: () => TemplateCategory.custom,
  );
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
      syncStatus: syncStatusFromJson(
        json['syncStatus'],
        fallback: SyncStatus.synchronized,
      ),
      hlc: json['hlc'] != null ? Hlc.parse(json['hlc'] as String) : null,
      serverVersion: json['serverVersion'] as int? ?? 0,
      isDeleted: json['isDeleted'] == true,
      deleteHlc: json['deleteHlc'] != null
          ? Hlc.parse(json['deleteHlc'] as String)
          : null,
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

final AccountTemplate websiteTemplate = const AccountTemplate(
  templateId: 'generic_info',
  title: '\u7f51\u7ad9\u6a21\u677f',
  subTitle:
      '\u4fdd\u5b58\u7f51\u7ad9\u3001\u767b\u5f55\u8d26\u53f7\u3001\u5bc6\u7801\u548c\u5907\u6ce8',
  icon: Icons.language_outlined,
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
        type: AccountFieldType.totp,
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
