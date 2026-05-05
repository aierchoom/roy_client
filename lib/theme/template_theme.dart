import 'package:flutter/material.dart';

import '../models/account_template.dart';

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
    case 'generic_info':
      return TemplateCategory.custom;
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

IconData iconForBuiltinTemplate(String id) {
  switch (id) {
    case 'generic_info':
      return Icons.language_outlined;
    default:
      return Icons.description_outlined;
  }
}
