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

const _vaultId = 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _deviceId = 'device_abcdef123456';
const _privateKey =
    'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _symmetricKey =
    'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

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

AccountItem _localPendingItem() {
  return AccountItem(
    id: 'account_1',
    name: 'Local Name',
    email: 'old@example.com',
    templateId: 'web_account',
    data: {'password': 'local-secret'},
    createdAt: 1,
    nameHlc: const Hlc(40, 0, 'local'),
    emailHlc: const Hlc(20, 0, 'local'),
    dataHlc: {'password': const Hlc(20, 0, 'local')},
    serverVersion: 1,
    syncStatus: SyncStatus.pendingPush,
  );
}

AccountItem _remoteItem() {
  return AccountItem(
    id: 'account_1',
    name: 'Remote Name',
    email: 'remote@example.com',
    templateId: 'web_account',
    data: {'password': 'remote-secret'},
    createdAt: 1,
    nameHlc: const Hlc(30, 0, 'remote'),
    emailHlc: const Hlc(50, 0, 'remote'),
    dataHlc: {'password': const Hlc(50, 0, 'remote')},
    serverVersion: 2,
    syncStatus: SyncStatus.synchronized,
  );
}

AccountItem _remoteDeletedItem() {
  return AccountItem(
    id: 'account_1',
    name: 'Remote Deleted',
    email: 'remote@example.com',
    templateId: 'web_account',
    data: {'password': 'remote-secret'},
    createdAt: 1,
    nameHlc: const Hlc(30, 0, 'remote'),
    emailHlc: const Hlc(30, 1, 'remote'),
    dataHlc: {'password': const Hlc(30, 2, 'remote')},
    serverVersion: 2,
    syncStatus: SyncStatus.synchronized,
    isDeleted: true,
    deleteHlc: const Hlc(80, 0, 'remote'),
  );
}

class _ConflictScenarioResult {
  final SyncResult result;
  final _FakeSecureStorageService storage;

  const _ConflictScenarioResult({required this.result, required this.storage});
}

Future<_ConflictScenarioResult> _runConflictScenario({
  required String conflictType,
  required AccountItem localItem,
  AccountItem? remoteItem,
  int localVersion = 1,
  int remoteVersion = 2,
}) async {
  final identity = _identityService(
    vaultId: _vaultId,
    deviceId: _deviceId,
    privateKey: _privateKey,
    symmetricKey: _symmetricKey,
  );
  await identity.initialize();

  final storage = _FakeSecureStorageService()
    ..settings['sync_version_$_vaultId'] = '$localVersion'
    ..accounts[localItem.id] = localItem;

  final remotePayload = remoteItem == null
      ? null
      : await SyncPayloadCodec.encode(
          item: remoteItem,
          vaultId: _vaultId,
          nodeId: 'device_remote999',
          privateKey: _privateKey,
          symmetricKey: _symmetricKey,
        );

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() async {
    await server.close(force: true);
  });

  server.listen((request) async {
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/vaults/$_vaultId/sync') {
      final since = int.parse(request.uri.queryParameters['since'] ?? '0');
      if (since > 0) {
        request.response.statusCode = HttpStatus.notModified;
        await request.response.close();
        return;
      }

      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'max_version': remoteItem == null ? 0 : remoteVersion,
          'items': [
            if (remoteItem != null)
              {
                'id': remoteItem.id,
                'version': remoteVersion,
                'is_deleted': remoteItem.isDeleted,
                'encrypted_signed_payload': remotePayload,
              },
          ],
        }),
      );
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && path == '/vaults/$_vaultId/sync') {
      request.response.statusCode = HttpStatus.conflict;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'error': 'Conflict detected on item ${localItem.id}',
          'conflict_type': conflictType,
          'item_id': localItem.id,
          'your_base': localItem.serverVersion,
          'server_actual': remoteItem == null ? 0 : remoteVersion,
          'server_is_deleted': remoteItem?.isDeleted == true,
        }),
      );
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  });

  SharedPreferences.setMockInitialValues({
    'sync_server_url': 'http://127.0.0.1:${server.port}',
  });

  final syncService = SyncService(
    storageService: storage,
    identityService: identity,
  );
  await syncService.initialize();

  return _ConflictScenarioResult(
    result: await syncService.syncNow(),
    storage: storage,
  );
}

void main() {
  test(
    'stale base conflict pulls remote changes and leaves a reviewable conflict',
    () async {
      const vaultId = 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const deviceId = 'device_abcdef123456';
      const privateKey =
          'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const symmetricKey =
          'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

      final identity = _identityService(
        vaultId: vaultId,
        deviceId: deviceId,
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      await identity.initialize();

      final storage = _FakeSecureStorageService()
        ..settings['sync_version_$vaultId'] = '1'
        ..accounts['account_1'] = _localPendingItem();

      final remotePayload = await SyncPayloadCodec.encode(
        item: _remoteItem(),
        vaultId: vaultId,
        nodeId: 'device_remote999',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        final path = request.uri.path;
        if (request.method == 'GET' && path == '/vaults/$vaultId/sync') {
          final since = int.parse(request.uri.queryParameters['since'] ?? '0');
          if (since > 0) {
            request.response.statusCode = HttpStatus.notModified;
            await request.response.close();
            return;
          }

          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'max_version': 2,
              'items': [
                {
                  'id': 'account_1',
                  'version': 2,
                  'is_deleted': false,
                  'encrypted_signed_payload': remotePayload,
                },
              ],
            }),
          );
          await request.response.close();
          return;
        }

        if (request.method == 'POST' && path == '/vaults/$vaultId/sync') {
          request.response.statusCode = HttpStatus.conflict;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'error': 'Conflict detected on item account_1',
              'conflict_type': 'stale_base_version',
              'item_id': 'account_1',
              'your_base': 1,
              'server_actual': 2,
              'server_is_deleted': false,
            }),
          );
          await request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      SharedPreferences.setMockInitialValues({
        'sync_server_url': 'http://127.0.0.1:${server.port}',
      });

      final syncService = SyncService(
        storageService: storage,
        identityService: identity,
      );
      await syncService.initialize();

      final result = await syncService.syncNow();
      final finalItem = storage.accounts['account_1']!;
      final finalLogs = storage.conflictLogs['account_1'] ?? const [];

      expect(result.success, isTrue);
      expect(result.conflictCount, greaterThan(0));
      expect(result.notice, contains('Remote changes were merged locally'));
      expect(finalItem.syncStatus, SyncStatus.conflict);
      expect(finalItem.name, 'Local Name');
      expect(finalItem.email, 'remote@example.com');
      expect(finalItem.data['password'], 'remote-secret');
      expect(finalLogs, isNotEmpty);
    },
  );

  test(
    'remote missing conflict creates an inbox decision without retry failure',
    () async {
      final scenario = await _runConflictScenario(
        conflictType: 'remote_missing',
        localItem: _localPendingItem().copyWith(serverVersion: 3),
        remoteItem: null,
        localVersion: 3,
        remoteVersion: 0,
      );
      final finalItem = scenario.storage.accounts['account_1']!;
      final logs = scenario.storage.conflictLogs['account_1'] ?? const [];

      expect(scenario.result.success, isTrue);
      expect(scenario.result.conflictCount, 1);
      expect(scenario.result.notice, contains('Remote record missing'));
      expect(finalItem.syncStatus, SyncStatus.synchronized);
      expect(finalItem.serverVersion, 0);
      expect(logs.single.fieldKey, 'record.remote_missing');
    },
  );

  test(
    'concurrent edit conflict pulls latest data and leaves field decisions',
    () async {
      final scenario = await _runConflictScenario(
        conflictType: 'concurrent_edit',
        localItem: _localPendingItem().copyWith(serverVersion: 0),
        remoteItem: _remoteItem(),
        localVersion: 1,
      );
      final finalItem = scenario.storage.accounts['account_1']!;
      final logs = scenario.storage.conflictLogs['account_1'] ?? const [];

      expect(scenario.result.success, isTrue);
      expect(scenario.result.conflictCount, greaterThan(0));
      expect(scenario.result.notice, contains('Concurrent remote edits'));
      expect(finalItem.syncStatus, SyncStatus.conflict);
      expect(finalItem.name, 'Local Name');
      expect(finalItem.email, 'remote@example.com');
      expect(logs.map((log) => log.fieldKey), contains('name'));
    },
  );

  test(
    'concurrent delete conflict accepts a winning remote tombstone with notice',
    () async {
      final scenario = await _runConflictScenario(
        conflictType: 'concurrent_delete',
        localItem: _localPendingItem(),
        remoteItem: _remoteDeletedItem(),
      );
      final finalItem = scenario.storage.accounts['account_1']!;

      expect(scenario.result.success, isTrue);
      expect(scenario.result.notice, contains('Remote delete was accepted'));
      expect(finalItem.isDeleted, isTrue);
      expect(finalItem.deleteHlc, const Hlc(80, 0, 'remote'));
      expect(finalItem.syncStatus, SyncStatus.synchronized);
    },
  );
}
