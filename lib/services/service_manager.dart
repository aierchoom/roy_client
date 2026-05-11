import 'dart:async';

import 'package:secret_roy/core/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/local_sync_change.dart';
import '../models/totp_credential.dart';
import '../sync/lan_sync_coordinator.dart';
import '../sync/sync_service.dart';
import '../system/service_manager/default_sync_server_url.dart';
import '../system/service_manager/password_tools.dart';
import '../system/service_manager/sync_coordinator.dart';
import '../system/service_manager/sync_server_url_store.dart';
import '../system/service_manager/vault_data_repository.dart';
import '../system/service_manager/vault_dump_coordinator.dart';
import '../system/service_manager/vault_import_export_coordinator.dart';
import '../system/service_manager/vault_import_types.dart';
import '../system/service_manager/vault_pairing_coordinator.dart';
import '../system/service_manager/vault_unlock_coordinator.dart';

export '../system/service_manager/vault_data_repository.dart' show TemplateInUseException;
export '../system/service_manager/vault_import_types.dart';
import 'auto_lock_service.dart';
import 'biometric_auth_service.dart';
import 'device_alias_service.dart';
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
    return defaultSyncServerUrlForCurrentPlatform();
  }

  late final EnhancedCryptoService _cryptoService;
  late final BiometricAuthService _biometricService;
  late final AutoLockService _autoLockService;
  late final IdentityService _identityService;
  late final SecureStorageService _secureStorageService;
  late DeviceAliasService _deviceAliasService;
  late final SyncService _syncService;
  late final VaultPairingService _vaultPairingService;
  late final LanPairingService _lanPairingService;
  late final SyncServerUrlStore _syncServerUrlStore;
  late final VaultDumpCoordinator _vaultDumpCoordinator;
  late final LanSyncCoordinator _lanSyncCoordinator;
  late final VaultUnlockCoordinator _vaultUnlockCoordinator;
  late final VaultDataRepository _vaultDataRepository;
  late final SyncCoordinator _syncCoordinator;
  late final VaultImportExportCoordinator _vaultImportExportCoordinator;
  late final VaultPairingCoordinator _vaultPairingCoordinator;

  ServiceManagerState _state = ServiceManagerState.uninitialized;
  String? _errorMessage;
  AutoLockObserver? _autoLockObserver;
  VoidCallback? _autoLockListener;

  bool _disposed = false;

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  ServiceManager._internal() {
    const secureStorage = FlutterSecureStorage();
    _cryptoService = EnhancedCryptoService(secureStorage: secureStorage);
    _biometricService = BiometricAuthService();
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
    _syncServerUrlStore = const SyncServerUrlStore();
    _vaultDumpCoordinator = VaultDumpCoordinator(
      identityService: _identityService,
      storageService: _secureStorageService,
    );
    _lanSyncCoordinator = LanSyncCoordinator(
      storage: _secureStorageService,
      identity: _identityService,
      pairing: _lanPairingService,
      syncService: _syncService,
    );
    _vaultUnlockCoordinator = VaultUnlockCoordinator(
      cryptoService: _cryptoService,
      secureStorageService: _secureStorageService,
      identityService: _identityService,
      autoLockService: _autoLockService,
      syncService: _syncService,
      biometricService: _biometricService,
      lanPairingService: _lanPairingService,
      lanSyncCoordinator: _lanSyncCoordinator,
    );
    _vaultDataRepository = VaultDataRepository(
      storage: _secureStorageService,
      identity: _identityService,
      sync: _syncService,
    );
    _syncCoordinator = SyncCoordinator(
      syncService: _syncService,
      identityService: _identityService,
      secureStorageService: _secureStorageService,
      syncServerUrlStore: _syncServerUrlStore,
    );
    _vaultImportExportCoordinator = VaultImportExportCoordinator(
      dumpCoordinator: _vaultDumpCoordinator,
      identityService: _identityService,
      storageService: _secureStorageService,
      syncService: _syncService,
      syncServerUrlStore: _syncServerUrlStore,
    );
    _vaultPairingCoordinator = VaultPairingCoordinator(
      vaultPairingService: _vaultPairingService,
      lanPairingService: _lanPairingService,
      identityService: _identityService,
      syncCoordinator: _syncCoordinator,
      importExportCoordinator: _vaultImportExportCoordinator,
    );
  }

  @visibleForTesting
  ServiceManager.testable({
    EnhancedCryptoService? cryptoService,
    BiometricAuthService? biometricService,
    AutoLockService? autoLockService,
    IdentityService? identityService,
    SecureStorageService? secureStorageService,
    DeviceAliasService? deviceAliasService,
    SyncService? syncService,
    VaultPairingService? vaultPairingService,
    LanPairingService? lanPairingService,
    SyncServerUrlStore? syncServerUrlStore,
    VaultDumpCoordinator? vaultDumpCoordinator,
    LanSyncCoordinator? lanSyncCoordinator,
    VaultUnlockCoordinator? vaultUnlockCoordinator,
    VaultDataRepository? vaultDataRepository,
    SyncCoordinator? syncCoordinator,
    VaultImportExportCoordinator? vaultImportExportCoordinator,
    VaultPairingCoordinator? vaultPairingCoordinator,
    ServiceManagerState initialState = ServiceManagerState.uninitialized,
  }) {
    const secureStorage = FlutterSecureStorage();
    _cryptoService = cryptoService ??
        EnhancedCryptoService(secureStorage: secureStorage);
    _biometricService = biometricService ?? BiometricAuthService();
    _autoLockService = autoLockService ??
        AutoLockService(
          cryptoService: _cryptoService,
          secureStorage: secureStorage,
        );
    _identityService = identityService ??
        IdentityService(
          secureStorage: const FlutterSecureKeyValueStore(secureStorage),
        );
    _secureStorageService = secureStorageService ?? SecureStorageService();
    _deviceAliasService = deviceAliasService ?? DeviceAliasService.testable();
    _syncService = syncService ??
        SyncService(
          storageService: _secureStorageService,
          identityService: _identityService,
          config: SyncConfig(serverUrl: defaultSyncServerUrl),
        );
    _vaultPairingService = vaultPairingService ?? VaultPairingService();
    _lanPairingService = lanPairingService ?? LanPairingService();
    _syncServerUrlStore = syncServerUrlStore ?? const SyncServerUrlStore();
    _vaultDumpCoordinator = vaultDumpCoordinator ??
        VaultDumpCoordinator(
          identityService: _identityService,
          storageService: _secureStorageService,
        );
    _lanSyncCoordinator = lanSyncCoordinator ??
        LanSyncCoordinator(
          storage: _secureStorageService,
          identity: _identityService,
          pairing: _lanPairingService,
          syncService: _syncService,
        );
    _vaultUnlockCoordinator = vaultUnlockCoordinator ??
        VaultUnlockCoordinator(
          cryptoService: _cryptoService,
          secureStorageService: _secureStorageService,
          identityService: _identityService,
          autoLockService: _autoLockService,
          syncService: _syncService,
          biometricService: _biometricService,
          lanPairingService: _lanPairingService,
          lanSyncCoordinator: _lanSyncCoordinator,
        );
    _vaultDataRepository = vaultDataRepository ??
        VaultDataRepository(
          storage: _secureStorageService,
          identity: _identityService,
          sync: _syncService,
        );
    _syncCoordinator = syncCoordinator ??
        SyncCoordinator(
          syncService: _syncService,
          identityService: _identityService,
          secureStorageService: _secureStorageService,
          syncServerUrlStore: _syncServerUrlStore,
        );
    _vaultImportExportCoordinator = vaultImportExportCoordinator ??
        VaultImportExportCoordinator(
          dumpCoordinator: _vaultDumpCoordinator,
          identityService: _identityService,
          storageService: _secureStorageService,
          syncService: _syncService,
          syncServerUrlStore: _syncServerUrlStore,
        );
    _vaultPairingCoordinator = vaultPairingCoordinator ??
        VaultPairingCoordinator(
          vaultPairingService: _vaultPairingService,
          lanPairingService: _lanPairingService,
          identityService: _identityService,
          syncCoordinator: _syncCoordinator,
          importExportCoordinator: _vaultImportExportCoordinator,
        );
    _state = initialState;
  }

  @visibleForTesting
  static void setInstanceForTesting(ServiceManager instance) {
    _instance = instance;
  }

  @visibleForTesting
  static void resetInstance() {
    _instance = null;
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
  DeviceAliasService get deviceAliasService => _deviceAliasService;
  SecureStorageService get storageService => _secureStorageService;
  SyncService get syncService => _syncService;
  LanSyncCoordinator get lanSyncCoordinator => _lanSyncCoordinator;
  VaultUnlockCoordinator get vaultUnlockCoordinator => _vaultUnlockCoordinator;
  VaultDataRepository get vaultDataRepository => _vaultDataRepository;
  SyncCoordinator get syncCoordinator => _syncCoordinator;
  VaultImportExportCoordinator get vaultImportExportCoordinator => _vaultImportExportCoordinator;
  VaultPairingCoordinator get vaultPairingCoordinator => _vaultPairingCoordinator;

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
        unawaited(_vaultUnlockCoordinator.performStorageCleanup());
        _vaultPairingCoordinator.clearJoinKeys();
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
    final effectivePassword = await _vaultUnlockCoordinator.resolveEffectivePassword(password);
    return _performUnlock(effectivePassword);
  }

  Future<UnlockResult> _performUnlock(String password) async {
    try {
      final cipher = await _vaultUnlockCoordinator.initializeAndUnlock(password);
      if (cipher == null) {
        _updateState(ServiceManagerState.locked);
        return UnlockResult.invalidPassword;
      }

      _deviceAliasService = await DeviceAliasService.create();

      // Auto-migrate legacy no-password users to pseudo-key
      if (await _vaultUnlockCoordinator.isNoPasswordMode() &&
          await _vaultUnlockCoordinator.readNoPasswordPseudoKey() == null) {
        unawaited(_vaultUnlockCoordinator.migrateNoPasswordToPseudoKey());
      }

      _updateState(ServiceManagerState.unlocked);
      return UnlockResult.success;
    } on IdentityCorruptedException catch (e, stack) {
      AppLogger.d('Failed to unlock because identity is corrupted: $e');
      AppLogger.d(stack.toString());
      _setError(
        'Vault identity is missing or damaged. Use a recovery route or reset the local vault before continuing. $e',
      );
      return UnlockResult.error;
    } catch (e, stack) {
      AppLogger.d('Failed to unlock with password: $e');
      AppLogger.d(stack.toString());
      _setError('Unlock failed: $e');
      return UnlockResult.error;
    }
  }

  Future<UnlockResult> unlockWithBiometric() async {
    if (_state == ServiceManagerState.unlocking) {
      return UnlockResult.alreadyInProgress;
    }

    final biometricStatus = await _vaultUnlockCoordinator.getBiometricStatus();
    if (biometricStatus != BiometricAuthStatus.enabled) {
      return UnlockResult.biometricNotEnabled;
    }

    _updateState(ServiceManagerState.unlocking);

    try {
      final password = await _vaultUnlockCoordinator.unlockWithBiometric();
      if (password == null) {
        _updateState(ServiceManagerState.locked);
        return UnlockResult.biometricFailed;
      }

      return _performUnlock(password);
    } catch (e) {
      _setError('Biometric unlock failed: $e');
      return UnlockResult.error;
    }
  }

  void lock() {
    unawaited(_vaultUnlockCoordinator.lock());
    _vaultPairingCoordinator.clearJoinKeys();
    _updateState(ServiceManagerState.locked);
  }

  Future<void> logout() async {
    await _vaultUnlockCoordinator.logout();
    _updateState(ServiceManagerState.locked);
  }

  Future<void> enableNoPasswordMode({String? preGeneratedPseudoKey}) async {
    final pseudoPassword = await _vaultUnlockCoordinator.enableNoPasswordMode(
      preGeneratedPseudoKey: preGeneratedPseudoKey,
    );
    await unlockWithPassword(pseudoPassword);
  }

  Future<bool> isNoPasswordMode() async {
    return _vaultUnlockCoordinator.isNoPasswordMode();
  }

  Future<void> disableNoPasswordMode() async {
    await _vaultUnlockCoordinator.disableNoPasswordMode();
  }

  Future<bool> changeMasterPassword(
    String oldPassword,
    String newPassword,
  ) async {
    return _vaultUnlockCoordinator.changeMasterPassword(oldPassword, newPassword);
  }

  Future<bool> checkIdentityExists() async {
    return _identityService.checkIdentityExists();
  }

  Future<void> resetApplication() async {
    _autoLockService.lock();
    await _syncService.disconnect();
    await _lanPairingService.stopHosting();
    await _lanSyncCoordinator.abort();
    await _secureStorageService.close();
    _secureStorageService.clearDatabaseCipher();
    _cryptoService.logout();
    await _secureStorageService.deleteDatabaseFile();
    _vaultPairingCoordinator.clearJoinKeys();

    // Clear Secure Storage (Identity, Master Password mode, etc)
    const secureStorage = FlutterSecureStorage();
    await secureStorage.deleteAll();

    // Clear SharedPreferences (Server URL, pairing states, etc)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _updateState(ServiceManagerState.locked);
  }

  Future<BiometricSetupResult> enableBiometric(String currentPassword) async {
    return _vaultUnlockCoordinator.enableBiometric(currentPassword);
  }

  Future<void> disableBiometric() async {
    await _vaultUnlockCoordinator.disableBiometric();
  }

  Future<BiometricAuthStatus> getBiometricStatus() async {
    return _vaultUnlockCoordinator.getBiometricStatus();
  }

  Future<String> getBiometricName() async {
    return _biometricService.getBiometricName();
  }

  Future<void> saveAccount(AccountItem account) async {
    if (!isUnlocked) return;
    await _vaultDataRepository.saveAccount(account);
  }

  Future<void> deleteAccount(String id) async {
    if (!isUnlocked) return;
    await _vaultDataRepository.deleteAccount(id);
  }

  Future<void> togglePin(String id) async {
    if (!isUnlocked) return;
    await _vaultDataRepository.togglePin(id);
  }

  Future<AccountItem?> getAccountById(String id) async {
    if (!isUnlocked) return null;
    return _vaultDataRepository.getAccountById(id);
  }

  Future<void> saveTotpCredential(TotpCredential credential) async {
    if (!isUnlocked) return;
    await _vaultDataRepository.saveTotpCredential(credential);
  }

  Future<void> deleteTotpCredential(String id) async {
    if (!isUnlocked) return;
    await _vaultDataRepository.deleteTotpCredential(id);
  }

  Future<int> countAccountsByTemplate(String templateId) async {
    if (!isUnlocked) return 0;
    return _vaultDataRepository.countAccountsByTemplate(templateId);
  }

  Future<void> saveTemplate(AccountTemplate template) async {
    if (!isUnlocked) return;
    await _vaultDataRepository.saveTemplate(template);
  }

  Future<void> deleteTemplate(String id) async {
    if (!isUnlocked) return;
    await _vaultDataRepository.deleteTemplate(id);
  }

  Future<bool> connectToSyncServer() async {
    if (!isUnlocked) return false;
    return _syncCoordinator.connect();
  }

  Future<void> disconnectFromSyncServer() async {
    await _syncCoordinator.disconnect();
  }

  Future<SyncResult> syncNow() async {
    if (!isUnlocked) {
      return SyncResult.failure('Vault is locked.');
    }

    final result = await _syncCoordinator.syncNow();
    if (result.success && result.pulled) {
      _deviceAliasService = await DeviceAliasService.create();
      _notify();
    }
    return result;
  }

  Future<List<LocalSyncChange>> loadOpenLocalSyncChanges() async {
    if (!isUnlocked || !_identityService.hasIdentity) {
      return const <LocalSyncChange>[];
    }
    return _vaultDataRepository.loadOpenLocalSyncChanges();
  }

  Future<SyncResult> approveAndSyncLocalChanges({
    Iterable<String>? changeIds,
  }) async {
    if (!isUnlocked || !_identityService.hasIdentity) {
      return SyncResult.failure('Vault is locked.');
    }

    await _vaultDataRepository.approveLocalSyncChanges(ids: changeIds);
    final result = await syncNow();
    _notify();
    return result;
  }

  Future<void> discardLocalSyncChange(String changeId) async {
    if (!isUnlocked || !_identityService.hasIdentity) return;

    await _vaultDataRepository.discardLocalSyncChange(changeId);
    _notify();
  }

  SyncState get syncState => _syncCoordinator.state;
  String? get syncErrorMessage => _syncCoordinator.errorMessage;
  String? get syncStatusNote => _syncCoordinator.statusNote;
  bool get isSyncConnected => _syncCoordinator.isConnected;
  int get syncVersion => _syncCoordinator.localVersion;
  bool get hasDirtyData => _syncCoordinator.isDirty;

  Future<String?> getSyncServerUrl() async {
    return _syncCoordinator.getServerUrl();
  }

  Future<void> setSyncServerUrl(String url) async {
    if (!isUnlocked) return;

    await _syncCoordinator.setServerUrl(url);
    _notify();
  }

  /// 导出独立备份包（不包含身份密钥的加密数据快照）。
  ///
  /// 与配对码不同，备份包仅返回密文字符串，适合离线保存到文件或剪贴板。
  /// 恢复时必须提供同一 vault 的 vaultId + privateKey + symmetricKey。
  Future<String?> exportBackupPackage() async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    return await _vaultImportExportCoordinator.exportEncryptedVaultDump();
  }

  Future<VaultBackupTestResult> testRecoverBackupPackage(
    String vaultDumpJson, {
    required String vaultId,
    required String privateKey,
    required String symmetricKey,
  }) async {
    return _vaultImportExportCoordinator.testRecoverBackupPackage(
      vaultDumpJson,
      vaultId: vaultId,
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
  }

  Future<String> exportSecureVaultLinkCode(
    String password, {
    bool includeData = false,
  }) async {
    return _vaultImportExportCoordinator.exportSecureVaultLinkCode(
      password,
      includeData: includeData,
      resolveSyncServerUrl: () => _resolveSyncServerUrl(allowEmpty: true),
    );
  }

  Future<VaultImportPreviewSummary> previewVaultImport(
    VaultIdentityImportPreview preview,
  ) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    return _vaultImportExportCoordinator.previewVaultImport(preview);
  }

  Future<VaultImportPreviewSummary> previewSecureVaultLinkCode(
    String secureCode,
    String password,
  ) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    return _vaultImportExportCoordinator.previewSecureVaultLinkCode(
      secureCode,
      password,
    );
  }

  Future<void> importVaultLinkCode(
    String code, {
    bool forceOverwrite = false,
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }

    await _vaultImportExportCoordinator.importVaultLinkCode(
      code,
      forceOverwrite: forceOverwrite,
    );
    _notify();
  }

  Future<void> importSecureVaultLinkCode(
    String secureCode,
    String password, {
    bool forceOverwrite = false,
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }

    await _vaultImportExportCoordinator.importSecureVaultLinkCode(
      secureCode,
      password,
      forceOverwrite: forceOverwrite,
    );
    _notify();
  }

  Future<void> importVaultIdentityPreview(
    VaultIdentityImportPreview preview, {
    bool forceOverwrite = false,
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    await _vaultImportExportCoordinator.importVaultIdentityPreview(
      preview,
      forceOverwrite: forceOverwrite,
    );
    _notify();
  }

  Future<PairingSessionInfo> createVaultPairingSession({
    Duration ttl = const Duration(minutes: 10),
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    return _vaultPairingCoordinator.createSession(ttl: ttl);
  }

  Future<PairingSessionStatus> getVaultPairingSessionStatus(
    String sessionId,
  ) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    return _vaultPairingCoordinator.getSessionStatus(sessionId);
  }

  Future<void> approveVaultPairingRequest({
    required String sessionId,
    required String requestId,
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    await _vaultPairingCoordinator.approveRequest(
      sessionId: sessionId,
      requestId: requestId,
    );
  }

  Future<PairingJoinResult> joinVaultPairingSession(String pairingCode) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    return _vaultPairingCoordinator.joinSession(pairingCode);
  }

  Future<PairingBundleResult> fetchAndImportVaultPairingBundle({
    required String sessionId,
    required String requestId,
    bool forceOverwrite = false,
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    final result = await _vaultPairingCoordinator.fetchAndImportBundle(
      sessionId: sessionId,
      requestId: requestId,
      forceOverwrite: forceOverwrite,
    );
    if (result.status == 'approved') {
      _notify();
    }
    return result;
  }

  Future<LanPairingHostSession> startLanVaultPairingHost({
    Duration ttl = const Duration(minutes: 3),
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    return _vaultPairingCoordinator.startLanHost(ttl: ttl);
  }

  Future<void> stopLanVaultPairingHost() async {
    await _vaultPairingCoordinator.stopLanHost();
  }

  Future<void> joinLanVaultPairingWithCode(
    String pairingCode, {
    bool forceOverwrite = false,
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    await _vaultPairingCoordinator.joinLanWithCode(
      pairingCode,
      forceOverwrite: forceOverwrite,
    );
    _notify();
  }

  Future<void> setAutoLockDuration(AutoLockDuration duration) async {
    await _autoLockService.setDuration(duration);
    _notify();
  }

  AutoLockDuration get autoLockDuration => _autoLockService.duration;

  Future<String> _resolveSyncServerUrl({bool allowEmpty = false}) async {
    return _syncCoordinator.resolveServerUrl(allowEmpty: allowEmpty);
  }

  static String generatePassword({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSpecial = true,
  }) {
    return ServiceManagerPasswordTools.generatePassword(
      length: length,
      includeUppercase: includeUppercase,
      includeLowercase: includeLowercase,
      includeNumbers: includeNumbers,
      includeSpecial: includeSpecial,
    );
  }

  static int calculatePasswordStrength(String password) {
    return ServiceManagerPasswordTools.calculatePasswordStrength(password);
  }

  static String getPasswordStrengthLevel(int score) {
    return ServiceManagerPasswordTools.getPasswordStrengthLevel(score);
  }

  static const int passwordStrengthThresholdVeryStrong =
      EnhancedCryptoService.strengthThresholdVeryStrong;
  static const int passwordStrengthThresholdStrong =
      EnhancedCryptoService.strengthThresholdStrong;
  static const int passwordStrengthThresholdMedium =
      EnhancedCryptoService.strengthThresholdMedium;
  static const int passwordStrengthThresholdWeak =
      EnhancedCryptoService.strengthThresholdWeak;

  void _updateState(ServiceManagerState newState) {
    _state = newState;
    if (newState != ServiceManagerState.error) {
      _errorMessage = null;
    }
    _notify();
  }

  void _setError(String message) {
    _errorMessage = message;
    _updateState(ServiceManagerState.error);
  }

  @override
  void dispose() {
    _disposed = true;
    disposeLifecycleObserver();
    _autoLockService.dispose();
    _syncService.dispose();
    _lanPairingService.dispose();
    _lanSyncCoordinator.dispose();
    unawaited(_vaultUnlockCoordinator.closeStorage());
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




