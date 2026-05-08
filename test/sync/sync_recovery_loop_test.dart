import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/local_sync_change.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
import 'package:secret_roy/sync/crdt_merge_engine.dart';
import 'package:secret_roy/sync/sync_payload_codec.dart';
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

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
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

class _StaticVaultServer {
  final String vaultId;
  final HttpServer _server;
  final List<Map<String, dynamic>> items;
  int getCount = 0;
  int postCount = 0;

  _StaticVaultServer._(
    this.vaultId,
    this._server,
    List<Map<String, dynamic>> items,
  ) : items = List<Map<String, dynamic>>.from(items) {
    _server.listen(_handleRequest);
  }

  static Future<_StaticVaultServer> start({
    required String vaultId,
    required List<Map<String, dynamic>> items,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _StaticVaultServer._(vaultId, server, items);
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final expectedPath = '/vaults/$vaultId/sync';

    if (request.method == 'GET' && path == expectedPath) {
      getCount += 1;
      final since = int.parse(request.uri.queryParameters['since'] ?? '0');
      final maxVersion = items.fold<int>(
        0,
        (current, item) => current > (item['version'] as int)
            ? current
            : item['version'] as int,
      );
      final changedItems = items
          .where((item) => (item['version'] as int) > since)
          .toList();
      if (changedItems.isEmpty && maxVersion <= since) {
        request.response.statusCode = HttpStatus.notModified;
        await request.response.close();
        return;
      }

      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'max_version': maxVersion, 'items': changedItems}),
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
      final acceptedVersions = <String, int>{};
      var maxVersion = _maxVersion();
      for (final push in pushes) {
        maxVersion += 1;
        final itemId = push['id'] as String;
        items.removeWhere((item) => item['id'] == itemId);
        items.add({
          'id': itemId,
          'version': maxVersion,
          'is_deleted': push['is_deleted'] == true,
          'encrypted_signed_payload': push['encrypted_signed_payload'],
        });
        acceptedVersions[itemId] = maxVersion;
      }

      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'success': true,
          'max_version': maxVersion,
          'accepted_versions': acceptedVersions,
        }),
      );
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  int _maxVersion() {
    return items.fold<int>(
      0,
      (current, item) =>
          current > (item['version'] as int) ? current : item['version'] as int,
    );
  }
}

IdentityService _identityService({
  required String vaultId,
  required String deviceId,
  required String privateKey,
  required String symmetricKey,
}) {
  return IdentityService(
    secureStorage: _MemorySecureKeyValueStore({
      'device_id': deviceId,
      'vault_id': vaultId,
      'private_key': privateKey,
      'symmetric_key': symmetricKey,
    }),
  );
}

AccountItem _item({
  required String id,
  required String name,
  required int serverVersion,
  required SyncStatus syncStatus,
  String password = 'secret',
  Hlc nameHlc = const Hlc(10, 0, 'device_aaaaaa111111'),
  Hlc emailHlc = const Hlc(10, 1, 'device_aaaaaa111111'),
  Hlc passwordHlc = const Hlc(10, 2, 'device_aaaaaa111111'),
}) {
  return AccountItem(
    id: id,
    name: name,
    email: 'owner@example.com',
    templateId: 'web_account',
    data: {'password': password},
    createdAt: 1,
    nameHlc: nameHlc,
    emailHlc: emailHlc,
    dataHlc: {'password': passwordHlc},
    serverVersion: serverVersion,
    syncStatus: syncStatus,
  );
}

String _recoveryMarker(String phase, {int localVersion = 0}) {
  return jsonEncode({
    'phase': phase,
    'local_version': localVersion,
    'started_at': DateTime.utc(2026, 1, 1).toIso8601String(),
  });
}

void main() {
  SharedPreferences.setMockInitialValues({});

  const vaultId = 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const deviceId = 'device_abcdef123456';
  const privateKey =
      'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const symmetricKey =
      'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  test(
    'sync resumes from a persisted pull marker before continuing normal sync',
    () async {
      final identity = _identityService(
        vaultId: vaultId,
        deviceId: deviceId,
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      await identity.initialize();

      final remoteItem = _item(
        id: 'account_1',
        name: 'Remote Account',
        serverVersion: 1,
        syncStatus: SyncStatus.synchronized,
      );
      final remotePayload = await SyncPayloadCodec.encodeAccount(
        item: remoteItem,
        vaultId: vaultId,
        nodeId: 'device_remote999',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      final server = await _StaticVaultServer.start(
        vaultId: vaultId,
        items: [
          {
            'id': remoteItem.id,
            'version': 1,
            'is_deleted': false,
            'encrypted_signed_payload': remotePayload,
          },
        ],
      );
      addTearDown(server.close);

      final storage = _FakeSecureStorageService()
        ..settings['sync_version_$vaultId'] = '0'
        ..settings['sync_recovery_$vaultId'] = _recoveryMarker('pull');

      final syncService = SyncService(
        storageService: storage,
        identityService: identity,
        config: SyncConfig(serverUrl: server.baseUrl),
      );
      await syncService.initialize();

      expect(syncService.recoveryPhase, 'pull');

      final result = await syncService.syncNow();
      final recoveredItem = storage.accounts['account_1'];

      expect(result.success, isTrue);
      expect(result.pulled, isTrue);
      expect(result.notice, contains('Recovered from an interrupted pull'));
      expect(recoveredItem, isNotNull);
      expect(recoveredItem!.name, 'Remote Account');
      expect(recoveredItem.syncStatus, SyncStatus.synchronized);
      expect(recoveredItem.serverVersion, 1);
      expect(storage.settings['sync_recovery_$vaultId'], isEmpty);
      expect(server.getCount, greaterThanOrEqualTo(1));
    },
  );

  test(
    'sync resumes from a persisted push marker by snapshotting instead of re-pushing',
    () async {
      final identity = _identityService(
        vaultId: vaultId,
        deviceId: deviceId,
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      await identity.initialize();

      final acceptedItem = _item(
        id: 'account_1',
        name: 'Accepted Once',
        serverVersion: 1,
        syncStatus: SyncStatus.pendingPush,
      );
      final acceptedPayload = await SyncPayloadCodec.encodeAccount(
        item: acceptedItem.copyWith(
          serverVersion: 1,
          syncStatus: SyncStatus.synchronized,
        ),
        vaultId: vaultId,
        nodeId: 'device_remote999',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      final server = await _StaticVaultServer.start(
        vaultId: vaultId,
        items: [
          {
            'id': acceptedItem.id,
            'version': 1,
            'is_deleted': false,
            'encrypted_signed_payload': acceptedPayload,
          },
        ],
      );
      addTearDown(server.close);

      final storage = _FakeSecureStorageService()
        ..settings['sync_version_$vaultId'] = '0'
        ..settings['sync_recovery_$vaultId'] = _recoveryMarker('push')
        ..accounts['account_1'] = acceptedItem;

      final syncService = SyncService(
        storageService: storage,
        identityService: identity,
        config: SyncConfig(serverUrl: server.baseUrl),
      );
      await syncService.initialize();

      final result = await syncService.syncNow();
      final recoveredItem = storage.accounts['account_1']!;

      expect(result.success, isTrue);
      expect(result.pulled, isTrue);
      expect(result.pushed, isFalse);
      expect(result.notice, contains('interrupted push'));
      expect(recoveredItem.syncStatus, SyncStatus.synchronized);
      expect(recoveredItem.serverVersion, 1);
      expect(storage.settings['sync_recovery_$vaultId'], isEmpty);
      expect(server.postCount, 0);
    },
  );

  test(
    'interrupted pull with no newer remote data keeps local edits pushable',
    () async {
      final identity = _identityService(
        vaultId: vaultId,
        deviceId: deviceId,
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      await identity.initialize();

      final remoteBase = _item(
        id: 'account_1',
        name: 'Original Remote',
        serverVersion: 1,
        syncStatus: SyncStatus.synchronized,
      );
      final remotePayload = await SyncPayloadCodec.encodeAccount(
        item: remoteBase,
        vaultId: vaultId,
        nodeId: 'device_remote999',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      final server = await _StaticVaultServer.start(
        vaultId: vaultId,
        items: [
          {
            'id': remoteBase.id,
            'version': 1,
            'is_deleted': false,
            'encrypted_signed_payload': remotePayload,
          },
        ],
      );
      addTearDown(server.close);

      final storage = _FakeSecureStorageService()
        ..settings['sync_version_$vaultId'] = '1'
        ..settings['sync_recovery_$vaultId'] = _recoveryMarker(
          'pull',
          localVersion: 1,
        )
        ..accounts['account_1'] = _item(
          id: 'account_1',
          name: 'Local Offline Edit',
          password: 'local-secret',
          serverVersion: 1,
          syncStatus: SyncStatus.pendingPush,
          nameHlc: const Hlc(40, 0, 'device_abcdef123456'),
          passwordHlc: const Hlc(45, 0, 'device_abcdef123456'),
        );

      final syncService = SyncService(
        storageService: storage,
        identityService: identity,
        config: SyncConfig(serverUrl: server.baseUrl),
      );
      await syncService.initialize();

      final result = await syncService.syncNow();
      final recoveredItem = storage.accounts['account_1']!;

      expect(result.success, isTrue);
      expect(result.pushed, isTrue);
      expect(result.conflictCount, 0);
      expect(result.notice, contains('interrupted pull'));
      expect(recoveredItem.name, 'Local Offline Edit');
      expect(recoveredItem.data['password'], 'local-secret');
      expect(recoveredItem.syncStatus, SyncStatus.synchronized);
      expect(recoveredItem.serverVersion, 2);
      expect(storage.conflictLogs['account_1'], isNull);
      expect(storage.settings['sync_recovery_$vaultId'], isEmpty);
      expect(server.postCount, 1);
    },
  );

  test('successful sync clears the persisted recovery marker', () async {
    final identity = _identityService(
      vaultId: vaultId,
      deviceId: deviceId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
    await identity.initialize();

    final server = await _StaticVaultServer.start(
      vaultId: vaultId,
      items: const [],
    );
    addTearDown(server.close);

    final storage = _FakeSecureStorageService()
      ..settings['sync_version_$vaultId'] = '0'
      ..accounts['account_1'] = _item(
        id: 'account_1',
        name: 'Fresh Local',
        serverVersion: 0,
        syncStatus: SyncStatus.pendingPush,
      );

    final syncService = SyncService(
      storageService: storage,
      identityService: identity,
      config: SyncConfig(serverUrl: server.baseUrl),
    );
    await syncService.initialize();

    final result = await syncService.syncNow();

    expect(result.success, isTrue);
    expect(storage.settings['sync_recovery_$vaultId'], isEmpty);
  });
}
