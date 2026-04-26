import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

abstract class SecureKeyValueStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  final FlutterSecureStorage _storage;

  const FlutterSecureKeyValueStore(this._storage);

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }
}

class IdentityCorruptedException implements Exception {
  final List<String> missingKeys;
  final List<String> invalidKeys;

  const IdentityCorruptedException({
    this.missingKeys = const [],
    this.invalidKeys = const [],
  });

  @override
  String toString() {
    final segments = <String>[];
    if (missingKeys.isNotEmpty) {
      segments.add('missing=${missingKeys.join(",")}');
    }
    if (invalidKeys.isNotEmpty) {
      segments.add('invalid=${invalidKeys.join(",")}');
    }
    final detail = segments.isEmpty ? 'unknown' : segments.join(' ');
    return 'IdentityCorruptedException($detail)';
  }
}

class IdentityTransferCodeException implements Exception {
  final String message;

  const IdentityTransferCodeException(this.message);

  @override
  String toString() => 'IdentityTransferCodeException($message)';
}

class IdentityService {
  static const String _transferCodePrefix = 'sroy-link-v1:';
  static const String _deviceIdKey = 'device_id';
  static const String _vaultIdKey = 'vault_id';
  static const String _privateKeyKey = 'private_key';
  static const String _symmetricKeyKey = 'symmetric_key';

  static final RegExp _currentDeviceIdPattern = RegExp(
    r'^device_[a-f0-9]{12}$',
    caseSensitive: false,
  );
  static final RegExp _legacyDeviceIdPattern = RegExp(
    r'^[a-f0-9]{8}$',
    caseSensitive: false,
  );
  static final RegExp _vaultIdPattern = RegExp(
    r'^vault_[a-f0-9]{32}$',
    caseSensitive: false,
  );
  static final RegExp _privateKeyPattern = RegExp(
    r'^priv_[a-f0-9]{64}$',
    caseSensitive: false,
  );
  static final RegExp _symmetricKeyPattern = RegExp(
    r'^sym_[a-f0-9]{64}$',
    caseSensitive: false,
  );

  final SecureKeyValueStore secureStorage;
  final Uuid _uuid;

  String? _deviceId;
  String? _vaultId;
  String? _privateKeyMock;
  String? _symmetricKeyMock;

  IdentityService({required this.secureStorage, Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  String get deviceId => _requireValue(_deviceId, 'deviceId');
  String get vaultId => _requireValue(_vaultId, 'vaultId');

  bool get hasIdentity =>
      _deviceId != null &&
      _vaultId != null &&
      _privateKeyMock != null &&
      _symmetricKeyMock != null;

  Future<bool> checkIdentityExists() async {
    final storedVaultId = await secureStorage.read(key: _vaultIdKey);
    final storedPrivateKey = await secureStorage.read(key: _privateKeyKey);
    final storedSymmetricKey = await secureStorage.read(key: _symmetricKeyKey);
    return storedVaultId != null &&
        storedPrivateKey != null &&
        storedSymmetricKey != null;
  }

  String get privateKey => _requireValue(_privateKeyMock, 'privateKey');
  String get symmetricKey => _requireValue(_symmetricKeyMock, 'symmetricKey');

  String exportTransferCode({String? syncServerUrl, String? vaultDump}) {
    final payload = {
      'version': 1,
      'vault_id': vaultId,
      'private_key': privateKey,
      'symmetric_key': symmetricKey,
      if (syncServerUrl != null) 'sync_server_url': syncServerUrl,
      if (vaultDump != null) 'vault_dump': vaultDump,
    };
    final encoded = base64UrlEncode(utf8.encode(jsonEncode(payload)));
    return '$_transferCodePrefix$encoded';
  }

  String exportSecureLinkCode(String password, {String? syncServerUrl, String? vaultDump}) {
    final payload = {
      'v': 2, // New version for secure code
      'vid': vaultId,
      'pk': privateKey,
      'sk': symmetricKey,
      if (syncServerUrl != null) 'url': syncServerUrl,
      if (vaultDump != null) 'dump': vaultDump,
    };
    
    final jsonBytes = utf8.encode(jsonEncode(payload));
    // Compression
    final compressedBytes = zlib.encode(jsonBytes);
    
    // Simple encryption derived from password
    final key = sha256.convert(utf8.encode(password)).bytes;
    final encryptedBytes = _xorBytes(compressedBytes, key);
    
    final encoded = base64UrlEncode(encryptedBytes);
    return 'sroy-secure-v1:$encoded';
  }

  Future<Map<String, String?>> importSecureLinkCode(String secureCode, String password) async {
    const prefix = 'sroy-secure-v1:';
    if (!secureCode.startsWith(prefix)) {
      throw const IdentityTransferCodeException('Invalid secure link code format.');
    }
    
    try {
      final encryptedBytes = base64Url.decode(secureCode.substring(prefix.length));
      final key = sha256.convert(utf8.encode(password)).bytes;
      final compressedBytes = _xorBytes(encryptedBytes, key);
      
      final jsonBytes = zlib.decode(compressedBytes);
      final payload = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
      
      if (payload['v'] != 2) throw const IdentityTransferCodeException('Unsupported secure code version.');
      
      _vaultId = payload['vid'] as String;
      _privateKeyMock = payload['pk'] as String;
      _symmetricKeyMock = payload['sk'] as String;

      await secureStorage.write(key: _vaultIdKey, value: _vaultId!);
      await secureStorage.write(key: _privateKeyKey, value: _privateKeyMock!);
      await secureStorage.write(key: _symmetricKeyKey, value: _symmetricKeyMock!);

      return {
        'sync_server_url': payload['url'] as String?,
        'vault_dump': payload['dump'] as String?,
      };
    } catch (e) {
      throw IdentityTransferCodeException('Failed to decrypt link code. Wrong password? ($e)');
    }
  }

  List<int> _xorBytes(List<int> input, List<int> key) {
    final output = List<int>.filled(input.length, 0);
    for (var i = 0; i < input.length; i++) {
      output[i] = input[i] ^ key[i % key.length];
    }
    return output;
  }

  Future<Map<String, String?>> importTransferCode(String rawCode) async {
    await _ensureDeviceId();

    final normalized = rawCode.trim();
    if (normalized.isEmpty) {
      throw const IdentityTransferCodeException('Transfer code is empty.');
    }

    final encodedPayload = normalized.startsWith(_transferCodePrefix)
        ? normalized.substring(_transferCodePrefix.length)
        : normalized;

    Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(
        jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(encodedPayload)),
              ),
            )
            as Map,
      );
    } catch (_) {
      throw const IdentityTransferCodeException(
        'Transfer code is not valid base64 JSON.',
      );
    }

    final version = payload['version'];
    final importedVaultId = payload['vault_id'] as String?;
    final importedPrivateKey = payload['private_key'] as String?;
    final importedSymmetricKey = payload['symmetric_key'] as String?;

    if (version != 1) {
      throw const IdentityTransferCodeException(
        'Unsupported transfer code version.',
      );
    }
    if (importedVaultId == null || !_vaultIdPattern.hasMatch(importedVaultId)) {
      throw const IdentityTransferCodeException(
        'Transfer code vault id is invalid.',
      );
    }
    if (importedPrivateKey == null ||
        !_privateKeyPattern.hasMatch(importedPrivateKey)) {
      throw const IdentityTransferCodeException(
        'Transfer code private key is invalid.',
      );
    }
    if (importedSymmetricKey == null ||
        !_symmetricKeyPattern.hasMatch(importedSymmetricKey)) {
      throw const IdentityTransferCodeException(
        'Transfer code symmetric key is invalid.',
      );
    }

    _vaultId = importedVaultId;
    _privateKeyMock = importedPrivateKey;
    _symmetricKeyMock = importedSymmetricKey;

    await secureStorage.write(key: _vaultIdKey, value: _vaultId!);
    await secureStorage.write(key: _privateKeyKey, value: _privateKeyMock!);
    await secureStorage.write(key: _symmetricKeyKey, value: _symmetricKeyMock!);
    
    return {
      'sync_server_url': payload['sync_server_url'] as String?,
      'vault_dump': payload['vault_dump'] as String?,
    };
  }

  Future<void> initialize() async {
    await _ensureDeviceId();

    final storedVaultId = await secureStorage.read(key: _vaultIdKey);
    final storedPrivateKey = await secureStorage.read(key: _privateKeyKey);
    final storedSymmetricKey = await secureStorage.read(key: _symmetricKeyKey);

    final identityEntries = <String, String?>{
      _vaultIdKey: storedVaultId,
      _privateKeyKey: storedPrivateKey,
      _symmetricKeyKey: storedSymmetricKey,
    };
    final populatedIdentityKeys = identityEntries.entries
        .where((entry) => entry.value != null)
        .map((entry) => entry.key)
        .toList();

    if (populatedIdentityKeys.isEmpty) {
      await _generateIdentity();
      return;
    }

    if (populatedIdentityKeys.length != identityEntries.length) {
      final missingKeys = identityEntries.entries
          .where((entry) => entry.value == null)
          .map((entry) => entry.key)
          .toList();
      throw IdentityCorruptedException(missingKeys: missingKeys);
    }

    final invalidKeys = <String>[];
    if (!_vaultIdPattern.hasMatch(storedVaultId!)) {
      invalidKeys.add(_vaultIdKey);
    }
    if (!_privateKeyPattern.hasMatch(storedPrivateKey!)) {
      invalidKeys.add(_privateKeyKey);
    }
    if (!_symmetricKeyPattern.hasMatch(storedSymmetricKey!)) {
      invalidKeys.add(_symmetricKeyKey);
    }
    if (invalidKeys.isNotEmpty) {
      throw IdentityCorruptedException(invalidKeys: invalidKeys);
    }

    _vaultId = storedVaultId;
    _privateKeyMock = storedPrivateKey;
    _symmetricKeyMock = storedSymmetricKey;
  }

  Future<void> _generateIdentity() async {
    _vaultId = 'vault_${_randomHex(32)}';
    _privateKeyMock = 'priv_${_randomHex(64)}';
    _symmetricKeyMock = 'sym_${_randomHex(64)}';

    await secureStorage.write(key: _vaultIdKey, value: _vaultId!);
    await secureStorage.write(key: _privateKeyKey, value: _privateKeyMock!);
    await secureStorage.write(key: _symmetricKeyKey, value: _symmetricKeyMock!);
  }

  Future<void> _ensureDeviceId() async {
    if (_deviceId != null) return;

    final storedDeviceId = await secureStorage.read(key: _deviceIdKey);
    if (storedDeviceId == null) {
      _deviceId = _generateDeviceId();
      await secureStorage.write(key: _deviceIdKey, value: _deviceId!);
      return;
    }

    if (!_isValidDeviceId(storedDeviceId)) {
      throw const IdentityCorruptedException(invalidKeys: [_deviceIdKey]);
    }
    _deviceId = storedDeviceId;
  }

  String _generateDeviceId() {
    return 'device_${_randomHex(12)}';
  }

  String _randomHex(int length) {
    final buffer = StringBuffer();
    while (buffer.length < length) {
      buffer.write(_uuid.v4().replaceAll('-', ''));
    }
    return buffer.toString().substring(0, length);
  }

  bool _isValidDeviceId(String value) {
    return _currentDeviceIdPattern.hasMatch(value) ||
        _legacyDeviceIdPattern.hasMatch(value);
  }

  String _requireValue(String? value, String fieldName) {
    if (value != null) {
      return value;
    }
    throw StateError(
      'IdentityService.$fieldName accessed before identity initialization completed.',
    );
  }
}
