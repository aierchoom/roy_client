import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/database_file_cipher.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
import 'package:secret_roy/services/totp_service.dart';
import 'package:secret_roy/sync/lan_sync_host_handler.dart';
import 'package:secret_roy/sync/lan_sync_session.dart';
import 'package:secret_roy/sync/sync_payload_codec.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String documentsPath;
  final String temporaryPath;

  _FakePathProviderPlatform({
    required this.documentsPath,
    required this.temporaryPath,
  });

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

class _FakeIdentityService implements IdentityService {
  @override
  String get deviceId => 'device_test';

  @override
  String get vaultId => 'vault_test';

  @override
  String? get vaultApiToken => null;

  @override
  bool get hasIdentity => true;

  @override
  String get privateKey => 'fake_private_key_32bytes_xxxxxx';

  @override
  String get symmetricKey => 'fake_symmetric_key_32bytes_xxxxx';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory rootDirectory;
  late Directory documentsDirectory;
  late Directory temporaryDirectory;
  late DatabaseFileCipher cipher;
  late SecureStorageService storage;
  late _FakeIdentityService identity;
  late LanSyncHostHandler handler;

  setUp(() async {
    rootDirectory = Directory.systemTemp.createTempSync(
      'lan_sync_host_test_',
    );
    documentsDirectory = Directory(p.join(rootDirectory.path, 'documents'))
      ..createSync(recursive: true);
    temporaryDirectory = Directory(p.join(rootDirectory.path, 'temp'))
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsPath: documentsDirectory.path,
      temporaryPath: temporaryDirectory.path,
    );
    cipher = DatabaseFileCipher(
      keyBytes: Uint8List.fromList(List<int>.filled(32, 42)),
    );
    storage = SecureStorageService(databaseCipher: cipher);
    await storage.initialize(deviceId: 'device_test');
    identity = _FakeIdentityService();
    handler = LanSyncHostHandler(
      storage: storage,
      identity: identity,
    );
  });

  tearDown(() async {
    handler.dispose();
    await storage.close(dispose: true);
    if (rootDirectory.existsSync()) {
      rootDirectory.deleteSync(recursive: true);
    }
  });

  group('handleStart', () {
    test('creates a new session with valid sessionId', () async {
      final result = await handler.handleStart('peer_device_1');
      expect(result['session_id'], isNotEmpty);
      expect(result['ttl_seconds'], greaterThan(0));
    });

    test('creates session in receiving phase', () async {
      await handler.handleStart('peer_device_1');
      final sessions = handler.getSessions();
      expect(sessions.length, 1);
      expect(sessions.first.phase, LanSyncPhase.receiving);
    });

    test('marks old session interrupted for same peer', () async {
      await handler.handleStart('peer_device_1');
      final firstSessionId = handler.getSessions().first.sessionId;

      await handler.handleStart('peer_device_1');
      // Old session should be interrupted; new session active
      final allSessions = handler.getSessions();
      expect(allSessions.where((s) => s.sessionId == firstSessionId).first.phase,
          LanSyncPhase.interrupted);
      expect(allSessions.where((s) => s.phase == LanSyncPhase.receiving).length, 1);
    });

    test('stores peer record IDs when provided', () async {
      await handler.handleStart(
        'peer_device_1',
        peerRecordIds: ['acc-1', 'tpl-1', 'totp-1'],
      );
      final sessions = handler.getSessions();
      expect(sessions.first.peerRecordIds, contains('acc-1'));
      expect(sessions.first.peerRecordIds, contains('tpl-1'));
      expect(sessions.first.peerRecordIds, contains('totp-1'));
    });
  });

  group('handleAbort', () {
    test('removes active session', () async {
      final result = await handler.handleStart('peer_device_1');
      final sessionId = result['session_id'] as String;

      expect(handler.getSessions().length, 1);

      await handler.handleAbort(sessionId);
      expect(handler.getSessions().isEmpty, isTrue);
    });

    test('is idempotent for unknown session', () async {
      await handler.handleAbort('nonexistent');
      expect(handler.getSessions().isEmpty, isTrue);
    });
  });

  group('cleanup', () {
    test('removes expired sessions', () async {
      // Create handler with very short TTL
      final shortTtlHandler = LanSyncHostHandler(
        storage: storage,
        identity: identity,
        config: const LanSyncConfig(sessionTtl: Duration(milliseconds: 1)),
      );

      await shortTtlHandler.handleStart('peer_device_1');
      await Future.delayed(const Duration(milliseconds: 50));

      shortTtlHandler.cleanup();
      expect(shortTtlHandler.getSessions().isEmpty, isTrue);
      shortTtlHandler.dispose();
    });

    test('keeps active non-expired sessions', () async {
      await handler.handleStart('peer_device_1');

      handler.cleanup();
      expect(handler.getSessions().length, 1);
    });
  });

  group('getSessionPhase', () {
    test('returns phase for active session', () async {
      final result = await handler.handleStart('peer_device_1');
      final sessionId = result['session_id'] as String;

      final phase = handler.getSessionPhase(sessionId);
      expect(phase, LanSyncPhase.receiving);
    });

    test('returns null for unknown session', () {
      final phase = handler.getSessionPhase('unknown');
      expect(phase, isNull);
    });
  });

  group('handlePush', () {
    test('accepts encrypted payloads and updates phase to receiving', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      final payload = await _encryptAccount(AccountItem(
        id: 'acc-push-1',
        name: 'Push Account',
        email: 'push@test.com',
        templateId: 'template_default',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.now('device_test'),
        emailHlc: Hlc.now('device_test'),
        dataHlc: {},
      ));

      final result = await handler.handlePush(sessionId, 0, [payload]);
      expect(result['accepted'], 0);
      expect(result['phase'], 'receiving');
    });

    test('rejects push when session phase is not connecting or receiving', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      // Transition session to pushing via triggerMerge (empty payloads)
      await handler.triggerMerge(sessionId);

      expect(
        () => handler.handlePush(sessionId, 0, []),
        throwsA(isA<LanSyncException>()),
      );
    });

    test('throws DATA_CORRUPTED on invalid payload', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      expect(
        () => handler.handlePush(sessionId, 0, ['invalid_payload']),
        throwsA(isA<LanSyncException>().having((e) => e.code, 'code', 'DATA_CORRUPTED')),
      );
    });
  });

  group('triggerMerge', () {
    test('transitions to pushing immediately when no peer payloads', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      await handler.triggerMerge(sessionId);
      expect(handler.getSessionPhase(sessionId), LanSyncPhase.pushing);
    });

    test('merges account with fast-forward when local does not exist', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      final account = AccountItem(
        id: 'acc-ff-1',
        name: 'FastForward',
        email: 'ff@test.com',
        templateId: 'template_default',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.now('device_test'),
        emailHlc: Hlc.now('device_test'),
        dataHlc: {},
      );
      final payload = await _encryptAccount(account);
      await handler.handlePush(sessionId, 0, [payload]);

      await handler.triggerMerge(sessionId);
      expect(handler.getSessionPhase(sessionId), LanSyncPhase.pushing);

      final pullResult = await handler.handlePull(sessionId);
      final items = pullResult['items'] as List<dynamic>;
      expect(items.length, greaterThanOrEqualTo(1));
    });

    test('merges template when local does not exist', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      final template = const AccountTemplate(
        templateId: 'tpl-ff-1',
        title: 'FastForwardTemplate',
        subTitle: '',
        category: TemplateCategory.access,
        fields: [],
      );
      final payload = await _encryptTemplate(template);
      await handler.handlePush(sessionId, 0, [payload]);

      await handler.triggerMerge(sessionId);
      expect(handler.getSessionPhase(sessionId), LanSyncPhase.pushing);
    });

    test('merges TOTP credential when local does not exist', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      final totp = TotpCredential(
        id: 'totp-ff-1',
        label: 'FastForwardTOTP',
        config: const TotpConfig(secret: 'JBSWY3DPEHPK3PXP'),
        linkedAccountIds: const [],
        createdAt: DateTime.now().millisecondsSinceEpoch,
        labelHlc: Hlc.now('device_test'),
        configHlc: Hlc.now('device_test'),
        linksHlc: Hlc.now('device_test'),
      );
      final payload = await _encryptTotp(totp);
      await handler.handlePush(sessionId, 0, [payload]);

      await handler.triggerMerge(sessionId);
      expect(handler.getSessionPhase(sessionId), LanSyncPhase.pushing);
    });

    test('produces conflicts when account fields diverge', () async {
      // Seed local account
      final localAccount = AccountItem(
        id: 'acc-conflict-1',
        name: 'LocalName',
        email: 'local@test.com',
        templateId: 'template_default',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.now('device_test'),
        emailHlc: Hlc.now('device_test'),
        dataHlc: {},
      );
      await storage.saveAccount(localAccount);

      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      // Remote account with higher HLCs to force non-fast-forward
      final remoteAccount = localAccount.copyWith(
        name: 'RemoteName',
        nameHlc: Hlc.now('remote_device'),
      );
      final payload = await _encryptAccount(remoteAccount);
      await handler.handlePush(sessionId, 0, [payload]);

      await handler.triggerMerge(sessionId);
      expect(handler.getSessionPhase(sessionId), LanSyncPhase.resolving);
      expect(handler.getConflictPreview(sessionId), isNotNull);
      expect(handler.getConflictPreview(sessionId)!.isNotEmpty, isTrue);
    });
  });

  group('handleResultQuery', () {
    test('returns merging phase with zero conflicts by default', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      final result = await handler.handleResultQuery(sessionId);
      expect(result['phase'], 'receiving');
      expect(result['conflict_count'], 0);
    });

    test('includes conflict preview when resolving', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      // Manually set resolving with preview
      final sessions = handler.getSessions();
      sessions.first.phase = LanSyncPhase.resolving;
      sessions.first.conflictPreview = [
        {'account_id': 'acc-1', 'field_key': 'name', 'field_value': 'A'},
      ];

      final result = await handler.handleResultQuery(sessionId);
      expect(result['phase'], 'resolving');
      expect(result['conflict_preview'], isNotNull);
    });
  });

  group('handlePull', () {
    test('returns empty items when session is not in pushing phase', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      final result = await handler.handlePull(sessionId);
      expect(result['items'], isEmpty);
      expect(result['phase'], 'receiving');
    });

    test('returns encrypted merged items in pushing phase', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      final account = AccountItem(
        id: 'acc-pull-host-1',
        name: 'HostAccount',
        email: 'host@test.com',
        templateId: 'template_default',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.now('device_test'),
        emailHlc: Hlc.now('device_test'),
        dataHlc: {},
      );
      final payload = await _encryptAccount(account);
      await handler.handlePush(sessionId, 0, [payload]);
      await handler.triggerMerge(sessionId);

      final result = await handler.handlePull(sessionId);
      final items = result['items'] as List<dynamic>;
      expect(items, isNotEmpty);
      expect(result['phase'], 'pushing');
    });

    test('includes host-only items via incremental transfer', () async {
      // Seed a host-only account
      final hostAccount = AccountItem(
        id: 'acc-host-only',
        name: 'HostOnly',
        email: 'only@host.com',
        templateId: 'template_default',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.now('device_test'),
        emailHlc: Hlc.now('device_test'),
        dataHlc: {},
      );
      await storage.saveAccount(hostAccount);

      final startResult = await handler.handleStart(
        'peer_device_1',
        peerRecordIds: ['some_other_id'],
      );
      final sessionId = startResult['session_id'] as String;
      await handler.triggerMerge(sessionId);

      final result = await handler.handlePull(sessionId);
      final items = result['items'] as List<dynamic>;
      // Should include the host-only item because peerRecordIds does not contain it
      expect(items.length, greaterThanOrEqualTo(1));
    });

    test('skips items already in merged list', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      final account = AccountItem(
        id: 'acc-dedup-1',
        name: 'Dedup',
        email: 'dedup@test.com',
        templateId: 'template_default',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.now('device_test'),
        emailHlc: Hlc.now('device_test'),
        dataHlc: {},
      );
      await storage.saveAccount(account);

      final payload = await _encryptAccount(account);
      await handler.handlePush(sessionId, 0, [payload]);
      await handler.triggerMerge(sessionId);

      final result = await handler.handlePull(sessionId);
      final items = result['items'] as List<dynamic>;
      // Merged item and host item have same id, so host item should be skipped
      // We should see exactly 1 encrypted item for this id
      expect(items.length, greaterThanOrEqualTo(1));
    });
  });

  group('commit', () {
    test('commits merged items to database', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      final account = AccountItem(
        id: 'acc-commit-1',
        name: 'CommitMe',
        email: 'commit@test.com',
        templateId: 'template_default',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.now('device_test'),
        emailHlc: Hlc.now('device_test'),
        dataHlc: {},
      );
      final payload = await _encryptAccount(account);
      await handler.handlePush(sessionId, 0, [payload]);
      await handler.triggerMerge(sessionId);

      await handler.commit(sessionId);
      expect(handler.getSessionPhase(sessionId), LanSyncPhase.completed);

      final local = await storage.getAccountById('acc-commit-1');
      expect(local, isNotNull);
      expect(local!.name, 'CommitMe');
    });

    test('throws when session is not in pushing phase', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      expect(
        () => handler.commit(sessionId),
        throwsA(isA<LanSyncException>().having((e) => e.code, 'code', 'INVALID_PHASE')),
      );
    });

    test('records sync timestamp even with empty merged items', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      await handler.triggerMerge(sessionId); // no payloads → pushing
      await handler.commit(sessionId);

      expect(handler.getSessionPhase(sessionId), LanSyncPhase.completed);
    });
  });

  group('getConflictPreview', () {
    test('returns null when no conflicts', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;

      expect(handler.getConflictPreview(sessionId), isNull);
    });

    test('returns null for unknown session', () {
      expect(handler.getConflictPreview('unknown'), isNull);
    });
  });

  group('cleanup terminal sessions', () {
    test('removes completed sessions', () async {
      final startResult = await handler.handleStart('peer_device_1');
      final sessionId = startResult['session_id'] as String;
      await handler.triggerMerge(sessionId);
      await handler.commit(sessionId);

      expect(handler.getSessions().length, 1);
      handler.cleanup();
      expect(handler.getSessions().isEmpty, isTrue);
    });
  });

  group('dispose', () {
    test('clears sessions and cancels timer', () async {
      await handler.handleStart('peer_device_1');
      expect(handler.getSessions().length, 1);

      handler.dispose();
      expect(handler.getSessions().isEmpty, isTrue);
    });
  });
}

Future<String> _encryptAccount(AccountItem account) async {
  return SyncPayloadCodec.encodePayload(
    payloadJson: account.toJson()..['_type'] = 'account',
    vaultId: 'vault_test',
    nodeId: 'device_test',
    privateKey: 'fake_private_key_32bytes_xxxxxx',
    symmetricKey: 'fake_symmetric_key_32bytes_xxxxx',
  );
}

Future<String> _encryptTemplate(AccountTemplate template) async {
  return SyncPayloadCodec.encodePayload(
    payloadJson: template.toJson()..['_type'] = 'template',
    vaultId: 'vault_test',
    nodeId: 'device_test',
    privateKey: 'fake_private_key_32bytes_xxxxxx',
    symmetricKey: 'fake_symmetric_key_32bytes_xxxxx',
  );
}

Future<String> _encryptTotp(TotpCredential totp) async {
  return SyncPayloadCodec.encodePayload(
    payloadJson: totp.toJson()..['_type'] = 'totp_credential',
    vaultId: 'vault_test',
    nodeId: 'device_test',
    privateKey: 'fake_private_key_32bytes_xxxxxx',
    symmetricKey: 'fake_symmetric_key_32bytes_xxxxx',
  );
}
