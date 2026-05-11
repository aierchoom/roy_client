import 'package:secret_roy/services/identity_service.dart';

import '../sync/sync_server_test_harness.dart';

class FakeIdentityService extends IdentityService {
  final bool _hasIdentity;

  FakeIdentityService({bool hasIdentity = true})
      : _hasIdentity = hasIdentity,
        super(
          secureStorage: MemorySecureKeyValueStore(
            hasIdentity
                ? {
                    'vault_id': 'vault_12345678901234567890123456789012',
                    'private_key': 'priv_1234567890123456789012345678901234567890123456789012345678901234',
                    'symmetric_key': 'sym_1234567890123456789012345678901234567890123456789012345678901234',
                  }
                : {},
          ),
        );

  @override
  bool get hasIdentity => _hasIdentity;

  @override
  String get deviceId => 'device_test001';

  @override
  String get vaultId => 'vault_12345678901234567890123456789012';

  @override
  Future<void> initialize({bool allowGenerateVaultIdentity = true}) async {}
}
