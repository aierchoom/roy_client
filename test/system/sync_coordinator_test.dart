import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/sync/sync_service.dart';
import 'package:secret_roy/system/service_manager/sync_coordinator.dart';
import 'package:secret_roy/system/service_manager/sync_server_url_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_identity_service.dart';
import '../sync/sync_server_test_harness.dart';

class _FakeSyncService extends SyncService {
  bool _connected = false;
  SyncState _state = SyncState.offline;
  String? _errorMessage;
  String? _statusNote;
  int _localVersion = 0;
  bool _isDirty = false;
  SyncResult _nextResult = SyncResult.success();

  _FakeSyncService()
      : super(
          storageService: FakeSecureStorageService(),
          identityService: FakeIdentityService(),
        );

  @override
  Future<bool> connect() async {
    _connected = true;
    return true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<SyncResult> syncNow() async => _nextResult;

  void setNextResult(SyncResult result) {
    _nextResult = result;
  }

  @override
  SyncState get state => _state;

  set state(SyncState value) => _state = value;

  @override
  String? get errorMessage => _errorMessage;

  set errorMessage(String? value) => _errorMessage = value;

  @override
  String? get statusNote => _statusNote;

  set statusNote(String? value) => _statusNote = value;

  @override
  bool get isConnected => _connected;

  @override
  int get localVersion => _localVersion;

  set localVersion(int value) => _localVersion = value;

  @override
  bool get isDirty => _isDirty;

  set isDirty(bool value) => _isDirty = value;
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SyncCoordinator', () {
    late FakeSecureStorageService storage;
    late FakeIdentityService identity;
    late _FakeSyncService syncService;
    late SyncServerUrlStore urlStore;
    late SyncCoordinator coordinator;

    setUp(() {
      storage = FakeSecureStorageService();
      identity = FakeIdentityService();
      syncService = _FakeSyncService();
      urlStore = SyncServerUrlStore(defaultUrl: () => 'http://localhost:3000');
      coordinator = SyncCoordinator(
        syncService: syncService,
        identityService: identity,
        secureStorageService: storage,
        syncServerUrlStore: urlStore,
      );
    });

    test('connect delegates to syncService', () async {
      final result = await coordinator.connect();
      expect(result, true);
      expect(syncService.isConnected, true);
    });

    test('disconnect delegates to syncService', () async {
      await coordinator.connect();
      await coordinator.disconnect();
      expect(syncService.isConnected, false);
    });

    test('syncNow returns early when pull fails', () async {
      syncService.setNextResult(
        SyncResult.success(pulled: false),
      );
      final result = await coordinator.syncNow();
      expect(result.pulled, false);
    });

    test('syncNow returns early when success is false', () async {
      syncService.setNextResult(
        SyncResult.failure('network error'),
      );
      final result = await coordinator.syncNow();
      expect(result.success, false);
    });

    test('syncNow reinitializes after successful pull', () async {
      syncService.setNextResult(
        SyncResult.success(pulled: true, pushed: true, version: 5),
      );
      syncService.localVersion = 5;
      final result = await coordinator.syncNow();
      expect(result.pulled, true);
      expect(result.pushed, true);
      expect(result.version, 5);
    });

    test('state passthrough', () {
      syncService.state = SyncState.connecting;
      expect(coordinator.state, SyncState.connecting);
    });

    test('errorMessage passthrough', () {
      syncService.errorMessage = 'err';
      expect(coordinator.errorMessage, 'err');
    });

    test('statusNote passthrough', () {
      syncService.statusNote = 'note';
      expect(coordinator.statusNote, 'note');
    });

    test('localVersion passthrough', () {
      syncService.localVersion = 42;
      expect(coordinator.localVersion, 42);
    });

    test('isDirty passthrough', () {
      syncService.isDirty = true;
      expect(coordinator.isDirty, true);
    });

    test('getServerUrl reads from store', () async {
      await urlStore.write('https://example.com', vaultId: identity.vaultId);
      final url = await coordinator.getServerUrl();
      expect(url, 'https://example.com');
    });

    test('setServerUrl writes and disconnects', () async {
      await coordinator.connect();
      await coordinator.setServerUrl('https://new.example.com');
      expect(syncService.isConnected, false);
      final url = await coordinator.getServerUrl();
      expect(url, 'https://new.example.com');
    });

    test('resolveServerUrl normalizes URL', () async {
      await urlStore.write('example.com/', vaultId: identity.vaultId);
      final url = await coordinator.resolveServerUrl();
      expect(url, 'https://example.com');
    });

    test('resolveServerUrl throws when empty and not allowed', () async {
      await urlStore.write('', vaultId: identity.vaultId);
      expect(
        () => coordinator.resolveServerUrl(),
        throwsA(isA<Exception>()),
      );
    });

    test('resolveServerUrl allows empty when flag is set', () async {
      await urlStore.write('', vaultId: identity.vaultId);
      final url = await coordinator.resolveServerUrl(allowEmpty: true);
      expect(url, '');
    });
  });
}
