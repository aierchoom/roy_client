import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:secret_roy/services/database_file_cipher.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
import 'package:secret_roy/sync/lan_sync_host_handler.dart';
import 'package:secret_roy/sync/lan_sync_session.dart';

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
}
