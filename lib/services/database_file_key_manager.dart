import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'database_file_cipher.dart';

typedef SecureStorageReader = Future<String?> Function({required String key});
typedef SecureStorageWriter =
    Future<void> Function({required String key, required String value});
typedef SecureStorageDeleter = Future<void> Function({required String key});

class DatabaseFileKeyManager {
  static const String databaseKeySaltKey = 'database_key_salt_v1';
  static const String databaseKeyEnvelopeKey = 'database_file_key_envelope_v1';
  static const String previousDatabaseKeyEnvelopeKey =
      'database_file_key_envelope_previous_v1';
  static const int defaultPbkdf2Iterations = 100000;
  static const int _saltLength = 16;
  static const int _hashBits = 256;
  static const int _databaseFileKeyLength = 32;

  final SecureStorageReader read;
  final SecureStorageWriter write;
  final SecureStorageDeleter delete;
  final int pbkdf2Iterations;

  const DatabaseFileKeyManager({
    required this.read,
    required this.write,
    required this.delete,
    this.pbkdf2Iterations = defaultPbkdf2Iterations,
  }) : assert(pbkdf2Iterations > 0);

  Future<Uint8List> unlock(String password) async {
    final wrappingKeyBytes = await _deriveWrappingKeyBytes(password);
    final unlockResult = await _readOrCreateDatabaseFileKey(wrappingKeyBytes);

    if (unlockResult.usedPreviousEnvelope) {
      await _storeDatabaseKeyEnvelope(wrappingKeyBytes, unlockResult.keyBytes);
    }
    await delete(key: previousDatabaseKeyEnvelopeKey);
    return unlockResult.keyBytes;
  }

  Future<void> rotateEnvelope({
    required String newPassword,
    required Uint8List databaseKeyBytes,
  }) async {
    final currentEnvelope = await read(key: databaseKeyEnvelopeKey);
    if (currentEnvelope != null) {
      await write(key: previousDatabaseKeyEnvelopeKey, value: currentEnvelope);
    }
    final wrappingKeyBytes = await _deriveWrappingKeyBytes(newPassword);
    await _storeDatabaseKeyEnvelope(wrappingKeyBytes, databaseKeyBytes);
  }

  Future<Uint8List> _deriveWrappingKeyBytes(String password) async {
    final salt = await _readOrCreateDatabaseKeySalt();
    final nonce = <int>[
      ...utf8.encode('SecretRoy database key wrap v1'),
      ...salt,
    ];
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: pbkdf2Iterations,
      bits: _hashBits,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: nonce,
    );
    return Uint8List.fromList(await secretKey.extractBytes());
  }

  Future<_DatabaseFileKeyUnlockResult> _readOrCreateDatabaseFileKey(
    Uint8List wrappingKeyBytes,
  ) async {
    Object? primaryError;
    final primaryEnvelope = await read(key: databaseKeyEnvelopeKey);
    if (primaryEnvelope != null) {
      try {
        return _DatabaseFileKeyUnlockResult(
          await _decryptDatabaseKeyEnvelope(
            encodedEnvelope: primaryEnvelope,
            wrappingKeyBytes: wrappingKeyBytes,
          ),
        );
      } catch (error) {
        primaryError = error;
      }
    }

    final previousEnvelope = await read(key: previousDatabaseKeyEnvelopeKey);
    if (previousEnvelope != null) {
      try {
        return _DatabaseFileKeyUnlockResult(
          await _decryptDatabaseKeyEnvelope(
            encodedEnvelope: previousEnvelope,
            wrappingKeyBytes: wrappingKeyBytes,
          ),
          usedPreviousEnvelope: true,
        );
      } catch (_) {
        if (primaryError != null) {
          throw StateError('Database file key envelope could not be unlocked.');
        }
      }
    }

    if (primaryError != null) {
      throw StateError('Database file key envelope could not be unlocked.');
    }

    final keyBytes = DatabaseFileCipher.generateKeyBytes();
    await _storeDatabaseKeyEnvelope(wrappingKeyBytes, keyBytes);
    return _DatabaseFileKeyUnlockResult(keyBytes);
  }

  Future<Uint8List> _decryptDatabaseKeyEnvelope({
    required String encodedEnvelope,
    required Uint8List wrappingKeyBytes,
  }) async {
    late final Uint8List envelopeBytes;
    try {
      envelopeBytes = Uint8List.fromList(base64Decode(encodedEnvelope));
    } on FormatException catch (error) {
      throw StateError(
        'Database file key envelope is not valid base64: $error',
      );
    }

    final keyBytes = await DatabaseFileCipher(
      keyBytes: wrappingKeyBytes,
    ).decrypt(envelopeBytes);
    if (keyBytes.length != _databaseFileKeyLength) {
      throw StateError(
        'Database file key has invalid length: ${keyBytes.length}.',
      );
    }
    return keyBytes;
  }

  Future<void> _storeDatabaseKeyEnvelope(
    Uint8List wrappingKeyBytes,
    Uint8List databaseKeyBytes,
  ) async {
    final envelopeBytes = await DatabaseFileCipher(
      keyBytes: wrappingKeyBytes,
    ).encrypt(databaseKeyBytes);
    await write(
      key: databaseKeyEnvelopeKey,
      value: base64Encode(envelopeBytes),
    );
  }

  Future<List<int>> _readOrCreateDatabaseKeySalt() async {
    final encodedSalt = await read(key: databaseKeySaltKey);
    if (encodedSalt != null) {
      try {
        final salt = base64Decode(encodedSalt);
        if (salt.length >= _saltLength) {
          return salt;
        }
      } on FormatException {
        // Fall through and replace malformed local metadata.
      }
    }

    final salt = List<int>.generate(
      _saltLength,
      (_) => Random.secure().nextInt(256),
    );
    await write(key: databaseKeySaltKey, value: base64Encode(salt));
    return salt;
  }
}

class _DatabaseFileKeyUnlockResult {
  final Uint8List keyBytes;
  final bool usedPreviousEnvelope;

  const _DatabaseFileKeyUnlockResult(
    this.keyBytes, {
    this.usedPreviousEnvelope = false,
  });
}
