import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/local_sync_change.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
import 'package:secret_roy/services/totp_service.dart';
import 'package:secret_roy/sync/crdt_merge_engine.dart';
import 'package:secret_roy/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values;

  _MemorySecureKeyValueStore(this.values);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class _FakeSecureStorageService extends SecureStorageService {
  final Map<String, String> settings = {};
  final Map<String, AccountItem> accounts = {};
  final Map<String, List<ConflictLog>> conflictLogs = {};

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
  Future<List<AccountTemplate>> loadDirtyTemplates() async => [];

  @override
  Future<void> ensurePendingSyncOutboxEntries(String vaultId) async {}

  @override
  Future<List<LocalSyncChange>> loadApprovedLocalSyncChanges({
    required String vaultId,
  }) async {
    return accounts.values
        .where((item) => item.syncStatus == SyncStatus.pendingPush)
        .map((item) => _approvedChange(vaultId, item))
        .toList();
  }

  @override
  Future<bool> hasOpenLocalSyncChanges(String vaultId) async {
    return accounts.values.any(
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
}

LocalSyncChange _approvedChange(String vaultId, AccountItem item) {
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

class _InMemoryVaultServer {
  final String vaultId;
  final HttpServer _server;
  final Map<String, Map<String, dynamic>> _items = {};
  int _currentVersion = 0;
  bool isUnavailable = false;
  int getCount = 0;
  int postCount = 0;

  _InMemoryVaultServer._(this.vaultId, this._server) {
    _server.listen(_handleRequest);
  }

  static Future<_InMemoryVaultServer> start(String vaultId) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _InMemoryVaultServer._(vaultId, server);
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}';
  int get currentVersion => _currentVersion;
  Map<String, dynamic>? getItem(String id) => _items[id];

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
      final since = int.parse(request.uri.queryParameters['since'] ?? '0');
      if (_currentVersion <= since) {
        request.response.statusCode = HttpStatus.notModified;
        await request.response.close();
        return;
      }

      final items =
          _items.values
              .where((item) => (item['version'] as int) > since)
              .toList()
            ..sort(
              (left, right) =>
                  (left['version'] as int).compareTo(right['version'] as int),
            );
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'max_version': _currentVersion, 'items': items}),
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

class _TestClient {
  final IdentityService identity;
  final _FakeSecureStorageService storage;
  final SyncService syncService;

  _TestClient._(this.identity, this.storage, this.syncService);

  static Future<_TestClient> create({
    required String vaultId,
    required String deviceId,
    required String privateKey,
    required String symmetricKey,
  }) async {
    final identity = IdentityService(
      secureStorage: _MemorySecureKeyValueStore({
        'device_id': deviceId,
        'vault_id': vaultId,
        'private_key': privateKey,
        'symmetric_key': symmetricKey,
      }),
    );
    await identity.initialize();

    final storage = _FakeSecureStorageService();
    final syncService = SyncService(
      storageService: storage,
      identityService: identity,
    );
    await syncService.initialize();
    return _TestClient._(identity, storage, syncService);
  }
}

AccountItem _baseItem({
  required String id,
  required String name,
  required String email,
  required String password,
  String? totpConfig,
  required int version,
  required SyncStatus syncStatus,
  required Hlc nameHlc,
  required Hlc emailHlc,
  required Hlc passwordHlc,
  Hlc? totpHlc,
  bool isDeleted = false,
  Hlc? deleteHlc,
}) {
  final data = {'password': password};
  final dataHlc = {'password': passwordHlc};
  if (totpConfig != null) {
    data['totp_secret'] = totpConfig;
    dataHlc['totp_secret'] = totpHlc ?? passwordHlc;
  }

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

String _totpConfig({
  String account = 'owner@example.com',
  String secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
}) {
  return TotpService.encodeConfig(
    'otpauth://totp/Example:$account?secret=$secret&issuer=Example',
  );
}

void main() {
  const vaultId = 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const privateKey =
      'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const symmetricKey =
      'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  test('device B pulls an account created and pushed by device A', () async {
    final server = await _InMemoryVaultServer.start(vaultId);
    addTearDown(server.close);
    SharedPreferences.setMockInitialValues({'sync_server_url': server.baseUrl});

    final clientA = await _TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_aaaaaa111111',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
    final clientB = await _TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_bbbbbb222222',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );

    clientA.storage.accounts['account_1'] = _baseItem(
      id: 'account_1',
      name: 'Primary Account',
      email: 'owner@example.com',
      password: 'super-secret',
      version: 0,
      syncStatus: SyncStatus.pendingPush,
      nameHlc: const Hlc(10, 0, 'device_aaaaaa111111'),
      emailHlc: const Hlc(10, 1, 'device_aaaaaa111111'),
      passwordHlc: const Hlc(10, 2, 'device_aaaaaa111111'),
    );

    final pushResult = await clientA.syncService.syncNow();
    final pullResult = await clientB.syncService.syncNow();
    final pulledItem = clientB.storage.accounts['account_1'];

    expect(pushResult.success, isTrue);
    expect(pushResult.pushed, isTrue);
    expect(server.currentVersion, 1);
    expect(pullResult.success, isTrue);
    expect(pullResult.pulled, isTrue);
    expect(pulledItem, isNotNull);
    expect(pulledItem!.name, 'Primary Account');
    expect(pulledItem.email, 'owner@example.com');
    expect(pulledItem.data['password'], 'super-secret');
    expect(pulledItem.syncStatus, SyncStatus.synchronized);
    expect(pulledItem.serverVersion, 1);
  });

  test('trusted devices sync TOTP secret and generate the same code', () async {
    final server = await _InMemoryVaultServer.start(vaultId);
    addTearDown(server.close);
    SharedPreferences.setMockInitialValues({'sync_server_url': server.baseUrl});

    final clientA = await _TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_aaaaaa111111',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
    final clientB = await _TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_bbbbbb222222',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );

    final totpConfig = _totpConfig();
    clientA.storage.accounts['account_1'] = _baseItem(
      id: 'account_1',
      name: '2FA Account',
      email: 'owner@example.com',
      password: 'super-secret',
      totpConfig: totpConfig,
      version: 0,
      syncStatus: SyncStatus.pendingPush,
      nameHlc: const Hlc(10, 0, 'device_aaaaaa111111'),
      emailHlc: const Hlc(10, 1, 'device_aaaaaa111111'),
      passwordHlc: const Hlc(10, 2, 'device_aaaaaa111111'),
      totpHlc: const Hlc(10, 3, 'device_aaaaaa111111'),
    );

    final pushResult = await clientA.syncService.syncNow();
    final pullResult = await clientB.syncService.syncNow();
    final pushedItem = clientA.storage.accounts['account_1']!;
    final pulledItem = clientB.storage.accounts['account_1']!;
    final pushedTotp = pushedItem.data['totp_secret']!;
    final pulledTotp = pulledItem.data['totp_secret']!;
    final fixedTime = DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true);
    final pushedCode = const TotpService()
        .generate(TotpService.parseConfig(pushedTotp), at: fixedTime)
        .value;
    final pulledCode = const TotpService()
        .generate(TotpService.parseConfig(pulledTotp), at: fixedTime)
        .value;
    final serverPayload =
        server.getItem('account_1')?['encrypted_signed_payload'] as String?;

    expect(pushResult.success, isTrue);
    expect(pushResult.pushed, isTrue);
    expect(pullResult.success, isTrue);
    expect(pullResult.pulled, isTrue);
    expect(pulledTotp, totpConfig);
    expect(pushedCode, '287082');
    expect(pulledCode, pushedCode);
    expect(pulledItem.syncStatus, SyncStatus.synchronized);
    expect(serverPayload, isNotNull);
    expect(serverPayload, contains('sroy-sync:'));
    expect(serverPayload, isNot(contains('totp_secret')));
    expect(serverPayload, isNot(contains('GEZDGNBVGY3TQOJQ')));
    expect(serverPayload, isNot(contains('otpauth://')));
  });

  test(
    'concurrent edits on two devices merge into a reviewable conflict state',
    () async {
      final server = await _InMemoryVaultServer.start(vaultId);
      addTearDown(server.close);
      SharedPreferences.setMockInitialValues({
        'sync_server_url': server.baseUrl,
      });

      final clientA = await _TestClient.create(
        vaultId: vaultId,
        deviceId: 'device_aaaaaa111111',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      final clientB = await _TestClient.create(
        vaultId: vaultId,
        deviceId: 'device_bbbbbb222222',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );

      clientA.storage.accounts['account_1'] = _baseItem(
        id: 'account_1',
        name: 'Original',
        email: 'owner@example.com',
        password: 'super-secret',
        version: 0,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(10, 0, 'base'),
        emailHlc: const Hlc(10, 1, 'base'),
        passwordHlc: const Hlc(10, 2, 'base'),
      );
      await clientA.syncService.syncNow();
      await clientB.syncService.syncNow();

      clientA.storage.accounts['account_1'] = _baseItem(
        id: 'account_1',
        name: 'Updated By A',
        email: 'owner@example.com',
        password: 'super-secret',
        version: 1,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(20, 0, 'device_aaaaaa111111'),
        emailHlc: const Hlc(10, 1, 'base'),
        passwordHlc: const Hlc(10, 2, 'base'),
      );
      clientB.storage.accounts['account_1'] = _baseItem(
        id: 'account_1',
        name: 'Original',
        email: 'b@example.com',
        password: 'super-secret',
        version: 1,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(10, 0, 'base'),
        emailHlc: const Hlc(30, 0, 'device_bbbbbb222222'),
        passwordHlc: const Hlc(10, 2, 'base'),
      );

      final pushAResult = await clientA.syncService.syncNow();
      final mergeBResult = await clientB.syncService.syncNow();
      final mergedItem = clientB.storage.accounts['account_1']!;
      final conflictLogs =
          clientB.storage.conflictLogs['account_1'] ?? const [];

      expect(pushAResult.success, isTrue);
      expect(pushAResult.pushed, isTrue);
      expect(server.currentVersion, 2);
      expect(mergeBResult.success, isTrue);
      expect(mergeBResult.pulled, isTrue);
      expect(mergedItem.name, 'Updated By A');
      expect(mergedItem.email, 'b@example.com');
      expect(mergedItem.syncStatus, SyncStatus.conflict);
      expect(conflictLogs, isNotEmpty);
      expect(
        conflictLogs.map((log) => log.fieldKey).toSet().contains('email'),
        isTrue,
      );
    },
  );

  test('concurrent TOTP secret edits enter the conflict inbox', () async {
    final server = await _InMemoryVaultServer.start(vaultId);
    addTearDown(server.close);
    SharedPreferences.setMockInitialValues({'sync_server_url': server.baseUrl});

    final clientA = await _TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_aaaaaa111111',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
    final clientB = await _TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_bbbbbb222222',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );

    final initialTotp = _totpConfig(account: 'initial@example.com');
    clientA.storage.accounts['account_1'] = _baseItem(
      id: 'account_1',
      name: '2FA Account',
      email: 'owner@example.com',
      password: 'super-secret',
      totpConfig: initialTotp,
      version: 0,
      syncStatus: SyncStatus.pendingPush,
      nameHlc: const Hlc(10, 0, 'base'),
      emailHlc: const Hlc(10, 1, 'base'),
      passwordHlc: const Hlc(10, 2, 'base'),
      totpHlc: const Hlc(10, 3, 'base'),
    );
    await clientA.syncService.syncNow();
    await clientB.syncService.syncNow();

    final totpFromA = _totpConfig(
      account: 'a@example.com',
      secret: 'JBSWY3DPEHPK3PXP',
    );
    final totpFromB = _totpConfig(
      account: 'b@example.com',
      secret: 'JBSWY3DPEHPK3PXQ',
    );
    clientA.storage.accounts['account_1'] = _baseItem(
      id: 'account_1',
      name: '2FA Account',
      email: 'owner@example.com',
      password: 'super-secret',
      totpConfig: totpFromA,
      version: 1,
      syncStatus: SyncStatus.pendingPush,
      nameHlc: const Hlc(10, 0, 'base'),
      emailHlc: const Hlc(10, 1, 'base'),
      passwordHlc: const Hlc(10, 2, 'base'),
      totpHlc: const Hlc(20, 0, 'device_aaaaaa111111'),
    );
    clientB.storage.accounts['account_1'] = _baseItem(
      id: 'account_1',
      name: '2FA Account',
      email: 'owner@example.com',
      password: 'super-secret',
      totpConfig: totpFromB,
      version: 1,
      syncStatus: SyncStatus.pendingPush,
      nameHlc: const Hlc(10, 0, 'base'),
      emailHlc: const Hlc(10, 1, 'base'),
      passwordHlc: const Hlc(10, 2, 'base'),
      totpHlc: const Hlc(30, 0, 'device_bbbbbb222222'),
    );

    final pushAResult = await clientA.syncService.syncNow();
    final mergeBResult = await clientB.syncService.syncNow();
    final mergedItem = clientB.storage.accounts['account_1']!;
    final conflictLogs = clientB.storage.conflictLogs['account_1'] ?? const [];

    expect(pushAResult.success, isTrue);
    expect(pushAResult.pushed, isTrue);
    expect(mergeBResult.success, isTrue);
    expect(mergeBResult.pulled, isTrue);
    expect(mergedItem.syncStatus, SyncStatus.conflict);
    expect(mergedItem.data['totp_secret'], totpFromB);
    expect(
      conflictLogs.map((log) => log.fieldKey),
      contains('data.totp_secret'),
    );
    expect(
      conflictLogs
          .where((log) => log.fieldKey == 'data.totp_secret')
          .single
          .fieldValue,
      totpFromA,
    );
  });

  test(
    'remote delete wins over an older local modification on another device',
    () async {
      final server = await _InMemoryVaultServer.start(vaultId);
      addTearDown(server.close);
      SharedPreferences.setMockInitialValues({
        'sync_server_url': server.baseUrl,
      });

      final clientA = await _TestClient.create(
        vaultId: vaultId,
        deviceId: 'device_aaaaaa111111',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      final clientB = await _TestClient.create(
        vaultId: vaultId,
        deviceId: 'device_bbbbbb222222',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );

      clientA.storage.accounts['account_1'] = _baseItem(
        id: 'account_1',
        name: 'Original',
        email: 'owner@example.com',
        password: 'super-secret',
        version: 0,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(10, 0, 'base'),
        emailHlc: const Hlc(10, 1, 'base'),
        passwordHlc: const Hlc(10, 2, 'base'),
      );
      await clientA.syncService.syncNow();
      await clientB.syncService.syncNow();

      clientB.storage.accounts['account_1'] = _baseItem(
        id: 'account_1',
        name: 'Edited By B',
        email: 'owner@example.com',
        password: 'super-secret',
        version: 1,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(20, 0, 'device_bbbbbb222222'),
        emailHlc: const Hlc(10, 1, 'base'),
        passwordHlc: const Hlc(10, 2, 'base'),
      );
      clientA.storage.accounts['account_1'] = _baseItem(
        id: 'account_1',
        name: 'Original',
        email: 'owner@example.com',
        password: 'super-secret',
        version: 1,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(10, 0, 'base'),
        emailHlc: const Hlc(10, 1, 'base'),
        passwordHlc: const Hlc(10, 2, 'base'),
        isDeleted: true,
        deleteHlc: const Hlc(30, 0, 'device_aaaaaa111111'),
      );

      final deleteResult = await clientA.syncService.syncNow();
      final reconcileResult = await clientB.syncService.syncNow();
      final finalItem = clientB.storage.accounts['account_1']!;

      expect(deleteResult.success, isTrue);
      expect(deleteResult.pushed, isTrue);
      expect(server.currentVersion, 2);
      expect(reconcileResult.success, isTrue);
      expect(reconcileResult.pulled, isTrue);
      expect(finalItem.isDeleted, isTrue);
      expect(finalItem.deleteHlc, const Hlc(30, 0, 'device_aaaaaa111111'));
      expect(finalItem.syncStatus, SyncStatus.synchronized);
    },
  );

  test(
    'device A keeps an offline edit pending and pushes it after recovery',
    () async {
      final server = await _InMemoryVaultServer.start(vaultId);
      addTearDown(server.close);
      SharedPreferences.setMockInitialValues({
        'sync_server_url': server.baseUrl,
      });

      final clientA = await _TestClient.create(
        vaultId: vaultId,
        deviceId: 'device_aaaaaa111111',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      final clientB = await _TestClient.create(
        vaultId: vaultId,
        deviceId: 'device_bbbbbb222222',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );

      clientA.storage.accounts['account_1'] = _baseItem(
        id: 'account_1',
        name: 'Original',
        email: 'owner@example.com',
        password: 'super-secret',
        version: 0,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(10, 0, 'device_aaaaaa111111'),
        emailHlc: const Hlc(10, 1, 'device_aaaaaa111111'),
        passwordHlc: const Hlc(10, 2, 'device_aaaaaa111111'),
      );
      final initialPush = await clientA.syncService.syncNow();
      final initialPull = await clientB.syncService.syncNow();

      expect(initialPush.success, isTrue, reason: 'seed push from A');
      expect(initialPull.success, isTrue, reason: 'seed pull into B');
      expect(server.currentVersion, 1, reason: 'seed server version');

      server.isUnavailable = true;
      final postCountBeforeOfflineEdit = server.postCount;
      clientA.storage.accounts['account_1'] = _baseItem(
        id: 'account_1',
        name: 'Offline Edit By A',
        email: 'owner@example.com',
        password: 'offline-secret',
        version: 1,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(40, 0, 'device_aaaaaa111111'),
        emailHlc: const Hlc(10, 1, 'device_aaaaaa111111'),
        passwordHlc: const Hlc(45, 0, 'device_aaaaaa111111'),
      );

      final pendingOfflineEdit = clientA.storage.accounts['account_1']!;

      expect(server.currentVersion, 1, reason: 'server did not accept edit');
      expect(
        server.postCount,
        postCountBeforeOfflineEdit,
        reason: 'offline local edit does not contact the server',
      );
      expect(pendingOfflineEdit.syncStatus, SyncStatus.pendingPush);
      expect(pendingOfflineEdit.serverVersion, 1);

      server.isUnavailable = false;
      final recoveryPush = await clientA.syncService.syncNow();
      final recoveredLocal = clientA.storage.accounts['account_1']!;
      final pullAfterRecovery = await clientB.syncService.syncNow();
      final pulledByB = clientB.storage.accounts['account_1']!;

      expect(recoveryPush.success, isTrue, reason: 'A recovery push');
      expect(recoveryPush.pushed, isTrue);
      expect(recoveredLocal.syncStatus, SyncStatus.synchronized);
      expect(recoveredLocal.serverVersion, 2);
      expect(
        server.currentVersion,
        2,
        reason: 'server accepted recovered edit',
      );

      expect(
        pullAfterRecovery.success,
        isTrue,
        reason: 'B pulls recovered edit',
      );
      expect(pullAfterRecovery.pulled, isTrue);
      expect(pulledByB.name, 'Offline Edit By A');
      expect(pulledByB.data['password'], 'offline-secret');
      expect(pulledByB.syncStatus, SyncStatus.synchronized);
      expect(pulledByB.serverVersion, 2);
      expect(clientA.storage.conflictLogs['account_1'], isNull);
      expect(clientB.storage.conflictLogs['account_1'], isNull);
    },
  );
}
