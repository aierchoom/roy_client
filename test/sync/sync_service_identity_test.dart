import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
import 'package:secret_roy/system/service_manager/sync_server_url_store.dart';
import 'package:secret_roy/system/service_manager/vault_dump_coordinator.dart';
import 'package:secret_roy/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class _FakeSecureStorageService extends SecureStorageService {
  final Map<String, String> settings = {};
  bool replaceAllDataForImportCalled = false;

  @override
  bool get isOpen => true;

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }

  @override
  Future<List<AccountTemplate>> loadDirtyTemplates() async => [];

  @override
  Future<void> ensurePendingSyncOutboxEntries(String vaultId) async {}

  @override
  Future<List<AccountItem>> loadAccounts({bool includeDeleted = false}) async =>
      [];

  @override
  Future<List<AccountTemplate>> loadCustomTemplates({
    bool includeDeleted = false,
  }) async => [];

  @override
  Future<void> replaceAllDataForImport({
    required List<AccountTemplate> templates,
    required List<AccountItem> accounts,
  }) async {
    replaceAllDataForImportCalled = true;
  }
}

IdentityService _identityWithVault({
  required String vaultId,
  String deviceId = 'device_abcdef123456',
}) {
  return IdentityService(
    secureStorage: _MemorySecureKeyValueStore()
      ..values.addAll({
        'device_id': deviceId,
        'vault_id': vaultId,
        'private_key':
            'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'symmetric_key':
            'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      }),
  );
}

String _recoveryMarker(String phase, {int localVersion = 0}) {
  return jsonEncode({
    'phase': phase,
    'local_version': localVersion,
    'started_at': '2026-04-30T10:00:00.000Z',
  });
}

void main() {
  test(
    'identity export/import reuses vault keys but keeps device id',
    () async {
      final sourceIdentity = IdentityService(
        secureStorage: _MemorySecureKeyValueStore(),
      );
      await sourceIdentity.initialize();
      final linkCode = sourceIdentity.exportTransferCode();

      final targetStore = _MemorySecureKeyValueStore();
      final targetIdentity = IdentityService(secureStorage: targetStore);
      await targetIdentity.initialize();
      final originalTargetDeviceId = targetIdentity.deviceId;

      await targetIdentity.importTransferCode(linkCode);

      expect(targetIdentity.deviceId, originalTargetDeviceId);
      expect(targetIdentity.vaultId, sourceIdentity.vaultId);
      expect(targetIdentity.privateKey, sourceIdentity.privateKey);
      expect(targetIdentity.symmetricKey, sourceIdentity.symmetricKey);
    },
  );

  test('identity import rejects malformed transfer code', () async {
    final identity = IdentityService(
      secureStorage: _MemorySecureKeyValueStore(),
    );
    await identity.initialize();

    expect(
      () => identity.importTransferCode('not-a-real-code'),
      throwsA(isA<IdentityTransferCodeException>()),
    );
  });

  test('identity preview does not apply imported vault keys', () async {
    final sourceIdentity = IdentityService(
      secureStorage: _MemorySecureKeyValueStore(),
    );
    await sourceIdentity.initialize();
    final linkCode = sourceIdentity.exportTransferCode();

    final targetIdentity = IdentityService(
      secureStorage: _MemorySecureKeyValueStore(),
    );
    await targetIdentity.initialize();
    final originalVaultId = targetIdentity.vaultId;

    final preview = await targetIdentity.previewTransferCode(linkCode);

    expect(preview.vaultId, sourceIdentity.vaultId);
    expect(targetIdentity.vaultId, originalVaultId);
  });

  test(
    'offline recovery code imports vault keys with the right password',
    () async {
      final sourceIdentity = IdentityService(
        secureStorage: _MemorySecureKeyValueStore(),
      );
      await sourceIdentity.initialize();
      final linkCode = await sourceIdentity.exportSecureLinkCode(
        'correct horse battery staple',
        syncServerUrl: 'http://127.0.0.1:8080',
        vaultDump: 'encrypted-vault-dump',
      );

      final targetIdentity = IdentityService(
        secureStorage: _MemorySecureKeyValueStore(),
      );
      await targetIdentity.initialize();
      final originalTargetDeviceId = targetIdentity.deviceId;

      final result = await targetIdentity.importSecureLinkCode(
        linkCode,
        'correct horse battery staple',
      );

      expect(linkCode, startsWith('sroy-recovery:'));
      expect(linkCode.contains(sourceIdentity.privateKey), isFalse);
      expect(targetIdentity.deviceId, originalTargetDeviceId);
      expect(targetIdentity.vaultId, sourceIdentity.vaultId);
      expect(targetIdentity.privateKey, sourceIdentity.privateKey);
      expect(targetIdentity.symmetricKey, sourceIdentity.symmetricKey);
      expect(result['sync_server_url'], 'http://127.0.0.1:8080');
      expect(result['vault_dump'], 'encrypted-vault-dump');
    },
  );

  test('offline recovery code rejects a wrong password', () async {
    final sourceIdentity = IdentityService(
      secureStorage: _MemorySecureKeyValueStore(),
    );
    await sourceIdentity.initialize();
    final linkCode = await sourceIdentity.exportSecureLinkCode(
      'right-password',
    );

    final targetIdentity = IdentityService(
      secureStorage: _MemorySecureKeyValueStore(),
    );
    await targetIdentity.initialize();

    expect(
      () => targetIdentity.importSecureLinkCode(linkCode, 'wrong-password'),
      throwsA(isA<IdentityTransferCodeException>()),
    );
  });

  test('offline recovery code requires a recovery password', () async {
    final identity = IdentityService(
      secureStorage: _MemorySecureKeyValueStore(),
    );
    await identity.initialize();

    expect(
      () => identity.exportSecureLinkCode(''),
      throwsA(isA<IdentityTransferCodeException>()),
    );
  });

  test('initialize stays inert before identity is established', () async {
    final syncService = SyncService(
      storageService: _FakeSecureStorageService(),
      identityService: IdentityService(
        secureStorage: _MemorySecureKeyValueStore(),
      ),
    );

    await syncService.initialize();

    expect(syncService.localVersion, 0);
    expect(syncService.lastSyncTime, isNull);
    expect(syncService.isDirty, isFalse);
  });

  test(
    'syncNow fails instead of pretending success when identity is missing',
    () async {
      SharedPreferences.setMockInitialValues({
        'sync_server_url': 'http://127.0.0.1:8080',
      });

      final syncService = SyncService(
        storageService: _FakeSecureStorageService(),
        identityService: IdentityService(
          secureStorage: _MemorySecureKeyValueStore(),
        ),
      );

      final result = await syncService.syncNow();

      expect(result.success, isFalse);
      expect(result.error, 'Identity not established.');
    },
  );

  test(
    'sync server URL store scopes migrated legacy values by vault',
    () async {
      SharedPreferences.setMockInitialValues({
        'sync_server_url': 'http://legacy.local',
      });
      const store = SyncServerUrlStore(defaultUrl: _emptyDefaultSyncUrl);

      final migrated = await store.read(vaultId: 'vault_1111');
      await store.write('http://vault2.local', vaultId: 'vault_2222');
      final prefs = await SharedPreferences.getInstance();

      expect(migrated, 'http://legacy.local');
      expect(
        prefs.getString('sync_server_url_vault_1111'),
        'http://legacy.local',
      );
      expect(await store.read(vaultId: 'vault_2222'), 'http://vault2.local');
      expect(await store.read(), 'http://legacy.local');
    },
  );

  test(
    'initialize migrates legacy sync metadata into vault-scoped keys',
    () async {
      const lastSync = '2026-04-30T10:00:00.000Z';
      final storage = _FakeSecureStorageService()
        ..settings['sync_dirty'] = '1'
        ..settings['sync_version'] = '12'
        ..settings['sync_last_time'] = lastSync
        ..settings['sync_recovery'] = _recoveryMarker('pull', localVersion: 12);
      final identityService = _identityWithVault(
        vaultId: 'vault_11111111111111111111111111111111',
      );
      await identityService.initialize();

      final syncService = SyncService(
        storageService: storage,
        identityService: identityService,
      );

      await syncService.initialize();

      expect(syncService.isDirty, isTrue);
      expect(syncService.localVersion, 12);
      expect(syncService.lastSyncTime, DateTime.parse(lastSync));
      expect(syncService.recoveryPhase, 'pull');
      expect(
        storage.settings['sync_dirty_vault_11111111111111111111111111111111'],
        '1',
      );
      expect(
        storage.settings['sync_version_vault_11111111111111111111111111111111'],
        '12',
      );
      expect(
        storage
            .settings['sync_last_time_vault_11111111111111111111111111111111'],
        lastSync,
      );
      expect(
        storage
            .settings['sync_recovery_vault_11111111111111111111111111111111'],
        isNotEmpty,
      );
    },
  );

  test('sync metadata state is isolated per vault', () async {
    final storage = _FakeSecureStorageService()
      ..settings['sync_version_vault_11111111111111111111111111111111'] = '7'
      ..settings['sync_dirty_vault_11111111111111111111111111111111'] = '1'
      ..settings['sync_recovery_vault_11111111111111111111111111111111'] =
          _recoveryMarker('push', localVersion: 7);
    final firstIdentity = _identityWithVault(
      vaultId: 'vault_11111111111111111111111111111111',
    );
    final secondIdentity = _identityWithVault(
      vaultId: 'vault_22222222222222222222222222222222',
      deviceId: 'device_123456abcdef',
    );
    await firstIdentity.initialize();
    await secondIdentity.initialize();

    final firstSyncService = SyncService(
      storageService: storage,
      identityService: firstIdentity,
    );
    await firstSyncService.initialize();

    final secondSyncService = SyncService(
      storageService: storage,
      identityService: secondIdentity,
    );
    await secondSyncService.initialize();

    expect(firstSyncService.isDirty, isTrue);
    expect(firstSyncService.localVersion, 7);
    expect(firstSyncService.recoveryPhase, 'push');
    expect(secondSyncService.isDirty, isFalse);
    expect(secondSyncService.localVersion, 0);
    expect(secondSyncService.recoveryPhase, isNull);
    expect(
      storage.settings['sync_dirty_vault_11111111111111111111111111111111'],
      '1',
    );
    expect(
      storage.settings.containsKey(
        'sync_dirty_vault_22222222222222222222222222222222',
      ),
      isFalse,
    );
  });

  test('vault dump import throws and does not write on invalid dump', () async {
    final identity = IdentityService(
      secureStorage: _MemorySecureKeyValueStore(),
    );
    await identity.initialize();
    final storage = _FakeSecureStorageService();
    final coordinator = VaultDumpCoordinator(
      identityService: identity,
      storageService: storage,
    );

    await expectLater(
      coordinator.importEncryptedVaultDump('not-a-vault-dump'),
      throwsA(isA<VaultDumpImportException>()),
    );
    expect(storage.replaceAllDataForImportCalled, isFalse);
  });
}

String _emptyDefaultSyncUrl() => '';
