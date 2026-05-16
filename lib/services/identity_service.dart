import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:secret_roy/core/crypto_random.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

abstract class SecureKeyValueStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
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

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
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

class VaultIdentityImportPreview {
  final String vaultId;
  final String privateKey;
  final String symmetricKey;
  final String? syncServerUrl;
  final String? vaultDump;
  final String? vaultApiToken;

  const VaultIdentityImportPreview({
    required this.vaultId,
    required this.privateKey,
    required this.symmetricKey,
    this.syncServerUrl,
    this.vaultDump,
    this.vaultApiToken,
  });

  String? operator [](String key) {
    return switch (key) {
      'sync_server_url' => syncServerUrl,
      'vault_dump' => vaultDump,
      'vault_api_token' => vaultApiToken,
      _ => null,
    };
  }

  Map<String, String?> toLegacyMap() {
    return {
      'sync_server_url': syncServerUrl,
      'vault_dump': vaultDump,
      'vault_api_token': vaultApiToken,
    };
  }
}

/// 设备身份与保险库身份管理服务，负责生成、存储和导出 vault 身份密钥。
///
/// [IdentityService] 在首次初始化时自动生成 [deviceId]、[vaultId]、
/// [privateKey]、[symmetricKey] 等身份凭证，并持久化到 [SecureKeyValueStore]。
/// 这些凭证是设备在同步网络中的唯一标识，也是端到端加密与配对的基础。
///
/// 主要功能范围：
/// - 身份初始化与完整性校验（[initialize]、[checkIdentityExists]）。
/// - 安全导出/导入（加密恢复码、明文 transfer code）。
/// - Vault API Token 管理（[setVaultApiToken]）。
///
/// 使用场景：
/// ```dart
/// final identity = IdentityService(secureStorage: store);
/// await identity.initialize();
/// print(identity.vaultId); // vault_xxx...
/// ```
///
/// 生命周期：
/// - [initialize]（首次会自动生成身份）→ 各种读写操作。
/// - 导入操作（[importSecureLinkCode] 等）会覆盖现有身份。
///
/// 异常：
/// - [IdentityCorruptedException] 身份数据缺失或格式非法。
/// - [IdentityTransferCodeException] 恢复码/transfer code 格式错误或解密失败。
class IdentityService {
  static const String _transferCodePrefix = 'sroy-link:';
  static const String _secureCodePrefix = 'sroy-recovery:';
  static const String _deviceIdKey = 'device_id';
  static const String _vaultIdKey = 'vault_id';
  static const String _privateKeyKey = 'private_key';
  static const String _symmetricKeyKey = 'symmetric_key';
  static const String _vaultApiTokenKey = 'vault_api_token';
  static const int _secureLinkIterations = 150000;
  static const int _secureLinkSaltLength = 16;
  static const int _secureLinkNonceLength = 12;

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
  String? _privateKeyMaterial;
  String? _symmetricKeyMaterial;
  String? _vaultApiToken;

  IdentityService({required this.secureStorage, Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  String get deviceId => _requireValue(_deviceId, 'deviceId');
  String get vaultId => _requireValue(_vaultId, 'vaultId');
  String? get vaultApiToken => _vaultApiToken;

  bool get hasIdentity =>
      _deviceId != null &&
      _vaultId != null &&
      _privateKeyMaterial != null &&
      _symmetricKeyMaterial != null;

  Future<void> setVaultApiToken(String? token) async {
    if (token != null && token.isNotEmpty) {
      _vaultApiToken = token;
      await secureStorage.write(key: _vaultApiTokenKey, value: token);
    } else {
      _vaultApiToken = null;
      await secureStorage.write(key: _vaultApiTokenKey, value: '');
    }
  }

  /// 检查本地是否已存在完整的 vault 身份。
  ///
  /// 返回 true 当且仅当 vaultId、privateKey、symmetricKey 均存在且格式合法。
  /// 用于应用启动时判断用户是否已有保险库。
  Future<bool> checkIdentityExists() async {
    final storedVaultId = await secureStorage.read(key: _vaultIdKey);
    final storedPrivateKey = await secureStorage.read(key: _privateKeyKey);
    final storedSymmetricKey = await secureStorage.read(key: _symmetricKeyKey);
    return _isValidVaultIdentity(
      vaultId: storedVaultId,
      privateKey: storedPrivateKey,
      symmetricKey: storedSymmetricKey,
    );
  }

  String get privateKey => _requireValue(_privateKeyMaterial, 'privateKey');
  String get symmetricKey =>
      _requireValue(_symmetricKeyMaterial, 'symmetricKey');

  /// Exports vault identity as an unencrypted transfer code.
  ///
  /// **WARNING**: This encodes private key and symmetric key in cleartext
  /// base64. Anyone who obtains this string has full vault access.
  /// Prefer [exportSecureLinkCode] which encrypts with a password-derived key.
  @Deprecated('Use exportSecureLinkCode instead for encrypted export')
  String exportTransferCode({String? syncServerUrl, String? vaultDump}) {
    final payload = {
      'version': 1,
      'vault_id': vaultId,
      'private_key': privateKey,
      'symmetric_key': symmetricKey,
      if (syncServerUrl != null) 'sync_server_url': syncServerUrl,
      if (vaultDump != null) 'vault_dump': vaultDump,
      if (_vaultApiToken != null) 'vault_api_token': _vaultApiToken,
    };
    final encoded = base64UrlEncode(utf8.encode(jsonEncode(payload)));
    return '$_transferCodePrefix$encoded';
  }

  /// 将当前身份导出为密码加密的恢复码（secure link code）。
  ///
  /// [password] 用于派生 PBKDF2 加密密钥，必须非空。
  /// [syncServerUrl] 与 [vaultDump] 为可选附加数据，可一并加密到恢复码中。
  ///
  /// 返回带有 `sroy-recovery:` 前缀的字符串，可直接保存或打印。
  ///
  /// 抛出 [IdentityTransferCodeException] 当 [password] 为空时。
  Future<String> exportSecureLinkCode(
    String password, {
    String? syncServerUrl,
    String? vaultDump,
  }) async {
    _validateSecureLinkPassword(password);

    final payload = {
      'v': 1,
      'vid': vaultId,
      'pk': privateKey,
      'sk': symmetricKey,
      if (syncServerUrl != null) 'url': syncServerUrl,
      if (vaultDump != null) 'dump': vaultDump,
    };

    final salt = CryptoRandom.bytes(_secureLinkSaltLength);
    final nonce = CryptoRandom.bytes(_secureLinkNonceLength);
    final secretKey = await _deriveSecureLinkKey(
      password: password,
      salt: salt,
      iterations: _secureLinkIterations,
    );
    final secretBox = await AesGcm.with256bits().encrypt(
      zlib.encode(utf8.encode(jsonEncode(payload))),
      secretKey: secretKey,
      nonce: nonce,
    );

    final envelope = {
      'v': 1,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _secureLinkIterations,
      'salt': base64UrlEncode(salt),
      'nonce': base64UrlEncode(secretBox.nonce),
      'ciphertext': base64UrlEncode(secretBox.cipherText),
      'mac': base64UrlEncode(secretBox.mac.bytes),
    };

    return '$_secureCodePrefix${base64UrlEncode(utf8.encode(jsonEncode(envelope)))}';
  }

  /// 导入密码加密的恢复码，替换当前本地身份。
  ///
  /// [secureCode] 为带有 `sroy-recovery:` 前缀的恢复码字符串。
  /// [password] 为解密所需的密码。
  ///
  /// 返回导入的附加数据映射（如 sync_server_url、vault_dump 等）。
  /// 导入成功后会立即将新身份写入安全存储。
  ///
  /// 抛出 [IdentityTransferCodeException] 当格式错误或密码不正确时。
  Future<Map<String, String?>> importSecureLinkCode(
    String secureCode,
    String password,
  ) async {
    final preview = await previewSecureLinkCode(secureCode, password);
    await _applyVaultIdentityImport(preview);
    return preview.toLegacyMap();
  }

  /// 预览密码加密恢复码的内容，不修改本地身份。
  ///
  /// [secureCode] 为恢复码字符串，[password] 为解密密码。
  /// 返回 [VaultIdentityImportPreview] 包含 vaultId、privateKey、symmetricKey
  /// 及可选附加数据，可用于用户确认后再执行 [importSecureLinkCode]。
  ///
  /// 抛出 [IdentityTransferCodeException] 当格式错误或密码不正确时。
  Future<VaultIdentityImportPreview> previewSecureLinkCode(
    String secureCode,
    String password,
  ) async {
    _validateSecureLinkPassword(password);

    final normalized = secureCode.trim();
    if (normalized.startsWith(_secureCodePrefix)) {
      return _importSecureLinkCode(
        normalized.substring(_secureCodePrefix.length),
        password,
      );
    }
    throw const IdentityTransferCodeException('Invalid recovery code format.');
  }

  Future<VaultIdentityImportPreview> _importSecureLinkCode(
    String encodedEnvelope,
    String password,
  ) async {
    try {
      final envelope = Map<String, dynamic>.from(
        jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(encodedEnvelope)),
              ),
            )
            as Map,
      );

      if (envelope['v'] != 1 ||
          envelope['kdf'] != 'pbkdf2-hmac-sha256' ||
          envelope['iterations'] is! int) {
        throw const IdentityTransferCodeException(
          'Unsupported recovery code version.',
        );
      }

      final iterations = envelope['iterations'] as int;
      if (iterations <= 0) {
        throw const IdentityTransferCodeException(
          'Recovery code KDF parameters are invalid.',
        );
      }

      final salt = base64Url.decode(
        base64Url.normalize(envelope['salt'] as String? ?? ''),
      );
      final nonce = base64Url.decode(
        base64Url.normalize(envelope['nonce'] as String? ?? ''),
      );
      final cipherText = base64Url.decode(
        base64Url.normalize(envelope['ciphertext'] as String? ?? ''),
      );
      final macBytes = base64Url.decode(
        base64Url.normalize(envelope['mac'] as String? ?? ''),
      );

      final secretKey = await _deriveSecureLinkKey(
        password: password,
        salt: salt,
        iterations: iterations,
      );
      final clearBytes = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: secretKey,
      );
      final payload = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(zlib.decode(clearBytes))) as Map,
      );

      return _importVaultIdentityPayload(
        version: payload['v'],
        expectedVersion: 1,
        vaultId: payload['vid'] as String?,
        privateKey: payload['pk'] as String?,
        symmetricKey: payload['sk'] as String?,
        syncServerUrl: payload['url'] as String?,
        vaultDump: payload['dump'] as String?,
        sourceLabel: 'recovery code',
      );
    } on IdentityTransferCodeException {
      rethrow;
    } catch (e) {
      throw IdentityTransferCodeException(
        'Failed to decrypt recovery code. Wrong password? ($e)',
      );
    }
  }

  Future<Map<String, String?>> importTransferCode(String rawCode) async {
    final preview = await previewTransferCode(rawCode);
    await _applyVaultIdentityImport(preview);
    return preview.toLegacyMap();
  }

  Future<VaultIdentityImportPreview> previewTransferCode(String rawCode) async {
    await _ensureDeviceId();

    final normalized = rawCode.trim();
    if (normalized.isEmpty) {
      throw const IdentityTransferCodeException('Transfer code is empty.');
    }

    if (!normalized.startsWith(_transferCodePrefix)) {
      throw const IdentityTransferCodeException(
        'Invalid transfer code format.',
      );
    }
    final encodedPayload = normalized.substring(_transferCodePrefix.length);

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
    } catch (e) {
      throw IdentityTransferCodeException(
        'Transfer code is not valid base64 JSON: $e',
      );
    }

    return _importVaultIdentityPayload(
      version: payload['version'],
      expectedVersion: 1,
      vaultId: payload['vault_id'] as String?,
      privateKey: payload['private_key'] as String?,
      symmetricKey: payload['symmetric_key'] as String?,
      syncServerUrl: payload['sync_server_url'] as String?,
      vaultDump: payload['vault_dump'] as String?,
      vaultApiToken: payload['vault_api_token'] as String?,
      sourceLabel: 'transfer code',
    );
  }

  Future<VaultIdentityImportPreview> _importVaultIdentityPayload({
    required Object? version,
    required int expectedVersion,
    required String? vaultId,
    required String? privateKey,
    required String? symmetricKey,
    required String? syncServerUrl,
    required String? vaultDump,
    String? vaultApiToken,
    required String sourceLabel,
  }) async {
    await _ensureDeviceId();
    if (version != expectedVersion) {
      throw IdentityTransferCodeException('Unsupported $sourceLabel version.');
    }
    if (vaultId == null || !_vaultIdPattern.hasMatch(vaultId)) {
      throw IdentityTransferCodeException('$sourceLabel vault id is invalid.');
    }
    if (privateKey == null || !_privateKeyPattern.hasMatch(privateKey)) {
      throw IdentityTransferCodeException(
        '$sourceLabel private key is invalid.',
      );
    }
    if (symmetricKey == null || !_symmetricKeyPattern.hasMatch(symmetricKey)) {
      throw IdentityTransferCodeException(
        '$sourceLabel symmetric key is invalid.',
      );
    }

    return VaultIdentityImportPreview(
      vaultId: vaultId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
      syncServerUrl: syncServerUrl,
      vaultDump: vaultDump,
      vaultApiToken: vaultApiToken,
    );
  }

  Future<void> _applyVaultIdentityImport(
    VaultIdentityImportPreview preview,
  ) async {
    _vaultId = preview.vaultId;
    _privateKeyMaterial = preview.privateKey;
    _symmetricKeyMaterial = preview.symmetricKey;
    _vaultApiToken = preview.vaultApiToken;

    await secureStorage.write(key: _vaultIdKey, value: _vaultId!);
    await secureStorage.write(key: _privateKeyKey, value: _privateKeyMaterial!);
    await secureStorage.write(
      key: _symmetricKeyKey,
      value: _symmetricKeyMaterial!,
    );
    if (_vaultApiToken != null) {
      await secureStorage.write(key: _vaultApiTokenKey, value: _vaultApiToken!);
    } else {
      await secureStorage.write(key: _vaultApiTokenKey, value: '');
    }
  }

  VaultIdentityImportPreview currentImportPreview() {
    return VaultIdentityImportPreview(
      vaultId: vaultId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
      vaultApiToken: _vaultApiToken,
    );
  }

  Future<void> applyImportPreview(VaultIdentityImportPreview preview) {
    return _applyVaultIdentityImport(preview);
  }

  Future<SecretKey> _deriveSecureLinkKey({
    required String password,
    required List<int> salt,
    required int iterations,
  }) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  void _validateSecureLinkPassword(String password) {
    if (password.isEmpty) {
      throw const IdentityTransferCodeException(
        'Recovery password is required.',
      );
    }
  }

  /// 初始化身份服务，从安全存储读取或生成身份凭证。
  ///
  /// [allowGenerateVaultIdentity] 为 false 时，若本地无身份则抛出
  /// [IdentityCorruptedException] 而非自动生成。
  ///
  /// 正常流程：
  /// - 若身份完整且有效，加载到内存。
  /// - 若身份不存在且允许生成，创建新的 vault 身份并持久化。
  /// - 若身份部分损坏（部分 key 缺失或格式非法），抛出 [IdentityCorruptedException]。
  Future<void> initialize({bool allowGenerateVaultIdentity = true}) async {
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
      if (!allowGenerateVaultIdentity) {
        throw const IdentityCorruptedException(
          missingKeys: [_vaultIdKey, _privateKeyKey, _symmetricKeyKey],
        );
      }
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
    _privateKeyMaterial = storedPrivateKey;
    _symmetricKeyMaterial = storedSymmetricKey;

    final storedVaultApiToken = await secureStorage.read(
      key: _vaultApiTokenKey,
    );
    if (storedVaultApiToken != null && storedVaultApiToken.isNotEmpty) {
      _vaultApiToken = storedVaultApiToken;
    }
  }

  Future<void> _generateIdentity() async {
    _vaultId = 'vault_${_randomHex(32)}';
    _privateKeyMaterial = 'priv_${_randomHex(64)}';
    _symmetricKeyMaterial = 'sym_${_randomHex(64)}';

    await secureStorage.write(key: _vaultIdKey, value: _vaultId!);
    await secureStorage.write(key: _privateKeyKey, value: _privateKeyMaterial!);
    await secureStorage.write(
      key: _symmetricKeyKey,
      value: _symmetricKeyMaterial!,
    );
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

  bool _isValidVaultIdentity({
    required String? vaultId,
    required String? privateKey,
    required String? symmetricKey,
  }) {
    return vaultId != null &&
        privateKey != null &&
        symmetricKey != null &&
        _vaultIdPattern.hasMatch(vaultId) &&
        _privateKeyPattern.hasMatch(privateKey) &&
        _symmetricKeyPattern.hasMatch(symmetricKey);
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
