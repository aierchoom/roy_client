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
import 'package:secret_roy/services/lan_pairing_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
import 'package:secret_roy/sync/lan_sync_coordinator.dart';
import 'package:secret_roy/sync/lan_sync_host_handler.dart';
import 'package:secret_roy/sync/lan_sync_session.dart';
import 'package:secret_roy/sync/sync_service.dart';

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

class _FakeSyncService extends SyncService {
  bool _syncing = false;

  _FakeSyncService()
      : super(
          storageService: SecureStorageService(
            databaseCipher: DatabaseFileCipher(
              keyBytes: Uint8List.fromList(List<int>.filled(32, 0)),
            ),
          ),
          identityService: _FakeIdentityService(),
        );

  @override
  bool get isSyncing => _syncing;

  void setSyncing(bool value) => _syncing = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLanPairingService extends LanPairingService {
  LanSyncHostHandler? _attachedHandler;
  LanPairingHostInfo? _discoverResult;

  @override
  void attachSyncHandler(LanSyncHostHandler handler) {
    _attachedHandler = handler;
  }

  @override
  void detachSyncHandler() {
    _attachedHandler = null;
  }

  @override
  Future<LanPairingHostInfo?> discoverHost({Duration timeout = const Duration(seconds: 8)}) async {
    return _discoverResult;
  }

  void setDiscoverResult(LanPairingHostInfo? result) => _discoverResult = result;

  LanSyncHostHandler? get attachedHandler => _attachedHandler;
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
  late _FakeSyncService syncService;
  late _FakeLanPairingService pairingService;
  late LanSyncCoordinator coordinator;

  setUp(() async {
    rootDirectory = Directory.systemTemp.createTempSync(
      'lan_sync_coord_test_',
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
    syncService = _FakeSyncService();
    pairingService = _FakeLanPairingService();
    coordinator = LanSyncCoordinator(
      storage: storage,
      identity: identity,
      pairing: pairingService,
      syncService: syncService,
    );
  });

  tearDown(() async {
    coordinator.dispose();
    await storage.close(dispose: true);
    if (rootDirectory.existsSync()) {
      rootDirectory.deleteSync(recursive: true);
    }
  });

  group('startAsHost', () {
    test('returns session ID when not busy and no server sync', () async {
      syncService.setSyncing(false);
      final sessionId = await coordinator.startAsHost();
      expect(sessionId, isNotNull);
      expect(sessionId, isNotEmpty);
      expect(coordinator.isBusy, isTrue);
      expect(coordinator.currentRole, 'host');
      expect(coordinator.currentSession, isNotNull);
      expect(coordinator.currentSession!.phase, LanSyncPhase.connecting);
    });

    test('returns null when server sync is in progress', () async {
      syncService.setSyncing(true);
      final sessionId = await coordinator.startAsHost();
      expect(sessionId, isNull);
      expect(coordinator.isBusy, isFalse);
    });

    test('returns null when already busy', () async {
      syncService.setSyncing(false);
      await coordinator.startAsHost();
      expect(coordinator.isBusy, isTrue);

      final secondSession = await coordinator.startAsHost();
      expect(secondSession, isNull);
    });

    test('attaches handler to pairing service', () async {
      syncService.setSyncing(false);
      await coordinator.startAsHost();
      expect(pairingService.attachedHandler, isNotNull);
    });
  });

  group('startAndRunAsRequester', () {
    test('returns error when no host discovered', () async {
      syncService.setSyncing(false);
      pairingService.setDiscoverResult(null);

      final result = await coordinator.startAndRunAsRequester();
      expect(result.success, isFalse);
      expect(result.error, contains('No LAN host discovered'));
      expect(coordinator.isBusy, isFalse);
    });

    test('returns error when server sync is in progress', () async {
      syncService.setSyncing(true);
      final result = await coordinator.startAndRunAsRequester();
      expect(result.success, isFalse);
      expect(result.error, contains('Server sync is in progress'));
    });

    test('returns error when already busy', () async {
      syncService.setSyncing(false);
      await coordinator.startAsHost();

      final result = await coordinator.startAndRunAsRequester();
      expect(result.success, isFalse);
      expect(result.error, contains('Another LAN sync is in progress'));
    });
  });

  group('abort', () {
    test('resets state after host session abort', () async {
      syncService.setSyncing(false);
      await coordinator.startAsHost();
      expect(coordinator.isBusy, isTrue);

      await coordinator.abort();
      expect(coordinator.isBusy, isFalse);
      expect(coordinator.currentSession!.phase, LanSyncPhase.interrupted);
    });

    test('detaches handler from pairing service', () async {
      syncService.setSyncing(false);
      await coordinator.startAsHost();
      expect(pairingService.attachedHandler, isNotNull);

      await coordinator.abort();
      expect(pairingService.attachedHandler, isNull);
    });
  });

  group('mutex with server sync', () {
    test('server sync prevents host start', () async {
      syncService.setSyncing(true);
      final sessionId = await coordinator.startAsHost();
      expect(sessionId, isNull);
    });

    test('server sync prevents requester start', () async {
      syncService.setSyncing(true);
      final result = await coordinator.startAndRunAsRequester();
      expect(result.success, isFalse);
    });
  });
}
