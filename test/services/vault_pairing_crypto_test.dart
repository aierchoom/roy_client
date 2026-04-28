import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/vault_pairing_crypto.dart';

void main() {
  test(
    'pairing bundle encrypts to requester public key and decrypts locally',
    () async {
      const transferCode =
          'sroy-link-v1:eyJ2YXVsdF9pZCI6InZhdWx0XzEyMyIsInBrIjoicHJpdiJ9';
      final requester = await VaultPairingCrypto.createKeyPair();

      final wrappedBundle = await VaultPairingCrypto.encryptBundle(
        plainBundle: transferCode,
        requesterPublicKey: requester.publicKey,
      );
      final decrypted = await VaultPairingCrypto.decryptBundle(
        wrappedBundle: wrappedBundle,
        keyPair: requester,
      );

      expect(wrappedBundle, startsWith(VaultPairingCrypto.prefix));
      expect(wrappedBundle.contains(transferCode), isFalse);
      expect(decrypted, transferCode);
    },
  );

  test('pairing bundle rejects a different requester key', () async {
    final requester = await VaultPairingCrypto.createKeyPair();
    final otherRequester = await VaultPairingCrypto.createKeyPair();
    final wrappedBundle = await VaultPairingCrypto.encryptBundle(
      plainBundle: 'sroy-link-v1:test',
      requesterPublicKey: requester.publicKey,
    );

    expect(
      () => VaultPairingCrypto.decryptBundle(
        wrappedBundle: wrappedBundle,
        keyPair: otherRequester,
      ),
      throwsA(isA<VaultPairingCryptoException>()),
    );
  });
}
