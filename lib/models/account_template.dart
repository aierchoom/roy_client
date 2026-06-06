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
  templateRef,
  subForm,
  longText,
  list,
  unknown,
}

enum TimeFieldFormat { full, date, monthYear, time }

enum TemplateCategory { access, secret, payment, identity, license, custom }

AccountFieldType fieldTypeFromString(String value) {
  return AccountFieldType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => AccountFieldType.unknown,
  );
}

TemplateCategory templateCategoryFromString(String? value) {
  switch (value) {
    case 'login':
    case 'work':
    case 'shopping':
      return TemplateCategory.access;
    case 'contact':
      return TemplateCategory.identity;
    case 'finance':
      return TemplateCategory.payment;
    case 'note':
      return TemplateCategory.secret;
  }

  return TemplateCategory.values.firstWhere(
    (category) => category.name == value,
    orElse: () => TemplateCategory.custom,
  );
}

IconData templateCategoryIcon(TemplateCategory category) {
  switch (category) {
    case TemplateCategory.access:
      return Icons.lock_person_outlined;
    case TemplateCategory.secret:
      return Icons.shield_outlined;
    case TemplateCategory.payment:
      return Icons.credit_card_outlined;
    case TemplateCategory.identity:
      return Icons.badge_outlined;
    case TemplateCategory.license:
      return Icons.key_outlined;
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

  final normalizedTitle = (title ?? '').toLowerCase();
  if (normalizedTitle.contains('note') ||
      normalizedTitle.contains('mnemonic') ||
      normalizedTitle.contains('seed') ||
      normalizedTitle.contains('recovery') ||
      normalizedTitle.contains('private key') ||
      normalizedTitle.contains('笔记') ||
      normalizedTitle.contains('助记词') ||
      normalizedTitle.contains('恢复码') ||
      normalizedTitle.contains('私钥')) {
    return TemplateCategory.secret;
  }
  if (normalizedTitle.contains('bank') ||
      normalizedTitle.contains('card') ||
      normalizedTitle.contains('payment') ||
      normalizedTitle.contains('wallet') ||
      normalizedTitle.contains('银行卡') ||
      normalizedTitle.contains('信用卡') ||
      normalizedTitle.contains('支付')) {
    return TemplateCategory.payment;
  }
  if (normalizedTitle.contains('id') ||
      normalizedTitle.contains('passport') ||
      normalizedTitle.contains('identity') ||
      normalizedTitle.contains('license plate') ||
      normalizedTitle.contains('证件') ||
      normalizedTitle.contains('身份') ||
      normalizedTitle.contains('护照')) {
    return TemplateCategory.identity;
  }
  if (normalizedTitle.contains('license') ||
      normalizedTitle.contains('serial') ||
      normalizedTitle.contains('activation') ||
      normalizedTitle.contains('授权') ||
      normalizedTitle.contains('序列号')) {
    return TemplateCategory.license;
  }
  if (normalizedTitle.contains('email') ||
      normalizedTitle.contains('web') ||
      normalizedTitle.contains('website') ||
      normalizedTitle.contains('app') ||
      normalizedTitle.contains('login') ||
      normalizedTitle.contains('api') ||
      normalizedTitle.contains('token') ||
      normalizedTitle.contains('server') ||
      normalizedTitle.contains('ssh') ||
      normalizedTitle.contains('wifi') ||
      normalizedTitle.contains('router') ||
      normalizedTitle.contains('nas') ||
      normalizedTitle.contains('账号') ||
      normalizedTitle.contains('登录') ||
      normalizedTitle.contains('服务') ||
      normalizedTitle.contains('服务器') ||
      normalizedTitle.contains('路由器')) {
    return TemplateCategory.access;
  }

  final sourceFields = fields ?? const <AccountField>[];
  final hasAccessLike = sourceFields.any((field) {
    final normalized = '${field.fieldKey} ${field.label}'.toLowerCase();
    return field.attributes.type == AccountFieldType.email ||
        field.attributes.type == AccountFieldType.url ||
        field.attributes.type == AccountFieldType.password ||
        normalized.contains('username') ||
        normalized.contains('password') ||
        normalized.contains('api') ||
        normalized.contains('token') ||
        normalized.contains('ssh') ||
        normalized.contains('wifi') ||
        normalized.contains('账号') ||
        normalized.contains('密码');
  });
  final hasPaymentLike = sourceFields.any((field) {
    final normalized = '${field.fieldKey} ${field.label}'.toLowerCase();
    return normalized.contains('card') ||
        normalized.contains('cvv') ||
        normalized.contains('bank') ||
        normalized.contains('支付') ||
        normalized.contains('银行卡');
  });
  final hasIdentityLike = sourceFields.any((field) {
    final normalized = '${field.fieldKey} ${field.label}'.toLowerCase();
    return normalized.contains('passport') ||
        normalized.contains('identity') ||
        normalized.contains('id_number') ||
        normalized.contains('证件') ||
        normalized.contains('身份证');
  });
  final hasLicenseLike = sourceFields.any((field) {
    final normalized = '${field.fieldKey} ${field.label}'.toLowerCase();
    return normalized.contains('license') ||
        normalized.contains('serial') ||
        normalized.contains('activation') ||
        normalized.contains('授权') ||
        normalized.contains('序列号');
  });
  final hasSecretLike = sourceFields.any(
    (field) =>
        field.attributes.isSecret &&
        (field.attributes.type == AccountFieldType.longText ||
            field.attributes.type == AccountFieldType.list),
  );
  if (hasPaymentLike) return TemplateCategory.payment;
  if (hasIdentityLike) return TemplateCategory.identity;
  if (hasLicenseLike) return TemplateCategory.license;
  if (hasAccessLike) return TemplateCategory.access;
  if (hasSecretLike) return TemplateCategory.secret;

  if (iconCodePoint == Icons.credit_card_outlined.codePoint) {
    return TemplateCategory.payment;
  }
  if (iconCodePoint == Icons.badge_outlined.codePoint) {
    return TemplateCategory.identity;
  }
  if (iconCodePoint == Icons.key_outlined.codePoint) {
    return TemplateCategory.license;
  }
  if (iconCodePoint == Icons.note_outlined.codePoint ||
      iconCodePoint == Icons.notes_outlined.codePoint ||
      iconCodePoint == Icons.article_outlined.codePoint ||
      iconCodePoint == Icons.vpn_key_outlined.codePoint) {
    return TemplateCategory.secret;
  }
  if (iconCodePoint == Icons.email_outlined.codePoint ||
      iconCodePoint == Icons.language_outlined.codePoint ||
      iconCodePoint == Icons.lock_outline.codePoint ||
      iconCodePoint == Icons.code_outlined.codePoint ||
      iconCodePoint == Icons.terminal_outlined.codePoint ||
      iconCodePoint == Icons.dns_outlined.codePoint ||
      iconCodePoint == Icons.wifi_outlined.codePoint ||
      iconCodePoint == Icons.computer_outlined.codePoint) {
    return TemplateCategory.access;
  }

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
  final String? targetTemplateId;
  final String? subTemplateId;
  final int? maxSubItems;

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
    this.targetTemplateId,
    this.subTemplateId,
    this.maxSubItems,
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
      targetTemplateId: json['targetTemplateId'] as String?,
      subTemplateId: json['subTemplateId'] as String?,
      maxSubItems: json['maxSubItems'] as int?,
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
      if (targetTemplateId != null) 'targetTemplateId': targetTemplateId,
      if (subTemplateId != null) 'subTemplateId': subTemplateId,
      if (maxSubItems != null) 'maxSubItems': maxSubItems,
    };
  }

  AccountFieldAttributes copyWith({
    AccountFieldType? type,
    bool? isPrimary,
    bool? isRequired,
    bool? isSecret,
    bool? isEditable,
    bool? isSearchable,
    bool? isCopyable,
    int? maxLength,
    int? minLength,
    String? regex,
    String? hint,
    bool? isReference,
    TimeFieldFormat? timeFormat,
    String? targetTemplateId,
    String? subTemplateId,
    int? maxSubItems,
  }) {
    return AccountFieldAttributes(
      type: type ?? this.type,
      isPrimary: isPrimary ?? this.isPrimary,
      isRequired: isRequired ?? this.isRequired,
      isSecret: isSecret ?? this.isSecret,
      isEditable: isEditable ?? this.isEditable,
      isSearchable: isSearchable ?? this.isSearchable,
      isCopyable: isCopyable ?? this.isCopyable,
      maxLength: maxLength ?? this.maxLength,
      minLength: minLength ?? this.minLength,
      regex: regex ?? this.regex,
      hint: hint ?? this.hint,
      isReference: isReference ?? this.isReference,
      timeFormat: timeFormat ?? this.timeFormat,
      targetTemplateId: targetTemplateId ?? this.targetTemplateId,
      subTemplateId: subTemplateId ?? this.subTemplateId,
      maxSubItems: maxSubItems ?? this.maxSubItems,
    );
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
  final List<String> parentTemplateIds;
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
    this.parentTemplateIds = const [],
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
      parentTemplateIds: (json['parentTemplateIds'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
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
      isDeleted: parseBoolValue(json['isDeleted']),
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
      if (parentTemplateIds.isNotEmpty)
        'parentTemplateIds': parentTemplateIds,
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
      if (parentTemplateIds.isNotEmpty)
        'parentTemplateIds': parentTemplateIds,
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
    List<String>? parentTemplateIds,
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
      parentTemplateIds: parentTemplateIds ?? this.parentTemplateIds,
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

AccountField _builtinField({
  required String fieldKey,
  required String label,
  String? description,
  required AccountFieldAttributes attributes,
  required int order,
}) {
  return AccountField(
    fieldKey: fieldKey,
    label: label,
    description: description,
    attributes: attributes,
    order: order,
    labelHlc: _builtinZeroHlc,
    descriptionHlc: _builtinZeroHlc,
    attributesHlc: _builtinZeroHlc,
    orderHlc: _builtinZeroHlc,
  );
}

final AccountTemplate websiteTemplate = AccountTemplate(
  templateId: 'builtin_generic_info',
  version: 1,
  title: '登录凭据',
  subTitle: '网站、App 或服务的账号、密码和 2FA',
  iconCodePoint: Icons.language_outlined.codePoint,
  category: TemplateCategory.access,
  fields: [
    _builtinField(
      fieldKey: 'website',
      label: '站点/服务',
      description: '网站名称、App 名称或登录地址。',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.url,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
        hint: 'https://example.com',
      ),
      order: 0,
    ),
    _builtinField(
      fieldKey: 'username',
      label: '账号',
      description: '登录用户名、邮箱或手机号。',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
        hint: '用户名 / 邮箱 / 手机号',
      ),
      order: 1,
    ),
    _builtinField(
      fieldKey: 'password',
      label: '密码',
      description: '该站点或服务的登录密码。',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.password,
        isRequired: true,
        isSecret: true,
        hint: '输入或生成密码',
      ),
      order: 2,
    ),
    _builtinField(
      fieldKey: 'totp',
      label: '2FA',
      description: '关联独立的 2FA/TOTP 凭据，不在账户字段中保存动态码密钥。',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.custom,
        isReference: true,
        isCopyable: false,
        hint: '选择或新建 2FA',
      ),
      order: 3,
    ),
    _builtinField(
      fieldKey: 'notes',
      label: '备注',
      description: '额外说明、恢复提示或安全问题等信息。',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        hint: '可选',
      ),
      order: 4,
    ),
  ],
);

final AccountTemplate secureNoteGenericTemplate = AccountTemplate(
  templateId: 'builtin_secure_note',
  version: 1,
  title: '通用安全笔记',
  subTitle: '存储恢复提示、私钥片段和其他敏感文本',
  iconCodePoint: Icons.note_outlined.codePoint,
  category: TemplateCategory.secret,
  fields: [
    _builtinField(
      fieldKey: 'content',
      label: '内容',
      description: '多行加密文本，默认折叠显示。',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.longText,
        isRequired: true,
        isSecret: true,
        hint: '粘贴或输入敏感内容...',
      ),
      order: 0,
    ),
  ],
);

final AccountTemplate secureNoteMnemonicTemplate = AccountTemplate(
  templateId: 'builtin_mnemonic',
  version: 1,
  title: '助记词',
  subTitle: '加密存储 12/24 个恢复词',
  iconCodePoint: Icons.vpn_key_outlined.codePoint,
  category: TemplateCategory.secret,
  fields: [
    _builtinField(
      fieldKey: 'mnemonic_words',
      label: '助记词',
      description: '支持整段粘贴自动分词，默认折叠隐藏。',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.list,
        isRequired: true,
        isSecret: true,
        hint:
            'abandon ability able about above absent absorb abstract absurd abuse access accident',
      ),
      order: 0,
    ),
  ],
);

final AccountTemplate apiServiceTemplate = AccountTemplate(
  templateId: 'builtin_api_service',
  version: 1,
  title: 'API 凭据',
  subTitle: '存储 API Key、Token 和端点信息',
  iconCodePoint: Icons.code_outlined.codePoint,
  category: TemplateCategory.access,
  fields: [
    _builtinField(
      fieldKey: 'service_name',
      label: '服务名称',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
        hint: 'OpenAI / Stripe / AWS',
      ),
      order: 0,
    ),
    _builtinField(
      fieldKey: 'api_keys',
      label: 'API Key',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.list,
        isSecret: true,
        hint: 'sk-proj-xxxxx',
      ),
      order: 1,
    ),
    _builtinField(
      fieldKey: 'endpoint',
      label: 'API 端点',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.url,
        hint: 'https://api.example.com/v1',
      ),
      order: 2,
    ),
  ],
);

final AccountTemplate paymentCardTemplate = AccountTemplate(
  templateId: 'builtin_payment_card',
  version: 1,
  title: '银行卡',
  subTitle: '银行卡、信用卡和支付卡信息',
  iconCodePoint: Icons.credit_card_outlined.codePoint,
  category: TemplateCategory.payment,
  fields: [
    _builtinField(
      fieldKey: 'bank_name',
      label: '银行名称',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
        hint: '中国工商银行',
      ),
      order: 0,
    ),
    _builtinField(
      fieldKey: 'card_number',
      label: '卡号',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        isRequired: true,
        isSearchable: true,
        hint: '6222 **** **** 8888',
      ),
      order: 1,
    ),
    _builtinField(
      fieldKey: 'cvv',
      label: 'CVV',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.password,
        isSecret: true,
        hint: '卡背后三位',
      ),
      order: 2,
    ),
    _builtinField(
      fieldKey: 'expiry_date',
      label: '有效期',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.time,
        timeFormat: TimeFieldFormat.monthYear,
        hint: 'MM/YY',
      ),
      order: 3,
    ),
    _builtinField(
      fieldKey: 'notes',
      label: '备注',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        hint: '可选',
      ),
      order: 4,
    ),
  ],
);

final AccountTemplate identityDocumentTemplate = AccountTemplate(
  templateId: 'builtin_identity_document',
  version: 1,
  title: '身份证件',
  subTitle: '身份证、护照、驾照等证件信息',
  iconCodePoint: Icons.badge_outlined.codePoint,
  category: TemplateCategory.identity,
  fields: [
    _builtinField(
      fieldKey: 'full_name',
      label: '姓名',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
      ),
      order: 0,
    ),
    _builtinField(
      fieldKey: 'id_number',
      label: '证件号码',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        isRequired: true,
        isSecret: true,
        hint: '110101********0001',
      ),
      order: 1,
    ),
    _builtinField(
      fieldKey: 'issuing_authority',
      label: '签发机关',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        hint: '某市公安局',
      ),
      order: 2,
    ),
    _builtinField(
      fieldKey: 'valid_until',
      label: '有效期限',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.time,
        timeFormat: TimeFieldFormat.date,
      ),
      order: 3,
    ),
    _builtinField(
      fieldKey: 'notes',
      label: '备注',
      attributes: const AccountFieldAttributes(type: AccountFieldType.text),
      order: 4,
    ),
  ],
);

final AccountTemplate wifiCredentialTemplate = AccountTemplate(
  templateId: 'builtin_wifi',
  version: 1,
  title: 'WiFi / 网络',
  subTitle: '家庭、办公网络和路由器登录信息',
  iconCodePoint: Icons.wifi_outlined.codePoint,
  category: TemplateCategory.access,
  fields: [
    _builtinField(
      fieldKey: 'ssid',
      label: '网络名称',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
        hint: 'Home_WiFi_5G',
      ),
      order: 0,
    ),
    _builtinField(
      fieldKey: 'wifi_password',
      label: 'WiFi 密码',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.password,
        isSecret: true,
        hint: 'WPA/WPA2 密码',
      ),
      order: 1,
    ),
    _builtinField(
      fieldKey: 'admin_url',
      label: '管理地址',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.url,
        hint: 'http://192.168.1.1',
      ),
      order: 2,
    ),
    _builtinField(
      fieldKey: 'admin_username',
      label: '管理账号',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        hint: 'admin',
      ),
      order: 3,
    ),
    _builtinField(
      fieldKey: 'admin_password',
      label: '管理密码',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.password,
        isSecret: true,
      ),
      order: 4,
    ),
  ],
);

final AccountTemplate serverCredentialTemplate = AccountTemplate(
  templateId: 'builtin_server_ssh',
  version: 1,
  title: '服务器 / SSH',
  subTitle: '服务器地址、登录用户、端口和 SSH 密钥',
  iconCodePoint: Icons.dns_outlined.codePoint,
  category: TemplateCategory.access,
  fields: [
    _builtinField(
      fieldKey: 'host',
      label: '主机地址',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.url,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
        hint: '192.168.1.100 或 domain.com',
      ),
      order: 0,
    ),
    _builtinField(
      fieldKey: 'ssh_user',
      label: '用户名',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        isRequired: true,
        hint: 'root',
      ),
      order: 1,
    ),
    _builtinField(
      fieldKey: 'ssh_port',
      label: '端口',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.number,
        hint: '22',
      ),
      order: 2,
    ),
    _builtinField(
      fieldKey: 'ssh_key',
      label: 'SSH 密钥',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.longText,
        isSecret: true,
        hint: '-----BEGIN OPENSSH PRIVATE KEY-----',
      ),
      order: 3,
    ),
    _builtinField(
      fieldKey: 'notes',
      label: '备注',
      attributes: const AccountFieldAttributes(type: AccountFieldType.text),
      order: 4,
    ),
  ],
);

final AccountTemplate softwareLicenseTemplate = AccountTemplate(
  templateId: 'builtin_software_license',
  version: 1,
  title: '软件授权',
  subTitle: '许可证密钥、购买邮箱和到期信息',
  iconCodePoint: Icons.key_outlined.codePoint,
  category: TemplateCategory.license,
  fields: [
    _builtinField(
      fieldKey: 'software_name',
      label: '软件名称',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        isPrimary: true,
        isRequired: true,
        isSearchable: true,
      ),
      order: 0,
    ),
    _builtinField(
      fieldKey: 'license_key',
      label: '授权码',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.text,
        isRequired: true,
        isSecret: true,
        hint: 'XXXX-XXXX-XXXX-XXXX',
      ),
      order: 1,
    ),
    _builtinField(
      fieldKey: 'purchase_email',
      label: '购买邮箱',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.email,
        hint: 'name@example.com',
      ),
      order: 2,
    ),
    _builtinField(
      fieldKey: 'expires_at',
      label: '到期时间',
      attributes: const AccountFieldAttributes(
        type: AccountFieldType.time,
        timeFormat: TimeFieldFormat.date,
      ),
      order: 3,
    ),
  ],
);

final List<AccountTemplate> basicAccountTemplates = [
  websiteTemplate,
  apiServiceTemplate,
  wifiCredentialTemplate,
  serverCredentialTemplate,
  secureNoteGenericTemplate,
  secureNoteMnemonicTemplate,
  paymentCardTemplate,
  identityDocumentTemplate,
  softwareLicenseTemplate,
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
  final importedIds = <String>{};
  for (final raw in rawList) {
    var template = AccountTemplate.fromJson(raw, isCustom: true);
    if (existingIds.contains(template.templateId)) {
      template = template.copyWith(
        templateId:
            'custom_${DateTime.now().millisecondsSinceEpoch}_${results.length}',
      );
    }
    importedIds.add(template.templateId);
    results.add(template);
  }

  // Resolve and clean references: merge existing + imported IDs.
  final allKnownIds = {...existingIds, ...importedIds};

  for (var i = 0; i < results.length; i++) {
    final t = results[i];

    // Strip dangling parent references.
    final validParents = t.parentTemplateIds
        .where((id) => allKnownIds.contains(id))
        .toList();
    if (validParents.length != t.parentTemplateIds.length) {
      results[i] = t.copyWith(parentTemplateIds: validParents);
    }

    // Strip dangling field references.
    final cleanedFields = t.fields.map((f) {
      var attrs = f.attributes;
      if (attrs.targetTemplateId != null &&
          !allKnownIds.contains(attrs.targetTemplateId)) {
        attrs = attrs.copyWith(targetTemplateId: null);
      }
      if (attrs.subTemplateId != null &&
          !allKnownIds.contains(attrs.subTemplateId)) {
        attrs = attrs.copyWith(subTemplateId: null);
      }
      if (identical(attrs, f.attributes)) return f;
      return f.copyWith(attributes: attrs);
    }).toList();
    if (!identical(cleanedFields, t.fields)) {
      results[i] = t.copyWith(fields: cleanedFields);
    }
  }

  return results;
}
