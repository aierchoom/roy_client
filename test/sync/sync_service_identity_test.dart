import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
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

  test(
    'secure identity link imports vault keys with the right password',
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

      expect(linkCode, startsWith('sroy-secure-v2:'));
      expect(linkCode.contains(sourceIdentity.privateKey), isFalse);
      expect(targetIdentity.deviceId, originalTargetDeviceId);
      expect(targetIdentity.vaultId, sourceIdentity.vaultId);
      expect(targetIdentity.privateKey, sourceIdentity.privateKey);
      expect(targetIdentity.symmetricKey, sourceIdentity.symmetricKey);
      expect(result['sync_server_url'], 'http://127.0.0.1:8080');
      expect(result['vault_dump'], 'encrypted-vault-dump');
    },
  );

  test('secure identity link rejects a wrong password', () async {
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

  test('secure identity link requires a transfer password', () async {
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
    'initialize migrates legacy dirty flag into vault-scoped metadata',
    () async {
      final storage = _FakeSecureStorageService()..settings['sync_dirty'] = '1';
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
      expect(
        storage.settings['sync_dirty_vault_11111111111111111111111111111111'],
        '1',
      );
    },
  );

  test('dirty state is isolated per vault', () async {
    final storage = _FakeSecureStorageService();
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
    await firstSyncService.markDirty();

    final secondSyncService = SyncService(
      storageService: storage,
      identityService: secondIdentity,
    );
    await secondSyncService.initialize();

    expect(firstSyncService.isDirty, isTrue);
    expect(secondSyncService.isDirty, isFalse);
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
}
