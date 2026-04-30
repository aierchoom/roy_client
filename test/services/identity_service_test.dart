import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/identity_service.dart';

class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values;

  _MemorySecureKeyValueStore([Map<String, String>? initialValues])
    : values = Map<String, String>.from(initialValues ?? const {});

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

const _validDeviceId = 'device_abcdef123456';
const _validVaultId = 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _validPrivateKey =
    'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _validSymmetricKey =
    'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  test('initialize persists and reuses a generated identity', () async {
    final store = _MemorySecureKeyValueStore();

    final firstService = IdentityService(secureStorage: store);
    await firstService.initialize();

    expect(firstService.hasIdentity, isTrue);
    expect(
      firstService.deviceId,
      matches(RegExp(r'^(device_[a-f0-9]{12}|[a-f0-9]{8})$')),
    );
    expect(firstService.vaultId, matches(RegExp(r'^vault_[a-f0-9]{32}$')));
    expect(firstService.privateKey, matches(RegExp(r'^priv_[a-f0-9]{64}$')));
    expect(firstService.symmetricKey, matches(RegExp(r'^sym_[a-f0-9]{64}$')));

    final secondService = IdentityService(secureStorage: store);
    await secondService.initialize();

    expect(secondService.deviceId, firstService.deviceId);
    expect(secondService.vaultId, firstService.vaultId);
    expect(secondService.privateKey, firstService.privateKey);
    expect(secondService.symmetricKey, firstService.symmetricKey);
  });

  test('independent stores generate different vault identities', () async {
    final firstService = IdentityService(
      secureStorage: _MemorySecureKeyValueStore(),
    );
    final secondService = IdentityService(
      secureStorage: _MemorySecureKeyValueStore(),
    );

    await firstService.initialize();
    await secondService.initialize();

    expect(firstService.vaultId, isNot(secondService.vaultId));
    expect(firstService.deviceId, isNot(secondService.deviceId));
  });

  test(
    'initialize refuses to create a new vault identity when generation is disabled',
    () async {
      final store = _MemorySecureKeyValueStore({'device_id': _validDeviceId});

      await expectLater(
        IdentityService(
          secureStorage: store,
        ).initialize(allowGenerateVaultIdentity: false),
        throwsA(
          isA<IdentityCorruptedException>().having(
            (error) => error.missingKeys,
            'missingKeys',
            containsAll(['vault_id', 'private_key', 'symmetric_key']),
          ),
        ),
      );
    },
  );

  test(
    'missing device id is repaired when vault identity is complete',
    () async {
      final store = _MemorySecureKeyValueStore({
        'vault_id': _validVaultId,
        'private_key': _validPrivateKey,
        'symmetric_key': _validSymmetricKey,
      });

      final service = IdentityService(secureStorage: store);
      await service.initialize(allowGenerateVaultIdentity: false);

      expect(service.deviceId, matches(RegExp(r'^device_[a-f0-9]{12}$')));
      expect(service.vaultId, _validVaultId);
      expect(service.privateKey, _validPrivateKey);
      expect(service.symmetricKey, _validSymmetricKey);
    },
  );

  test('checkIdentityExists validates vault identity material', () async {
    final completeStore = _MemorySecureKeyValueStore({
      'vault_id': _validVaultId,
      'private_key': _validPrivateKey,
      'symmetric_key': _validSymmetricKey,
    });
    final invalidStore = _MemorySecureKeyValueStore({
      'vault_id': _validVaultId,
      'private_key': 'not-a-private-key',
      'symmetric_key': _validSymmetricKey,
    });

    expect(
      await IdentityService(secureStorage: completeStore).checkIdentityExists(),
      isTrue,
    );
    expect(
      await IdentityService(secureStorage: invalidStore).checkIdentityExists(),
      isFalse,
    );
  });

  test('initialize rejects partially persisted identity state', () async {
    final store = _MemorySecureKeyValueStore({
      'device_id': _validDeviceId,
      'vault_id': _validVaultId,
      'private_key': _validPrivateKey,
    });

    expect(
      () => IdentityService(secureStorage: store).initialize(),
      throwsA(
        isA<IdentityCorruptedException>().having(
          (error) => error.missingKeys,
          'missingKeys',
          contains('symmetric_key'),
        ),
      ),
    );
  });
}
