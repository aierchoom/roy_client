import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/database_file_cipher.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
import 'package:secret_roy/services/totp_service.dart';
import 'package:secret_roy/sync/crdt_merge_engine.dart';
import 'package:secret_roy/system/service_manager/vault_dump_coordinator.dart';

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

class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory rootDirectory;
  late Directory documentsDirectory;
  late Directory temporaryDirectory;
  late DatabaseFileCipher cipher;

  setUp(() {
    rootDirectory = Directory.systemTemp.createTempSync(
      'secret_roy_vault_dump_',
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
      keyBytes: Uint8List.fromList(List<int>.filled(32, 21)),
    );
  });

  tearDown(() {
    if (rootDirectory.existsSync()) {
      rootDirectory.deleteSync(recursive: true);
    }
  });

  group('VaultDumpCoordinator', () {
    test('preserves source syncStatus during export and validate round-trip',
        () async {
      final identity = IdentityService(
        secureStorage: _MemorySecureKeyValueStore()
          ..values.addAll({
            'device_id': 'device_abcdef123456',
            'vault_id': 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'private_key':
                'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'symmetric_key':
                'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'vault_api_token': 'token_123',
          }),
      );
      await identity.initialize();

      final storage = SecureStorageService(databaseCipher: cipher);
      await storage.initialize(deviceId: 'device_test');
      addTearDown(() => storage.close(dispose: true));

      final coordinator = VaultDumpCoordinator(
        identityService: identity,
        storageService: storage,
      );

      final accountPending = _makeAccount(
        id: 'account_pending',
        name: 'Pending Account',
        syncStatus: SyncStatus.pendingPush,
      );
      final accountConflict = _makeAccount(
        id: 'account_conflict',
        name: 'Conflict Account',
        syncStatus: SyncStatus.conflict,
      );
      final accountSynced = _makeAccount(
        id: 'account_synced',
        name: 'Synced Account',
        syncStatus: SyncStatus.synchronized,
      );

      await storage.saveAccount(accountPending, isSyncMerge: true);
      await storage.saveAccount(accountConflict, isSyncMerge: true);
      await storage.saveAccount(accountSynced, isSyncMerge: true);

      final dump = await coordinator.exportEncryptedVaultDump();
      expect(dump, isNotNull);

      final plan = await coordinator.validateEncryptedVaultDump(
        vaultDumpJson: dump!,
        vaultId: identity.vaultId,
        privateKey: identity.privateKey,
        symmetricKey: identity.symmetricKey,
      );

      expect(plan.accounts.length, 3);

      final parsedPending = plan.accounts.singleWhere(
        (a) => a.id == 'account_pending',
      );
      final parsedConflict = plan.accounts.singleWhere(
        (a) => a.id == 'account_conflict',
      );
      final parsedSynced = plan.accounts.singleWhere(
        (a) => a.id == 'account_synced',
      );

      expect(parsedPending.syncStatus, SyncStatus.pendingPush);
      expect(parsedConflict.syncStatus, SyncStatus.conflict);
      expect(parsedSynced.syncStatus, SyncStatus.synchronized);
    });

    test('validateEncryptedVaultDump does not mutate coordinator identity',
        () async {
      final identityA = IdentityService(
        secureStorage: _MemorySecureKeyValueStore()
          ..values.addAll({
            'device_id': 'device_abcdef123456',
            'vault_id': 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'private_key':
                'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'symmetric_key':
                'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          }),
      );
      await identityA.initialize();

      final storage = SecureStorageService(databaseCipher: cipher);
      await storage.initialize(deviceId: 'device_test');
      addTearDown(() => storage.close(dispose: true));

      final coordinator = VaultDumpCoordinator(
        identityService: identityA,
        storageService: storage,
      );

      // Create a dump encrypted with vault B keys
      final identityB = IdentityService(
        secureStorage: _MemorySecureKeyValueStore()
          ..values.addAll({
            'device_id': 'device_abcdef123456',
            'vault_id': 'vault_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'private_key':
                'priv_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'symmetric_key':
                'sym_cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          }),
      );
      await identityB.initialize();

      final tempCoordinator = VaultDumpCoordinator(
        identityService: identityB,
        storageService: storage,
      );
      await storage.saveAccount(
        _makeAccount(id: 'b_account', name: 'B Account', syncStatus: SyncStatus.synchronized),
        isSyncMerge: true,
      );
      final dump = await tempCoordinator.exportEncryptedVaultDump();
      expect(dump, isNotNull);
      final dumpNonNull = dump!;

      // Validate using vault B keys should succeed
      final plan = await coordinator.validateEncryptedVaultDump(
        vaultDumpJson: dumpNonNull,
        vaultId: identityB.vaultId,
        privateKey: identityB.privateKey,
        symmetricKey: identityB.symmetricKey,
      );
      expect(plan.accounts, isNotEmpty);

      // Coordinator's own identity (A) must remain untouched
      expect(identityA.vaultId, 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      expect(identityA.privateKey,
          'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    });

    test('validateEncryptedVaultDump does not write to storage', () async {
      final identity = IdentityService(
        secureStorage: _MemorySecureKeyValueStore()
          ..values.addAll({
            'device_id': 'device_abcdef123456',
            'vault_id': 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'private_key':
                'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'symmetric_key':
                'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          }),
      );
      await identity.initialize();

      final storage = SecureStorageService(databaseCipher: cipher);
      await storage.initialize(deviceId: 'device_test');
      addTearDown(() => storage.close(dispose: true));

      // Seed storage with original data
      await storage.saveAccount(
        _makeAccount(id: 'original', name: 'Original', syncStatus: SyncStatus.synchronized),
        isSyncMerge: true,
      );

      final coordinator = VaultDumpCoordinator(
        identityService: identity,
        storageService: storage,
      );

      final dump = await coordinator.exportEncryptedVaultDump();
      expect(dump, isNotNull);

      final plan = await coordinator.validateEncryptedVaultDump(
        vaultDumpJson: dump!,
        vaultId: identity.vaultId,
        privateKey: identity.privateKey,
        symmetricKey: identity.symmetricKey,
      );
      expect(plan.accounts.length, 1);

      // Storage must still contain only the original account
      final loaded = await storage.loadAccounts();
      expect(loaded.length, 1);
      expect(loaded.single.id, 'original');
    });
  });

  group('SecureStorageService.replaceAllDataForImport', () {
    test('preserves syncStatus of imported accounts', () async {
      final storage = SecureStorageService(databaseCipher: cipher);
      await storage.initialize(deviceId: 'device_test');
      addTearDown(() => storage.close(dispose: true));

      final account = _makeAccount(
        id: 'account_1',
        name: 'Test Account',
        syncStatus: SyncStatus.pendingPush,
      );

      await storage.replaceAllDataForImport(
        templates: [],
        accounts: [account],
      );

      final loaded = await storage.loadAccounts();
      expect(loaded.length, 1);
      expect(loaded.single.syncStatus, SyncStatus.pendingPush);
    });

    test('preserves syncStatus of imported TOTP credentials', () async {
      final storage = SecureStorageService(databaseCipher: cipher);
      await storage.initialize(deviceId: 'device_test');
      addTearDown(() => storage.close(dispose: true));

      final credential = TotpCredential(
        id: 'totp_1',
        label: 'Test TOTP',
        config: const TotpConfig(secret: 'JBSWY3DPEHPK3PXP'),
        linkedAccountIds: const [],
        createdAt: DateTime.now().millisecondsSinceEpoch,
        labelHlc: Hlc.zero('test'),
        configHlc: Hlc.zero('test'),
        linksHlc: Hlc.zero('test'),
        syncStatus: SyncStatus.pendingPush,
      );

      await storage.replaceAllDataForImport(
        templates: [],
        accounts: [],
        totpCredentials: [credential],
      );

      final loaded = await storage.loadTotpCredentials();
      expect(loaded.length, 1);
      expect(loaded.single.syncStatus, SyncStatus.pendingPush);
    });

    test('clears outbox and conflict logs during import', () async {
      final storage = SecureStorageService(databaseCipher: cipher);
      await storage.initialize(deviceId: 'device_test');
      addTearDown(() => storage.close(dispose: true));

      const vaultId = 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      final account = _makeAccount(
        id: 'account_1',
        name: 'Test Account',
        syncStatus: SyncStatus.pendingPush,
      );
      await storage.saveAccount(account, isSyncMerge: true);

      await storage.ensurePendingSyncOutboxEntries(vaultId);
      final outboxBefore = await storage.loadOpenLocalSyncChanges(
        vaultId: vaultId,
      );
      expect(outboxBefore, isNotEmpty);

      await storage.saveConflictLogs([
        ConflictLog(
          accountId: 'account_1',
          fieldKey: 'name',
          fieldValue: 'conflicted',
          hlc: Hlc.zero('test'),
        ),
      ]);
      final conflictsBefore = await storage.getConflictLogs('account_1');
      expect(conflictsBefore, isNotEmpty);

      await storage.replaceAllDataForImport(
        templates: [],
        accounts: [account],
      );

      final outboxAfter = await storage.loadOpenLocalSyncChanges(
        vaultId: vaultId,
      );
      expect(outboxAfter, isEmpty);

      final conflictsAfter = await storage.getConflictLogs('account_1');
      expect(conflictsAfter, isEmpty);
    });

    test(
        'ensurePendingSyncOutboxEntries recreates outbox only for pendingPush accounts after import',
        () async {
      final storage = SecureStorageService(databaseCipher: cipher);
      await storage.initialize(deviceId: 'device_test');
      addTearDown(() => storage.close(dispose: true));

      const vaultId = 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      final accountPending = _makeAccount(
        id: 'account_pending',
        name: 'Pending Account',
        syncStatus: SyncStatus.pendingPush,
      );
      final accountConflict = _makeAccount(
        id: 'account_conflict',
        name: 'Conflict Account',
        syncStatus: SyncStatus.conflict,
      );
      final accountSynced = _makeAccount(
        id: 'account_synced',
        name: 'Synced Account',
        syncStatus: SyncStatus.synchronized,
      );

      await storage.replaceAllDataForImport(
        templates: [],
        accounts: [accountPending, accountConflict, accountSynced],
      );

      await storage.ensurePendingSyncOutboxEntries(vaultId);

      final outbox = await storage.loadOpenLocalSyncChanges(
        vaultId: vaultId,
      );
      expect(outbox.length, 1);
      expect(outbox.single.entityId, 'account_pending');
    });

    test('preserves sync settings during import', () async {
      final storage = SecureStorageService(databaseCipher: cipher);
      await storage.initialize(deviceId: 'device_test');
      addTearDown(() => storage.close(dispose: true));

      await storage.setSetting('sync_version_testvault', '42');
      await storage.setSetting('sync_dirty_testvault', '1');

      final account = _makeAccount(
        id: 'account_1',
        name: 'Test Account',
        syncStatus: SyncStatus.pendingPush,
      );
      await storage.replaceAllDataForImport(
        templates: [],
        accounts: [account],
      );

      final version = await storage.getSetting('sync_version_testvault');
      final dirty = await storage.getSetting('sync_dirty_testvault');
      expect(version, '42');
      expect(dirty, '1');
    });
  });
}

AccountItem _makeAccount({
  required String id,
  required String name,
  required SyncStatus syncStatus,
}) {
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
    syncStatus: syncStatus,
  );
}
