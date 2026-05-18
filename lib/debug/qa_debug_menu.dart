import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_text_extension.dart';

import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/hlc.dart';
import '../models/totp_credential.dart';
import '../services/service_manager.dart';
import '../services/totp_service.dart';
import '../theme/app_design_tokens.dart';

// ---------------------------------------------------------------------------
// QA Debug Menu — 运行时数据注入工具
// ---------------------------------------------------------------------------
// 仅在 kDebugMode 下显示。
// ---------------------------------------------------------------------------

class QaDebugMenu extends StatelessWidget {
  const QaDebugMenu({super.key});

  static Future<void> show(BuildContext context) async {
    if (!kDebugMode) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const QaDebugMenu(),
    );
  }

  /// 快捷注入 N 个随机账户。
  static Future<void> injectRandomAccounts(
    BuildContext context,
    int count,
  ) async {
    if (!kDebugMode) return;
    final sm = context.read<ServiceManager>();
    if (!sm.isUnlocked) return;
    for (var i = 0; i < count; i++) {
      await sm.saveAccount(_randomAccount('acc_${_randHex(6)}', i));
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已新增 $count 个账户')));
    }
  }

  /// 快捷清空所有账户。
  static Future<void> clearAllAccounts(BuildContext context) async {
    if (!kDebugMode) return;
    final sm = context.read<ServiceManager>();
    if (!sm.isUnlocked) return;
    final accounts = await sm.storageService.loadAccounts();
    for (final a in accounts) {
      await sm.deleteAccount(a.id);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已清空所有账户')));
    }
  }

  static String _randHex(int length) {
    final random = Random.secure();
    final sb = StringBuffer();
    const chars = '0123456789abcdef';
    for (var i = 0; i < length; i++) {
      sb.write(chars[random.nextInt(16)]);
    }
    return sb.toString();
  }

  /// 根据模板生成一条随机账户数据并保存。
  static Future<void> injectAccountFromTemplate(
    BuildContext context,
    AccountTemplate template,
  ) async {
    if (!kDebugMode) return;
    final sm = context.read<ServiceManager>();
    if (!sm.isUnlocked) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'acc_${_randHex(6)}';
    final data = <String, dynamic>{};
    final dataHlc = <String, Hlc>{};

    for (final field in template.fields) {
      final value = _mockValueForField(field);
      if (value != null) {
        data[field.fieldKey] = value;
        dataHlc[field.fieldKey] = Hlc(now, 0, 'local');
      }
    }

    // 模板如果有预设的 primary 字段，用它生成 name
    final primaryField = template.fields.cast<AccountField?>().firstWhere(
      (f) => f?.attributes.isPrimary ?? false,
      orElse: () => null,
    );
    final name = primaryField != null
        ? '${data[primaryField.fieldKey]} ${template.title}'
        : '${template.title} ${_randHex(4)}';

    final account = AccountItem(
      id: id,
      name: name,
      email: data.containsKey('email')
          ? data['email'] as String
          : 'user${_randHex(4)}@example.com',
      templateId: template.templateId,
      templateVersion: template.version,
      data: Map.unmodifiable(Map<String, dynamic>.from(data)),
      fieldMeta: const {},
      createdAt: now,
      modifiedAt: now,
      nameHlc: Hlc(now, 0, 'local'),
      emailHlc: Hlc(now, 0, 'local'),
      dataHlc: Map.unmodifiable(Map<String, Hlc>.from(dataHlc)),
      syncStatus: SyncStatus.pendingPush,
      serverVersion: 0,
    );

    await sm.saveAccount(account);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已新增: ${account.name}')));
    }
  }

  /// 根据模板批量生成 N 条随机账户数据并保存。
  static Future<void> injectAccountsFromTemplate(
    BuildContext context,
    AccountTemplate template,
    int count,
  ) async {
    if (!kDebugMode) return;
    final sm = context.read<ServiceManager>();
    if (!sm.isUnlocked) return;
    for (var i = 0; i < count; i++) {
      await _injectOneFromTemplate(sm, template);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已新增 $count 个 ${template.title} 账户')),
      );
    }
  }

  static Future<void> _injectOneFromTemplate(
    ServiceManager sm,
    AccountTemplate template,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'acc_${_randHex(6)}';
    final data = <String, dynamic>{};
    final dataHlc = <String, Hlc>{};

    for (final field in template.fields) {
      final value = _mockValueForField(field);
      if (value != null) {
        data[field.fieldKey] = value;
        dataHlc[field.fieldKey] = Hlc(now, 0, 'local');
      }
    }

    final primaryField = template.fields.cast<AccountField?>().firstWhere(
      (f) => f?.attributes.isPrimary ?? false,
      orElse: () => null,
    );
    final name = primaryField != null
        ? '${data[primaryField.fieldKey]} ${template.title}'
        : '${template.title} ${_randHex(4)}';

    final account = AccountItem(
      id: id,
      name: name,
      email: data.containsKey('email')
          ? data['email'] as String
          : 'user${_randHex(4)}@example.com',
      templateId: template.templateId,
      templateVersion: template.version,
      data: Map.unmodifiable(Map<String, dynamic>.from(data)),
      fieldMeta: const {},
      createdAt: now,
      modifiedAt: now,
      nameHlc: Hlc(now, 0, 'local'),
      emailHlc: Hlc(now, 0, 'local'),
      dataHlc: Map.unmodifiable(Map<String, Hlc>.from(dataHlc)),
      syncStatus: SyncStatus.pendingPush,
      serverVersion: 0,
    );

    await sm.saveAccount(account);
  }

  static dynamic _mockValueForField(AccountField field) {
    final type = field.attributes.type;
    switch (type) {
      case AccountFieldType.text:
      case AccountFieldType.custom:
        return 'mock_${_randHex(4)}';
      case AccountFieldType.password:
        return 'Pass${_randHex(6)}!';
      case AccountFieldType.number:
        return '${Random.secure().nextInt(900000) + 100000}';
      case AccountFieldType.email:
        return 'user${_randHex(4)}@example.com';
      case AccountFieldType.phone:
        return '1${Random.secure().nextInt(9) + 1}${Random.secure().nextInt(900000000) + 100000000}';
      case AccountFieldType.url:
        return 'https://${_randHex(6)}.com';
      case AccountFieldType.time:
        final fmt = field.attributes.timeFormat;
        final dt = DateTime.now().subtract(
          Duration(days: Random.secure().nextInt(365)),
        );
        switch (fmt) {
          case TimeFieldFormat.date:
            return '${dt.year}-${_pad(dt.month, 2)}-${_pad(dt.day, 2)}';
          case TimeFieldFormat.monthYear:
            return '${_pad(dt.month, 2)}/${(dt.year % 100).toString().padLeft(2, '0')}';
          case TimeFieldFormat.time:
            return '${_pad(dt.hour, 2)}:${_pad(dt.minute, 2)}';
          default:
            return dt.toIso8601String();
        }
      case AccountFieldType.longText:
        return 'This is a randomly generated long text content for testing purposes. ID: ${_randHex(8)}';
      case AccountFieldType.list:
        return List.generate(3, (_) => 'item_${_randHex(4)}').join(', ');
      case AccountFieldType.accountLink:
        return 'acc_${_randHex(6)}';
      case AccountFieldType.unknown:
        return 'unknown_${_randHex(4)}';
    }
  }

  static AccountItem _randomAccount(String id, int index) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final names = [
      'GitHub',
      'Gmail',
      'Twitter',
      '阿里云',
      'AWS',
      'Stripe',
      'Notion',
      'Figma',
      'Vercel',
      'Cloudflare',
    ];
    final name = names[index % names.length];
    return AccountItem(
      id: id,
      name: '$name ${index + 1}',
      email: 'user${_randHex(4)}@example.com',
      templateId: 'builtin_generic_info',
      templateVersion: 0,
      data: Map.unmodifiable({
        'username': 'user${_randHex(4)}',
        'password': 'pass${_randHex(8)}!',
        'website': 'https://${_randHex(6)}.com',
      }),
      fieldMeta: const {},
      createdAt: now,
      modifiedAt: now,
      nameHlc: Hlc(now, 0, 'local'),
      emailHlc: Hlc(now, 0, 'local'),
      dataHlc: Map.unmodifiable({
        'username': Hlc(now, 0, 'local'),
        'password': Hlc(now, 0, 'local'),
        'website': Hlc(now, 0, 'local'),
      }),
      syncStatus: SyncStatus.pendingPush,
      serverVersion: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sm = context.read<ServiceManager>();
    final isUnlocked = sm.isUnlocked;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bug_report,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'QA Debug Menu',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            if (!isUnlocked)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text('保险库未解锁，请先解锁后再注入数据。'),
              )
            else ...[
              _Section(
                title: 'Mock 场景注入',
                children: [
                  _ActionTile(
                    icon: Icons.person_outline,
                    title: '标准用户场景',
                    subtitle: '6 账户 + 2 模板 + 2 TOTP',
                    onTap: () => _inject(context, _standardUser(sm)),
                  ),
                  _ActionTile(
                    icon: Icons.format_list_bulleted,
                    title: '模板账户场景',
                    subtitle: '9 模板 + 9 账户（覆盖全部预设）',
                    onTap: () => _inject(context, _templateAccounts(sm)),
                  ),
                  _ActionTile(
                    icon: Icons.storage_outlined,
                    title: '大数据量场景',
                    subtitle: '100 账户 + 10 模板 + 20 TOTP',
                    onTap: () => _inject(context, _largeDataset(sm)),
                  ),
                  _ActionTile(
                    icon: Icons.sync_problem_outlined,
                    title: '待同步场景',
                    subtitle: '10 账户 + 10 条待推送变更',
                    onTap: () => _inject(context, _pendingSync(sm)),
                  ),
                ],
              ),
              _Section(
                title: '危险操作',
                children: [
                  _ActionTile(
                    icon: Icons.delete_forever,
                    title: '清空所有数据',
                    subtitle: '删除账户、模板、TOTP（不可逆）',
                    color: Colors.red,
                    onTap: () => _confirmClear(context, sm),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _inject(BuildContext context, Future<void> action) async {
    Navigator.of(context).pop();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action;
      messenger.showSnackBar(const SnackBar(content: Text('数据注入成功')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('注入失败: $e')));
    }
  }

  Future<void> _confirmClear(BuildContext context, ServiceManager sm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('这将删除所有本地数据，包括账户、模板和 TOTP。确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.text('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              ctx.text('清空', 'Clear'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (context.mounted) Navigator.of(context).pop();
      await _clearAll(sm);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('所有数据已清空')));
      }
    }
  }

  // ====== 注入逻辑 ======

  Future<void> _standardUser(ServiceManager sm) async {
    await _clearAll(sm);
    final tplSocial = _template('tpl_social', '社交媒体', [
      _field(
        'platform',
        '平台',
        AccountFieldType.text,
        isPrimary: true,
        isRequired: true,
      ),
      _field('social_username', '用户名', AccountFieldType.text, isRequired: true),
      _field(
        'social_password',
        '密码',
        AccountFieldType.password,
        isSecret: true,
      ),
    ]);
    final tplServer = _template('tpl_server', '服务器', [
      _field(
        'host',
        '主机',
        AccountFieldType.url,
        isPrimary: true,
        isRequired: true,
      ),
      _field('ssh_user', 'SSH用户', AccountFieldType.text, isRequired: true),
      _field('ssh_port', '端口', AccountFieldType.number),
      _field('ssh_key', 'SSH密钥', AccountFieldType.password, isSecret: true),
    ]);
    await sm.saveTemplate(tplSocial);
    await sm.saveTemplate(tplServer);

    await sm.saveAccount(
      _account('acc_github', 'GitHub')
          .withEmail('alice@example.com')
          .withField('username', 'alice_dev')
          .withField('password', 'ghp_xxxxxxxxxxxx')
          .withField('website', 'https://github.com')
          .build(),
    );
    await sm.saveAccount(
      _account('acc_gmail', 'Gmail')
          .withEmail('alice@gmail.com')
          .withField('username', 'alice@gmail.com')
          .withField('password', 'gmail_password_2024')
          .withField('website', 'https://gmail.com')
          .build(),
    );
    await sm.saveAccount(
      _account('acc_bank', '招商银行')
          .withTemplateId('builtin_payment')
          .withField('bankName', '招商银行')
          .withField('cardNumber', '6225 8888 8888 8888')
          .withField('cvv', '888')
          .withField('expiryDate', '08/29')
          .build(),
    );
    await sm.saveAccount(
      _account('acc_note', '助记词备份')
          .withTemplateId('builtin_secure_note')
          .withField(
            'content',
            'abandon ability able about above absent absorb abstract absurd',
          )
          .build(),
    );
    await sm.saveAccount(
      _account('acc_api', 'OpenAI API')
          .withField('service_name', 'OpenAI')
          .withField('api_keys', 'sk-xxxxxxxxxxxxxxxxxxxxxxxx')
          .withField('endpoint', 'https://api.openai.com')
          .build(),
    );
    await sm.saveAccount(
      _account('acc_wifi', '家里WiFi')
          .withField('ssid', 'Home_5G')
          .withField('wifi_password', 'home_wifi_pass_2024')
          .build(),
    );

    await sm.saveTotpCredential(
      _totp('totp_github', 'GitHub')
          .withConfig(
            TotpConfig(
              secret: 'JBSWY3DPEHPK3PXP',
              issuer: 'GitHub',
              account: 'alice',
            ),
          )
          .withLinkedAccountIds(['acc_github'])
          .build(),
    );
    await sm.saveTotpCredential(
      _totp('totp_google', 'Google')
          .withConfig(
            TotpConfig(
              secret: 'JBSWY3DPEHPK3PXP',
              issuer: 'Google',
              account: 'alice@gmail.com',
            ),
          )
          .withLinkedAccountIds(['acc_gmail'])
          .build(),
    );
  }

  Future<void> _templateAccounts(ServiceManager sm) async {
    await _clearAll(sm);
    final templates = <AccountTemplate>[
      _template('tpl_secure_note', '安全笔记', [
        _field('content', '内容', AccountFieldType.longText, isSecret: true),
      ]),
      _template('tpl_mnemonic', '助记词', [
        _field('mnemonic_words', '助记词', AccountFieldType.list, isSecret: true),
      ]),
      _template('tpl_api_keys', 'API Key', [
        _field(
          'service_name',
          '服务名称',
          AccountFieldType.text,
          isPrimary: true,
          isRequired: true,
        ),
        _field('api_keys', 'API Key', AccountFieldType.list, isSecret: true),
      ]),
      _template('tpl_bank_card', '银行卡', [
        _field('bank_name', '银行名称', AccountFieldType.text, isRequired: true),
        _field('card_number', '卡号', AccountFieldType.text, isRequired: true),
        _field('cvv', 'CVV', AccountFieldType.password, isSecret: true),
        _field('expiry_date', '有效期', AccountFieldType.text),
      ]),
      _template('tpl_identity', '身份证件', [
        _field('full_name', '姓名', AccountFieldType.text, isRequired: true),
        _field(
          'id_number',
          '证件号码',
          AccountFieldType.text,
          isRequired: true,
          isSecret: true,
        ),
        _field('issuing_authority', '签发机关', AccountFieldType.text),
        _field('valid_until', '有效期限', AccountFieldType.text),
      ]),
      _template('tpl_wifi', 'WiFi', [
        _field('ssid', '网络名称', AccountFieldType.text, isRequired: true),
        _field(
          'wifi_password',
          'WiFi 密码',
          AccountFieldType.password,
          isSecret: true,
        ),
      ]),
      _template('tpl_server_ssh', '服务器', [
        _field(
          'host',
          '主机地址',
          AccountFieldType.url,
          isPrimary: true,
          isRequired: true,
        ),
        _field('ssh_user', '用户名', AccountFieldType.text, isRequired: true),
        _field('ssh_port', '端口', AccountFieldType.number),
        _field('ssh_key', 'SSH 密钥', AccountFieldType.password, isSecret: true),
      ]),
      _template('tpl_social_media', '社交媒体', [
        _field(
          'platform',
          '平台名称',
          AccountFieldType.text,
          isPrimary: true,
          isRequired: true,
        ),
        _field(
          'social_username',
          '用户名',
          AccountFieldType.text,
          isRequired: true,
        ),
        _field(
          'social_password',
          '密码',
          AccountFieldType.password,
          isSecret: true,
        ),
        _field('phone_bound', '绑定手机', AccountFieldType.phone),
      ]),
      _template('tpl_license_key', '软件授权', [
        _field(
          'software_name',
          '软件名称',
          AccountFieldType.text,
          isRequired: true,
        ),
        _field(
          'license_key',
          '授权码',
          AccountFieldType.text,
          isRequired: true,
          isSecret: true,
        ),
        _field('purchase_email', '购买邮箱', AccountFieldType.email),
      ]),
    ];
    for (final t in templates) {
      await sm.saveTemplate(t);
    }

    await sm.saveAccount(
      _account('acc_secure_note', '路由器配置备份')
          .withTemplateId('tpl_secure_note')
          .withField('content', 'admin / admin\n192.168.1.1')
          .build(),
    );
    await sm.saveAccount(
      _account('acc_mnemonic', 'ETH 钱包助记词')
          .withTemplateId('tpl_mnemonic')
          .withField(
            'mnemonic_words',
            'abandon ability able about above absent absorb abstract absurd abuse access',
          )
          .build(),
    );
    await sm.saveAccount(
      _account('acc_api_keys', 'OpenAI API')
          .withTemplateId('tpl_api_keys')
          .withField('service_name', 'OpenAI')
          .withField('api_keys', 'sk-proj-xxxxxxxxxxxxxxxxxxxxxxxx')
          .build(),
    );
    await sm.saveAccount(
      _account('acc_bank_card', '招商银行信用卡')
          .withTemplateId('tpl_bank_card')
          .withField('bank_name', '招商银行')
          .withField('card_number', '6225 8888 8888 8888')
          .withField('cvv', '888')
          .withField('expiry_date', '08/29')
          .build(),
    );
    await sm.saveAccount(
      _account('acc_identity', '身份证')
          .withTemplateId('tpl_identity')
          .withField('full_name', '张三')
          .withField('id_number', '11010119900101xxxx')
          .withField('issuing_authority', '北京市公安局')
          .withField('valid_until', '2030-01-01')
          .build(),
    );
    await sm.saveAccount(
      _account('acc_wifi', '家里WiFi')
          .withTemplateId('tpl_wifi')
          .withField('ssid', 'Home_5G')
          .withField('wifi_password', 'home_wifi_pass_2024')
          .build(),
    );
    await sm.saveAccount(
      _account('acc_server_ssh', '阿里云 ECS')
          .withTemplateId('tpl_server_ssh')
          .withField('host', '192.168.1.100')
          .withField('ssh_user', 'root')
          .withField('ssh_port', '22')
          .withField('ssh_key', '-----BEGIN OPENSSH PRIVATE KEY-----\n...')
          .build(),
    );
    await sm.saveAccount(
      _account('acc_social_media', 'Twitter')
          .withTemplateId('tpl_social_media')
          .withField('platform', 'Twitter')
          .withField('social_username', '@alice_dev')
          .withField('social_password', 'twitter_pass_2024')
          .withField('phone_bound', '+86 138 **** 8888')
          .build(),
    );
    await sm.saveAccount(
      _account('acc_license_key', 'JetBrains License')
          .withTemplateId('tpl_license_key')
          .withField('software_name', 'IntelliJ IDEA')
          .withField('license_key', 'XXXX-XXXX-XXXX-XXXX')
          .withField('purchase_email', 'alice@example.com')
          .build(),
    );
  }

  Future<void> _largeDataset(ServiceManager sm) async {
    await _clearAll(sm);
    for (var i = 0; i < 10; i++) {
      await sm.saveTemplate(
        _template('tpl_${_pad(i, 3)}', 'Template ${_pad(i + 1, 3)}', [
          _field('field1', 'Field 1', AccountFieldType.text),
          _field(
            'field2',
            'Field 2',
            AccountFieldType.password,
            isSecret: true,
          ),
        ]),
      );
    }
    for (var i = 0; i < 100; i++) {
      await sm.saveAccount(
        _account('acc_${_pad(i, 3)}', 'Account ${_pad(i + 1, 3)}')
            .withEmail('user${_pad(i + 1, 3)}@example.com')
            .withField('username', 'user${_pad(i + 1, 3)}')
            .withField('password', 'pass${_pad(i + 1, 3)}!')
            .withField('website', 'https://site${_pad(i + 1, 3)}.com')
            .build(),
      );
    }
    for (var i = 0; i < 20; i++) {
      await sm.saveTotpCredential(
        _totp('totp_${_pad(i, 3)}', 'Service ${_pad(i + 1, 3)}')
            .withConfig(
              TotpConfig(
                secret: 'JBSWY3DPEHPK3PXP',
                issuer: 'Service ${_pad(i + 1, 3)}',
              ),
            )
            .build(),
      );
    }
  }

  Future<void> _pendingSync(ServiceManager sm) async {
    await _clearAll(sm);
    for (var i = 0; i < 10; i++) {
      await sm.saveAccount(
        _account('acc_${_pad(i, 3)}', 'Pending Account ${_pad(i + 1, 3)}')
            .withEmail('user${_pad(i + 1, 3)}@example.com')
            .withField('username', 'user${_pad(i + 1, 3)}')
            .withField('password', 'pass${_pad(i + 1, 3)}!')
            .withSyncStatus(SyncStatus.pendingPush)
            .build(),
      );
    }
  }

  Future<void> _clearAll(ServiceManager sm) async {
    final accounts = await sm.storageService.loadAccounts();
    for (final a in accounts) {
      await sm.deleteAccount(a.id);
    }
    final templates = await sm.storageService.loadCustomTemplates();
    for (final t in templates) {
      await sm.deleteTemplate(t.templateId);
    }
    final totps = await sm.storageService.loadTotpCredentials();
    for (final t in totps) {
      await sm.deleteTotpCredential(t.id);
    }
  }

  // ====== 快捷构造器 ======

  AccountTemplate _template(
    String id,
    String title,
    List<AccountField> fields,
  ) {
    return AccountTemplate(
      templateId: id,
      version: 1,
      title: title,
      subTitle: '',
      category: TemplateCategory.custom,
      fields: fields,
      isCustom: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  AccountField _field(
    String key,
    String label,
    AccountFieldType type, {
    bool isPrimary = false,
    bool isRequired = false,
    bool isSecret = false,
    bool isSearchable = false,
  }) {
    return AccountField(
      fieldKey: key,
      label: label,
      attributes: AccountFieldAttributes(
        type: type,
        isPrimary: isPrimary,
        isRequired: isRequired,
        isSecret: isSecret,
        isSearchable: isSearchable,
      ),
      order: 0,
    );
  }

  _AccountItemBuilder _account(String id, String name) {
    return _AccountItemBuilder()
      ..id = id
      ..name = name
      ..email = '';
  }

  _TotpBuilder _totp(String id, String label) {
    return _TotpBuilder()
      ..id = id
      ..label = label;
  }

  static String _pad(int n, int width) => n.toString().padLeft(width, '0');
}

// ---------------------------------------------------------------------------
// 流式构造器（最小化内联实现，不依赖 test helpers）
// ---------------------------------------------------------------------------

class _AccountItemBuilder {
  String id = '';
  String name = '';
  String email = '';
  String templateId = 'builtin_generic_info';
  final Map<String, dynamic> data = {};
  SyncStatus syncStatus = SyncStatus.pendingPush;
  int serverVersion = 0;

  _AccountItemBuilder withEmail(String value) {
    email = value;
    return this;
  }

  _AccountItemBuilder withTemplateId(String value) {
    templateId = value;
    return this;
  }

  _AccountItemBuilder withField(String key, dynamic value) {
    data[key] = value;
    return this;
  }

  _AccountItemBuilder withSyncStatus(SyncStatus status) {
    syncStatus = status;
    return this;
  }

  AccountItem build() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return AccountItem(
      id: id,
      name: name,
      email: email,
      templateId: templateId,
      templateVersion: 0,
      data: Map.unmodifiable(Map<String, dynamic>.from(data)),
      fieldMeta: const {},
      createdAt: now,
      modifiedAt: now,
      nameHlc: Hlc(now, 0, 'local'),
      emailHlc: Hlc(now, 0, 'local'),
      dataHlc: Map.unmodifiable(
        data.map((k, _) => MapEntry(k, Hlc(now, 0, 'local'))),
      ),
      syncStatus: syncStatus,
      serverVersion: serverVersion,
    );
  }
}

class _TotpBuilder {
  String id = '';
  String label = '';
  TotpConfig config = const TotpConfig(secret: 'JBSWY3DPEHPK3PXP');
  List<String> linkedAccountIds = [];

  _TotpBuilder withConfig(TotpConfig value) {
    config = value;
    return this;
  }

  _TotpBuilder withLinkedAccountIds(List<String> ids) {
    linkedAccountIds = ids;
    return this;
  }

  TotpCredential build() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return TotpCredential(
      id: id,
      label: label,
      config: config,
      linkedAccountIds: List.unmodifiable(List<String>.from(linkedAccountIds)),
      createdAt: now,
      labelHlc: Hlc(now, 0, 'local'),
      configHlc: Hlc(now, 0, 'local'),
      linksHlc: Hlc(now, 0, 'local'),
    );
  }
}

// ---------------------------------------------------------------------------
// UI 组件
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
