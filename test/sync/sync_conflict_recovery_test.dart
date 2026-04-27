import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
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

      final remotePayload = SyncPayloadCodec.encode(
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
}
