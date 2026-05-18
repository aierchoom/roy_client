// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/app_notification.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/local_sync_change.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/models/vault_health_report.dart';

import 'mock_data_factory.dart';

// ---------------------------------------------------------------------------
// 场景数据包
// ---------------------------------------------------------------------------

/// 一个 Mock 场景包含的全部数据实体。
///
/// 通过 [MockDataFactory.scenario.xxx()] 生成后，可直接注入 FakeStorage
/// 或用于任何测试断言。
class MockScenarioData {
  final List<AccountItem> accounts;
  final List<AccountTemplate> templates;
  final List<TotpCredential> totps;
  final List<LocalSyncChange> syncChanges;
  final List<AppNotification> notifications;
  final VaultHealthReport? healthReport;

  const MockScenarioData({
    this.accounts = const [],
    this.templates = const [],
    this.totps = const [],
    this.syncChanges = const [],
    this.notifications = const [],
    this.healthReport,
  });

  int get totalAccounts => accounts.length;
  int get totalTemplates => templates.length;
  int get totalTotps => totps.length;
  int get pendingSyncCount => syncChanges
      .where((c) => c.status == LocalSyncStatus.pendingReview)
      .length;

  /// 汇总信息，用于调试输出。
  @override
  String toString() {
    return 'MockScenarioData(accounts=$totalAccounts, templates=$totalTemplates, '
        'totps=$totalTotps, pendingSync=$pendingSyncCount, '
        'notifications=${notifications.length})';
  }
}

// ---------------------------------------------------------------------------
// 场景构造器
// ---------------------------------------------------------------------------

/// 预定义 Mock 场景构造器集合。
///
/// 用法：
/// ```dart
/// final data = MockDataFactory.scenario.standardUser();
/// final large = MockDataFactory.scenario.largeDataset(accountCount: 200);
/// ```
class MockScenario {
  MockScenario._();

  // ====== 标准用户场景 ======

  /// 一个典型用户的保险库数据。
  ///
  /// 包含：
  /// - 6 个账户（网站、银行、安全笔记、API、社交媒体、WiFi）
  /// - 2 个自定义模板
  /// - 2 个 TOTP（GitHub + Google）
  /// - 1 条待同步变更
  /// - 0 条通知
  static MockScenarioData standardUser() {
    final accounts = <AccountItem>[
      MockDataFactory.websiteAccount(
        id: 'acc_github',
        name: 'GitHub',
        email: 'alice@example.com',
        username: 'alice_dev',
        password: 'ghp_xxxxxxxxxxxx',
        website: 'https://github.com',
      ),
      MockDataFactory.websiteAccount(
        id: 'acc_gmail',
        name: 'Gmail',
        email: 'alice@gmail.com',
        username: 'alice@gmail.com',
        password: 'gmail_password_2024',
        website: 'https://gmail.com',
      ),
      MockDataFactory.bankAccount(
        id: 'acc_bank',
        name: '招商银行',
        bankName: '招商银行',
        cardNumber: '6225 8888 8888 8888',
        cvv: '888',
        expiryDate: '08/29',
      ),
      MockDataFactory.secureNote(
        id: 'acc_note',
        name: '助记词备份',
        content:
            'abandon ability able about above absent absorb abstract absurd',
      ),
      MockDataFactory.account(id: 'acc_api', name: 'OpenAI API')
          .withField('service_name', 'OpenAI')
          .withField('api_keys', 'sk-xxxxxxxxxxxxxxxxxxxxxxxx')
          .withField('endpoint', 'https://api.openai.com')
          .build(),
      MockDataFactory.account(id: 'acc_wifi', name: '家里WiFi')
          .withField('ssid', 'Home_5G')
          .withField('wifi_password', 'home_wifi_pass_2024')
          .build(),
    ];

    final templates = <AccountTemplate>[
      MockDataFactory.template('tpl_social')
          .withTitle('社交媒体')
          .withCategory(TemplateCategory.custom)
          .addField(
            key: 'platform',
            label: '平台',
            type: AccountFieldType.text,
            isPrimary: true,
            isRequired: true,
          )
          .addField(
            key: 'social_username',
            label: '用户名',
            type: AccountFieldType.text,
            isRequired: true,
          )
          .addField(
            key: 'social_password',
            label: '密码',
            type: AccountFieldType.password,
            isSecret: true,
          )
          .build(),
      MockDataFactory.template('tpl_server')
          .withTitle('服务器')
          .withCategory(TemplateCategory.custom)
          .addField(
            key: 'host',
            label: '主机',
            type: AccountFieldType.url,
            isPrimary: true,
            isRequired: true,
          )
          .addField(
            key: 'ssh_user',
            label: 'SSH用户',
            type: AccountFieldType.text,
            isRequired: true,
          )
          .addField(key: 'ssh_port', label: '端口', type: AccountFieldType.number)
          .addField(
            key: 'ssh_key',
            label: 'SSH密钥',
            type: AccountFieldType.password,
            isSecret: true,
          )
          .build(),
    ];

    final totps = <TotpCredential>[
      MockDataFactory.totp(id: 'totp_github', label: 'GitHub')
          .fromOtpAuthUri(
            'otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
          )
          .linkToAccount('acc_github')
          .build(),
      MockDataFactory.totp(id: 'totp_google', label: 'Google')
          .fromOtpAuthUri(
            'otpauth://totp/Google:alice@gmail.com?secret=JBSWY3DPEHPK3PXP&issuer=Google',
          )
          .linkToAccount('acc_gmail')
          .build(),
    ];

    return MockScenarioData(
      accounts: accounts,
      templates: templates,
      totps: totps,
    );
  }

  // ====== 冲突场景 ======

  /// 一组存在 CRDT 冲突的数据，用于测试合并逻辑。
  ///
  /// 包含：
  /// - 1 对 name/email 冲突的账户（local vs remote）
  /// - 1 对字段冲突的账户
  /// - 0 模板 / 0 TOTP
  static MockScenarioData conflictPair() {
    final pair = MockDataFactory.conflictAccountPair(
      id: 'acc_conflict',
      localName: '本地名称',
      remoteName: '远程名称',
      localEmail: 'local@device.com',
      remoteEmail: 'remote@server.com',
    );

    final fieldConflictLocal =
        MockDataFactory.account(
              id: 'acc_field_conflict',
              name: 'Field Conflict',
            )
            .withPassword('local_password')
            .withUsername('local_user')
            .withNameHlc(const Hlc(10, 0, 'local'))
            .withDataHlc('password', const Hlc(10, 0, 'local'))
            .withDataHlc('username', const Hlc(8, 0, 'local'))
            .withSyncStatus(SyncStatus.synchronized)
            .withServerVersion(1)
            .build();

    final fieldConflictRemote =
        MockDataFactory.account(
              id: 'acc_field_conflict',
              name: 'Field Conflict',
            )
            .withPassword('remote_password')
            .withUsername('remote_user')
            .withNameHlc(const Hlc(10, 0, 'local'))
            .withDataHlc('password', const Hlc(11, 0, 'remote'))
            .withDataHlc('username', const Hlc(12, 0, 'remote'))
            .withSyncStatus(SyncStatus.synchronized)
            .withServerVersion(2)
            .build();

    return MockScenarioData(
      accounts: [
        pair.local,
        pair.remote,
        fieldConflictLocal,
        fieldConflictRemote,
      ],
    );
  }

  // ====== 大数据量场景 ======

  /// 大量账户数据，用于测试列表性能、搜索、滚动。
  ///
  /// 默认生成 100 个同构网站账户 + 10 个模板 + 20 个 TOTP。
  static MockScenarioData largeDataset({
    int accountCount = 100,
    int templateCount = 10,
    int totpCount = 20,
  }) {
    final accounts = MockDataFactory.batchWebsiteAccounts(
      count: accountCount,
      prefix: 'acc',
      nameBuilder: (i) => 'Account ${_pad(i + 1, 3)}',
    );

    final templates = List.generate(templateCount, (i) {
      return MockDataFactory.template('tpl_${_pad(i, 3)}')
          .withTitle('Template ${_pad(i + 1, 3)}')
          .withCategory(TemplateCategory.custom)
          .addField(
            key: 'field1',
            label: 'Field 1',
            type: AccountFieldType.text,
          )
          .addField(
            key: 'field2',
            label: 'Field 2',
            type: AccountFieldType.password,
            isSecret: true,
          )
          .build();
    });

    final totps = List.generate(totpCount, (i) {
      return MockDataFactory.totp(
            id: 'totp_${_pad(i, 3)}',
            label: 'Service ${_pad(i + 1, 3)}',
          )
          .fromParams(
            secret: 'JBSWY3DPEHPK3PXP',
            issuer: 'Service ${_pad(i + 1, 3)}',
          )
          .build();
    });

    return MockScenarioData(
      accounts: accounts,
      templates: templates,
      totps: totps,
    );
  }

  // ====== 空保险库场景 ======

  /// 没有任何数据的保险库，用于测试空状态 UI。
  static MockScenarioData emptyVault() => const MockScenarioData();

  // ====== 待同步场景 ======

  /// 包含大量待推送本地变更的场景，用于测试同步队列 UI。
  static MockScenarioData pendingSync({int pendingCount = 10}) {
    final accounts = MockDataFactory.batchWebsiteAccounts(
      count: pendingCount,
      prefix: 'acc',
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final changes = accounts.map((a) {
      return LocalSyncChange(
        id: 'change_${a.id}',
        vaultId: 'vault_test',
        entityType: LocalSyncEntityType.account,
        entityId: a.id,
        action: LocalSyncAction.create,
        title: a.name,
        beforeJson: null,
        afterJson: LocalSyncChange.encodeSnapshot(a.toJson()),
        diff: const <String, dynamic>{},
        baseServerVersion: 0,
        status: LocalSyncStatus.pendingReview,
        createdAt: now,
        updatedAt: now,
      );
    }).toList();

    return MockScenarioData(accounts: accounts, syncChanges: changes);
  }

  // ====== 模板账户场景（覆盖所有内置字段预设） ======

  /// 覆盖全部内置字段预设的模板及其对应账户。
  ///
  /// 包含：
  /// - 9 个自定义模板（对应 9 个 [kFieldPresets]）
  /// - 9 个使用这些模板的账户（每个模板 1 个示例账户）
  static MockScenarioData templateAccounts() {
    final templates = <AccountTemplate>[
      MockDataFactory.template('tpl_secure_note')
          .withTitle('安全笔记')
          .withCategory(TemplateCategory.custom)
          .addField(
            key: 'content',
            label: '内容',
            type: AccountFieldType.longText,
            isSecret: true,
          )
          .build(),
      MockDataFactory.template('tpl_mnemonic')
          .withTitle('助记词')
          .withCategory(TemplateCategory.custom)
          .addField(
            key: 'mnemonic_words',
            label: '助记词',
            type: AccountFieldType.list,
            isSecret: true,
          )
          .build(),
      MockDataFactory.template('tpl_api_keys')
          .withTitle('API Key')
          .withCategory(TemplateCategory.custom)
          .addField(
            key: 'service_name',
            label: '服务名称',
            type: AccountFieldType.text,
            isPrimary: true,
            isRequired: true,
          )
          .addField(
            key: 'api_keys',
            label: 'API Key',
            type: AccountFieldType.list,
            isSecret: true,
          )
          .build(),
      MockDataFactory.template('tpl_bank_card')
          .withTitle('银行卡')
          .withCategory(TemplateCategory.payment)
          .addField(
            key: 'bank_name',
            label: '银行名称',
            type: AccountFieldType.text,
            isRequired: true,
          )
          .addField(
            key: 'card_number',
            label: '卡号',
            type: AccountFieldType.text,
            isRequired: true,
          )
          .addField(
            key: 'cvv',
            label: 'CVV',
            type: AccountFieldType.password,
            isSecret: true,
          )
          .addField(
            key: 'expiry_date',
            label: '有效期',
            type: AccountFieldType.text,
          )
          .build(),
      MockDataFactory.template('tpl_identity')
          .withTitle('身份证件')
          .withCategory(TemplateCategory.custom)
          .addField(
            key: 'full_name',
            label: '姓名',
            type: AccountFieldType.text,
            isRequired: true,
          )
          .addField(
            key: 'id_number',
            label: '证件号码',
            type: AccountFieldType.text,
            isRequired: true,
            isSecret: true,
          )
          .addField(
            key: 'issuing_authority',
            label: '签发机关',
            type: AccountFieldType.text,
          )
          .addField(
            key: 'valid_until',
            label: '有效期限',
            type: AccountFieldType.text,
          )
          .build(),
      MockDataFactory.template('tpl_wifi')
          .withTitle('WiFi')
          .withCategory(TemplateCategory.custom)
          .addField(
            key: 'ssid',
            label: '网络名称',
            type: AccountFieldType.text,
            isRequired: true,
          )
          .addField(
            key: 'wifi_password',
            label: 'WiFi 密码',
            type: AccountFieldType.password,
            isSecret: true,
          )
          .build(),
      MockDataFactory.template('tpl_server_ssh')
          .withTitle('服务器')
          .withCategory(TemplateCategory.custom)
          .addField(
            key: 'host',
            label: '主机地址',
            type: AccountFieldType.url,
            isPrimary: true,
            isRequired: true,
          )
          .addField(
            key: 'ssh_user',
            label: '用户名',
            type: AccountFieldType.text,
            isRequired: true,
          )
          .addField(key: 'ssh_port', label: '端口', type: AccountFieldType.number)
          .addField(
            key: 'ssh_key',
            label: 'SSH 密钥',
            type: AccountFieldType.password,
            isSecret: true,
          )
          .build(),
      MockDataFactory.template('tpl_social_media')
          .withTitle('社交媒体')
          .withCategory(TemplateCategory.custom)
          .addField(
            key: 'platform',
            label: '平台名称',
            type: AccountFieldType.text,
            isPrimary: true,
            isRequired: true,
          )
          .addField(
            key: 'social_username',
            label: '用户名',
            type: AccountFieldType.text,
            isRequired: true,
          )
          .addField(
            key: 'social_password',
            label: '密码',
            type: AccountFieldType.password,
            isSecret: true,
          )
          .addField(
            key: 'phone_bound',
            label: '绑定手机',
            type: AccountFieldType.phone,
          )
          .build(),
      MockDataFactory.template('tpl_license_key')
          .withTitle('软件授权')
          .withCategory(TemplateCategory.custom)
          .addField(
            key: 'software_name',
            label: '软件名称',
            type: AccountFieldType.text,
            isRequired: true,
          )
          .addField(
            key: 'license_key',
            label: '授权码',
            type: AccountFieldType.text,
            isRequired: true,
            isSecret: true,
          )
          .addField(
            key: 'purchase_email',
            label: '购买邮箱',
            type: AccountFieldType.email,
          )
          .build(),
    ];

    final accounts = <AccountItem>[
      MockDataFactory.account(id: 'acc_secure_note', name: '路由器配置备份')
          .withTemplateId('tpl_secure_note')
          .withField('content', 'admin / admin\n192.168.1.1')
          .build(),
      MockDataFactory.account(id: 'acc_mnemonic', name: 'ETH 钱包助记词')
          .withTemplateId('tpl_mnemonic')
          .withField(
            'mnemonic_words',
            'abandon ability able about above absent absorb abstract absurd abuse access',
          )
          .build(),
      MockDataFactory.account(id: 'acc_api_keys', name: 'OpenAI API')
          .withTemplateId('tpl_api_keys')
          .withField('service_name', 'OpenAI')
          .withField('api_keys', 'sk-proj-xxxxxxxxxxxxxxxxxxxxxxxx')
          .build(),
      MockDataFactory.account(id: 'acc_bank_card', name: '招商银行信用卡')
          .withTemplateId('tpl_bank_card')
          .withField('bank_name', '招商银行')
          .withField('card_number', '6225 8888 8888 8888')
          .withField('cvv', '888')
          .withField('expiry_date', '08/29')
          .build(),
      MockDataFactory.account(id: 'acc_identity', name: '身份证')
          .withTemplateId('tpl_identity')
          .withField('full_name', '张三')
          .withField('id_number', '11010119900101xxxx')
          .withField('issuing_authority', '北京市公安局')
          .withField('valid_until', '2030-01-01')
          .build(),
      MockDataFactory.account(id: 'acc_wifi', name: '家里WiFi')
          .withTemplateId('tpl_wifi')
          .withField('ssid', 'Home_5G')
          .withField('wifi_password', 'home_wifi_pass_2024')
          .build(),
      MockDataFactory.account(id: 'acc_server_ssh', name: '阿里云 ECS')
          .withTemplateId('tpl_server_ssh')
          .withField('host', '192.168.1.100')
          .withField('ssh_user', 'root')
          .withField('ssh_port', '22')
          .withField('ssh_key', '-----BEGIN OPENSSH PRIVATE KEY-----\n...')
          .build(),
      MockDataFactory.account(id: 'acc_social_media', name: 'Twitter')
          .withTemplateId('tpl_social_media')
          .withField('platform', 'Twitter')
          .withField('social_username', '@alice_dev')
          .withField('social_password', 'twitter_pass_2024')
          .withField('phone_bound', '+86 138 **** 8888')
          .build(),
      MockDataFactory.account(id: 'acc_license_key', name: 'JetBrains License')
          .withTemplateId('tpl_license_key')
          .withField('software_name', 'IntelliJ IDEA')
          .withField('license_key', 'XXXX-XXXX-XXXX-XXXX')
          .withField('purchase_email', 'alice@example.com')
          .build(),
    ];

    return MockScenarioData(accounts: accounts, templates: templates);
  }

  // ====== 混合数据场景（账户 + 模板 + TOTP + 通知） ======

  /// 接近真实用户环境的混合数据。
  static MockScenarioData mixedRealWorld() {
    final base = standardUser();

    final notifications = <AppNotification>[
      AppNotification(
        id: 'notif_1',
        type: AppNotificationType.passwordExpiry,
        title: '密码过期提醒',
        body: 'GitHub 密码已 90 天未更换',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        accountId: 'acc_github',
      ),
      AppNotification(
        id: 'notif_2',
        type: AppNotificationType.weakPassword,
        title: '弱密码警告',
        body: '家里WiFi 密码强度不足',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        accountId: 'acc_wifi',
      ),
    ];

    final healthReport = VaultHealthReport(
      score: 72,
      grade: VaultHealthGrade.good,
      items: [
        const VaultHealthItem(
          id: 'check_reuse',
          title: '密码复用检查',
          riskLevel: VaultHealthRiskLevel.medium,
          isPass: false,
          description: '发现 2 组账户使用相同密码',
        ),
        const VaultHealthItem(
          id: 'check_2fa',
          title: '2FA 覆盖率',
          riskLevel: VaultHealthRiskLevel.low,
          isPass: true,
          description: '33% 的账户已绑定 TOTP',
        ),
      ],
      calculatedAt: DateTime.now(),
    );

    return MockScenarioData(
      accounts: base.accounts,
      templates: base.templates,
      totps: base.totps,
      notifications: notifications,
      healthReport: healthReport,
    );
  }

  // ---------------------------------------------------------------------------
  // 辅助方法
  // ---------------------------------------------------------------------------

  static String _pad(int n, int width) => n.toString().padLeft(width, '0');
}
