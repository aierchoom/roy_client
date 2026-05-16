import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/lan_pairing_service.dart';
import 'package:secret_roy/services/vault_pairing_crypto.dart';
import 'package:secret_roy/services/vault_pairing_service.dart';
import 'package:secret_roy/system/service_manager/sync_coordinator.dart';
import 'package:secret_roy/system/service_manager/vault_import_export_coordinator.dart';
import 'package:secret_roy/system/service_manager/vault_pairing_coordinator.dart';
import 'package:secret_roy/system/service_manager/vault_dump_coordinator.dart';
import 'package:secret_roy/system/service_manager/sync_server_url_store.dart';

import '../fakes/fake_identity_service.dart';
import '../fakes/fake_sync_service.dart';
import '../sync/sync_server_test_harness.dart';

Future<IdentityService> _initializedIdentity() async {
  final identity = IdentityService(
    secureStorage: MemorySecureKeyValueStore({
      'device_id': 'device_abcdef123456',
      'vault_id': 'vault_12345678901234567890123456789012',
      'private_key': 'priv_1234567890123456789012345678901234567890123456789012345678901234',
      'symmetric_key': 'sym_1234567890123456789012345678901234567890123456789012345678901234',
    }),
  );
  await identity.initialize();
  return identity;
}

class _MockSyncCoordinator extends SyncCoordinator {
  _MockSyncCoordinator() : super(
    syncService: FakeSyncService(),
    identityService: FakeIdentityService(),
    secureStorageService: FakeSecureStorageService(),
    syncServerUrlStore: SyncServerUrlStore(defaultUrl: () => 'https://example.com'),
  );

  @override
  Future<String> resolveServerUrl({bool allowEmpty = false}) async => 'https://example.com';
}

class _MockImportExportCoordinator extends VaultImportExportCoordinator {
  _MockImportExportCoordinator() : super(
    dumpCoordinator: VaultDumpCoordinator(
      identityService: FakeIdentityService(),
      storageService: FakeSecureStorageService(),
    ),
    identityService: FakeIdentityService(),
    storageService: FakeSecureStorageService(),
    syncService: FakeSyncService(),
    syncServerUrlStore: SyncServerUrlStore(defaultUrl: () => ''),
  );

  String? _exportResult;
  bool importVaultLinkCodeCalled = false;
  String? lastImportedCode;
  bool? lastForceOverwrite;

  void setExportResult(String? result) => _exportResult = result;

  @override
  Future<String?> exportEncryptedVaultDump() async => _exportResult;

  @override
  Future<void> importVaultLinkCode(String code, {bool forceOverwrite = false}) async {
    importVaultLinkCodeCalled = true;
    lastImportedCode = code;
    lastForceOverwrite = forceOverwrite;
  }
}

class _MockVaultPairingService extends VaultPairingService {
  String? lastServerUrl;
  String? lastVaultId;
  String? lastHostDeviceId;
  String? lastSessionId;
  String? lastRequestId;
  String? lastWrappedVaultBundle;
  String? lastPairingCode;
  String? lastRequesterPublicKey;
  String? lastRequesterDeviceId;
  Duration? lastTtl;

  PairingSessionInfo? _createSessionResult;
  PairingJoinResult? _joinSessionResult;
  PairingSessionStatus? _getHostSessionStatusResult;
  PairingBundleResult? _getBundleResult;

  void setCreateSessionResult(PairingSessionInfo result) => _createSessionResult = result;
  void setJoinSessionResult(PairingJoinResult result) => _joinSessionResult = result;
  void setGetHostSessionStatusResult(PairingSessionStatus result) => _getHostSessionStatusResult = result;
  void setGetBundleResult(PairingBundleResult result) => _getBundleResult = result;

  @override
  Future<PairingSessionInfo> createSession({
    required String serverUrl,
    required String vaultId,
    required String hostDeviceId,
    Duration ttl = const Duration(minutes: 10),
  }) async {
    lastServerUrl = serverUrl;
    lastVaultId = vaultId;
    lastHostDeviceId = hostDeviceId;
    lastTtl = ttl;
    return _createSessionResult!;
  }

  @override
  Future<PairingJoinResult> joinSession({
    required String serverUrl,
    required String pairingCode,
    required String requesterDeviceId,
    required String requesterPublicKey,
  }) async {
    lastServerUrl = serverUrl;
    lastPairingCode = pairingCode;
    lastRequesterDeviceId = requesterDeviceId;
    lastRequesterPublicKey = requesterPublicKey;
    return _joinSessionResult!;
  }

  @override
  Future<PairingSessionStatus> getHostSessionStatus({
    required String serverUrl,
    required String sessionId,
    required String hostDeviceId,
  }) async {
    lastServerUrl = serverUrl;
    lastSessionId = sessionId;
    lastHostDeviceId = hostDeviceId;
    return _getHostSessionStatusResult!;
  }

  @override
  Future<void> approveSession({
    required String serverUrl,
    required String sessionId,
    required String hostDeviceId,
    required String requestId,
    required String wrappedVaultBundle,
  }) async {
    lastServerUrl = serverUrl;
    lastSessionId = sessionId;
    lastHostDeviceId = hostDeviceId;
    lastRequestId = requestId;
    lastWrappedVaultBundle = wrappedVaultBundle;
  }

  @override
  Future<PairingBundleResult> getBundle({
    required String serverUrl,
    required String sessionId,
    required String requestId,
    required String requesterDeviceId,
  }) async {
    lastServerUrl = serverUrl;
    lastSessionId = sessionId;
    lastRequestId = requestId;
    lastRequesterDeviceId = requesterDeviceId;
    return _getBundleResult!;
  }
}

class _MockLanPairingService extends LanPairingService {
  String? lastTransferCode;
  String? lastPairingCode;
  String? lastRequesterDeviceId;
  bool stopHostingCalled = false;
  Duration? lastTtl;

  LanPairingHostSession? _startHostingResult;
  String? _claimTransferCodeResult;

  void setStartHostingResult(LanPairingHostSession result) => _startHostingResult = result;
  void setClaimTransferCodeResult(String result) => _claimTransferCodeResult = result;

  @override
  Future<LanPairingHostSession> startHosting({
    required String transferCode,
    Duration ttl = const Duration(minutes: 3),
  }) async {
    lastTransferCode = transferCode;
    lastTtl = ttl;
    return _startHostingResult!;
  }

  @override
  Future<void> stopHosting() async {
    stopHostingCalled = true;
  }

  @override
  Future<String> claimTransferCodeByCode({
    required String pairingCode,
    required String requesterDeviceId,
    Duration discoveryTimeout = const Duration(seconds: 12),
    Duration claimTimeout = const Duration(seconds: 8),
    bool useRequesterEncryption = true,
  }) async {
    lastPairingCode = pairingCode;
    lastRequesterDeviceId = requesterDeviceId;
    return _claimTransferCodeResult!;
  }
}

VaultPairingCoordinator _createCoordinator({
  _MockVaultPairingService? vaultPairingService,
  _MockLanPairingService? lanPairingService,
  IdentityService? identityService,
  _MockSyncCoordinator? syncCoordinator,
  _MockImportExportCoordinator? importExportCoordinator,
}) {
  return VaultPairingCoordinator(
    vaultPairingService: vaultPairingService ?? _MockVaultPairingService(),
    lanPairingService: lanPairingService ?? _MockLanPairingService(),
    identityService: identityService ?? FakeIdentityService(),
    syncCoordinator: syncCoordinator ?? _MockSyncCoordinator(),
    importExportCoordinator: importExportCoordinator ?? _MockImportExportCoordinator(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultPairingCoordinator', () {
    test('createSession delegates with resolved serverUrl', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setCreateSessionResult(PairingSessionInfo(
        sessionId: 'sid_1',
        pairingCode: 'code_1',
        status: 'created',
        expiresAt: DateTime(2025),
      ));
      final coordinator = _createCoordinator(vaultPairingService: pairingService);
      final result = await coordinator.createSession(ttl: const Duration(minutes: 5));
      expect(result.sessionId, 'sid_1');
      expect(pairingService.lastServerUrl, 'https://example.com');
      expect(pairingService.lastVaultId, 'vault_12345678901234567890123456789012');
      expect(pairingService.lastHostDeviceId, 'device_test001');
    });

    test('getSessionStatus delegates correctly', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setGetHostSessionStatusResult(PairingSessionStatus(
        sessionId: 'sid_1',
        status: 'waiting',
        expiresAt: DateTime(2025),
      ));
      final coordinator = _createCoordinator(vaultPairingService: pairingService);
      final result = await coordinator.getSessionStatus('sid_1');
      expect(result.status, 'waiting');
      expect(pairingService.lastSessionId, 'sid_1');
    });

    test('approveRequest exports dump and encrypts bundle', () async {
      final identity = await _initializedIdentity();
      final keyPair = await VaultPairingCrypto.createKeyPair();
      final pairingService = _MockVaultPairingService();
      pairingService.setGetHostSessionStatusResult(PairingSessionStatus(
        sessionId: 'sid_1',
        status: 'waiting',
        expiresAt: DateTime(2025),
        pendingRequest: PairingPendingRequest(
          requestId: 'req_1',
          requesterDeviceId: 'device_joiner',
          requesterPublicKey: keyPair.publicKey,
          requestedAt: DateTime.now(),
        ),
      ));
      final importExport = _MockImportExportCoordinator();
      importExport.setExportResult('dump_data');
      final coordinator = _createCoordinator(
        vaultPairingService: pairingService,
        importExportCoordinator: importExport,
        identityService: identity,
      );
      await coordinator.approveRequest(sessionId: 'sid_1', requestId: 'req_1');
      expect(pairingService.lastWrappedVaultBundle, isNotNull);
      expect(pairingService.lastWrappedVaultBundle!.isNotEmpty, true);
      expect(pairingService.lastRequestId, 'req_1');
    });

    test('approveRequest throws when pendingRequest is null', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setGetHostSessionStatusResult(PairingSessionStatus(
        sessionId: 'sid_1',
        status: 'waiting',
        expiresAt: DateTime(2025),
      ));
      final coordinator = _createCoordinator(vaultPairingService: pairingService);
      expect(
        () => coordinator.approveRequest(sessionId: 'sid_1', requestId: 'req_1'),
        throwsA(isA<VaultPairingServiceException>()),
      );
    });

    test('approveRequest throws when requestId mismatch', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setGetHostSessionStatusResult(PairingSessionStatus(
        sessionId: 'sid_1',
        status: 'waiting',
        expiresAt: DateTime(2025),
        pendingRequest: PairingPendingRequest(
          requestId: 'req_other',
          requesterDeviceId: 'device_joiner',
          requesterPublicKey: 'pubkey',
          requestedAt: DateTime.now(),
        ),
      ));
      final coordinator = _createCoordinator(vaultPairingService: pairingService);
      expect(
        () => coordinator.approveRequest(sessionId: 'sid_1', requestId: 'req_1'),
        throwsA(isA<VaultPairingServiceException>()),
      );
    });

    test('approveRequest throws when requesterPublicKey is empty', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setGetHostSessionStatusResult(PairingSessionStatus(
        sessionId: 'sid_1',
        status: 'waiting',
        expiresAt: DateTime(2025),
        pendingRequest: PairingPendingRequest(
          requestId: 'req_1',
          requesterDeviceId: 'device_joiner',
          requesterPublicKey: '',
          requestedAt: DateTime.now(),
        ),
      ));
      final coordinator = _createCoordinator(vaultPairingService: pairingService);
      expect(
        () => coordinator.approveRequest(sessionId: 'sid_1', requestId: 'req_1'),
        throwsA(isA<VaultPairingServiceException>()),
      );
    });

    test('joinSession creates keyPair and caches it', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setJoinSessionResult(PairingJoinResult(
        sessionId: 'sid_1',
        requestId: 'req_1',
        status: 'pending',
        expiresAt: DateTime(2025),
      ));
      final coordinator = _createCoordinator(vaultPairingService: pairingService);
      final result = await coordinator.joinSession('code_1');
      expect(result.requestId, 'req_1');
      expect(pairingService.lastRequesterPublicKey, isNotNull);
      expect(pairingService.lastRequesterPublicKey!.isNotEmpty, true);
      // Verify key is cached internally
      // Key is cached internally; verified indirectly via fetchAndImportBundle.
    });

    test('joinSession trims pairingCode whitespace', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setJoinSessionResult(PairingJoinResult(
        sessionId: 'sid_1',
        requestId: 'req_1',
        status: 'pending',
        expiresAt: DateTime(2025),
      ));
      final coordinator = _createCoordinator(vaultPairingService: pairingService);
      await coordinator.joinSession('  code_1  ');
      expect(pairingService.lastPairingCode, 'code_1');
    });

    test('fetchAndImportBundle decrypts and imports on approved', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setJoinSessionResult(PairingJoinResult(
        sessionId: 'sid_1',
        requestId: 'req_1',
        status: 'pending',
        expiresAt: DateTime(2025),
      ));
      final importExport = _MockImportExportCoordinator();
      final coordinator = _createCoordinator(
        vaultPairingService: pairingService,
        importExportCoordinator: importExport,
      );

      // joinSession generates and caches a key pair
      await coordinator.joinSession('code_1');
      // Use the publicKey captured by the mock joinSession
      final publicKey = pairingService.lastRequesterPublicKey!;
      final transferCode = 'sroy-link:test_transfer';
      final wrappedBundle = await VaultPairingCrypto.encryptBundle(
        plainBundle: transferCode,
        requesterPublicKey: publicKey,
      );
      pairingService.setGetBundleResult(PairingBundleResult(
        status: 'approved',
        wrappedVaultBundle: wrappedBundle,
      ));

      final result = await coordinator.fetchAndImportBundle(
        sessionId: 'sid_1',
        requestId: 'req_1',
        forceOverwrite: true,
      );
      expect(result.status, 'approved');
      expect(importExport.importVaultLinkCodeCalled, true);
      expect(importExport.lastImportedCode, transferCode);
      expect(importExport.lastForceOverwrite, true);
      // Key should be removed after successful import
      // Key removed after import; verified by second fetch throwing key expired.
      expect(
        () => coordinator.fetchAndImportBundle(sessionId: 'sid_1', requestId: 'req_1'),
        throwsA(isA<VaultPairingServiceException>()),
      );
    });

    test('fetchAndImportBundle throws when key pair is missing', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setGetBundleResult(const PairingBundleResult(
        status: 'approved',
        wrappedVaultBundle: 'some_bundle',
      ));
      final coordinator = _createCoordinator(vaultPairingService: pairingService);
      expect(
        () => coordinator.fetchAndImportBundle(sessionId: 'sid_1', requestId: 'req_1'),
        throwsA(isA<VaultPairingServiceException>()),
      );
    });

    test('fetchAndImportBundle throws when wrappedBundle is empty', () async {
      await VaultPairingCrypto.createKeyPair();
      final pairingService = _MockVaultPairingService();
      pairingService.setGetBundleResult(const PairingBundleResult(
        status: 'approved',
        wrappedVaultBundle: '',
      ));
      final coordinator = _createCoordinator(vaultPairingService: pairingService);
      // Pre-populate by joining first
      pairingService.setJoinSessionResult(PairingJoinResult(
        sessionId: 'sid_1',
        requestId: 'req_1',
        status: 'pending',
        expiresAt: DateTime(2025),
      ));
      await coordinator.joinSession('code_1');
      expect(
        () => coordinator.fetchAndImportBundle(sessionId: 'sid_1', requestId: 'req_1'),
        throwsA(isA<VaultPairingServiceException>()),
      );
    });

    test('fetchAndImportBundle throws when wrappedBundle is null', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setGetBundleResult(const PairingBundleResult(
        status: 'approved',
        wrappedVaultBundle: null,
      ));
      final coordinator = _createCoordinator(vaultPairingService: pairingService);
      pairingService.setJoinSessionResult(PairingJoinResult(
        sessionId: 'sid_1',
        requestId: 'req_1',
        status: 'pending',
        expiresAt: DateTime(2025),
      ));
      await coordinator.joinSession('code_1');
      expect(
        () => coordinator.fetchAndImportBundle(sessionId: 'sid_1', requestId: 'req_1'),
        throwsA(isA<VaultPairingServiceException>()),
      );
    });

    test('fetchAndImportBundle does not import when not approved', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setGetBundleResult(const PairingBundleResult(status: 'pending'));
      final importExport = _MockImportExportCoordinator();
      final coordinator = _createCoordinator(
        vaultPairingService: pairingService,
        importExportCoordinator: importExport,
      );
      final result = await coordinator.fetchAndImportBundle(
        sessionId: 'sid_1',
        requestId: 'req_1',
      );
      expect(result.status, 'pending');
      expect(importExport.importVaultLinkCodeCalled, false);
    });

    test('startLanHost exports dump and starts hosting', () async {
      final identity = await _initializedIdentity();
      final lanService = _MockLanPairingService();
      lanService.setStartHostingResult(LanPairingHostSession(
        pairingCode: 'lan_code',
        serverPort: 12345,
        expiresAt: DateTime(2025),
      ));
      final importExport = _MockImportExportCoordinator();
      importExport.setExportResult('dump_data');
      final coordinator = _createCoordinator(
        lanPairingService: lanService,
        importExportCoordinator: importExport,
        identityService: identity,
      );
      final result = await coordinator.startLanHost(ttl: const Duration(minutes: 5));
      expect(result.pairingCode, 'lan_code');
      expect(lanService.lastTransferCode, isNotNull);
    });

    test('stopLanHost delegates to lanPairingService', () async {
      final lanService = _MockLanPairingService();
      final coordinator = _createCoordinator(lanPairingService: lanService);
      await coordinator.stopLanHost();
      expect(lanService.stopHostingCalled, true);
    });

    test('clearJoinKeys removes cached keys', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setJoinSessionResult(PairingJoinResult(
        sessionId: 'sid_1',
        requestId: 'req_1',
        status: 'pending',
        expiresAt: DateTime(2025),
      ));
      pairingService.setGetBundleResult(const PairingBundleResult(
        status: 'approved',
        wrappedVaultBundle: 'some_bundle',
      ));
      final coordinator = _createCoordinator(vaultPairingService: pairingService);
      await coordinator.joinSession('code_1');
      coordinator.clearJoinKeys();
      expect(
        () => coordinator.fetchAndImportBundle(sessionId: 'sid_1', requestId: 'req_1'),
        throwsA(isA<VaultPairingServiceException>()),
      );
    });

    test('joinLanWithCode claims and imports with forceOverwrite', () async {
      final lanService = _MockLanPairingService();
      lanService.setClaimTransferCodeResult('transfer_code_123');
      final importExport = _MockImportExportCoordinator();
      final coordinator = _createCoordinator(
        lanPairingService: lanService,
        importExportCoordinator: importExport,
      );
      await coordinator.joinLanWithCode('lan_code', forceOverwrite: true);
      expect(lanService.lastPairingCode, 'lan_code');
      expect(lanService.lastRequesterDeviceId, 'device_test001');
      expect(importExport.importVaultLinkCodeCalled, true);
      expect(importExport.lastImportedCode, 'transfer_code_123');
      expect(importExport.lastForceOverwrite, true);
    });

    test('joinLanWithCode defaults forceOverwrite to false', () async {
      final lanService = _MockLanPairingService();
      lanService.setClaimTransferCodeResult('transfer_code_456');
      final importExport = _MockImportExportCoordinator();
      final coordinator = _createCoordinator(
        lanPairingService: lanService,
        importExportCoordinator: importExport,
      );
      await coordinator.joinLanWithCode('lan_code');
      expect(importExport.lastForceOverwrite, false);
    });

    test('createSession uses default ttl when not provided', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setCreateSessionResult(PairingSessionInfo(
        sessionId: 'sid_1',
        pairingCode: 'code_1',
        status: 'created',
        expiresAt: DateTime(2025),
      ));
      final coordinator = _createCoordinator(vaultPairingService: pairingService);
      await coordinator.createSession();
      expect(pairingService.lastTtl, const Duration(minutes: 10));
    });

    test('startLanHost uses default ttl when not provided', () async {
      final identity = await _initializedIdentity();
      final lanService = _MockLanPairingService();
      lanService.setStartHostingResult(LanPairingHostSession(
        pairingCode: 'lan_code',
        serverPort: 12345,
        expiresAt: DateTime(2025),
      ));
      final importExport = _MockImportExportCoordinator();
      importExport.setExportResult('dump_data');
      final coordinator = _createCoordinator(
        lanPairingService: lanService,
        importExportCoordinator: importExport,
        identityService: identity,
      );
      await coordinator.startLanHost();
      expect(lanService.lastTtl, const Duration(minutes: 3));
    });

    test('fetchAndImportBundle defaults forceOverwrite to false', () async {
      final pairingService = _MockVaultPairingService();
      pairingService.setJoinSessionResult(PairingJoinResult(
        sessionId: 'sid_1',
        requestId: 'req_1',
        status: 'pending',
        expiresAt: DateTime(2025),
      ));
      final importExport = _MockImportExportCoordinator();
      final coordinator = _createCoordinator(
        vaultPairingService: pairingService,
        importExportCoordinator: importExport,
      );
      await coordinator.joinSession('code_1');
      final publicKey = pairingService.lastRequesterPublicKey!;
      final transferCode = 'sroy-link:test_transfer';
      final wrappedBundle = await VaultPairingCrypto.encryptBundle(
        plainBundle: transferCode,
        requesterPublicKey: publicKey,
      );
      pairingService.setGetBundleResult(PairingBundleResult(
        status: 'approved',
        wrappedVaultBundle: wrappedBundle,
      ));
      await coordinator.fetchAndImportBundle(sessionId: 'sid_1', requestId: 'req_1');
      expect(importExport.lastForceOverwrite, false);
    });
  });
}
