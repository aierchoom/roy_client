import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/app_notification.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/local_sync_change.dart';
import 'package:secret_roy/models/template_conflict_log.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/database_file_cipher.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
import 'package:secret_roy/services/totp_service.dart';
import 'package:secret_roy/sync/crdt_merge_engine.dart';
import 'package:secret_roy/sync/sync_service.dart';

/// 内存中的 [SecureKeyValueStore]，用于测试环境替代 FlutterSecureStorage。
class MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values;

  MemorySecureKeyValueStore(this.values);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

/// 最小化的内存 [SecureStorageService]，用于 Server 同步测试。
///
/// 不依赖真实 SQLite，所有数据保存在内存 Map 中。
/// 子类可通过覆写方法扩展行为（如控制 outbox 审批、拦截 pushing 回调等）。
class FakeSecureStorageService extends SecureStorageService {
  final Map<String, String> settings = {};
  final Map<String, AccountItem> accounts = {};
  final Map<String, AccountTemplate> templates = {};
  final Map<String, TotpCredential> totpCredentials = {};
  final Map<String, List<ConflictLog>> conflictLogs = {};
  final List<LocalSyncChange> syncChanges = [];
  final StreamController<StorageChangeEvent> _changeController =
      StreamController<StorageChangeEvent>.broadcast();

  FakeSecureStorageService() : super();

  @override
  Stream<StorageChangeEvent> get onChange => _changeController.stream;

  @override
  bool get isOpen => true;

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }

  @override
  Future<AccountItem?> getAccountById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final item = accounts[id];
    if (item == null) {
      return null;
    }
    if (!includeDeleted && item.isDeleted) {
      return null;
    }
    return item;
  }

  @override
  Future<void> saveAccount(
    AccountItem account, {
    bool isSyncMerge = false,
  }) async {
    accounts[account.id] = account;
  }

  @override
  Future<List<AccountItem>> loadPendingSyncAccounts() async {
    return accounts.values
        .where((item) => item.syncStatus == SyncStatus.pendingPush)
        .toList();
  }

  @override
  Future<List<AccountTemplate>> loadDirtyTemplates() async {
    return templates.values
        .where(
          (item) => item.isCustom && item.syncStatus != SyncStatus.synchronized,
        )
        .toList();
  }

  @override
  Future<List<TotpCredential>> loadDirtyTotpCredentials() async {
    return totpCredentials.values
        .where((item) => item.syncStatus != SyncStatus.synchronized)
        .toList();
  }

  @override
  Future<TotpCredential?> getTotpCredentialById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final item = totpCredentials[id];
    if (item == null) return null;
    if (!includeDeleted && item.isDeleted) return null;
    return item;
  }

  @override
  Future<void> saveTotpCredential(
    TotpCredential credential, {
    bool isSyncMerge = false,
  }) async {
    totpCredentials[credential.id] = credential;
  }

  @override
  Future<void> saveTemplate(
    AccountTemplate template, {
    bool isSyncMerge = false,
  }) async {
    templates[template.templateId] = template;
  }

  @override
  Future<void> saveConflictLogs(List<ConflictLog> logs) async {
    for (final log in logs) {
      conflictLogs.putIfAbsent(log.accountId, () => []).add(log);
    }
  }

  @override
  Future<List<ConflictLog>> getConflictLogs(String accountId) async {
    return List<ConflictLog>.from(conflictLogs[accountId] ?? const []);
  }

  @override
  Future<void> ensurePendingSyncOutboxEntries(String vaultId) async {}

  @override
  Future<List<LocalSyncChange>> loadApprovedLocalSyncChanges({
    required String vaultId,
  }) async {
    return [
      ...accounts.values
          .where((item) => item.syncStatus == SyncStatus.pendingPush)
          .map((item) => approvedChange(vaultId, item)),
      ...totpCredentials.values
          .where((item) => item.syncStatus == SyncStatus.pendingPush)
          .map((item) => approvedTotpChange(vaultId, item)),
    ];
  }

  @override
  Future<bool> hasOpenLocalSyncChanges(String vaultId) async {
    return accounts.values.any(
          (item) => item.syncStatus == SyncStatus.pendingPush,
        ) ||
        totpCredentials.values.any(
          (item) => item.syncStatus == SyncStatus.pendingPush,
        );
  }

  @override
  Future<void> markLocalSyncChangesPushing(Iterable<String> ids) async {}

  @override
  Future<void> markLocalSyncChangesPushed(Iterable<String> ids) async {}

  @override
  Future<void> markLocalSyncChangesFailed(
    Iterable<String> ids,
    String errorMessage,
  ) async {}

  @override
  Future<void> markLocalSyncChangesConflict(
    Iterable<String> ids,
    String errorMessage,
  ) async {}

  @override
  Future<List<AccountItem>> loadAccounts({bool includeDeleted = false}) async {
    return accounts.values
        .where((item) => includeDeleted || !item.isDeleted)
        .toList();
  }

  @override
  Future<List<AccountTemplate>> loadCustomTemplates({
    bool includeDeleted = false,
  }) async {
    return templates.values
        .where((item) => item.isCustom && (includeDeleted || !item.isDeleted))
        .toList();
  }

  @override
  Future<List<TotpCredential>> loadTotpCredentials({
    bool includeDeleted = false,
  }) async {
    return totpCredentials.values
        .where((item) => includeDeleted || !item.isDeleted)
        .toList();
  }

  @override
  Future<List<LocalSyncChange>> loadOpenLocalSyncChanges({
    required String vaultId,
  }) async {
    return syncChanges.where((c) => c.vaultId == vaultId && c.status != LocalSyncStatus.pushed).toList();
  }

  @override
  Future<List<TemplateConflictLog>> getTemplateConflictLogs([
    String? templateId,
  ]) async {
    return [];
  }

  @override
  Future<bool> isDatabaseInitialized() async => false;

  @override
  Future<void> initialize({String deviceId = 'local'}) async {}

  @override
  Future<void> close({bool dispose = false}) async {}

  @override
  Future<void> deleteDatabaseFile() async {}

  @override
  void clearDatabaseCipher() {}

  @override
  void setDatabaseCipher(DatabaseFileCipher cipher) {}

  @override
  Future<void> rotateDatabaseCipher(DatabaseFileCipher cipher) async {}

  @override
  Future<void> deleteAccount(
    String id, {
    bool isSyncMerge = false,
    Hlc? syncDeleteHlc,
  }) async {
    final item = accounts[id];
    if (item != null) {
      accounts[id] = item.copyWith(isDeleted: true);
    }
    _changeController.add(
      StorageChangeEvent(
        type: StorageItemType.account,
        action: StorageAction.delete,
        id: id,
      ),
    );
  }

  @override
  Future<void> recordLocalSyncChange({
    required String vaultId,
    required LocalSyncEntityType entityType,
    required String entityId,
    required LocalSyncAction action,
    required String title,
    required Map<String, dynamic>? beforeSnapshot,
    required Map<String, dynamic>? afterSnapshot,
    required int baseServerVersion,
    bool skipIfUnchanged = false,
  }) async {
    syncChanges.add(LocalSyncChange(
      id: 'sync_${syncChanges.length}',
      vaultId: vaultId,
      entityType: entityType,
      entityId: entityId,
      action: action,
      title: title,
      beforeJson: beforeSnapshot != null ? jsonEncode(beforeSnapshot) : null,
      afterJson: afterSnapshot != null ? jsonEncode(afterSnapshot) : null,
      diff: const {},
      baseServerVersion: baseServerVersion,
      status: LocalSyncStatus.pendingReview,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  final List<AppNotification> notifications = [];

  @override
  @override
  Future<List<AppNotification>> loadNotifications() async => List.from(notifications);

  @override
  Future<void> saveNotification(AppNotification notification) async {
    final idx = notifications.indexWhere((n) => n.id == notification.id);
    if (idx >= 0) {
      notifications[idx] = notification;
    } else {
      notifications.add(notification);
    }
  }

  @override
  Future<void> markNotificationRead(String id) async {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      notifications[idx] = notifications[idx].copyWith(isRead: true);
    }
  }

  @override
  Future<void> markAllNotificationsRead() async {
    for (var i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(isRead: true);
    }
  }

  @override
  Future<void> deleteNotification(String id) async {
    notifications.removeWhere((n) => n.id == id);
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    return notifications.where((n) => !n.isRead).length;
  }

  @override
  Future<void> deleteAllNotifications() async {
    notifications.clear();
  }

  @override
  Future<AccountTemplate?> loadTemplateById(String id, {bool includeDeleted = false}) async {
    return templates[id];
  }

  @override
  Future<void> deleteTemplate(String id, {bool isSyncMerge = false, Hlc? syncDeleteHlc}) async {
    templates.remove(id);
  }

  @override
  Future<void> hardDeleteTemplate(String id) async {
    templates.remove(id);
  }

  @override
  Future<void> togglePin(String id) async {
    final account = accounts[id];
    if (account != null) {
      accounts[id] = account.copyWith(isPinned: !account.isPinned);
    }
  }

  @override
  Future<int> countAccountsByTemplate(String templateId) async {
    return accounts.values.where((a) => a.templateId == templateId && !a.isDeleted).length;
  }

  @override
  Future<void> hardDeleteAccount(String id) async {
    accounts.remove(id);
  }

  @override
  Future<void> hardDeleteTotpCredential(String id) async {
    totpCredentials.remove(id);
  }

  @override
  Future<void> deleteTotpCredential(String id, {bool isSyncMerge = false, Hlc? syncDeleteHlc}) async {
    final item = totpCredentials[id];
    if (item != null) {
      totpCredentials[id] = item.copyWith(isDeleted: true);
    }
  }

  @override
  Future<void> approveLocalSyncChanges({required String vaultId, Iterable<String>? ids}) async {}

  @override
  Future<LocalSyncChange?> getLocalSyncChange(String id) async => null;

  @override
  Future<void> deleteLocalSyncChange(String id) async {}
}

/// 内存中的 Vault 同步服务器，用于单台设备模拟多设备同步场景。
///
/// 绑定到 `127.0.0.1:0`（随机端口），提供完整的 pull/push 语义：
/// - GET `/vaults/{vaultId}/sync?since=x`：分页返回版本号大于 `since` 的 items
/// - POST `/vaults/{vaultId}/sync`：批量推送，支持 409 冲突检测与版本追踪
/// - `isUnavailable` 开关可模拟 503 服务不可用
class InMemoryVaultServer {
  final String vaultId;
  final HttpServer _server;
  final Map<String, Map<String, dynamic>> _items = {};
  int _currentVersion = 0;

  /// 设为 `true` 时，所有请求返回 503。
  bool isUnavailable = false;

  /// GET 请求计数。
  int getCount = 0;

  /// 记录每次 GET 请求的 URI 路径与查询字符串。
  final List<String> getRequestUrls = [];

  /// POST 请求计数。
  int postCount = 0;

  /// 响应延迟，用于模拟慢网络。
  Duration? responseDelay;

  /// 设为 `true` 时，GET 返回非 JSON 响应体。
  bool returnMalformedJson = false;

  /// 分页大小限制。设为 null 时不分页。
  int? pageSizeLimit;

  InMemoryVaultServer._(this.vaultId, this._server) {
    _server.listen(_handleRequest);
  }

  /// 启动服务器，返回实例。
  static Future<InMemoryVaultServer> start(String vaultId) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return InMemoryVaultServer._(vaultId, server);
  }

  /// 基础 URL，例如 `http://127.0.0.1:54321`。
  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  /// 当前服务器全局版本号。
  int get currentVersion => _currentVersion;

  /// 获取指定 id 的 item 原始数据（不含解密）。
  Map<String, dynamic>? getItem(String id) => _items[id];

  /// 关闭服务器。
  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final expectedPath = '/vaults/$vaultId/sync';

    if (isUnavailable) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': 'Sync server unavailable'}));
      await request.response.close();
      return;
    }

    if (request.method == 'GET' && path == expectedPath) {
      getCount += 1;
      getRequestUrls.add(request.uri.toString());

      if (responseDelay != null) {
        await Future<void>.delayed(responseDelay!);
      }

      if (returnMalformedJson) {
        request.response.statusCode = HttpStatus.ok;
        request.response.write('this is not json');
        await request.response.close();
        return;
      }

      final since = int.parse(request.uri.queryParameters['since'] ?? '0');
      if (_currentVersion <= since) {
        request.response.statusCode = HttpStatus.notModified;
        await request.response.close();
        return;
      }

      final allItems =
          _items.values
              .where((item) => (item['version'] as int) > since)
              .toList()
            ..sort(
              (left, right) =>
                  (left['version'] as int).compareTo(right['version'] as int),
            );

      final cursor = int.parse(request.uri.queryParameters['cursor'] ?? '0');
      final limit = pageSizeLimit ??
          int.parse(request.uri.queryParameters['limit'] ?? '100');
      final pagedItems = allItems.skip(cursor).take(limit).toList();
      final remaining = allItems.length - cursor;
      final hasMore = remaining > limit;

      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'max_version': _currentVersion,
          'items': pagedItems,
          if (hasMore) 'has_more': true,
          if (hasMore) 'next_cursor': cursor + pagedItems.length,
          'total_count': allItems.length,
        }),
      );
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && path == expectedPath) {
      postCount += 1;
      final body = await utf8.decoder.bind(request).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final pushes = (decoded['pushes'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

      for (final push in pushes) {
        final existing = _items[push['id'] as String];
        final existingVersion = existing == null
            ? 0
            : existing['version'] as int;
        final expectedBase = push['expected_base_version'] as int? ?? -1;
        if (existingVersion != expectedBase) {
          request.response.statusCode = HttpStatus.conflict;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'error': 'Conflict detected on item ${push['id']}',
              'conflict_type': existing == null
                  ? 'remote_missing'
                  : existing['is_deleted'] == true
                  ? 'concurrent_delete'
                  : expectedBase == 0
                  ? 'concurrent_edit'
                  : 'stale_base_version',
              'item_id': push['id'],
              'your_base': expectedBase,
              'server_actual': existingVersion,
              'server_is_deleted': existing?['is_deleted'] == true,
            }),
          );
          await request.response.close();
          return;
        }
      }

      final acceptedVersions = <String, int>{};
      for (final push in pushes) {
        _currentVersion += 1;
        final itemId = push['id'] as String;
        _items[itemId] = {
          'id': itemId,
          'version': _currentVersion,
          'encrypted_signed_payload': push['encrypted_signed_payload'],
          'is_deleted': push['is_deleted'] == true,
        };
        acceptedVersions[itemId] = _currentVersion;
      }

      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'success': true,
          'max_version': _currentVersion,
          'accepted_versions': acceptedVersions,
        }),
      );
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }
}

/// 单设备上的虚拟同步客户端。
///
/// 包含独立的 [IdentityService]、[FakeSecureStorageService] 和 [SyncService]，
/// 可与 [InMemoryVaultServer] 配合模拟多设备同步。
class TestClient {
  final IdentityService identity;
  final FakeSecureStorageService storage;
  final SyncService syncService;

  TestClient._(this.identity, this.storage, this.syncService);

  /// 创建一个客户端，自动初始化身份与同步服务。
  static Future<TestClient> create({
    required String vaultId,
    required String deviceId,
    required String privateKey,
    required String symmetricKey,
  }) async {
    final identity = IdentityService(
      secureStorage: MemorySecureKeyValueStore({
        'device_id': deviceId,
        'vault_id': vaultId,
        'private_key': privateKey,
        'symmetric_key': symmetricKey,
      }),
    );
    await identity.initialize();

    final storage = FakeSecureStorageService();
    final syncService = SyncService(
      storageService: storage,
      identityService: identity,
    );
    await syncService.initialize();
    return TestClient._(identity, storage, syncService);
  }
}

/// 构造一个用于测试的 [AccountItem]。
AccountItem baseItem({
  required String id,
  required String name,
  required String email,
  required String password,
  required int version,
  required SyncStatus syncStatus,
  required Hlc nameHlc,
  required Hlc emailHlc,
  required Hlc passwordHlc,
  bool isDeleted = false,
  Hlc? deleteHlc,
}) {
  final data = {'password': password};
  final dataHlc = {'password': passwordHlc};

  return AccountItem(
    id: id,
    name: name,
    email: email,
    templateId: 'web_account',
    data: data,
    createdAt: 1,
    nameHlc: nameHlc,
    emailHlc: emailHlc,
    dataHlc: dataHlc,
    serverVersion: version,
    syncStatus: syncStatus,
    isDeleted: isDeleted,
    deleteHlc: deleteHlc,
  );
}

/// 构造一个用于测试的 [TotpCredential]。
TotpCredential baseTotpCredential({
  required String id,
  required String label,
  required String config,
  required int version,
  required SyncStatus syncStatus,
  required Hlc labelHlc,
  required Hlc configHlc,
  required Hlc linksHlc,
  List<String> linkedAccountIds = const [],
}) {
  return TotpCredential(
    id: id,
    label: label,
    config: TotpService.parseConfig(config),
    linkedAccountIds: linkedAccountIds,
    createdAt: 1,
    labelHlc: labelHlc,
    configHlc: configHlc,
    linksHlc: linksHlc,
    serverVersion: version,
    syncStatus: syncStatus,
  );
}

/// 返回一个标准的 TOTP config 字符串。
String totpConfig({
  String account = 'owner@example.com',
  String secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
}) {
  return TotpService.encodeConfig(
    'otpauth://totp/Example:$account?secret=$secret&issuer=Example',
  );
}

/// 为 [AccountItem] 构造一个已审批的 [LocalSyncChange]。
LocalSyncChange approvedChange(String vaultId, AccountItem item) {
  return LocalSyncChange(
    id: 'change_${item.id}',
    vaultId: vaultId,
    entityType: LocalSyncEntityType.account,
    entityId: item.id,
    action: item.isDeleted ? LocalSyncAction.delete : LocalSyncAction.update,
    title: item.name,
    beforeJson: null,
    afterJson: null,
    diff: const {
      'changed_fields': ['record.updated'],
    },
    baseServerVersion: item.serverVersion,
    status: LocalSyncStatus.approved,
    createdAt: 1,
    updatedAt: 1,
    approvedAt: 1,
  );
}

/// 为 [TotpCredential] 构造一个已审批的 [LocalSyncChange]。
LocalSyncChange approvedTotpChange(String vaultId, TotpCredential item) {
  return LocalSyncChange(
    id: 'change_${item.id}',
    vaultId: vaultId,
    entityType: LocalSyncEntityType.totpCredential,
    entityId: item.id,
    action: item.isDeleted ? LocalSyncAction.delete : LocalSyncAction.update,
    title: item.displayLabel,
    beforeJson: null,
    afterJson: null,
    diff: const {
      'changed_fields': ['record.updated'],
    },
    baseServerVersion: item.serverVersion,
    status: LocalSyncStatus.approved,
    createdAt: 1,
    updatedAt: 1,
    approvedAt: 1,
  );
}

/// 为 [AccountTemplate] 构造一个已审批的 [LocalSyncChange]。
LocalSyncChange approvedTemplateChange(String vaultId, AccountTemplate item) {
  return LocalSyncChange(
    id: 'template_change_${item.templateId}',
    vaultId: vaultId,
    entityType: LocalSyncEntityType.template,
    entityId: item.templateId,
    action: LocalSyncAction.update,
    title: item.title,
    beforeJson: null,
    afterJson: null,
    diff: const {
      'changed_fields': ['record.updated'],
    },
    baseServerVersion: item.serverVersion,
    status: LocalSyncStatus.approved,
    createdAt: 1,
    updatedAt: 1,
    approvedAt: 1,
  );
}

/// 构造一个最小化的同步测试用 [AccountTemplate]。
AccountTemplate cleanTemplateWithId(String templateId) {
  return AccountTemplate(
    templateId: templateId,
    title: 'Template',
    subTitle: 'Test template',
    category: TemplateCategory.login,
    fields: const [],
    isCustom: true,
    syncStatus: SyncStatus.synchronized,
  );
}
