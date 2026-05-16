// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/totp_service.dart';
import 'package:secret_roy/utils/field_presets.dart';

import 'hlc_helpers.dart';

// ---------------------------------------------------------------------------
// 常量与默认值
// ---------------------------------------------------------------------------

const String _kDefaultTemplateId = 'builtin_generic_info';
const String _kDefaultNodeId = 'local';

String _nextId(String prefix, int index) => '${prefix}_${_pad(index, 3)}';

String _pad(int n, int width) => n.toString().padLeft(width, '0');

// ---------------------------------------------------------------------------
// AccountItemBuilder
// ---------------------------------------------------------------------------

/// AccountItem 的流式构造器。
///
/// 自动填充所有 CRDT 时钟和默认值，只需关注业务字段。
///
/// 基础用法：
/// ```dart
/// final item = AccountItemBuilder()
///   .withName('GitHub')
///   .withEmail('alice@example.com')
///   .withPassword('secret123')
///   .build();
/// ```
///
/// 高级用法（手动覆盖任意字段）：
/// ```dart
/// final item = AccountItemBuilder()
///   .withName('GitHub')
///   .withField('otpToken', '123456')
///   .withPinned(true)
///   .withSyncStatus(SyncStatus.synchronized)
///   .withServerVersion(5)
///   .build();
/// ```
class AccountItemBuilder {
  String _id = '';
  String _name = '';
  String _email = '';
  String _templateId = _kDefaultTemplateId;
  int _templateVersion = 0;
  final Map<String, dynamic> _data = {};
  final Map<String, AccountFieldMeta> _fieldMeta = {};
  int _createdAt = 0;
  int _modifiedAt = 0;
  String? _lastEditedBy;
  int? _lastEditedAt;
  Hlc _nameHlc = hlc.zero;
  Hlc _emailHlc = hlc.zero;
  final Map<String, Hlc> _dataHlc = {};
  int _serverVersion = 0;
  SyncStatus _syncStatus = SyncStatus.pendingPush;
  bool _isDeleted = false;
  Hlc? _deleteHlc;
  bool _isPinned = false;
  Hlc? _pinHlc;

  // ---- 必填快捷设置 ----

  AccountItemBuilder withId(String id) {
    _id = id;
    return this;
  }

  AccountItemBuilder withName(String name) {
    _name = name;
    _nameHlc = hlc.now(_kDefaultNodeId);
    return this;
  }

  AccountItemBuilder withEmail(String email) {
    _email = email;
    _emailHlc = hlc.now(_kDefaultNodeId);
    return this;
  }

  AccountItemBuilder withTemplateId(String templateId) {
    _templateId = templateId;
    return this;
  }

  /// 使用内置模板常量快速设置模板ID
  AccountItemBuilder withTemplate(AccountTemplate template) {
    _templateId = template.templateId;
    return this;
  }

  // ---- data 字段快捷设置 ----

  /// 设置单个 data 字段，同时自动为其生成 HLC。
  AccountItemBuilder withField(String key, dynamic value) {
    _data[key] = value;
    _dataHlc[key] = hlc.now(_kDefaultNodeId);
    return this;
  }

  /// 批量设置 data 字段。
  AccountItemBuilder withData(Map<String, dynamic> data) {
    for (final entry in data.entries) {
      _data[entry.key] = entry.value;
      _dataHlc[entry.key] = hlc.now(_kDefaultNodeId);
    }
    return this;
  }

  AccountItemBuilder withPassword(String password) => withField('password', password);

  AccountItemBuilder withUsername(String username) => withField('username', username);

  AccountItemBuilder withWebsite(String url) => withField('website', url);

  AccountItemBuilder withNotes(String notes) => withField('notes', notes);

  AccountItemBuilder withPhone(String phone) => withField('phone', phone);

  AccountItemBuilder withOtpToken(String token) => withField('otpToken', token);

  // ---- 元数据与状态 ----

  AccountItemBuilder withCreatedAt(int timestamp) {
    _createdAt = timestamp;
    return this;
  }

  AccountItemBuilder withModifiedAt(int timestamp) {
    _modifiedAt = timestamp;
    return this;
  }

  AccountItemBuilder withServerVersion(int version) {
    _serverVersion = version;
    return this;
  }

  AccountItemBuilder withSyncStatus(SyncStatus status) {
    _syncStatus = status;
    return this;
  }

  AccountItemBuilder withPinned(bool pinned) {
    _isPinned = pinned;
    if (pinned) _pinHlc = hlc.now(_kDefaultNodeId);
    return this;
  }

  AccountItemBuilder withDeleted({Hlc? deleteHlc}) {
    _isDeleted = true;
    _deleteHlc = deleteHlc ?? hlc.now(_kDefaultNodeId);
    return this;
  }

  // ---- HLC 手动覆盖 ----

  AccountItemBuilder withNameHlc(Hlc h) {
    _nameHlc = h;
    return this;
  }

  AccountItemBuilder withEmailHlc(Hlc h) {
    _emailHlc = h;
    return this;
  }

  AccountItemBuilder withDataHlc(String key, Hlc h) {
    _dataHlc[key] = h;
    return this;
  }

  // ---- 构建 ----

  AccountItem build() {
    assert(_id.isNotEmpty, 'AccountItemBuilder: id must be set. Use .withId() or MockDataFactory.account()');
    if (_createdAt == 0) _createdAt = _defaultTimestamp();
    if (_modifiedAt == 0) _modifiedAt = _createdAt;
    return AccountItem(
      id: _id,
      name: _name,
      email: _email,
      templateId: _templateId,
      templateVersion: _templateVersion,
      data: Map.unmodifiable(Map<String, dynamic>.from(_data)),
      fieldMeta: Map.unmodifiable(Map<String, AccountFieldMeta>.from(_fieldMeta)),
      createdAt: _createdAt,
      modifiedAt: _modifiedAt,
      lastEditedBy: _lastEditedBy,
      lastEditedAt: _lastEditedAt,
      nameHlc: _nameHlc,
      emailHlc: _emailHlc,
      dataHlc: Map.unmodifiable(Map<String, Hlc>.from(_dataHlc)),
      serverVersion: _serverVersion,
      syncStatus: _syncStatus,
      isDeleted: _isDeleted,
      deleteHlc: _deleteHlc,
      isPinned: _isPinned,
      pinHlc: _pinHlc,
    );
  }
}

// ---------------------------------------------------------------------------
// AccountTemplateBuilder
// ---------------------------------------------------------------------------

/// AccountTemplate 的流式构造器。
///
/// 支持从零构建或基于字段预设快速生成。
///
/// 基础用法：
/// ```dart
/// final t = AccountTemplateBuilder('custom_bank')
///   .withTitle('My Bank')
///   .withCategory(TemplateCategory.payment)
///   .addField(key: 'cardNumber', label: '卡号', type: AccountFieldType.text)
///   .addField(key: 'cvv', label: 'CVV', type: AccountFieldType.password, isSecret: true)
///   .build();
/// ```
///
/// 基于预设：
/// ```dart
/// final t = AccountTemplateBuilder.fromPreset('bank_card')
///   .withTitle('My Bank Card')
///   .build();
/// ```
class AccountTemplateBuilder {
  final String _templateId;
  int _version = 1;
  String _title = '';
  String _subTitle = '';
  int? _iconCodePoint;
  TemplateCategory _category = TemplateCategory.custom;
  final List<AccountField> _fields = [];
  bool _isCustom = true;
  int? _createdAt;
  int? _modifiedAt;
  String? _lastEditedBy;
  int? _lastEditedAt;
  SyncStatus _syncStatus = SyncStatus.pendingPush;
  Hlc? _hlc;
  int _serverVersion = 0;
  bool _isDeleted = false;
  Hlc? _deleteHlc;

  AccountTemplateBuilder(this._templateId);

  /// 从 [kFieldPresets] 中按 id 查找预设并复制字段。
  factory AccountTemplateBuilder.fromPreset(String presetId) {
    final preset = kFieldPresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => throw ArgumentError('Unknown preset id: $presetId. '
          'Available: ${kFieldPresets.map((p) => p.id).join(', ')}'),
    );
    return AccountTemplateBuilder(preset.id)
      ..withTitle(preset.name)
      .._fields.addAll(
        preset.fields.map((f) => AccountField(
          fieldKey: f.fieldKey,
          label: f.label,
          description: f.description,
          attributes: f.attributes,
          order: f.order,
        )),
      );
  }

  AccountTemplateBuilder withTitle(String title) {
    _title = title;
    return this;
  }

  AccountTemplateBuilder withSubTitle(String subTitle) {
    _subTitle = subTitle;
    return this;
  }

  AccountTemplateBuilder withCategory(TemplateCategory category) {
    _category = category;
    return this;
  }

  AccountTemplateBuilder withIcon(int codePoint) {
    _iconCodePoint = codePoint;
    return this;
  }

  /// 添加一个字段。
  AccountTemplateBuilder addField({
    required String key,
    required String label,
    required AccountFieldType type,
    String? description,
    bool isPrimary = false,
    bool isRequired = false,
    bool isSecret = false,
    bool isEditable = true,
    bool isSearchable = false,
    bool isCopyable = true,
    int? maxLength,
    int? minLength,
  }) {
    _fields.add(AccountField(
      fieldKey: key,
      label: label,
      description: description,
      attributes: AccountFieldAttributes(
        type: type,
        isPrimary: isPrimary,
        isRequired: isRequired,
        isSecret: isSecret,
        isEditable: isEditable,
        isSearchable: isSearchable,
        isCopyable: isCopyable,
        maxLength: maxLength,
        minLength: minLength,
      ),
      order: _fields.length,
    ));
    return this;
  }

  /// 批量添加字段。
  AccountTemplateBuilder addFields(List<AccountField> fields) {
    _fields.addAll(fields);
    return this;
  }

  AccountTemplateBuilder withSyncStatus(SyncStatus status) {
    _syncStatus = status;
    return this;
  }

  AccountTemplateBuilder withServerVersion(int version) {
    _serverVersion = version;
    return this;
  }

  AccountTemplateBuilder withDeleted() {
    _isDeleted = true;
    _deleteHlc = hlc.now(_kDefaultNodeId);
    return this;
  }

  AccountTemplateBuilder withCreatedAt(int timestamp) {
    _createdAt = timestamp;
    return this;
  }

  AccountTemplate build() {
    if (_createdAt == null) _createdAt = _defaultTimestamp();
    return AccountTemplate(
      templateId: _templateId,
      version: _version,
      title: _title,
      subTitle: _subTitle,
      iconCodePoint: _iconCodePoint,
      category: _category,
      fields: List.unmodifiable(List<AccountField>.from(_fields)),
      isCustom: _isCustom,
      createdAt: _createdAt,
      modifiedAt: _modifiedAt,
      lastEditedBy: _lastEditedBy,
      lastEditedAt: _lastEditedAt,
      syncStatus: _syncStatus,
      hlc: _hlc,
      serverVersion: _serverVersion,
      isDeleted: _isDeleted,
      deleteHlc: _deleteHlc,
    );
  }
}

// ---------------------------------------------------------------------------
// TotpCredentialBuilder
// ---------------------------------------------------------------------------

/// TotpCredential 的流式构造器。
///
/// 支持从 otpauth URI 或离散参数构建。
///
/// 用法：
/// ```dart
/// final totp = TotpCredentialBuilder('totp_1')
///   .withLabel('GitHub')
///   .fromOtpAuthUri('otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP&issuer=GitHub')
///   .linkToAccount('account_1')
///   .build();
/// ```
class TotpCredentialBuilder {
  final String _id;
  String _label = '';
  TotpConfig _config = const TotpConfig(secret: 'JBSWY3DPEHPK3PXP');
  final List<String> _linkedAccountIds = [];
  int _createdAt = 0;
  Hlc _labelHlc = hlc.zero;
  Hlc _configHlc = hlc.zero;
  Hlc _linksHlc = hlc.zero;
  int _serverVersion = 0;
  SyncStatus _syncStatus = SyncStatus.pendingPush;
  bool _isDeleted = false;
  Hlc? _deleteHlc;

  TotpCredentialBuilder(this._id);

  TotpCredentialBuilder withLabel(String label) {
    _label = label;
    _labelHlc = hlc.now(_kDefaultNodeId);
    return this;
  }

  /// 从 otpauth URI 解析配置。
  TotpCredentialBuilder fromOtpAuthUri(String uri) {
    _config = TotpService.parseConfig(uri);
    _configHlc = hlc.now(_kDefaultNodeId);
    return this;
  }

  /// 从离散参数构造配置。
  TotpCredentialBuilder fromParams({
    required String secret,
    String? issuer,
    String? account,
    TotpAlgorithm algorithm = TotpAlgorithm.sha1,
    int digits = 6,
    int period = 30,
  }) {
    _config = TotpConfig(
      secret: secret,
      issuer: issuer,
      account: account,
      algorithm: algorithm,
      digits: digits,
      period: period,
    );
    _configHlc = hlc.now(_kDefaultNodeId);
    return this;
  }

  TotpCredentialBuilder linkToAccount(String accountId) {
    if (!_linkedAccountIds.contains(accountId)) {
      _linkedAccountIds.add(accountId);
      _linksHlc = hlc.now(_kDefaultNodeId);
    }
    return this;
  }

  TotpCredentialBuilder withCreatedAt(int timestamp) {
    _createdAt = timestamp;
    return this;
  }

  TotpCredentialBuilder withSyncStatus(SyncStatus status) {
    _syncStatus = status;
    return this;
  }

  TotpCredentialBuilder withServerVersion(int version) {
    _serverVersion = version;
    return this;
  }

  TotpCredentialBuilder withDeleted() {
    _isDeleted = true;
    _deleteHlc = hlc.now(_kDefaultNodeId);
    return this;
  }

  TotpCredential build() {
    if (_createdAt == 0) _createdAt = _defaultTimestamp();
    return TotpCredential(
      id: _id,
      label: _label,
      config: _config,
      linkedAccountIds: List.unmodifiable(List<String>.from(_linkedAccountIds)),
      createdAt: _createdAt,
      labelHlc: _labelHlc,
      configHlc: _configHlc,
      linksHlc: _linksHlc,
      serverVersion: _serverVersion,
      syncStatus: _syncStatus,
      isDeleted: _isDeleted,
      deleteHlc: _deleteHlc,
    );
  }
}

// ---------------------------------------------------------------------------
// MockDataFactory — 静态工厂与批量生成
// ---------------------------------------------------------------------------

/// Mock 数据统一工厂入口。
///
/// 提供便捷的一行代码构造器、批量生成器、以及常见测试场景的预置数据。
///
/// ## 单个对象构造
/// ```dart
/// final account = MockDataFactory.account(id: 'acc_001', name: 'GitHub')
///   .withEmail('alice@example.com')
///   .withPassword('secret123')
///   .build();
/// ```
///
/// ## 批量生成
/// ```dart
/// final accounts = MockDataFactory.batch.accounts(count: 50);
/// final templates = MockDataFactory.batch.templates(count: 5);
/// ```
///
/// ## 场景数据
/// ```dart
/// final scenario = MockDataFactory.scenario.standardUser();
/// // scenario.accounts / scenario.templates / scenario.totps
/// ```
class MockDataFactory {
  MockDataFactory._();

  // ====== 便捷一行构造器 ======

  /// 快速构造一个 [AccountItemBuilder]，自动分配 id。
  ///
  /// ```dart
  /// final a = MockDataFactory.account(id: 'acc_1', name: 'GitHub')
  ///   .withPassword('secret')
  ///   .build();
  /// ```
  static AccountItemBuilder account({required String id, required String name}) {
    return AccountItemBuilder()
      ..withId(id)
      ..withName(name)
      ..withEmail('')
      ..withCreatedAt(_defaultTimestamp());
  }

  /// 构造一个完整的网站登录账户。
  static AccountItem websiteAccount({
    required String id,
    String name = 'Example Site',
    String email = '',
    String username = 'user001',
    String password = 'password123',
    String website = 'https://example.com',
  }) {
    return AccountItemBuilder()
      .withId(id)
      .withName(name)
      .withEmail(email)
      .withTemplateId('builtin_generic_info')
      .withUsername(username)
      .withPassword(password)
      .withWebsite(website)
      .build();
  }

  /// 构造一个安全笔记账户。
  static AccountItem secureNote({
    required String id,
    String name = 'My Secure Note',
    String content = 'This is a secret note content.',
  }) {
    return AccountItemBuilder()
      .withId(id)
      .withName(name)
      .withEmail('')
      .withTemplateId('builtin_secure_note')
      .withField('content', content)
      .build();
  }

  /// 构造一个银行账号。
  static AccountItem bankAccount({
    required String id,
    String name = 'My Bank',
    String bankName = 'Example Bank',
    String cardNumber = '6222 0222 0000 0000',
    String cvv = '123',
    String expiryDate = '12/28',
  }) {
    return AccountItemBuilder()
      .withId(id)
      .withName(name)
      .withEmail('')
      .withTemplateId('builtin_payment')
      .withField('bankName', bankName)
      .withField('cardNumber', cardNumber)
      .withField('cvv', cvv)
      .withField('expiryDate', expiryDate)
      .build();
  }

  /// 构造一个已删除的账户（tombstone）。
  static AccountItem deletedAccount({
    required String id,
    String name = 'Deleted',
    int serverVersion = 3,
  }) {
    return AccountItemBuilder()
      .withId(id)
      .withName(name)
      .withEmail('')
      .withTemplateId('builtin_generic_info')
      .withData({})
      .withSyncStatus(SyncStatus.synchronized)
      .withServerVersion(serverVersion)
      .withDeleted()
      .build();
  }

  /// 快速构造一个 [AccountTemplateBuilder]。
  static AccountTemplateBuilder template(String templateId) {
    return AccountTemplateBuilder(templateId);
  }

  /// 快速构造一个 [TotpCredentialBuilder]。
  static TotpCredentialBuilder totp({required String id, required String label}) {
    return TotpCredentialBuilder(id)..withLabel(label);
  }



  // ====== 批量生成器 ======

  /// 批量生成一组账户。
  ///
  /// ```dart
  /// final accounts = MockDataFactory.batch.accounts(
  ///   count: 100,
  ///   prefix: 'acc',
  ///   builder: (i) => MockDataFactory.websiteAccount(id: 'acc_$i'),
  /// );
  /// ```
  static List<AccountItem> batchAccounts({
    required int count,
    required AccountItem Function(int index) builder,
  }) {
    return List.generate(count, builder);
  }

  /// 批量生成一组同构网站账户。
  static List<AccountItem> batchWebsiteAccounts({
    required int count,
    String prefix = 'acc',
    String Function(int index)? nameBuilder,
  }) {
    return List.generate(count, (i) {
      final name = nameBuilder?.call(i) ?? 'Website Account ${_pad(i + 1, 3)}';
      return websiteAccount(
        id: _nextId(prefix, i),
        name: name,
        username: 'user${_pad(i + 1, 3)}',
        password: 'pass${_pad(i + 1, 3)}!',
        website: 'https://site${_pad(i + 1, 3)}.com',
      );
    });
  }

  /// 批量生成一组模板。
  static List<AccountTemplate> batchTemplates({
    required int count,
    required AccountTemplate Function(int index) builder,
  }) {
    return List.generate(count, builder);
  }

  /// 批量生成一组 TOTP 凭证。
  static List<TotpCredential> batchTotps({
    required int count,
    required TotpCredential Function(int index) builder,
  }) {
    return List.generate(count, builder);
  }

  // ====== CRDT 冲突构造器 ======

  /// 构造一对存在冲突的账户（本地 vs 远程）。
  ///
  /// ```dart
  /// final pair = MockDataFactory.conflict.accountPair(
  ///   id: 'acc_conflict',
  ///   localName: 'Local Name',
  ///   remoteName: 'Remote Name',
  /// );
  /// // pair.local  /  pair.remote
  /// ```
  static _ConflictPair<AccountItem> conflictAccountPair({
    required String id,
    required String localName,
    required String remoteName,
    String localEmail = 'local@example.com',
    String remoteEmail = 'remote@example.com',
    String templateId = 'builtin_generic_info',
    int baseTime = 10,
  }) {
    final localHlc = hlc.local(baseTime);
    final remoteHlc = hlc.remote(baseTime + 1);
    final local = AccountItemBuilder()
      .withId(id)
      .withName(localName)
      .withEmail(localEmail)
      .withTemplateId(templateId)
      .withData({})
      .withNameHlc(localHlc)
      .withEmailHlc(localHlc)
      .withSyncStatus(SyncStatus.synchronized)
      .withServerVersion(1)
      .build();
    final remote = AccountItemBuilder()
      .withId(id)
      .withName(remoteName)
      .withEmail(remoteEmail)
      .withTemplateId(templateId)
      .withData({})
      .withNameHlc(remoteHlc)
      .withEmailHlc(remoteHlc)
      .withSyncStatus(SyncStatus.synchronized)
      .withServerVersion(2)
      .build();
    return _ConflictPair(local: local, remote: remote);
  }

  // ====== 默认值配置 ======

  /// 修改后续所有生成器使用的默认时间戳。
  /// 通常在测试 setUp 中调用以保持数据时间一致。
  static void setDefaultTimestamp(int timestamp) {
    _defaultTimestampOverride = timestamp;
  }

  /// 恢复默认时间戳。
  static void resetDefaultTimestamp() {
    _defaultTimestampOverride = null;
  }
}

// 顶层默认时间戳（可被 MockDataFactory.setDefaultTimestamp 覆盖）
int? _defaultTimestampOverride;
int _defaultTimestamp() => _defaultTimestampOverride ?? DateTime(2024, 1, 1).millisecondsSinceEpoch;

// ---------------------------------------------------------------------------
// 冲突数据对
// ---------------------------------------------------------------------------

class _ConflictPair<T> {
  final T local;
  final T remote;
  const _ConflictPair({required this.local, required this.remote});
}
