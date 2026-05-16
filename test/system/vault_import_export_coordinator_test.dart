import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/system/service_manager/sync_server_url_store.dart';
import 'package:secret_roy/system/service_manager/vault_dump_coordinator.dart';
import 'package:secret_roy/system/service_manager/vault_import_export_coordinator.dart';
import 'package:secret_roy/system/service_manager/vault_import_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_identity_service.dart';
import '../fakes/fake_sync_service.dart';
import '../sync/sync_server_test_harness.dart';

class _MockDumpCoordinator extends VaultDumpCoordinator {
  _MockDumpCoordinator() : super(
    identityService: FakeIdentityService(),
    storageService: FakeSecureStorageService(),
  );

  String? _exportResult;
  VaultDumpImportPlan? _validateResult;
  Exception? _validateException;
  bool importValidatedCalled = false;
  Exception? _importValidatedException;

  void setExportResult(String? result) => _exportResult = result;
  void setValidateResult(VaultDumpImportPlan? result, {Exception? exception}) {
    _validateResult = result;
    _validateException = exception;
  }
  void setImportValidatedException(Exception? e) => _importValidatedException = e;

  @override
  Future<String?> exportEncryptedVaultDump() async => _exportResult;

  @override
  Future<VaultDumpImportPlan> validateEncryptedVaultDump({
    required String vaultDumpJson,
    required String vaultId,
    required String privateKey,
    required String symmetricKey,
  }) async {
    if (_validateException != null) throw _validateException!;
    if (_validateResult == null) {
      throw const VaultDumpImportException('Missing');
    }
    return _validateResult!;
  }

  @override
  Future<void> importValidatedVaultDump(VaultDumpImportPlan plan) async {
    importValidatedCalled = true;
    if (_importValidatedException != null) throw _importValidatedException!;
  }
}

class _MockIdentityService extends FakeIdentityService {
  VaultIdentityImportPreview? _previewTransferCodeResult;
  VaultIdentityImportPreview? _previewSecureLinkCodeResult;
  String? _exportSecureLinkCodeResult;
  VaultIdentityImportPreview? _lastAppliedPreview;
  int applyImportCount = 0;
  int currentImportPreviewCount = 0;
  final String _vaultId;

  _MockIdentityService({bool hasIdentity = true, String? vaultId})
      : _vaultId = vaultId ?? 'vault_12345678901234567890123456789012',
        super(hasIdentity: hasIdentity);

  void setPreviewTransferCodeResult(VaultIdentityImportPreview result) =>
      _previewTransferCodeResult = result;
  void setPreviewSecureLinkCodeResult(VaultIdentityImportPreview result) =>
      _previewSecureLinkCodeResult = result;
  void setExportSecureLinkCodeResult(String result) =>
      _exportSecureLinkCodeResult = result;

  @override
  Future<VaultIdentityImportPreview> previewTransferCode(String rawCode) async =>
      _previewTransferCodeResult!;

  @override
  Future<VaultIdentityImportPreview> previewSecureLinkCode(
    String secureCode,
    String password,
  ) async =>
      _previewSecureLinkCodeResult!;

  @override
  Future<String> exportSecureLinkCode(
    String password, {
    String? syncServerUrl,
    String? vaultDump,
  }) async =>
      _exportSecureLinkCodeResult!;

  @override
  Future<void> applyImportPreview(VaultIdentityImportPreview preview) async {
    applyImportCount++;
    _lastAppliedPreview = preview;
  }

  @override
  String get vaultId => _vaultId;

  @override
  VaultIdentityImportPreview currentImportPreview() {
    currentImportPreviewCount++;
    return VaultIdentityImportPreview(
      vaultId: vaultId,
      privateKey: 'priv_1234567890123456789012345678901234567890123456789012345678901234',
      symmetricKey: 'sym_1234567890123456789012345678901234567890123456789012345678901234',
    );
  }
}

class _MockStorageService extends FakeSecureStorageService {
  bool clearAllDataCalled = false;

  @override
  Future<void> clearAllData() async {
    clearAllDataCalled = true;
    accounts.clear();
    templates.clear();
    totpCredentials.clear();
  }

  @override
  Future<void> replaceAllDataForImport({
    required List<AccountTemplate> templates,
    required List<AccountItem> accounts,
    List<TotpCredential> totpCredentials = const [],
  }) async {
    this.accounts.clear();
    for (final a in accounts) {
      this.accounts[a.id] = a;
    }
    this.templates.clear();
    for (final t in templates) {
      this.templates[t.templateId] = t;
    }
    for (final t in totpCredentials) {
      this.totpCredentials[t.id] = t;
    }
  }
}

class _MockSyncService extends FakeSyncService {
  int _localVersion = 0;
  bool _isDirty = false;
  bool disconnectCalled = false;
  bool initializeCalled = false;
  int _initializeThrowCount = 0;

  @override
  int get localVersion => _localVersion;
  @override
  bool get isDirty => _isDirty;

  void setLocalVersion(int v) => _localVersion = v;
  void setIsDirty(bool v) => _isDirty = v;
  void setThrowOnInitializeTimes(int times) => _initializeThrowCount = times;

  @override
  Future<void> disconnect() async {
    disconnectCalled = true;
  }

  @override
  Future<void> initialize() async {
    initializeCalled = true;
    if (_initializeThrowCount > 0) {
      _initializeThrowCount--;
      throw Exception('init failed');
    }
  }
}

VaultImportExportCoordinator _createCoordinator({
  required _MockDumpCoordinator dumpCoordinator,
  required _MockIdentityService identityService,
  required _MockStorageService storageService,
  required _MockSyncService syncService,
}) {
  return VaultImportExportCoordinator(
    dumpCoordinator: dumpCoordinator,
    identityService: identityService,
    storageService: storageService,
    syncService: syncService,
    syncServerUrlStore: SyncServerUrlStore(defaultUrl: () => ''),
  );
}

AccountItem _makeAccount({required String id, required String name}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return AccountItem(
    id: id,
    name: name,
    email: '',
    templateId: 'generic_info',
    data: const {},
    createdAt: now,
    nameHlc: Hlc.zero('test'),
    emailHlc: Hlc.zero('test'),
    dataHlc: const {},
    syncStatus: SyncStatus.synchronized,
  );
}

AccountTemplate _makeTemplate({required String id, required String title}) {
  return AccountTemplate(
    templateId: id,
    title: title,
    subTitle: '',
    category: TemplateCategory.custom,
    fields: const [],
  );
}

VaultIdentityImportPreview _makePreview({
  String? vaultDump,
  String? syncServerUrl,
}) {
  return VaultIdentityImportPreview(
    vaultId: 'vault_12345678901234567890123456789012',
    privateKey: 'priv_1234567890123456789012345678901234567890123456789012345678901234',
    symmetricKey: 'sym_1234567890123456789012345678901234567890123456789012345678901234',
    vaultDump: vaultDump,
    syncServerUrl: syncServerUrl,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('VaultImportExportCoordinator', () {
    test('exportEncryptedVaultDump delegates to dumpCoordinator', () async {
      final dump = _MockDumpCoordinator();
      dump.setExportResult('encrypted_dump');
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: _MockIdentityService(),
        storageService: _MockStorageService(),
        syncService: _MockSyncService(),
      );

      final result = await coordinator.exportEncryptedVaultDump();
      expect(result, 'encrypted_dump');
    });

    test('testRecoverBackupPackage returns valid result on success', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(VaultDumpImportPlan(
        templates: [_makeTemplate(id: 't1', title: 'T1')],
        accounts: [_makeAccount(id: 'a1', name: 'A1')],
      ));
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: _MockIdentityService(),
        storageService: _MockStorageService(),
        syncService: _MockSyncService(),
      );

      final result = await coordinator.testRecoverBackupPackage(
        'dump',
        vaultId: 'vault_12345678901234567890123456789012',
        privateKey: 'priv_1234567890123456789012345678901234567890123456789012345678901234',
        symmetricKey: 'sym_1234567890123456789012345678901234567890123456789012345678901234',
      );

      expect(result.valid, true);
      expect(result.accountCount, 1);
      expect(result.templateCount, 1);
      expect(result.errorMessage, isNull);
    });

    test('testRecoverBackupPackage returns invalid result on exception', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(null, exception: const VaultDumpImportException('Bad'));
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: _MockIdentityService(),
        storageService: _MockStorageService(),
        syncService: _MockSyncService(),
      );

      final result = await coordinator.testRecoverBackupPackage(
        'dump',
        vaultId: 'vault_id',
        privateKey: 'priv',
        symmetricKey: 'sym',
      );

      expect(result.valid, false);
      expect(result.errorMessage, 'Bad');
      expect(result.accountCount, 0);
      expect(result.templateCount, 0);
    });

    test('exportSecureVaultLinkCode includes vaultDump when includeData is true', () async {
      final dump = _MockDumpCoordinator();
      dump.setExportResult('vault_dump_data');
      final identity = _MockIdentityService();
      identity.setExportSecureLinkCodeResult('secure_code');
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: identity,
        storageService: _MockStorageService(),
        syncService: _MockSyncService(),
      );

      final result = await coordinator.exportSecureVaultLinkCode(
        'password',
        includeData: true,
        resolveSyncServerUrl: () async => 'https://example.com',
      );

      expect(result, 'secure_code');
    });

    test('exportSecureVaultLinkCode passes null vaultDump when includeData is false', () async {
      final identity = _MockIdentityService();
      identity.setExportSecureLinkCodeResult('secure_code');
      final coordinator = _createCoordinator(
        dumpCoordinator: _MockDumpCoordinator(),
        identityService: identity,
        storageService: _MockStorageService(),
        syncService: _MockSyncService(),
      );

      final result = await coordinator.exportSecureVaultLinkCode(
        'password',
        includeData: false,
        resolveSyncServerUrl: () async => '',
      );

      expect(result, 'secure_code');
    });

    test('previewVaultImport without dump and no local data', () async {
      final coordinator = _createCoordinator(
        dumpCoordinator: _MockDumpCoordinator(),
        identityService: _MockIdentityService(),
        storageService: _MockStorageService(),
        syncService: _MockSyncService(),
      );

      final preview = await coordinator.previewVaultImport(_makePreview());
      expect(preview.vaultId, 'vault_12345678901234567890123456789012');
      expect(preview.vaultIdMatchesCurrent, true);
      expect(preview.hasLocalData, false);
      expect(preview.includesDataSnapshot, false);
      expect(preview.accountCount, 0);
      expect(preview.templateCount, 0);
    });

    test('previewVaultImport with valid dump and local data', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(VaultDumpImportPlan(
        templates: [_makeTemplate(id: 't1', title: 'T1')],
        accounts: [_makeAccount(id: 'a1', name: 'A1')],
      ));
      final storage = _MockStorageService();
      storage.accounts['a1'] = _makeAccount(id: 'a1', name: 'Local');
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: _MockIdentityService(),
        storageService: storage,
        syncService: _MockSyncService()..setLocalVersion(1),
      );

      final preview = await coordinator.previewVaultImport(
        _makePreview(vaultDump: 'dump_json'),
      );
      expect(preview.hasLocalData, true);
      expect(preview.includesDataSnapshot, true);
      expect(preview.accountCount, 1);
      expect(preview.templateCount, 1);
      expect(preview.vaultIdMatchesCurrent, true);
    });

    test('previewVaultImport throws VaultImportException on invalid dump', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(null, exception: const VaultDumpImportException('Corrupt'));
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: _MockIdentityService(),
        storageService: _MockStorageService(),
        syncService: _MockSyncService(),
      );

      expect(
        () => coordinator.previewVaultImport(_makePreview(vaultDump: 'bad')),
        throwsA(isA<VaultImportException>()),
      );
    });

    test('importVaultIdentityPreview succeeds with data and forceOverwrite', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(VaultDumpImportPlan(
        templates: [_makeTemplate(id: 't1', title: 'T1')],
        accounts: [_makeAccount(id: 'a1', name: 'A1')],
      ));
      final identity = _MockIdentityService();
      final storage = _MockStorageService();
      storage.accounts['old'] = _makeAccount(id: 'old', name: 'Old');
      final sync = _MockSyncService();
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: identity,
        storageService: storage,
        syncService: sync,
      );

      await coordinator.importVaultIdentityPreview(
        _makePreview(vaultDump: 'dump', syncServerUrl: 'https://example.com'),
        forceOverwrite: true,
      );

      expect(sync.disconnectCalled, true);
      expect(identity._lastAppliedPreview, isNotNull);
      expect(dump.importValidatedCalled, true);
      expect(sync.initializeCalled, true);
    });

    test('importVaultIdentityPreview clears local data when dump has no data', () async {
      final dump = _MockDumpCoordinator();
      final identity = _MockIdentityService();
      final storage = _MockStorageService();
      storage.accounts['old'] = _makeAccount(id: 'old', name: 'Old');
      final sync = _MockSyncService();
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: identity,
        storageService: storage,
        syncService: sync,
      );

      await coordinator.importVaultIdentityPreview(
        _makePreview(),
        forceOverwrite: true,
      );

      expect(storage.clearAllDataCalled, true);
      expect(dump.importValidatedCalled, false);
      expect(sync.initializeCalled, true);
    });

    test('importVaultIdentityPreview throws precondition when local data exists and no force', () async {
      final storage = _MockStorageService();
      storage.accounts['old'] = _makeAccount(id: 'old', name: 'Old');
      final sync = _MockSyncService();
      final coordinator = _createCoordinator(
        dumpCoordinator: _MockDumpCoordinator(),
        identityService: _MockIdentityService(),
        storageService: storage,
        syncService: sync,
      );

      expect(
        () => coordinator.importVaultIdentityPreview(
          _makePreview(),
          forceOverwrite: false,
        ),
        throwsA(isA<VaultImportPreconditionException>()),
      );
      expect(sync.disconnectCalled, false);
    });

    test('importVaultIdentityPreview rolls back identity on initialize failure', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(VaultDumpImportPlan(
        templates: [_makeTemplate(id: 't1', title: 'T1')],
        accounts: [_makeAccount(id: 'a1', name: 'A1')],
      ));
      final identity = _MockIdentityService();
      final sync = _MockSyncService()..setThrowOnInitializeTimes(1);
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: identity,
        storageService: _MockStorageService(),
        syncService: sync,
      );

      VaultImportException? caught;
      try {
        await coordinator.importVaultIdentityPreview(
          _makePreview(vaultDump: 'dump'),
          forceOverwrite: true,
        );
      } on VaultImportException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(identity.applyImportCount, 2);
      expect(identity.currentImportPreviewCount, 1);
      expect(sync.initializeCalled, true);
    });

    test('importVaultIdentityPreview rolls back on importValidated failure', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(VaultDumpImportPlan(
        templates: [_makeTemplate(id: 't1', title: 'T1')],
        accounts: [_makeAccount(id: 'a1', name: 'A1')],
      ));
      dump.setImportValidatedException(Exception('write failed'));
      final identity = _MockIdentityService();
      final sync = _MockSyncService();
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: identity,
        storageService: _MockStorageService(),
        syncService: sync,
      );

      VaultImportException? caught;
      try {
        await coordinator.importVaultIdentityPreview(
          _makePreview(vaultDump: 'dump'),
          forceOverwrite: true,
        );
      } on VaultImportException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(identity.applyImportCount, 2);
      expect(identity.currentImportPreviewCount, 1);
      expect(sync.initializeCalled, true);
    });

    test('previewSecureVaultLinkCode decrypts and previews', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(VaultDumpImportPlan(
        templates: [_makeTemplate(id: 't1', title: 'T1')],
        accounts: [_makeAccount(id: 'a1', name: 'A1')],
      ));
      final identity = _MockIdentityService();
      identity.setPreviewSecureLinkCodeResult(_makePreview(vaultDump: 'dump'));
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: identity,
        storageService: _MockStorageService(),
        syncService: _MockSyncService(),
      );

      final preview = await coordinator.previewSecureVaultLinkCode('code', 'password');
      expect(preview.vaultId, 'vault_12345678901234567890123456789012');
      expect(preview.includesDataSnapshot, true);
    });

    test('importVaultLinkCode parses transfer code and imports', () async {
      final identity = _MockIdentityService();
      identity.setPreviewTransferCodeResult(_makePreview());
      final sync = _MockSyncService();
      final coordinator = _createCoordinator(
        dumpCoordinator: _MockDumpCoordinator(),
        identityService: identity,
        storageService: _MockStorageService(),
        syncService: sync,
      );

      await coordinator.importVaultLinkCode('code', forceOverwrite: true);
      expect(sync.disconnectCalled, true);
      expect(sync.initializeCalled, true);
    });

    test('importSecureVaultLinkCode decrypts and imports', () async {
      final identity = _MockIdentityService();
      identity.setPreviewSecureLinkCodeResult(_makePreview());
      final sync = _MockSyncService();
      final coordinator = _createCoordinator(
        dumpCoordinator: _MockDumpCoordinator(),
        identityService: identity,
        storageService: _MockStorageService(),
        syncService: sync,
      );

      await coordinator.importSecureVaultLinkCode('code', 'password', forceOverwrite: true);
      expect(sync.disconnectCalled, true);
      expect(sync.initializeCalled, true);
    });

    test('importVaultIdentityPreview throws when validateIncomingVaultDump fails', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(null, exception: const VaultDumpImportException('Bad dump'));
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: _MockIdentityService(),
        storageService: _MockStorageService(),
        syncService: _MockSyncService(),
      );

      expect(
        () => coordinator.importVaultIdentityPreview(
          _makePreview(vaultDump: 'bad'),
          forceOverwrite: true,
        ),
        throwsA(isA<VaultImportException>()),
      );
    });

    test('importVaultIdentityPreview clears local data when dumpPlan is empty and hadLocalData', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(const VaultDumpImportPlan(
        templates: [],
        accounts: [],
      ));
      final identity = _MockIdentityService();
      final storage = _MockStorageService();
      storage.accounts['old'] = _makeAccount(id: 'old', name: 'Old');
      final sync = _MockSyncService();
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: identity,
        storageService: storage,
        syncService: sync,
      );

      await coordinator.importVaultIdentityPreview(
        _makePreview(vaultDump: 'dump'),
        forceOverwrite: true,
      );

      expect(storage.clearAllDataCalled, true);
      expect(dump.importValidatedCalled, false);
      expect(sync.initializeCalled, true);
    });

    test('importVaultIdentityPreview does not clear data when dumpPlan is empty and no local data', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(const VaultDumpImportPlan(
        templates: [],
        accounts: [],
      ));
      final identity = _MockIdentityService();
      final storage = _MockStorageService();
      final sync = _MockSyncService();
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: identity,
        storageService: storage,
        syncService: sync,
      );

      await coordinator.importVaultIdentityPreview(
        _makePreview(vaultDump: 'dump'),
        forceOverwrite: true,
      );

      expect(storage.clearAllDataCalled, false);
      expect(dump.importValidatedCalled, false);
      expect(sync.initializeCalled, true);
    });

    test('importVaultIdentityPreview rolls back on VaultDumpImportException from importValidated', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(VaultDumpImportPlan(
        templates: [_makeTemplate(id: 't1', title: 'T1')],
        accounts: [_makeAccount(id: 'a1', name: 'A1')],
      ));
      dump.setImportValidatedException(const VaultDumpImportException('write failed'));
      final identity = _MockIdentityService();
      final sync = _MockSyncService();
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: identity,
        storageService: _MockStorageService(),
        syncService: sync,
      );

      VaultImportException? caught;
      try {
        await coordinator.importVaultIdentityPreview(
          _makePreview(vaultDump: 'dump'),
          forceOverwrite: true,
        );
      } on VaultImportException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught!.message, 'write failed');
      expect(identity.applyImportCount, 2);
      expect(identity.currentImportPreviewCount, 1);
      expect(sync.initializeCalled, true);
    });

    test('previewVaultImport with no current identity', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(VaultDumpImportPlan(
        templates: [_makeTemplate(id: 't1', title: 'T1')],
        accounts: [_makeAccount(id: 'a1', name: 'A1')],
      ));
      final identity = _MockIdentityService(hasIdentity: false);
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: identity,
        storageService: _MockStorageService(),
        syncService: _MockSyncService(),
      );

      final preview = await coordinator.previewVaultImport(
        _makePreview(vaultDump: 'dump'),
      );
      expect(preview.vaultIdMatchesCurrent, false);
      expect(preview.accountCount, 1);
      expect(preview.templateCount, 1);
      expect(preview.hasLocalData, false);
    });

    test('previewVaultImport with mismatched vaultId', () async {
      final dump = _MockDumpCoordinator();
      dump.setValidateResult(VaultDumpImportPlan(
        templates: [_makeTemplate(id: 't1', title: 'T1')],
        accounts: [_makeAccount(id: 'a1', name: 'A1')],
      ));
      final identity = _MockIdentityService();
      final coordinator = _createCoordinator(
        dumpCoordinator: dump,
        identityService: identity,
        storageService: _MockStorageService(),
        syncService: _MockSyncService(),
      );

      final preview = await coordinator.previewVaultImport(
        const VaultIdentityImportPreview(
          vaultId: 'vault_mismatchbbbbbbbbbbbbbbbbbbbb',
          privateKey: 'priv_1234567890123456789012345678901234567890123456789012345678901234',
          symmetricKey: 'sym_1234567890123456789012345678901234567890123456789012345678901234',
          vaultDump: 'dump',
        ),
      );
      expect(preview.vaultIdMatchesCurrent, false);
    });

    test('_hasLocalVaultDataForImport detects dirty sync state', () async {
      final storage = _MockStorageService();
      final sync = _MockSyncService()..setIsDirty(true);
      final coordinator = _createCoordinator(
        dumpCoordinator: _MockDumpCoordinator(),
        identityService: _MockIdentityService(),
        storageService: storage,
        syncService: sync,
      );

      final preview = await coordinator.previewVaultImport(_makePreview());
      expect(preview.hasLocalData, true);
    });

    test('exportSecureVaultLinkCode passes null syncServerUrl when empty', () async {
      final identity = _MockIdentityService();
      identity.setExportSecureLinkCodeResult('secure_code');
      final coordinator = _createCoordinator(
        dumpCoordinator: _MockDumpCoordinator(),
        identityService: identity,
        storageService: _MockStorageService(),
        syncService: _MockSyncService(),
      );

      final result = await coordinator.exportSecureVaultLinkCode(
        'password',
        includeData: false,
        resolveSyncServerUrl: () async => '',
      );
      expect(result, 'secure_code');
    });
  });
}
