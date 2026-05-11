import 'dart:typed_data';

import 'package:secret_roy/services/database_file_cipher.dart';
import 'package:secret_roy/services/enhanced_crypto_service.dart';

class FakeCryptoService extends EnhancedCryptoService {
  bool _unlocked = false;
  bool _shouldFail = false;
  bool _allowEmptyPassword = false;

  FakeCryptoService() : super(secureStorage: null);

  void setShouldFail(bool value) => _shouldFail = value;

  void setAllowEmptyPassword(bool value) => _allowEmptyPassword = value;

  @override
  Future<bool> initMasterKey(String masterPassword) async {
    if (_shouldFail) return false;
    _unlocked = masterPassword.isNotEmpty || _allowEmptyPassword;
    return _unlocked;
  }

  @override
  Future<bool> verifyMasterPassword(String password) async {
    return _unlocked;
  }

  @override
  Future<bool> updateMasterPassword(
    String oldPassword,
    String newPassword,
  ) async {
    return _unlocked;
  }

  @override
  void logout() {
    _unlocked = false;
  }

  @override
  DatabaseFileCipher createDatabaseFileCipher() {
    return FakeDatabaseFileCipher();
  }
}

class FakeDatabaseFileCipher extends DatabaseFileCipher {
  FakeDatabaseFileCipher() : super(keyBytes: Uint8List(32));

  @override
  Future<Uint8List> encrypt(Uint8List plaintext) async => plaintext;

  @override
  Future<Uint8List> decrypt(Uint8List encrypted) async => encrypted;
}
