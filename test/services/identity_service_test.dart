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

  test('initialize rejects partially persisted identity state', () async {
    final store = _MemorySecureKeyValueStore({
      'device_id': 'device_abcdef123456',
      'vault_id': 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'private_key':
          'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
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
