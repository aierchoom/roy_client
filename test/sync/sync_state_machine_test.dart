import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/local_sync_change.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/totp_service.dart';
import 'package:secret_roy/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_server_test_harness.dart';

/// 扩展 [FakeSecureStorageService]，增加状态机测试所需的观察与控制字段。
class _FakeSecureStorageService extends FakeSecureStorageService {
  final List<String> pushedLocalSyncChangeIds = [];
  final Map<String, int> refreshedBaseVersions = {};
  FutureOr<void> Function(Iterable<String> ids)? onMarkPushing;
  List<LocalSyncChange>? approvedChangesOverride;
  bool autoApprovePending = true;

  @override
  Future<List<LocalSyncChange>> loadApprovedLocalSyncChanges({
    required String vaultId,
  }) async {
    if (approvedChangesOverride != null) {
      return approvedChangesOverride!;
    }
    if (!autoApprovePending) return [];
    return super.loadApprovedLocalSyncChanges(vaultId: vaultId);
  }

  @override
  Future<bool> hasOpenLocalSyncChanges(String vaultId) async {
    if (!autoApprovePending) {
      return accounts.values.any(
            (item) => item.syncStatus == SyncStatus.pendingPush,
          ) ||
          totpCredentials.values.any(
            (item) => item.syncStatus == SyncStatus.pendingPush,
          );
    }
    return super.hasOpenLocalSyncChanges(vaultId);
  }

  @override
  Future<void> markLocalSyncChangesPushing(Iterable<String> ids) async {
    final callback = onMarkPushing;
    if (callback != null) {
      await callback(ids);
    }
  }

  @override
  Future<void> markLocalSyncChangesPushed(Iterable<String> ids) async {
    pushedLocalSyncChangeIds.addAll(ids);
  }

  @override
  Future<void> refreshOpenLocalSyncChangeBaseVersion({
    required String vaultId,
    required LocalSyncEntityType entityType,
    required String entityId,
    required int baseServerVersion,
  }) async {
    refreshedBaseVersions['${entityType.name}:$entityId'] = baseServerVersion;
  }
}

AccountItem _pendingItem() {
  return baseItem(
    id: 'account_1',
    name: 'Local Name',
    email: 'owner@example.com',
    password: 'secret',
    version: 0,
    syncStatus: SyncStatus.pendingPush,
    nameHlc: const Hlc(10, 0, 'device_abcdef123456'),
    emailHlc: const Hlc(10, 1, 'device_abcdef123456'),
    passwordHlc: const Hlc(10, 2, 'device_abcdef123456'),
  );
}

TotpCredential _pendingTotpCredential({required String config}) {
  return baseTotpCredential(
    id: 'totp_1',
    label: 'Example',
    config: config,
    version: 0,
    syncStatus: SyncStatus.pendingPush,
    labelHlc: const Hlc(10, 0, 'device_abcdef123456'),
    configHlc: const Hlc(10, 1, 'device_abcdef123456'),
    linksHlc: const Hlc(10, 2, 'device_abcdef123456'),
  );
}

String _totpConfig() {
  return totpConfig(secret: 'JBSWY3DPEHPK3PXP');
}

IdentityService _identityService() {
  return IdentityService(
    secureStorage: MemorySecureKeyValueStore({
      'device_id': 'device_abcdef123456',
      'vault_id': 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'private_key':
          'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'symmetric_key':
          'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    }),
  );
}

class _SyncProbeServer {
  final HttpServer _server;
  final Completer<void>? _gate;
  final int getStatusCode;
  final String? getError;
  final String? getBody;
  final int postStatusCode;
  final String? postError;
  final String? postBody;
  int getCount = 0;
  int postCount = 0;
  String? lastPostBody;

  _SyncProbeServer._(
    this._server,
    this._gate, {
    required this.getStatusCode,
    required this.getError,
    required this.getBody,
    required this.postStatusCode,
    required this.postError,
    required this.postBody,
  }) {
    _server.listen(_handleRequest);
  }

  static Future<_SyncProbeServer> start({
    Completer<void>? gate,
    int getStatusCode = 200,
    String? getError,
    String? getBody,
    int postStatusCode = 200,
    String? postError,
    String? postBody,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _SyncProbeServer._(
      server,
      gate,
      getStatusCode: getStatusCode,
      getError: getError,
      getBody: getBody,
      postStatusCode: postStatusCode,
      postError: postError,
      postBody: postBody,
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
        getBody ??
            (getStatusCode == 200
                ? jsonEncode({'max_version': 0, 'items': const <dynamic>[]})
                : jsonEncode({'error': getError ?? 'Pull failed'})),
      );
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && request.uri.path.endsWith('/sync')) {
      postCount += 1;
      lastPostBody = await utf8.decoder.bind(request).join();
      request.response.statusCode = postStatusCode;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        postBody ??
            (postStatusCode == 200
                ? _defaultPostSuccessBody()
                : jsonEncode({'error': postError ?? 'Push failed'})),
      );
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  String _defaultPostSuccessBody() {
    final decoded = jsonDecode(lastPostBody ?? '{}');
    final pushes = decoded is Map
        ? (decoded['pushes'] as List<dynamic>? ?? const <dynamic>[])
        : const <dynamic>[];
    final acceptedVersions = <String, int>{};
    for (final push in pushes) {
      if (push is Map && push['id'] is String) {
        acceptedVersions[push['id'] as String] = acceptedVersions.length + 1;
      }
    }
    return jsonEncode({
      'success': true,
      'max_version': acceptedVersions.length,
      'accepted_versions': acceptedVersions,
    });
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
    expect(syncService.state, SyncState.networkUnreachable);
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
      expect(syncService.state, SyncState.networkUnreachable);
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

    expect(syncService.isSyncing, isTrue);
    expect(syncService.isConnected, isTrue);

    gate.complete();
    final connected = await connectFuture;

    expect(connected, isTrue);
    expect(syncService.state, SyncState.idle);
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
      expect(syncService.state, SyncState.networkUnreachable);
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
      expect(syncService.state, SyncState.serverError);
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
      expect(syncService.state, SyncState.serverError);
      expect(syncService.errorMessage, contains('Push HTTP 503'));
      expect(result.error, syncService.statusNote);
      expect(server.postCount, 1);
    },
  );

  test(
    'syncNow surfaces invalid payload conflict types from push responses',
    () async {
      final identity = _identityService();
      await identity.initialize();

      final storage = _FakeSecureStorageService()
        ..accounts['account_1'] = _pendingItem();
      final server = await _SyncProbeServer.start(
        postStatusCode: 400,
        postBody: jsonEncode({
          'error': 'Invalid encrypted payload envelope for item account_1',
          'conflict_type': 'invalid_payload',
          'item_id': 'account_1',
        }),
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
      expect(result.error, contains('Invalid encrypted payload envelope'));
      expect(syncService.state, SyncState.protocolError);
      expect(syncService.errorMessage, contains('Sync payload rejected'));
      expect(
        syncService.statusNote,
        'The sync server rejected a local encrypted payload. Reopen the item and retry; inspect client logs if it repeats.',
      );
      expect(server.postCount, 1);
    },
  );

  test('syncNow rejects malformed pull responses before pushing', () async {
    final identity = _identityService();
    await identity.initialize();

    final server = await _SyncProbeServer.start(
      getBody: jsonEncode({'max_version': 'bad', 'items': const <dynamic>[]}),
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
    expect(result.error, contains('pull response max_version'));
    expect(syncService.state, SyncState.protocolError);
    expect(syncService.errorMessage, contains('Sync protocol invalid'));
    expect(server.postCount, 0);
  });

  test(
    'syncNow rejects malformed push acknowledgements without marking clean',
    () async {
      final identity = _identityService();
      await identity.initialize();

      final storage = _FakeSecureStorageService()
        ..accounts['account_1'] = _pendingItem();
      final server = await _SyncProbeServer.start(
        postBody: jsonEncode({
          'success': true,
          'accepted_versions': {'account_1': 'bad'},
        }),
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
      expect(result.error, contains('accepted version for account_1'));
      expect(storage.accounts['account_1']!.syncStatus, SyncStatus.pendingPush);
      expect(server.postCount, 1);
    },
  );

  test(
    'syncNow rejects push acknowledgements missing accepted item versions',
    () async {
      final identity = _identityService();
      await identity.initialize();

      final storage = _FakeSecureStorageService()
        ..accounts['account_1'] = _pendingItem();
      final server = await _SyncProbeServer.start(
        postBody: jsonEncode({
          'success': true,
          'max_version': 2,
          'accepted_versions': const <String, int>{},
        }),
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
      expect(
        result.error,
        contains('push response missing accepted version for account_1'),
      );
      expect(storage.accounts['account_1']!.syncStatus, SyncStatus.pendingPush);
      expect(server.postCount, 1);
    },
  );

  test('accepted push preserves local edits made while pushing', () async {
    final identity = _identityService();
    await identity.initialize();

    final original = _pendingItem();
    final storage = _FakeSecureStorageService()
      ..accounts[original.id] = original;
    storage.onMarkPushing = (_) {
      storage.accounts[original.id] = original.copyWith(
        name: 'Edited During Push',
        nameHlc: const Hlc(20, 0, 'device_abcdef123456'),
        syncStatus: SyncStatus.pendingPush,
      );
    };
    final server = await _SyncProbeServer.start(
      postBody: jsonEncode({
        'success': true,
        'max_version': 2,
        'accepted_versions': {original.id: 2},
      }),
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
    final saved = storage.accounts[original.id]!;

    expect(result.success, isTrue);
    expect(saved.name, 'Edited During Push');
    expect(saved.serverVersion, 2);
    expect(saved.syncStatus, SyncStatus.pendingPush);
    expect(storage.pushedLocalSyncChangeIds, ['change_${original.id}']);
    expect(storage.refreshedBaseVersions['account:${original.id}'], 2);
  });

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
    expect(syncService.state, SyncState.idle);
    expect(syncService.statusNote, 'Pushed local changes.');
  });

  test(
    'approved outbox status updates are scoped by entity type and id',
    () async {
      final identity = _identityService();
      await identity.initialize();
      final vaultId = identity.vaultId;

      final account = _pendingItem();
      final storage = _FakeSecureStorageService()
        ..accounts[account.id] = account
        ..templates[account.id] = cleanTemplateWithId(account.id)
        ..approvedChangesOverride = [
          approvedChange(vaultId, account),
          approvedTemplateChange(vaultId, cleanTemplateWithId(account.id)),
        ];
      final server = await _SyncProbeServer.start(
        postBody: jsonEncode({
          'success': true,
          'max_version': 2,
          'accepted_versions': {account.id: 2},
        }),
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

      expect(result.success, isTrue);
      expect(storage.pushedLocalSyncChangeIds, ['change_${account.id}']);
      expect(
        storage.pushedLocalSyncChangeIds,
        isNot(contains('template_change_${account.id}')),
      );
    },
  );

  test('syncNow does not push unapproved local changes', () async {
    final identity = _identityService();
    await identity.initialize();

    final storage = _FakeSecureStorageService()
      ..autoApprovePending = false
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
    expect(result.pushed, isFalse);
    expect(server.postCount, 0);
    expect(storage.accounts['account_1']!.syncStatus, SyncStatus.pendingPush);
    expect(syncService.isDirty, isTrue);
    expect(
      syncService.statusNote,
      'Local changes are waiting for review before push.',
    );
  });

  test('syncNow does not push unapproved 2FA credential changes', () async {
    final identity = _identityService();
    await identity.initialize();

    final totpConfig = _totpConfig();
    final storage = _FakeSecureStorageService()
      ..autoApprovePending = false
      ..totpCredentials['totp_1'] = _pendingTotpCredential(config: totpConfig);
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
    expect(result.pushed, isFalse);
    expect(server.postCount, 0);
    expect(server.lastPostBody, isNull);
    expect(
      storage.totpCredentials['totp_1']!.config.secret,
      TotpService.parseConfig(totpConfig).secret,
    );
    expect(
      storage.totpCredentials['totp_1']!.syncStatus,
      SyncStatus.pendingPush,
    );
    expect(syncService.isDirty, isTrue);
    expect(
      syncService.statusNote,
      'Local changes are waiting for review before push.',
    );
  });

  test('approved 2FA credential push only sends encrypted payload', () async {
    final identity = _identityService();
    await identity.initialize();

    final totpConfig = _totpConfig();
    final storage = _FakeSecureStorageService()
      ..totpCredentials['totp_1'] = _pendingTotpCredential(config: totpConfig);
    final server = await _SyncProbeServer.start(
      postBody: jsonEncode({
        'success': true,
        'max_version': 1,
        'accepted_versions': {'totp_1': 1},
      }),
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
    final postBody = server.lastPostBody ?? '';
    final syncedItem = storage.totpCredentials['totp_1']!;

    expect(result.success, isTrue);
    expect(result.pushed, isTrue);
    expect(server.postCount, 1);
    expect(postBody, contains('encrypted_signed_payload'));
    expect(postBody, contains('sroy-sync:'));
    expect(postBody, isNot(contains('JBSWY3DPEHPK3PXP')));
    expect(postBody, isNot(contains('otpauth://')));
    expect(storage.pushedLocalSyncChangeIds, ['change_totp_1']);
    expect(syncedItem.syncStatus, SyncStatus.synchronized);
    expect(syncedItem.serverVersion, 1);
    expect(
      syncedItem.config.secret,
      TotpService.parseConfig(totpConfig).secret,
    );
  });
}
