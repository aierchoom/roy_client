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
  longText,
  list,
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
  note,
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
      return Icons.lock_person_outlined;
    case TemplateCategory.payment:
      return Icons.credit_card_outlined;
    case TemplateCategory.contact:
      return Icons.contact_mail_outlined;
    case TemplateCategory.identity:
      return Icons.badge_outlined;
    case TemplateCategory.work:
      return Icons.work_outline;
    case TemplateCategory.shopping:
      return Icons.shopping_bag_outlined;
    case TemplateCategory.finance:
      return Icons.account_balance_outlined;
    case TemplateCategory.note:
      return Icons.sticky_note_2_outlined;
    case TemplateCategory.custom:
      return Icons.widgets_outlined;
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
    case 'builtin_secure_note':
    case 'builtin_mnemonic':
    case 'builtin_api_service':
      return TemplateCategory.note;
  }

  if (iconCodePoint == Icons.credit_card_outlined.codePoint) {
    return TemplateCategory.payment;
  }
  if (iconCodePoint == Icons.email_outlined.codePoint ||
      iconCodePoint == Icons.language_outlined.codePoint ||
      iconCodePoint == Icons.lock_outline.codePoint ||
      iconCodePoint == Icons.vpn_key_outlined.codePoint) {
    return TemplateCategory.login;
  }
  if (iconCodePoint == Icons.phone_outlined.codePoint) {
    return TemplateCategory.contact;
  }
  if (iconCodePoint == Icons.business_center_outlined.codePoint ||
      iconCodePoint == Icons.apartment_outlined.codePoint) {
    return TemplateCategory.work;
  }
  if (iconCodePoint == Icons.shopping_bag_outlined.codePoint) {
    return TemplateCategory.shopping;
  }

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
  if (normalizedTitle.contains('note') ||
      normalizedTitle.contains('mnemonic') ||
      normalizedTitle.contains('助记词') ||
      normalizedTitle.contains('笔记') ||
      normalizedTitle.contains('密钥') ||
      normalizedTitle.contains('api key') ||
      normalizedTitle.contains('私钥')) {
    return TemplateCategory.note;
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
  final hasNoteLike = sourceFields.any((field) {
    return field.attributes.type == AccountFieldType.longText ||
        field.attributes.type == AccountFieldType.list;
  });

  if (hasPaymentLike) return TemplateCategory.payment;
  if (hasPhoneLike) return TemplateCategory.contact;
  if (hasNoteLike) return TemplateCategory.note;
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
  final int order;
  final Hlc labelHlc;
  final Hlc descriptionHlc;
  final Hlc attributesHlc;
  final Hlc orderHlc;

  const AccountField({
    required this.fieldKey,
    required this.label,
    this.description,
    required this.attributes,
    this.order = 0,
    this.labelHlc = const Hlc(0, 0, 'local'),
    this.descriptionHlc = const Hlc(0, 0, 'local'),
    this.attributesHlc = const Hlc(0, 0, 'local'),
    this.orderHlc = const Hlc(0, 0, 'local'),
  });

  factory AccountField.fromJson(Map<String, dynamic> json) {
    return AccountField(
      fieldKey: json['fieldKey'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String?,
      attributes: AccountFieldAttributes.fromJson(
        (json['attributes'] as Map<String, dynamic>?) ?? {},
      ),
      order: json['order'] as int? ?? 0,
      labelHlc: json['labelHlc'] != null
          ? Hlc.parse(json['labelHlc'] as String)
          : Hlc.zero('local'),
      descriptionHlc: json['descriptionHlc'] != null
          ? Hlc.parse(json['descriptionHlc'] as String)
          : Hlc.zero('local'),
      attributesHlc: json['attributesHlc'] != null
          ? Hlc.parse(json['attributesHlc'] as String)
          : Hlc.zero('local'),
      orderHlc: json['orderHlc'] != null
          ? Hlc.parse(json['orderHlc'] as String)
          : Hlc.zero('local'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fieldKey': fieldKey,
      'label': label,
      'description': description,
      'attributes': attributes.toJson(),
      'order': order,
      'labelHlc': labelHlc.toString(),
      'descriptionHlc': descriptionHlc.toString(),
      'attributesHlc': attributesHlc.toString(),
      'orderHlc': orderHlc.toString(),
    };
  }

  Map<String, dynamic> toExportJson() {
    return {
      'fieldKey': fieldKey,
      'label': label,
      'description': description,
      'attributes': attributes.toJson(),
      'order': order,
    };
  }

  AccountField copyWith({
    String? fieldKey,
    String? label,
    String? description,
    AccountFieldAttributes? attributes,
    int? order,
    Hlc? labelHlc,
    Hlc? descriptionHlc,
    Hlc? attributesHlc,
    Hlc? orderHlc,
  }) {
    return AccountField(
      fieldKey: fieldKey ?? this.fieldKey,
      label: label ?? this.label,
      description: description ?? this.description,
      attributes: attributes ?? this.attributes,
      order: order ?? this.order,
      labelHlc: labelHlc ?? this.labelHlc,
      descriptionHlc: descriptionHlc ?? this.descriptionHlc,
      attributesHlc: attributesHlc ?? this.attributesHlc,
      orderHlc: orderHlc ?? this.orderHlc,
    );
  }
}

class AccountTemplate {
  final String templateId;
  final int version;
  final String title;
  final String subTitle;
  final int? iconCodePoint;
  final TemplateCategory category;
  final List<AccountField> fields;
  final bool isCustom;
  final int? createdAt;
  final int? modifiedAt;
  final String? lastEditedBy;
  final int? lastEditedAt;

  final SyncStatus syncStatus;
  final Hlc? hlc;
  final int serverVersion;
  final bool isDeleted;
  final Hlc? deleteHlc;

  const AccountTemplate({
    required this.templateId,
    this.version = 1,
    required this.title,
    required this.subTitle,
    this.iconCodePoint,
    required this.category,
    required this.fields,
    this.isCustom = false,
    this.createdAt,
    this.modifiedAt,
    this.lastEditedBy,
    this.lastEditedAt,
    this.syncStatus = SyncStatus.pendingPush,
    this.hlc,
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
      version: json['version'] as int? ?? 1,
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
      createdAt: json['createdAt'] as int?,
      modifiedAt: json['modifiedAt'] as int?,
      lastEditedBy: json['lastEditedBy'] as String?,
      lastEditedAt: json['lastEditedAt'] as int?,
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
      'version': version,
      'title': title,
      'subtitle': subTitle,
      'icon': iconCodePoint,
      'category': category.name,
      'fields': fields.map((field) => field.toJson()).toList(),
      'createdAt': createdAt,
      'modifiedAt': modifiedAt,
      'lastEditedBy': lastEditedBy,
      'lastEditedAt': lastEditedAt,
      'syncStatus': syncStatus.name,
      'hlc': hlc?.toString(),
      'serverVersion': serverVersion,
      'isDeleted': isDeleted,
      'deleteHlc': deleteHlc?.toString(),
    };
  }

  Map<String, dynamic> toExportJson() {
    return {
      'templateId': templateId,
      'version': version,
      'title': title,
      'subtitle': subTitle,
      'icon': iconCodePoint,
      'category': category.name,
      'fields': fields.map((f) => f.toExportJson()).toList(),
    };
  }

  AccountTemplate copyWith({
    String? templateId,
    int? version,
    String? title,
    String? subTitle,
    int? iconCodePoint,
    TemplateCategory? category,
    List<AccountField>? fields,
    bool? isCustom,
    int? createdAt,
    int? modifiedAt,
    String? lastEditedBy,
    int? lastEditedAt,
    SyncStatus? syncStatus,
    Hlc? hlc,
    int? serverVersion,
    bool? isDeleted,
    Hlc? deleteHlc,
  }) {
    return AccountTemplate(
      templateId: templateId ?? this.templateId,
      version: version ?? this.version,
      title: title ?? this.title,
      subTitle: subTitle ?? this.subTitle,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      category: category ?? this.category,
      fields: fields ?? this.fields,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      hlc: hlc ?? this.hlc,
      serverVersion: serverVersion ?? this.serverVersion,
      isDeleted: isDeleted ?? this.isDeleted,
      deleteHlc: deleteHlc ?? this.deleteHlc,
    );
  }
}

final _builtinZeroHlc = Hlc.zero('builtin');

final AccountTemplate secureNoteGenericTemplate = AccountTemplate(
  templateId: 'builtin_secure_note',
  version: 1,
  title: '通用安全笔记',
  subTitle:
      '存储助记词、API Key、私钥等敏感文本',
  iconCodePoint: Icons.note_outlined.codePoint,
  category: TemplateCategory.note,
  fields: [
    AccountField(
      fieldKey: 'content',
      label: '内容',
      description:
          '多行加密文本，默认折叠显示。',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.longText,
        isRequired: true,
        isSecret: true,
        hint: '粘贴或输入敏感内容...',
      ),
      order: 0,
      labelHlc: _builtinZeroHlc,
      descriptionHlc: _builtinZeroHlc,
      attributesHlc: _builtinZeroHlc,
      orderHlc: _builtinZeroHlc,
    ),
  ],
);

final AccountTemplate secureNoteMnemonicTemplate = AccountTemplate(
  templateId: 'builtin_mnemonic',
  version: 1,
  title: '助记词',
  subTitle: '加密存储 12/24 个孝复词',
  iconCodePoint: Icons.vpn_key_outlined.codePoint,
  category: TemplateCategory.note,
  fields: [
    AccountField(
      fieldKey: 'mnemonic_words',
      label: '助记词',
      description:
          '支持整段粘贴自动分词，默认折叠隐藏。',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.list,
        isRequired: true,
        isSecret: true,
        hint:
            'abandon ability able about above absent absorb abstract absurd abuse access accident',
      ),
      order: 0,
      labelHlc: _builtinZeroHlc,
      descriptionHlc: _builtinZeroHlc,
      attributesHlc: _builtinZeroHlc,
      orderHlc: _builtinZeroHlc,
    ),
  ],
);

final AccountTemplate apiServiceTemplate = AccountTemplate(
  templateId: 'builtin_api_service',
  version: 1,
  title: 'API 服务',
  subTitle: '存储 API Key、Token 和端点信息',
  iconCodePoint: Icons.code_outlined.codePoint,
  category: TemplateCategory.note,
  fields: [
    AccountField(
      fieldKey: 'service_name',
      label: '服务名称',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.text,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
        hint: 'OpenAI / Stripe / AWS',
      ),
      order: 0,
      labelHlc: _builtinZeroHlc,
      attributesHlc: _builtinZeroHlc,
      orderHlc: _builtinZeroHlc,
    ),
    AccountField(
      fieldKey: 'api_keys',
      label: 'API Key',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.list,
        isSecret: true,
        hint: 'sk-proj-xxxxx',
      ),
      order: 1,
      labelHlc: _builtinZeroHlc,
      attributesHlc: _builtinZeroHlc,
      orderHlc: _builtinZeroHlc,
    ),
    AccountField(
      fieldKey: 'endpoint',
      label: 'API 端点',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.url,
        hint: 'https://api.example.com/v1',
      ),
      order: 2,
      labelHlc: _builtinZeroHlc,
      attributesHlc: _builtinZeroHlc,
      orderHlc: _builtinZeroHlc,
    ),
  ],
);

final AccountTemplate websiteTemplate = AccountTemplate(
  templateId: 'builtin_generic_info',
  version: 1,
  title: '网站模板',
  subTitle:
      '保存网站、登录账号、密码和备注',
  iconCodePoint: Icons.language_outlined.codePoint,
  category: TemplateCategory.login,
  fields: [
    AccountField(
      fieldKey: 'website',
      label: '网站',
      description:
          '网站名称或登录地址。',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.url,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
        hint: 'https://example.com',
      ),
      order: 0,
      labelHlc: _builtinZeroHlc,
      descriptionHlc: _builtinZeroHlc,
      attributesHlc: _builtinZeroHlc,
      orderHlc: _builtinZeroHlc,
    ),
    AccountField(
      fieldKey: 'username',
      label: '账号',
      description:
          '登录用户名、邮箱或手机号。',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.text,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
        hint: '用户名 / 邮箱 / 手机号',
      ),
      order: 1,
      labelHlc: _builtinZeroHlc,
      descriptionHlc: _builtinZeroHlc,
      attributesHlc: _builtinZeroHlc,
      orderHlc: _builtinZeroHlc,
    ),
    AccountField(
      fieldKey: 'password',
      label: '密码',
      description: '该网站的登录密码。',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.password,
        isRequired: true,
        isSecret: true,
        hint: '输入或生成密码',
      ),
      order: 2,
      labelHlc: _builtinZeroHlc,
      descriptionHlc: _builtinZeroHlc,
      attributesHlc: _builtinZeroHlc,
      orderHlc: _builtinZeroHlc,
    ),
    AccountField(
      fieldKey: 'totp',
      label: '2FA',
      description:
          '关联独立的 2FA/TOTP 凭据，不在账户字段中保存动态码密钥。',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.custom,
        isReference: true,
        isCopyable: false,
        hint: '选择或新建 2FA',
      ),
      order: 3,
      labelHlc: _builtinZeroHlc,
      descriptionHlc: _builtinZeroHlc,
      attributesHlc: _builtinZeroHlc,
      orderHlc: _builtinZeroHlc,
    ),
    AccountField(
      fieldKey: 'notes',
      label: '备注',
      description:
          '额外说明、恢复提示或安全问题等信息。',
      attributes: AccountFieldAttributes(
        type: AccountFieldType.text,
        hint: '可选',
      ),
      order: 4,
      labelHlc: _builtinZeroHlc,
      descriptionHlc: _builtinZeroHlc,
      attributesHlc: _builtinZeroHlc,
      orderHlc: _builtinZeroHlc,
    ),
  ],
);

final List<AccountTemplate> basicAccountTemplates = [
  websiteTemplate,
  secureNoteGenericTemplate,
  secureNoteMnemonicTemplate,
  apiServiceTemplate,
];

String encodeTemplateExport(List<AccountTemplate> templates) {
  return jsonEncode({
    'version': 1,
    'templates': templates.map((t) => t.toExportJson()).toList(),
  });
}

List<AccountTemplate> parseTemplateExport(
  String json, {
  required Set<String> existingIds,
}) {
  final trimmed = json.trim();
  final decoded = const JsonDecoder().convert(trimmed);

  List<Map<String, dynamic>> rawList;
  if (decoded is Map<String, dynamic>) {
    if (decoded.containsKey('templates')) {
      rawList = (decoded['templates'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    } else {
      rawList = [decoded];
    }
  } else if (decoded is List<dynamic>) {
    rawList = decoded.cast<Map<String, dynamic>>();
  } else {
    throw FormatException('Unsupported JSON format');
  }

  final results = <AccountTemplate>[];
  for (final raw in rawList) {
    var template = AccountTemplate.fromJson(raw, isCustom: true);
    if (existingIds.contains(template.templateId)) {
      template = template.copyWith(
        templateId: 'custom_${DateTime.now().millisecondsSinceEpoch}_${results.length}',
      );
    }
    results.add(template);
  }
  return results;
}
