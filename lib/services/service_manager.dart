import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_item.dart';
import '../models/account_template.dart';
import '../sync/sync_payload_codec.dart';
import '../sync/sync_service.dart';
import 'auto_lock_service.dart';
import 'biometric_auth_service.dart';
import 'enhanced_crypto_service.dart';
import 'identity_service.dart';
import 'lan_pairing_service.dart';
import 'secure_storage_service.dart';
import 'vault_pairing_service.dart';

enum ServiceManagerState { uninitialized, locked, unlocking, unlocked, error }

class ServiceManager extends ChangeNotifier {
  static ServiceManager? _instance;

  static ServiceManager get instance {
    _instance ??= ServiceManager._internal();
    return _instance!;
  }

  static String get defaultSyncServerUrl {
    if (kIsWeb) return '';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return '';
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'http://127.0.0.1:8080';
      case TargetPlatform.fuchsia:
        return '';
    }
  }

  late final EnhancedCryptoService _cryptoService;
  late final BiometricAuthService _biometricService;
  late final AutoLockService _autoLockService;
  late final IdentityService _identityService;
  late final SecureStorageService _secureStorageService;
  late final SyncService _syncService;
  late final VaultPairingService _vaultPairingService;
  late final LanPairingService _lanPairingService;

  ServiceManagerState _state = ServiceManagerState.uninitialized;
  String? _errorMessage;
  AutoLockObserver? _autoLockObserver;
  VoidCallback? _autoLockListener;

  ServiceManager._internal() {
    const secureStorage = FlutterSecureStorage();
    _cryptoService = EnhancedCryptoService(secureStorage: secureStorage);
    _biometricService = BiometricAuthService(secureStorage: secureStorage);
    _autoLockService = AutoLockService(
      cryptoService: _cryptoService,
      secureStorage: secureStorage,
    );
    _identityService = IdentityService(
      secureStorage: const FlutterSecureKeyValueStore(secureStorage),
    );
    _secureStorageService = SecureStorageService();
    _syncService = SyncService(
      storageService: _secureStorageService,
      identityService: _identityService,
      config: SyncConfig(serverUrl: defaultSyncServerUrl),
    );
    _vaultPairingService = VaultPairingService();
    _lanPairingService = LanPairingService();
  }

  ServiceManagerState get state => _state;
  bool get isLocked => _state == ServiceManagerState.locked;
  bool get isUnlocked => _state == ServiceManagerState.unlocked;
  bool get hasIdentity => _identityService.hasIdentity;
  String? get errorMessage => _errorMessage;

  EnhancedCryptoService get cryptoService => _cryptoService;
  BiometricAuthService get biometricService => _biometricService;
  AutoLockService get autoLockService => _autoLockService;
  IdentityService get identityService => _identityService;
  SecureStorageService get storageService => _secureStorageService;
  SyncService get syncService => _syncService;

  Future<void> initialize() async {
    if (_state != ServiceManagerState.uninitialized) return;

    try {
      await _autoLockService.initialize();
      _updateState(ServiceManagerState.locked);
    } catch (e) {
      _setError('Initialization failed: $e');
    }
  }

  void setupLifecycleObserver() {
    if (_autoLockObserver != null) return;

    _autoLockObserver = AutoLockObserver(_autoLockService);
    WidgetsBinding.instance.addObserver(_autoLockObserver!);

    _autoLockListener = () {
      if (_autoLockService.isLocked && _state == ServiceManagerState.unlocked) {
        _syncService.reset();
        _updateState(ServiceManagerState.locked);
      }
    };
    _autoLockService.addListener(_autoLockListener!);
  }

  void disposeLifecycleObserver() {
    if (_autoLockObserver != null) {
      WidgetsBinding.instance.removeObserver(_autoLockObserver!);
      _autoLockObserver = null;
    }

    if (_autoLockListener != null) {
      _autoLockService.removeListener(_autoLockListener!);
      _autoLockListener = null;
    }
  }

  Future<UnlockResult> unlockWithPassword(String password) async {
    if (_state == ServiceManagerState.unlocking) {
      return UnlockResult.alreadyInProgress;
    }

    _updateState(ServiceManagerState.unlocking);
    return _completeUnlock(password);
  }

  Future<UnlockResult> _completeUnlock(String password) async {
    try {
      await _identityService.initialize();
      await _secureStorageService.initialize(
        deviceId: _identityService.deviceId,
      );
      final didUnlock = await _cryptoService.initMasterKey(password);
      if (!didUnlock) {
        await _secureStorageService.close();
        await _syncService.disconnect();
        _updateState(ServiceManagerState.locked);
        return UnlockResult.invalidPassword;
      }
      _autoLockService.unlock();
      await _syncService.initialize();

      unawaited(_syncService.connect());
      _updateState(ServiceManagerState.unlocked);
      return UnlockResult.success;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('Failed to unlock with password: $e');
        debugPrint(stack.toString());
      }
      _setError('Unlock failed: $e');
      return UnlockResult.error;
    }
  }

  Future<UnlockResult> unlockWithBiometric() async {
    if (_state == ServiceManagerState.unlocking) {
      return UnlockResult.alreadyInProgress;
    }

    final biometricStatus = await _biometricService.getStatus();
    if (biometricStatus != BiometricAuthStatus.enabled) {
      return UnlockResult.biometricNotEnabled;
    }

    _updateState(ServiceManagerState.unlocking);

    try {
      final password = await _biometricService.unlockWithBiometric();
      if (password == null) {
        _updateState(ServiceManagerState.locked);
        return UnlockResult.biometricFailed;
      }

      return _completeUnlock(password);
    } catch (e) {
      _setError('Biometric unlock failed: $e');
      return UnlockResult.error;
    }
  }

  void lock() {
    _autoLockService.lock();
    unawaited(_secureStorageService.close());
    unawaited(_syncService.disconnect());
    unawaited(_lanPairingService.stopHosting());
    _updateState(ServiceManagerState.locked);
  }

  Future<void> logout() async {
    lock();
    _cryptoService.logout();
  }

  Future<void> enableNoPasswordMode() async {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: 'no_password_mode', value: 'true');
    await unlockWithPassword('');
  }

  Future<bool> isNoPasswordMode() async {
    const secureStorage = FlutterSecureStorage();
    return await secureStorage.read(key: 'no_password_mode') == 'true';
  }

  Future<void> disableNoPasswordMode() async {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'no_password_mode');
  }

  Future<bool> changeMasterPassword(String oldPassword, String newPassword) async {
    final success = await _cryptoService.updateMasterPassword(oldPassword, newPassword);
    if (success) {
      if (newPassword.isNotEmpty) {
        await disableNoPasswordMode();
      } else {
        await enableNoPasswordMode();
      }
    }
    return success;
  }

  Future<bool> checkIdentityExists() async {
    return _identityService.checkIdentityExists();
  }

  Future<void> resetApplication() async {
    await logout();
    await _secureStorageService.deleteDatabaseFile();
    
    // Clear Secure Storage (Identity, Master Password mode, etc)
    const secureStorage = FlutterSecureStorage();
    await secureStorage.deleteAll();
    
    // Clear SharedPreferences (Server URL, pairing states, etc)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    _updateState(ServiceManagerState.locked);
  }

  Future<BiometricSetupResult> enableBiometric(String currentPassword) async {
    final isValidPassword = await _cryptoService.verifyMasterPassword(
      currentPassword,
    );
    if (!isValidPassword) {
      return BiometricSetupResult.invalidPassword;
    }
    return _biometricService.enableBiometric(currentPassword);
  }

  Future<void> disableBiometric() async {
    await _biometricService.disableBiometric();
  }

  Future<BiometricAuthStatus> getBiometricStatus() async {
    return _biometricService.getStatus();
  }

  Future<String> getBiometricName() async {
    return _biometricService.getBiometricName();
  }

  Future<void> saveAccount(AccountItem account) async {
    if (!isUnlocked) return;
    await _secureStorageService.saveAccount(account);
    await _syncService.markDirty();
    unawaited(_syncService.syncNow());
  }

  Future<void> deleteAccount(String id) async {
    if (!isUnlocked) return;
    await _secureStorageService.deleteAccount(id);
    await _syncService.markDirty();
    unawaited(_syncService.syncNow());
  }

  Future<int> countAccountsByTemplate(String templateId) async {
    if (!isUnlocked) return 0;
    return _secureStorageService.countAccountsByTemplate(templateId);
  }

  Future<void> saveTemplate(AccountTemplate template) async {
    if (!isUnlocked) return;
    await _secureStorageService.saveTemplate(template);
    await _syncService.markDirty();
    unawaited(_syncService.syncNow());
  }

  Future<void> deleteTemplate(String id) async {
    if (!isUnlocked) return;
    final usageCount = await _secureStorageService.countAccountsByTemplate(id);
    if (usageCount > 0) {
      throw TemplateInUseException(templateId: id, usageCount: usageCount);
    }
    await _secureStorageService.deleteTemplate(id);
    await _syncService.markDirty();
    unawaited(_syncService.syncNow());
  }

  Future<bool> connectToSyncServer() async {
    if (!isUnlocked) return false;
    return _syncService.connect();
  }

  Future<void> disconnectFromSyncServer() async {
    await _syncService.disconnect();
  }

  Future<SyncResult> syncNow() async {
    if (!isUnlocked) {
      return SyncResult.failure('Vault is locked.');
    }

    final result = await _syncService.syncNow();
    if (!result.success || !result.pulled) {
      return result;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    await _identityService.initialize();
    await _secureStorageService.initialize(deviceId: _identityService.deviceId);
    await _syncService.initialize();

    notifyListeners();

    return SyncResult.success(
      pulled: result.pulled,
      pushed: result.pushed,
      version: _syncService.localVersion,
      conflictCount: result.conflictCount,
      notice: result.notice,
    );
  }

  SyncState get syncState => _syncService.state;
  String? get syncErrorMessage => _syncService.errorMessage;
  String? get syncStatusNote => _syncService.statusNote;
  bool get isSyncConnected => _syncService.isConnected;
  int get syncVersion => _syncService.localVersion;
  bool get hasDirtyData => _syncService.isDirty;

  Future<String?> getSyncServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sync_server_url');
  }

  Future<void> setSyncServerUrl(String url) async {
    if (!isUnlocked) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_server_url', url);
    await disconnectFromSyncServer();
    notifyListeners();
  }

  Future<String?> _exportEncryptedVaultDump() async {
    if (!_identityService.hasIdentity) return null;
    
    final accountsList = await _secureStorageService.loadAccounts(includeDeleted: true);
    final templatesList = await _secureStorageService.loadCustomTemplates();
    
    final payloadJson = {
      'accounts': accountsList.map((a) => a.toJson()).toList(),
      'templates': templatesList.map((t) => t.toJson()).toList(),
    };
    
    return SyncPayloadCodec.encodePayload(
      payloadJson: payloadJson,
      vaultId: _identityService.vaultId,
      nodeId: _identityService.deviceId,
      privateKey: _identityService.privateKey,
      symmetricKey: _identityService.symmetricKey,
    );
  }

  Future<void> _importEncryptedVaultDump(String vaultDumpJson) async {
    if (!_identityService.hasIdentity) return;
    
    try {
      final payloadJson = SyncPayloadCodec.decodePayload(
        encodedPayload: vaultDumpJson,
        expectedVaultId: _identityService.vaultId,
        privateKey: _identityService.privateKey,
        symmetricKey: _identityService.symmetricKey,
      );
      
      final accountsList = payloadJson['accounts'] as List?;
      final templatesList = payloadJson['templates'] as List?;
      
      if (templatesList != null || accountsList != null) {
        await _secureStorageService.clearAllData();
      }
      
      if (templatesList != null) {
        for (final t in templatesList) {
          final template = AccountTemplate.fromJson(Map<String, dynamic>.from(t));
          await _secureStorageService.saveTemplate(template, isSyncMerge: true);
        }
      }
      
      if (accountsList != null) {
        for (final a in accountsList) {
          final account = AccountItem.fromJson(Map<String, dynamic>.from(a));
          await _secureStorageService.saveAccount(
            account.copyWith(syncStatus: SyncStatus.synchronized), 
            isSyncMerge: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to import vault dump: $e');
    }
  }

  Future<String> exportVaultLinkCode() async {
    final serverUrl = await _resolveSyncServerUrl(allowEmpty: true);
    final vaultDump = await _exportEncryptedVaultDump();
    return _identityService.exportTransferCode(
      syncServerUrl: serverUrl.isEmpty ? null : serverUrl,
      vaultDump: vaultDump,
    );
  }

  Future<String> exportSecureVaultLinkCode(String password, {bool includeData = false}) async {
    final serverUrl = await _resolveSyncServerUrl(allowEmpty: true);
    final vaultDump = includeData ? await _exportEncryptedVaultDump() : null;
    return _identityService.exportSecureLinkCode(
      password,
      syncServerUrl: serverUrl.isEmpty ? null : serverUrl,
      vaultDump: vaultDump,
    );
  }

  Future<void> importVaultLinkCode(String code) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }

    await _syncService.disconnect();
    final importResult = await _identityService.importTransferCode(code);
    final syncServerUrl = importResult['sync_server_url'];
    final vaultDump = importResult['vault_dump'];

    if (syncServerUrl != null && syncServerUrl.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_server_url', syncServerUrl);
    }

    if (vaultDump != null && vaultDump.isNotEmpty) {
      await _importEncryptedVaultDump(vaultDump);
    }
    await _syncService.initialize();
    notifyListeners();
  }

  Future<void> importSecureVaultLinkCode(String secureCode, String password) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }

    await _syncService.disconnect();
    final importResult = await _identityService.importSecureLinkCode(secureCode, password);
    final syncServerUrl = importResult['sync_server_url'];
    final vaultDump = importResult['vault_dump'];

    if (syncServerUrl != null && syncServerUrl.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_server_url', syncServerUrl);
    }

    if (vaultDump != null && vaultDump.isNotEmpty) {
      await _importEncryptedVaultDump(vaultDump);
    }
    await _syncService.initialize();
    notifyListeners();
  }

  Future<PairingSessionInfo> createVaultPairingSession({
    Duration ttl = const Duration(minutes: 10),
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }

    final serverUrl = await _resolveSyncServerUrl();
    return _vaultPairingService.createSession(
      serverUrl: serverUrl,
      vaultId: _identityService.vaultId,
      hostDeviceId: _identityService.deviceId,
      ttl: ttl,
    );
  }

  Future<PairingSessionStatus> getVaultPairingSessionStatus(
    String sessionId,
  ) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }

    final serverUrl = await _resolveSyncServerUrl();
    return _vaultPairingService.getHostSessionStatus(
      serverUrl: serverUrl,
      sessionId: sessionId,
      hostDeviceId: _identityService.deviceId,
    );
  }

  Future<void> approveVaultPairingRequest({
    required String sessionId,
    required String requestId,
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }

    final serverUrl = await _resolveSyncServerUrl();
    final vaultDump = await _exportEncryptedVaultDump();
    final wrappedVaultBundle = _identityService.exportTransferCode(
      syncServerUrl: serverUrl.isEmpty ? null : serverUrl,
      vaultDump: vaultDump,
    );
    await _vaultPairingService.approveSession(
      serverUrl: serverUrl,
      sessionId: sessionId,
      hostDeviceId: _identityService.deviceId,
      requestId: requestId,
      wrappedVaultBundle: wrappedVaultBundle,
    );
  }

  Future<PairingJoinResult> joinVaultPairingSession(String pairingCode) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }

    final serverUrl = await _resolveSyncServerUrl();
    return _vaultPairingService.joinSession(
      serverUrl: serverUrl,
      pairingCode: pairingCode.trim(),
      requesterDeviceId: _identityService.deviceId,
    );
  }

  Future<PairingBundleResult> fetchAndImportVaultPairingBundle({
    required String sessionId,
    required String requestId,
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }

    final serverUrl = await _resolveSyncServerUrl();
    final bundleResult = await _vaultPairingService.getBundle(
      serverUrl: serverUrl,
      sessionId: sessionId,
      requestId: requestId,
      requesterDeviceId: _identityService.deviceId,
    );

    if (bundleResult.status == 'approved') {
      final wrappedBundle = bundleResult.wrappedVaultBundle;
      if (wrappedBundle == null || wrappedBundle.isEmpty) {
        throw const VaultPairingServiceException(
          'Pairing bundle is empty. Retry the approval flow.',
        );
      }
      await importVaultLinkCode(wrappedBundle);
    }

    return bundleResult;
  }

  Future<LanPairingHostSession> startLanVaultPairingHost({
    Duration ttl = const Duration(minutes: 3),
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    if (kIsWeb) {
      throw const LanPairingServiceException(
        'LAN direct pairing is not supported on web builds.',
      );
    }

    final serverUrl = await _resolveSyncServerUrl(allowEmpty: true);
    final vaultDump = await _exportEncryptedVaultDump();
    final transferCode = _identityService.exportTransferCode(
      syncServerUrl: serverUrl.isEmpty ? null : serverUrl,
      vaultDump: vaultDump,
    );
    return _lanPairingService.startHosting(
      transferCode: transferCode,
      ttl: ttl,
    );
  }

  Future<void> stopLanVaultPairingHost() async {
    await _lanPairingService.stopHosting();
  }

  Future<void> joinLanVaultPairingWithCode(String pairingCode) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    if (kIsWeb) {
      throw const LanPairingServiceException(
        'LAN direct pairing is not supported on web builds.',
      );
    }

    final transferCode = await _lanPairingService.claimTransferCodeByCode(
      pairingCode: pairingCode,
      requesterDeviceId: _identityService.deviceId,
    );
    await importVaultLinkCode(transferCode);
  }

  Future<void> setAutoLockDuration(AutoLockDuration duration) async {
    await _autoLockService.setDuration(duration);
    notifyListeners();
  }

  AutoLockDuration get autoLockDuration => _autoLockService.duration;

  Future<String> _resolveSyncServerUrl({bool allowEmpty = false}) async {
    final normalized = _normalizeServerUrl(
      (await getSyncServerUrl()) ?? defaultSyncServerUrl,
    );
    if (normalized.isEmpty && !allowEmpty) {
      throw const VaultPairingServiceException(
        'Sync server URL is not configured.',
      );
    }
    return normalized;
  }

  String _normalizeServerUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) {
      return '';
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static String generatePassword({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSpecial = true,
  }) {
    return EnhancedCryptoService.generatePassword(
      length: length,
      includeUppercase: includeUppercase,
      includeLowercase: includeLowercase,
      includeNumbers: includeNumbers,
      includeSpecial: includeSpecial,
    );
  }

  static int calculatePasswordStrength(String password) {
    return EnhancedCryptoService.calculatePasswordStrength(password);
  }

  static String getPasswordStrengthLevel(int score) {
    return EnhancedCryptoService.getPasswordStrengthLevel(score);
  }

  void _updateState(ServiceManagerState newState) {
    _state = newState;
    if (newState != ServiceManagerState.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _updateState(ServiceManagerState.error);
  }

  @override
  void dispose() {
    disposeLifecycleObserver();
    _autoLockService.dispose();
    _syncService.dispose();
    _lanPairingService.dispose();
    unawaited(_secureStorageService.close());
    super.dispose();
  }
}

enum UnlockResult {
  success,
  invalidPassword,
  biometricNotEnabled,
  biometricFailed,
  alreadyInProgress,
  error,
}

class TemplateInUseException implements Exception {
  final String templateId;
  final int usageCount;

  const TemplateInUseException({
    required this.templateId,
    required this.usageCount,
  });

  @override
  String toString() {
    return 'TemplateInUseException(templateId: $templateId, usageCount: $usageCount)';
  }
}
