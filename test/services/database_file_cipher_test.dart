import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/database_file_cipher.dart';

void main() {
  test('encrypts and decrypts a database byte stream', () async {
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final cipher = DatabaseFileCipher(keyBytes: key);
    final plaintext = Uint8List.fromList(
      utf8.encode('SQLite format 3\u0000secret rows go here'),
    );

    final encrypted = await cipher.encrypt(plaintext);
    final decrypted = await cipher.decrypt(encrypted);

    expect(DatabaseFileCipher.looksEncrypted(encrypted), isTrue);
    expect(
      utf8.decode(encrypted, allowMalformed: true),
      isNot(contains('secret rows')),
    );
    expect(decrypted, plaintext);
  });

  test('rejects decryption with the wrong key', () async {
    final cipher = DatabaseFileCipher(
      keyBytes: Uint8List.fromList(List<int>.filled(32, 7)),
    );
    final wrongCipher = DatabaseFileCipher(
      keyBytes: Uint8List.fromList(List<int>.filled(32, 9)),
    );
    final encrypted = await cipher.encrypt(Uint8List.fromList([1, 2, 3, 4]));

    expect(
      () => wrongCipher.decrypt(encrypted),
      throwsA(isA<DatabaseFileCipherException>()),
    );
  });

  test('rejects malformed envelopes', () async {
    final cipher = DatabaseFileCipher(
      keyBytes: Uint8List.fromList(List<int>.filled(32, 1)),
    );

    expect(DatabaseFileCipher.looksEncrypted([1, 2, 3]), isFalse);
    expect(
      () => cipher.decrypt(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<DatabaseFileCipherException>()),
    );
  });
}
