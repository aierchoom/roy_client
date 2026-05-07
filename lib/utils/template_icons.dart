import 'package:flutter/material.dart';

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
  final codePoint = rawValue is int
      ? rawValue
      : (rawValue is String ? int.tryParse(rawValue) : null);
  if (codePoint != null && codePoint > 0) {
    return IconData(codePoint, fontFamily: 'MaterialIcons');
  }
  return null;
}

int? templateIconStorageValue(IconData? icon) {
  return icon?.codePoint;
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
