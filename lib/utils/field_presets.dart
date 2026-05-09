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
    id: 'secure_note',
    name: '安全笔记',
    icon: Icons.note_outlined,
    fields: [
      AccountField(
        fieldKey: 'content',
        label: '内容',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.longText,
          isRequired: true,
          isSecret: true,
          hint: '粘贴或输入敏感内容...',
        ),
      ),
    ],
  ),
  FieldPreset(
    id: 'mnemonic',
    name: '助记词',
    icon: Icons.vpn_key_outlined,
    fields: [
      AccountField(
        fieldKey: 'mnemonic_words',
        label: '助记词',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.list,
          isRequired: true,
          isSecret: true,
          hint:
              'abandon ability able about above absent absorb abstract absurd abuse access accident',
        ),
      ),
    ],
  ),
  FieldPreset(
    id: 'api_keys',
    name: 'API Key',
    icon: Icons.code_outlined,
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
      ),
      AccountField(
        fieldKey: 'api_keys',
        label: 'API Key',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.list,
          isSecret: true,
          hint: 'sk-proj-xxxxx',
        ),
      ),
    ],
  ),
  FieldPreset(
    id: 'bank_card',
    name: '银行卡',
    icon: Icons.credit_card_outlined,
    fields: [
      AccountField(
        fieldKey: 'bank_name',
        label: '银行名称',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSearchable: true,
          hint: '中国工商银行',
        ),
      ),
      AccountField(
        fieldKey: 'card_number',
        label: '卡号',
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
          hint: '卡背后三位',
        ),
      ),
      AccountField(
        fieldKey: 'expiry_date',
        label: '有效期',
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
    name: '身份证件',
    icon: Icons.badge_outlined,
    fields: [
      AccountField(
        fieldKey: 'full_name',
        label: '姓名',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSearchable: true,
        ),
      ),
      AccountField(
        fieldKey: 'id_number',
        label: '证件号码',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSecret: true,
          hint: '110101********0001',
        ),
      ),
      AccountField(
        fieldKey: 'issuing_authority',
        label: '签发机关',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          hint: '某市公安局',
        ),
      ),
      AccountField(
        fieldKey: 'valid_until',
        label: '有效期限',
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
        label: '网络名称',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSearchable: true,
          hint: 'Home_WiFi_5G',
        ),
      ),
      AccountField(
        fieldKey: 'wifi_password',
        label: 'WiFi 密码',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.password,
          isSecret: true,
          hint: 'wpa2密码',
        ),
      ),
    ],
  ),
  FieldPreset(
    id: 'server_ssh',
    name: '服务器',
    icon: Icons.dns_outlined,
    fields: [
      AccountField(
        fieldKey: 'host',
        label: '主机地址',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.url,
          isRequired: true,
          isSearchable: true,
          hint: '192.168.1.100 或 domain.com',
        ),
      ),
      AccountField(
        fieldKey: 'ssh_user',
        label: '用户名',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          hint: 'root',
        ),
      ),
      AccountField(
        fieldKey: 'ssh_port',
        label: '端口',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.number,
          hint: '22',
        ),
      ),
      AccountField(
        fieldKey: 'ssh_key',
        label: 'SSH 密钥',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.password,
          isSecret: true,
          hint: 'id_rsa 私钥',
        ),
      ),
    ],
  ),
  FieldPreset(
    id: 'social_media',
    name: '社交媒体',
    icon: Icons.chat_bubble_outline,
    fields: [
      AccountField(
        fieldKey: 'platform',
        label: '平台名称',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSearchable: true,
          hint: 'WeChat / Twitter',
        ),
      ),
      AccountField(
        fieldKey: 'social_username',
        label: '用户名',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSearchable: true,
        ),
      ),
      AccountField(
        fieldKey: 'social_password',
        label: '密码',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.password,
          isSecret: true,
        ),
      ),
      AccountField(
        fieldKey: 'phone_bound',
        label: '绑定手机',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.phone,
          hint: '138 **** 8888',
        ),
      ),
    ],
  ),
  FieldPreset(
    id: 'license_key',
    name: '软件授权',
    icon: Icons.key_outlined,
    fields: [
      AccountField(
        fieldKey: 'software_name',
        label: '软件名称',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSearchable: true,
        ),
      ),
      AccountField(
        fieldKey: 'license_key',
        label: '授权码',
        attributes: AccountFieldAttributes(
          type: AccountFieldType.text,
          isRequired: true,
          isSecret: true,
          hint: 'XXXX-XXXX-XXXX-XXXX',
        ),
      ),
      AccountField(
        fieldKey: 'purchase_email',
        label: '购买邮箱',
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
    final uniqueKey = generateUniqueFieldKey(field.fieldKey, {
      ...existingKeys,
      ...keysSoFar,
    });
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
