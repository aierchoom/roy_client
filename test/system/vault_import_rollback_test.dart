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
import 'package:secret_roy/services/database_file_cipher.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
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

class _FailingStorageService extends SecureStorageService {
  _FailingStorageService({super.databaseCipher});

  @override
  Future<void> replaceAllDataForImport({
    required List<AccountTemplate> templates,
    required List<AccountItem> accounts,
    List<dynamic> totpCredentials = const <dynamic>[],
  }) async {
    throw StateError('Simulated database write failure during import');
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
      'secret_roy_rollback_',
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

  group('Vault import rollback', () {
    test(
        'restores previous identity when dump write fails; old data remains readable',
        () async {
      // Set up initial identity (vault A)
      final identityA = IdentityService(
        secureStorage: _MemorySecureKeyValueStore()
          ..values.addAll({
            'device_id': 'device_abcdef123456',
            'vault_id': 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'private_key':
                'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'symmetric_key':
                'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'vault_api_token': 'token_a',
          }),
      );
      await identityA.initialize();

      // Set up storage that will fail during import
      final storage = _FailingStorageService(databaseCipher: cipher);
      await storage.initialize(deviceId: 'device_test');
      addTearDown(() => storage.close(dispose: true));

      // Store original data under identity A
      final originalAccount = AccountItem(
        id: 'account_original',
        name: 'Original Account',
        email: '',
        templateId: 'generic_info',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.zero('test'),
        emailHlc: Hlc.zero('test'),
        dataHlc: const {},
        syncStatus: SyncStatus.synchronized,
      );
      await storage.saveAccount(originalAccount, isSyncMerge: true);

      final coordinator = VaultDumpCoordinator(
        identityService: identityA,
        storageService: storage,
      );

      // Prepare a dump plan (simulating data from vault B)
      final dumpPlan = VaultDumpImportPlan(
        templates: const [],
        accounts: [
          AccountItem(
            id: 'account_new',
            name: 'New Account',
            email: '',
            templateId: 'generic_info',
            data: const {},
            createdAt: DateTime.now().millisecondsSinceEpoch,
            nameHlc: Hlc.zero('test'),
            emailHlc: Hlc.zero('test'),
            dataHlc: const {},
            syncStatus: SyncStatus.pendingPush,
          ),
        ],
      );

      // Capture previous identity for rollback
      final previousIdentity = identityA.currentImportPreview();

      // Prepare new identity (vault B)
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
      final newPreview = identityB.currentImportPreview();

      // Simulate ServiceManager._importVaultIdentityPreview rollback path
      var identityApplied = false;
      try {
        await identityA.applyImportPreview(newPreview);
        identityApplied = true;
        await coordinator.importValidatedVaultDump(dumpPlan);
        fail('Expected VaultDumpImportException');
      } on VaultDumpImportException {
        // Expected
        if (identityApplied) {
          await identityA.applyImportPreview(previousIdentity);
        }
      }

      // Verify previous identity is restored
      expect(identityA.vaultId, previousIdentity.vaultId);
      expect(identityA.privateKey, previousIdentity.privateKey);
      expect(identityA.symmetricKey, previousIdentity.symmetricKey);

      // Verify old data is still readable
      final loadedAccounts = await storage.loadAccounts();
      expect(loadedAccounts.length, 1);
      expect(loadedAccounts.single.id, 'account_original');
      expect(loadedAccounts.single.name, 'Original Account');
    });

    test('rolls back identity even for unexpected errors during import',
        () async {
      // Set up initial identity
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

      final previousIdentity = identity.currentImportPreview();

      final newIdentity = IdentityService(
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
      await newIdentity.initialize();
      final newPreview = newIdentity.currentImportPreview();

      var identityApplied = false;
      try {
        await identity.applyImportPreview(newPreview);
        identityApplied = true;
        throw Exception('Unexpected catastrophic failure');
      } catch (_) {
        if (identityApplied) {
          await identity.applyImportPreview(previousIdentity);
        }
      }

      expect(identity.vaultId, previousIdentity.vaultId);
      expect(identity.privateKey, previousIdentity.privateKey);
    });
  });
}
