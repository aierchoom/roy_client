import 'package:flutter/material.dart';

import '../models/account_template.dart';

/// A preset group of fields that can be quickly inserted into a template.
class FieldPreset {
  final String id;
  final String name;
  final IconData icon;
  final List<AccountField> fields;

  const FieldPreset({
    required this.id,
    required this.name,
    required this.icon,
    required this.fields,
  });
}

/// Built-in field presets for common account types.
const List<FieldPreset> kFieldPresets = [
  FieldPreset(
    id: 'bank_card',
    name: '\u94f6\u884c\u5361',
    icon: Icons.credit_card_outlined,
    fields: [
      AccountField(
        fieldKey: 'bank_name',
        label: '\u94f6\u884c\u540d\u79f0',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSearchable: true,
          hint: '\u4e2d\u56fd\u5de5\u5546\u94f6\u884c',
        ),
      ),
      AccountField(
        fieldKey: 'card_number',
        label: '\u5361\u53f7',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSearchable: true,
          hint: '6222 **** **** 8888',
        ),
      ),
      AccountField(
        fieldKey: 'cvv',
        label: 'CVV',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.password,
          isSecret: true,
          hint: '\u5361\u80cc\u540e\u4e09\u4f4d',
        ),
      ),
      AccountField(
        fieldKey: 'expiry_date',
        label: '\u6709\u6548\u671f',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.time,
          timeFormat: TimeFieldFormat.monthYear,
          hint: 'MM/YY',
        ),
      ),
    ],
  ),
  FieldPreset(
    id: 'identity',
    name: '\u8eab\u4efd\u8bc1\u4ef6',
    icon: Icons.badge_outlined,
    fields: [
      AccountField(
        fieldKey: 'full_name',
        label: '\u59d3\u540d',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSearchable: true,
        ),
      ),
      AccountField(
        fieldKey: 'id_number',
        label: '\u8bc1\u4ef6\u53f7\u7801',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSecret: true,
          hint: '110101********0001',
        ),
      ),
      AccountField(
        fieldKey: 'issuing_authority',
        label: '\u7b7e\u53d1\u673a\u5173',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          hint: '\u67d0\u5e02\u516c\u5b89\u5c40',
        ),
      ),
      AccountField(
        fieldKey: 'valid_until',
        label: '\u6709\u6548\u671f\u9650',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.time,
          timeFormat: TimeFieldFormat.date,
        ),
      ),
    ],
  ),
  FieldPreset(
    id: 'wifi',
    name: 'WiFi',
    icon: Icons.wifi_outlined,
    fields: [
      AccountField(
        fieldKey: 'ssid',
        label: '\u7f51\u7edc\u540d\u79f0',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSearchable: true,
          hint: 'Home_WiFi_5G',
        ),
      ),
      AccountField(
        fieldKey: 'wifi_password',
        label: 'WiFi \u5bc6\u7801',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.password,
          isSecret: true,
          hint: 'wpa2\u5bc6\u7801',
        ),
      ),
    ],
  ),
  FieldPreset(
    id: 'server_ssh',
    name: '\u670d\u52a1\u5668',
    icon: Icons.dns_outlined,
    fields: [
      AccountField(
        fieldKey: 'host',
        label: '\u4e3b\u673a\u5730\u5740',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.url,
          isRequired: true,
          isSearchable: true,
          hint: '192.168.1.100 \u6216 domain.com',
        ),
      ),
      AccountField(
        fieldKey: 'ssh_user',
        label: '\u7528\u6237\u540d',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          hint: 'root',
        ),
      ),
      AccountField(
        fieldKey: 'ssh_port',
        label: '\u7aef\u53e3',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.number,
          hint: '22',
        ),
      ),
      AccountField(
        fieldKey: 'ssh_key',
        label: 'SSH \u5bc6\u94a5',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.password,
          isSecret: true,
          hint: 'id_rsa \u79c1\u94a5',
        ),
      ),
    ],
  ),
  FieldPreset(
    id: 'social_media',
    name: '\u793e\u4ea4\u5a92\u4f53',
    icon: Icons.chat_bubble_outline,
    fields: [
      AccountField(
        fieldKey: 'platform',
        label: '\u5e73\u53f0\u540d\u79f0',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSearchable: true,
          hint: 'WeChat / Twitter',
        ),
      ),
      AccountField(
        fieldKey: 'social_username',
        label: '\u7528\u6237\u540d',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSearchable: true,
        ),
      ),
      AccountField(
        fieldKey: 'social_password',
        label: '\u5bc6\u7801',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.password,
          isSecret: true,
        ),
      ),
      AccountField(
        fieldKey: 'phone_bound',
        label: '\u7ed1\u5b9a\u624b\u673a',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.phone,
          hint: '138 **** 8888',
        ),
      ),
    ],
  ),
  FieldPreset(
    id: 'license_key',
    name: '\u8f6f\u4ef6\u6388\u6743',
    icon: Icons.key_outlined,
    fields: [
      AccountField(
        fieldKey: 'software_name',
        label: '\u8f6f\u4ef6\u540d\u79f0',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSearchable: true,
        ),
      ),
      AccountField(
        fieldKey: 'license_key',
        label: '\u6388\u6743\u7801',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSecret: true,
          hint: 'XXXX-XXXX-XXXX-XXXX',
        ),
      ),
      AccountField(
        fieldKey: 'purchase_email',
        label: '\u8d2d\u4e70\u90ae\u7bb1',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.email,
          hint: 'name@example.com',
        ),
      ),
    ],
  ),
];

/// Generates a unique field key that does not conflict with existing keys.
String generateUniqueFieldKey(String baseKey, Set<String> existingKeys) {
  if (!existingKeys.contains(baseKey)) return baseKey;
  var suffix = 2;
  var candidate = '${baseKey}_$suffix';
  while (existingKeys.contains(candidate)) {
    suffix++;
    candidate = '${baseKey}_$suffix';
  }
  return candidate;
}

/// Creates a copy of [preset] fields with unique keys and optional label overrides.
List<AccountField> instantiatePresetFields(
  FieldPreset preset, {
  required Set<String> existingKeys,
}) {
  final result = <AccountField>[];
  final keysSoFar = <String>{};

  for (final field in preset.fields) {
    final uniqueKey = generateUniqueFieldKey(field.fieldKey, {...existingKeys, ...keysSoFar});
    keysSoFar.add(uniqueKey);
    result.add(
      AccountField(
        fieldKey: uniqueKey,
        label: field.label,
        description: field.description,
        attributes: field.attributes,
      ),
    );
  }

  return result;
}
