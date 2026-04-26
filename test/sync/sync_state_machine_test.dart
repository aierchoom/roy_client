import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
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
  Future<List<AccountItem>> loadPendingSyncAccounts() async {
    return accounts.values
        .where((item) => item.syncStatus == SyncStatus.pendingPush)
        .toList();
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
}

IdentityService _identityService() {
  return IdentityService(
    secureStorage: _MemorySecureKeyValueStore({
      'device_id': 'device_abcdef123456',
      'vault_id': 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'private_key':
          'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'symmetric_key':
          'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    }),
  );
}

AccountItem _pendingItem() {
  return AccountItem(
    id: 'account_1',
    name: 'Local Name',
    email: 'owner@example.com',
    templateId: 'web_account',
    data: const {'password': 'secret'},
    createdAt: 1,
    nameHlc: const Hlc(10, 0, 'device_abcdef123456'),
    emailHlc: const Hlc(10, 1, 'device_abcdef123456'),
    dataHlc: const {'password': Hlc(10, 2, 'device_abcdef123456')},
    serverVersion: 0,
    syncStatus: SyncStatus.pendingPush,
  );
}

class _SyncProbeServer {
  final HttpServer _server;
  final Completer<void>? _gate;
  final int getStatusCode;
  final String? getError;
  final int postStatusCode;
  final String? postError;
  int getCount = 0;
  int postCount = 0;

  _SyncProbeServer._(
    this._server,
    this._gate, {
    required this.getStatusCode,
    required this.getError,
    required this.postStatusCode,
    required this.postError,
  }) {
    _server.listen(_handleRequest);
  }

  static Future<_SyncProbeServer> start({
    Completer<void>? gate,
    int getStatusCode = 200,
    String? getError,
    int postStatusCode = 200,
    String? postError,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _SyncProbeServer._(
      server,
      gate,
      getStatusCode: getStatusCode,
      getError: getError,
      postStatusCode: postStatusCode,
      postError: postError,
    );
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (_gate != null) {
      await _gate.future;
    }

    if (request.method == 'GET' && request.uri.path.endsWith('/sync')) {
      getCount += 1;
      request.response.statusCode = getStatusCode;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        getStatusCode == 200
            ? jsonEncode({'max_version': 0, 'items': const <dynamic>[]})
            : jsonEncode({'error': getError ?? 'Pull failed'}),
      );
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && request.uri.path.endsWith('/sync')) {
      postCount += 1;
      request.response.statusCode = postStatusCode;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        postStatusCode == 200
            ? jsonEncode({
                'success': true,
                'max_version': 0,
                'accepted_versions': const <String, int>{},
              })
            : jsonEncode({'error': postError ?? 'Push failed'}),
      );
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }
}

void main() {
  SharedPreferences.setMockInitialValues({});

  test('syncNow sets error state when sync server URL is missing', () async {
    final identity = _identityService();
    await identity.initialize();

    final syncService = SyncService(
      storageService: _FakeSecureStorageService(),
      identityService: identity,
      config: const SyncConfig(serverUrl: ''),
    );
    addTearDown(syncService.dispose);
    await syncService.initialize();

    final result = await syncService.syncNow();

    expect(result.success, isFalse);
    expect(result.error, 'Sync server URL not configured.');
    expect(syncService.state, SyncState.error);
    expect(syncService.errorMessage, 'Sync server URL not configured.');
    expect(
      syncService.statusNote,
      'Set a sync server address before trying again.',
    );
  });

  test(
    'connect reuses setup guidance when sync server URL is missing',
    () async {
      final identity = _identityService();
      await identity.initialize();

      final syncService = SyncService(
        storageService: _FakeSecureStorageService(),
        identityService: identity,
        config: const SyncConfig(serverUrl: ''),
      );
      addTearDown(syncService.dispose);
      await syncService.initialize();

      final connected = await syncService.connect();

      expect(connected, isFalse);
      expect(syncService.state, SyncState.error);
      expect(syncService.errorMessage, 'Sync server URL not configured.');
      expect(
        syncService.statusNote,
        'Set a sync server address before trying again.',
      );
    },
  );

  test('connect stays in syncing until the first sync finishes', () async {
    final identity = _identityService();
    await identity.initialize();

    final gate = Completer<void>();
    final server = await _SyncProbeServer.start(gate: gate);
    addTearDown(server.close);

    final syncService = SyncService(
      storageService: _FakeSecureStorageService(),
      identityService: identity,
      config: SyncConfig(serverUrl: server.baseUrl),
    );
    addTearDown(syncService.dispose);
    await syncService.initialize();

    final connectFuture = syncService.connect();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(syncService.state, SyncState.syncing);
    expect(syncService.isConnected, isTrue);

    gate.complete();
    final connected = await connectFuture;

    expect(connected, isTrue);
    expect(syncService.state, SyncState.synced);
    expect(syncService.statusNote, 'Already up to date.');
    expect(server.getCount, greaterThanOrEqualTo(1));
  });

  test(
    'connect returns false and leaves the service offline on transport failure',
    () async {
      final identity = _identityService();
      await identity.initialize();

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUrl = 'http://127.0.0.1:${server.port}';
      await server.close(force: true);

      final syncService = SyncService(
        storageService: _FakeSecureStorageService(),
        identityService: identity,
        config: SyncConfig(serverUrl: baseUrl),
      );
      addTearDown(syncService.dispose);
      await syncService.initialize();

      final connected = await syncService.connect();

      expect(connected, isFalse);
      expect(syncService.state, SyncState.offline);
      expect(syncService.isConnected, isFalse);
      expect(
        syncService.statusNote,
        'Cannot reach the sync server. Verify the address and network path.',
      );
    },
  );

  test(
    'syncNow surfaces server persistence errors from pull responses',
    () async {
      final identity = _identityService();
      await identity.initialize();

      final server = await _SyncProbeServer.start(
        getStatusCode: 503,
        getError:
            'Vault file is unreadable: vault_vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.json',
      );
      addTearDown(server.close);

      final syncService = SyncService(
        storageService: _FakeSecureStorageService(),
        identityService: identity,
        config: SyncConfig(serverUrl: server.baseUrl),
      );
      addTearDown(syncService.dispose);
      await syncService.initialize();

      final result = await syncService.syncNow();

      expect(result.success, isFalse);
      expect(result.error, contains('Vault file is unreadable'));
      expect(syncService.state, SyncState.error);
      expect(syncService.errorMessage, contains('Pull HTTP 503'));
      expect(result.error, syncService.statusNote);
    },
  );

  test(
    'syncNow surfaces server persistence errors from push responses',
    () async {
      final identity = _identityService();
      await identity.initialize();

      final storage = _FakeSecureStorageService()
        ..accounts['account_1'] = _pendingItem();
      final server = await _SyncProbeServer.start(
        postStatusCode: 503,
        postError:
            'Failed to persist vault vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      addTearDown(server.close);

      final syncService = SyncService(
        storageService: storage,
        identityService: identity,
        config: SyncConfig(serverUrl: server.baseUrl),
      );
      addTearDown(syncService.dispose);
      await syncService.initialize();

      final result = await syncService.syncNow();

      expect(result.success, isFalse);
      expect(result.error, contains('Failed to persist vault'));
      expect(syncService.state, SyncState.error);
      expect(syncService.errorMessage, contains('Push HTTP 503'));
      expect(result.error, syncService.statusNote);
      expect(server.postCount, 1);
    },
  );

  test('successful push leaves a stable success note for the UI', () async {
    final identity = _identityService();
    await identity.initialize();

    final storage = _FakeSecureStorageService()
      ..accounts['account_1'] = _pendingItem();
    final server = await _SyncProbeServer.start();
    addTearDown(server.close);

    final syncService = SyncService(
      storageService: storage,
      identityService: identity,
      config: SyncConfig(serverUrl: server.baseUrl),
    );
    addTearDown(syncService.dispose);
    await syncService.initialize();

    final result = await syncService.syncNow();

    expect(result.success, isTrue);
    expect(result.pushed, isTrue);
    expect(syncService.state, SyncState.synced);
    expect(syncService.statusNote, 'Pushed local changes.');
  });
}
