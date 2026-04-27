import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/database_file_cipher.dart';
import 'package:secret_roy/services/database_file_key_manager.dart';

class _MemorySecureStorage {
  final Map<String, String> values = {};

  Future<String?> read({required String key}) async => values[key];

  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

DatabaseFileKeyManager _manager(_MemorySecureStorage storage) {
  return DatabaseFileKeyManager(
    read: storage.read,
    write: storage.write,
    delete: storage.delete,
    pbkdf2Iterations: 1,
  );
}

void main() {
  test(
    'keeps the random database file key stable across password changes',
    () async {
      final storage = _MemorySecureStorage();
      final manager = _manager(storage);

      final keyBytes = await manager.unlock('old-password');
      final encryptedBytes = await DatabaseFileCipher(
        keyBytes: keyBytes,
      ).encrypt(Uint8List.fromList(utf8.encode('persisted sqlite bytes')));
      final firstEnvelope =
          storage.values[DatabaseFileKeyManager.databaseKeyEnvelopeKey];

      expect(firstEnvelope, isNotNull);
      expect(
        storage.values[DatabaseFileKeyManager.databaseKeySaltKey],
        isNotNull,
      );

      await manager.rotateEnvelope(
        newPassword: 'new-password',
        databaseKeyBytes: keyBytes,
      );
      final rotatedEnvelope =
          storage.values[DatabaseFileKeyManager.databaseKeyEnvelopeKey];
      expect(rotatedEnvelope, isNot(firstEnvelope));

      final unlockedKeyBytes = await _manager(storage).unlock('new-password');
      expect(unlockedKeyBytes, orderedEquals(keyBytes));
      expect(
        storage.values[DatabaseFileKeyManager.previousDatabaseKeyEnvelopeKey],
        isNull,
      );

      final decryptedBytes = await DatabaseFileCipher(
        keyBytes: unlockedKeyBytes,
      ).decrypt(encryptedBytes);
      expect(utf8.decode(decryptedBytes), 'persisted sqlite bytes');
    },
  );

  test(
    'recovers from the previous database key envelope after interruption',
    () async {
      final storage = _MemorySecureStorage();
      final manager = _manager(storage);

      final keyBytes = await manager.unlock('old-password');
      final encryptedBytes = await DatabaseFileCipher(
        keyBytes: keyBytes,
      ).encrypt(Uint8List.fromList(utf8.encode('recoverable sqlite bytes')));
      final oldEnvelope =
          storage.values[DatabaseFileKeyManager.databaseKeyEnvelopeKey];
      expect(oldEnvelope, isNotNull);

      const brokenPrimaryEnvelope = 'AQIDBAU=';
      storage.values[DatabaseFileKeyManager.previousDatabaseKeyEnvelopeKey] =
          oldEnvelope!;
      storage.values[DatabaseFileKeyManager.databaseKeyEnvelopeKey] =
          brokenPrimaryEnvelope;

      final recoveredKeyBytes = await _manager(storage).unlock('old-password');
      expect(recoveredKeyBytes, orderedEquals(keyBytes));
      expect(
        storage.values[DatabaseFileKeyManager.previousDatabaseKeyEnvelopeKey],
        isNull,
      );
      expect(
        storage.values[DatabaseFileKeyManager.databaseKeyEnvelopeKey],
        isNot(brokenPrimaryEnvelope),
      );

      final decryptedBytes = await DatabaseFileCipher(
        keyBytes: recoveredKeyBytes,
      ).decrypt(encryptedBytes);
      expect(utf8.decode(decryptedBytes), 'recoverable sqlite bytes');
    },
  );
}
