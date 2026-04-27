import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
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
  Future<List<AccountTemplate>> loadDirtyTemplates() async => [];
}

class _StaticVaultServer {
  final String vaultId;
  final HttpServer _server;
  final List<Map<String, dynamic>> items;
  int getCount = 0;
  int postCount = 0;

  _StaticVaultServer._(this.vaultId, this._server, this.items) {
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
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'success': true,
          'max_version': items.fold<int>(
            0,
            (current, item) => current > (item['version'] as int)
                ? current
                : item['version'] as int,
          ),
          'accepted_versions': const <String, int>{},
        }),
      );
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
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
}) {
  return AccountItem(
    id: id,
    name: name,
    email: 'owner@example.com',
    templateId: 'web_account',
    data: {'password': 'secret'},
    createdAt: 1,
    nameHlc: const Hlc(10, 0, 'device_aaaaaa111111'),
    emailHlc: const Hlc(10, 1, 'device_aaaaaa111111'),
    dataHlc: {'password': const Hlc(10, 2, 'device_aaaaaa111111')},
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
      final server = await _StaticVaultServer.start(
        vaultId: vaultId,
        items: [
          {
            'id': remoteItem.id,
            'version': 1,
            'is_deleted': false,
            'encrypted_signed_payload': SyncPayloadCodec.encode(
              item: remoteItem,
              vaultId: vaultId,
              nodeId: 'device_remote999',
              privateKey: privateKey,
              symmetricKey: symmetricKey,
            ),
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
      final server = await _StaticVaultServer.start(
        vaultId: vaultId,
        items: [
          {
            'id': acceptedItem.id,
            'version': 1,
            'is_deleted': false,
            'encrypted_signed_payload': SyncPayloadCodec.encode(
              item: acceptedItem.copyWith(
                serverVersion: 1,
                syncStatus: SyncStatus.synchronized,
              ),
              vaultId: vaultId,
              nodeId: 'device_remote999',
              privateKey: privateKey,
              symmetricKey: symmetricKey,
            ),
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

  test('successful sync clears the persisted recovery marker', () async {
    final identity = _identityService(
      vaultId: vaultId,
      deviceId: deviceId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
    await identity.initialize();

    final server = await _StaticVaultServer.start(vaultId: vaultId, items: const []);
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
