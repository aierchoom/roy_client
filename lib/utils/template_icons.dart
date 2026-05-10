import 'package:flutter/material.dart';

const List<IconData> kTemplateIconOptions = [
  // General
  Icons.description_outlined,
  Icons.article_outlined,
  Icons.notes_outlined,
  Icons.folder_outlined,
  Icons.folder_copy_outlined,
  Icons.inventory_2_outlined,
  Icons.widgets_outlined,
  // Security / Login
  Icons.lock_outline,
  Icons.lock_person_outlined,
  Icons.password_outlined,
  Icons.fingerprint_outlined,
  Icons.vpn_key_outlined,
  Icons.shield_outlined,
  Icons.verified_user_outlined,
  // Payment / Finance
  Icons.credit_card_outlined,
  Icons.payment_outlined,
  Icons.account_balance_outlined,
  Icons.account_balance_wallet_outlined,
  Icons.savings_outlined,
  // Communication
  Icons.email_outlined,
  Icons.phone_outlined,
  Icons.contact_mail_outlined,
  Icons.chat_bubble_outline,
  // Web / Service
  Icons.language_outlined,
  Icons.link_outlined,
  Icons.cloud_outlined,
  Icons.computer_outlined,
  Icons.code_outlined,
  Icons.terminal_outlined,
  // Shopping
  Icons.shopping_bag_outlined,
  Icons.shopping_cart_outlined,
  Icons.local_mall_outlined,
  Icons.storefront_outlined,
  // Work / Business
  Icons.business_center_outlined,
  Icons.apartment_outlined,
  Icons.work_outline,
  Icons.group_outlined,
  // Lifestyle
  Icons.favorite_border,
  Icons.flight_outlined,
  Icons.hotel_outlined,
  Icons.restaurant_outlined,
  Icons.local_cafe_outlined,
  Icons.sports_esports_outlined,
  Icons.games_outlined,
  Icons.movie_outlined,
  Icons.music_note_outlined,
  Icons.photo_camera_outlined,
  // Transport
  Icons.directions_car_outlined,
  Icons.train_outlined,
  Icons.electric_bike_outlined,
  // Education
  Icons.school_outlined,
  Icons.book_outlined,
  Icons.menu_book_outlined,
];

IconData? templateIconFromStorageValue(Object? rawValue) {
  final codePoint = rawValue is int
      ? rawValue
      : (rawValue is String ? int.tryParse(rawValue) : null);
  if (codePoint == null || codePoint <= 0) return null;
  for (final icon in kTemplateIconOptions) {
    if (icon.codePoint == codePoint) return icon;
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
