import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:secret_roy/core/app_logger.dart';
import 'package:secret_roy/core/crypto_random.dart';
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
import '../system/service_manager/sync_server_url_store.dart';
import '../system/service_manager/vault_dump_coordinator.dart';
import 'auto_lock_service.dart';
import 'biometric_auth_service.dart';
import 'device_alias_service.dart';
import 'enhanced_crypto_service.dart';
import 'identity_service.dart';
import 'lan_pairing_service.dart';
import 'vault_pairing_crypto.dart';
import 'secure_storage_service.dart';
import 'vault_pairing_service.dart';

enum ServiceManagerState { uninitialized, locked, unlocking, unlocked, error }

class VaultImportPreviewSummary {
  final String vaultId;
  final bool vaultIdMatchesCurrent;
  final int accountCount;
  final int templateCount;
  final bool hasLocalData;
  final bool includesDataSnapshot;

  const VaultImportPreviewSummary({
    required this.vaultId,
    required this.vaultIdMatchesCurrent,
    required this.accountCount,
    required this.templateCount,
    required this.hasLocalData,
    required this.includesDataSnapshot,
  });
}

/// 独立备份包的验证结果，不暴露解析后的原始对象。
class VaultBackupTestResult {
  final bool valid;
  final String? errorMessage;
  final int accountCount;
  final int templateCount;

  const VaultBackupTestResult({
    required this.valid,
    this.errorMessage,
    required this.accountCount,
    required this.templateCount,
  });
}

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

  ServiceManagerState _state = ServiceManagerState.uninitialized;
  String? _errorMessage;
  AutoLockObserver? _autoLockObserver;
  VoidCallback? _autoLockListener;
  final Map<String, VaultPairingKeyPair> _vaultPairingJoinKeysByRequestId = {};
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
        unawaited(_closeStorageForLock());
        unawaited(_syncService.disconnect());
        unawaited(_lanPairingService.stopHosting());
        unawaited(_lanSyncCoordinator.abort());
        _vaultPairingJoinKeysByRequestId.clear();
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
    final effectivePassword = await _resolveEffectivePassword(password);
    return _completeUnlock(effectivePassword);
  }

  Future<UnlockResult> _completeUnlock(String password) async {
    try {
      final hasDatabase = await _secureStorageService.isDatabaseInitialized();
      await _identityService.initialize(
        allowGenerateVaultIdentity: !hasDatabase,
      );
      _deviceAliasService = await DeviceAliasService.create();
      final didUnlock = await _cryptoService.initMasterKey(password);
      if (!didUnlock) {
        await _secureStorageService.close();
        _secureStorageService.clearDatabaseCipher();
        await _syncService.disconnect();
        _updateState(ServiceManagerState.locked);
        return UnlockResult.invalidPassword;
      }
      _secureStorageService.setDatabaseCipher(
        _cryptoService.createDatabaseFileCipher(),
      );
      await _secureStorageService.initialize(
        deviceId: _identityService.deviceId,
      );
      _autoLockService.unlock();
      await _syncService.initialize();
      await _secureStorageService.ensurePendingSyncOutboxEntries(
        _identityService.vaultId,
      );

      // Auto-migrate legacy no-password users to pseudo-key
      if (await isNoPasswordMode() && await _readNoPasswordPseudoKey() == null) {
        unawaited(_migrateNoPasswordToPseudoKey());
      }

      unawaited(_syncService.connect());
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
    unawaited(_closeStorageForLock());
    unawaited(_syncService.disconnect());
    unawaited(_lanPairingService.stopHosting());
    unawaited(_lanSyncCoordinator.abort());
    _vaultPairingJoinKeysByRequestId.clear();
    _updateState(ServiceManagerState.locked);
  }

  Future<void> _closeStorageForLock() async {
    try {
      await _secureStorageService.close();
    } catch (e) {
      AppLogger.d('Failed to close encrypted storage while locking: $e');
    } finally {
      _secureStorageService.clearDatabaseCipher();
    }
  }

  Future<void> logout() async {
    lock();
    _cryptoService.logout();
  }

  Future<void> enableNoPasswordMode({String? preGeneratedPseudoKey}) async {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: 'no_password_mode', value: 'true');
    // Biometric unlock with an empty password offers no security benefit;
    // disable it when entering no-password mode.
    await disableBiometric();

    final pseudoPassword = preGeneratedPseudoKey ?? _generateNoPasswordPseudoKey();
    await secureStorage.write(key: _noPasswordPseudoKey, value: pseudoPassword);

    await unlockWithPassword(pseudoPassword);
  }

  Future<bool> isNoPasswordMode() async {
    if (Platform.environment['SECRETROY_TEST_DISABLE_NO_PASSWORD'] == '1') {
      return false;
    }
    const secureStorage = FlutterSecureStorage();
    return await secureStorage.read(key: 'no_password_mode') == 'true';
  }

  Future<void> disableNoPasswordMode() async {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'no_password_mode');
    await secureStorage.delete(key: _noPasswordPseudoKey);
  }

  Future<bool> changeMasterPassword(
    String oldPassword,
    String newPassword,
  ) async {
    final effectiveNewPassword = newPassword.isEmpty
        ? _generateNoPasswordPseudoKey()
        : newPassword;

    final success = await _cryptoService.updateMasterPassword(
      oldPassword,
      effectiveNewPassword,
    );
    if (success) {
      await _secureStorageService.rotateDatabaseCipher(
        _cryptoService.createDatabaseFileCipher(),
      );
      if (newPassword.isNotEmpty) {
        await disableNoPasswordMode();
      } else {
        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(key: 'no_password_mode', value: 'true');
        await disableBiometric();
        await secureStorage.write(
          key: _noPasswordPseudoKey,
          value: effectiveNewPassword,
        );
      }
    }
    return success;
  }

  static const String _noPasswordPseudoKey = 'no_password_pseudo_key';

  static String _generateNoPasswordPseudoKey() {
    return base64Encode(CryptoRandom.bytes(32));
  }

  Future<String> _resolveEffectivePassword(String inputPassword) async {
    if (inputPassword.isNotEmpty) return inputPassword;

    if (!await isNoPasswordMode()) return inputPassword;

    final pseudoKey = await _readNoPasswordPseudoKey();
    if (pseudoKey != null && pseudoKey.isNotEmpty) {
      return pseudoKey;
    }

    // Legacy: old no-password mode without pseudo key
    return inputPassword;
  }

  Future<String?> _readNoPasswordPseudoKey() async {
    const secureStorage = FlutterSecureStorage();
    return secureStorage.read(key: _noPasswordPseudoKey);
  }

  Future<void> _migrateNoPasswordToPseudoKey() async {
    try {
      final pseudoPassword = _generateNoPasswordPseudoKey();
      final success = await _cryptoService.updateMasterPassword(
        '',
        pseudoPassword,
      );
      if (success) {
        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(
          key: _noPasswordPseudoKey,
          value: pseudoPassword,
        );
        AppLogger.d('[ServiceManager] Migrated no-password mode to pseudo-key');
      } else {
        AppLogger.d(
          '[ServiceManager] No-password pseudo-key migration failed: '
          'updateMasterPassword returned false',
        );
      }
    } catch (e, stack) {
      AppLogger.d(
        '[ServiceManager] No-password pseudo-key migration failed: $e',
      );
      AppLogger.d(stack.toString());
    }
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
    _vaultPairingJoinKeysByRequestId.clear();

    // Clear Secure Storage (Identity, Master Password mode, etc)
    const secureStorage = FlutterSecureStorage();
    await secureStorage.deleteAll();

    // Clear SharedPreferences (Server URL, pairing states, etc)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _updateState(ServiceManagerState.locked);
  }

  Future<BiometricSetupResult> enableBiometric(String currentPassword) async {
    if (await isNoPasswordMode()) {
      return BiometricSetupResult.noPasswordMode;
    }
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
    final before = await _secureStorageService.getAccountById(
      account.id,
      includeDeleted: true,
    );
    await _secureStorageService.saveAccount(account);
    final after = await _secureStorageService.getAccountById(
      account.id,
      includeDeleted: true,
    );
    if (after != null) {
      await _secureStorageService.recordLocalSyncChange(
        vaultId: _identityService.vaultId,
        entityType: LocalSyncEntityType.account,
        entityId: after.id,
        action: before == null
            ? LocalSyncAction.create
            : LocalSyncAction.update,
        title: after.name,
        beforeSnapshot: before?.toJson(),
        afterSnapshot: after.toJson(),
        baseServerVersion: before?.serverVersion ?? after.serverVersion,
      );
    }
    await _syncService.reconcileDirtyState();
  }

  Future<void> deleteAccount(String id) async {
    if (!isUnlocked) return;
    final before = await _secureStorageService.getAccountById(
      id,
      includeDeleted: true,
    );
    await _secureStorageService.deleteAccount(id);
    final after = await _secureStorageService.getAccountById(
      id,
      includeDeleted: true,
    );
    await _secureStorageService.recordLocalSyncChange(
      vaultId: _identityService.vaultId,
      entityType: LocalSyncEntityType.account,
      entityId: id,
      action: LocalSyncAction.delete,
      title: before?.name ?? after?.name ?? id,
      beforeSnapshot: before?.toJson(),
      afterSnapshot: after?.toJson(),
      baseServerVersion: before?.serverVersion ?? after?.serverVersion ?? 0,
    );
    await _syncService.reconcileDirtyState();
  }

  Future<void> togglePin(String id) async {
    if (!isUnlocked) return;
    final before = await _secureStorageService.getAccountById(
      id,
      includeDeleted: true,
    );
    await _secureStorageService.togglePin(id);
    final after = await _secureStorageService.getAccountById(
      id,
      includeDeleted: true,
    );
    await _secureStorageService.recordLocalSyncChange(
      vaultId: _identityService.vaultId,
      entityType: LocalSyncEntityType.account,
      entityId: id,
      action: LocalSyncAction.update,
      title: before?.name ?? after?.name ?? id,
      beforeSnapshot: before?.toJson(),
      afterSnapshot: after?.toJson(),
      baseServerVersion: before?.serverVersion ?? after?.serverVersion ?? 0,
    );
    await _syncService.reconcileDirtyState();
  }

  Future<AccountItem?> getAccountById(String id) async {
    if (!isUnlocked) return null;
    return _secureStorageService.getAccountById(id);
  }

  Future<void> saveTotpCredential(TotpCredential credential) async {
    if (!isUnlocked) return;
    final before = await _secureStorageService.getTotpCredentialById(
      credential.id,
      includeDeleted: true,
    );
    await _secureStorageService.saveTotpCredential(credential);
    final after = await _secureStorageService.getTotpCredentialById(
      credential.id,
      includeDeleted: true,
    );
    if (after != null) {
      await _secureStorageService.recordLocalSyncChange(
        vaultId: _identityService.vaultId,
        entityType: LocalSyncEntityType.totpCredential,
        entityId: after.id,
        action: before == null
            ? LocalSyncAction.create
            : LocalSyncAction.update,
        title: after.displayLabel,
        beforeSnapshot: before?.toJson(),
        afterSnapshot: after.toJson(),
        baseServerVersion: before?.serverVersion ?? after.serverVersion,
      );
    }
    await _syncService.reconcileDirtyState();
  }

  Future<void> deleteTotpCredential(String id) async {
    if (!isUnlocked) return;
    final before = await _secureStorageService.getTotpCredentialById(
      id,
      includeDeleted: true,
    );
    await _secureStorageService.deleteTotpCredential(id);
    final after = await _secureStorageService.getTotpCredentialById(
      id,
      includeDeleted: true,
    );
    await _secureStorageService.recordLocalSyncChange(
      vaultId: _identityService.vaultId,
      entityType: LocalSyncEntityType.totpCredential,
      entityId: id,
      action: LocalSyncAction.delete,
      title: before?.displayLabel ?? after?.displayLabel ?? id,
      beforeSnapshot: before?.toJson(),
      afterSnapshot: after?.toJson(),
      baseServerVersion: before?.serverVersion ?? after?.serverVersion ?? 0,
    );
    await _syncService.reconcileDirtyState();
  }

  Future<int> countAccountsByTemplate(String templateId) async {
    if (!isUnlocked) return 0;
    return _secureStorageService.countAccountsByTemplate(templateId);
  }

  Future<void> saveTemplate(AccountTemplate template) async {
    if (!isUnlocked) return;
    final before = await _secureStorageService.loadTemplateById(
      template.templateId,
    );
    await _secureStorageService.saveTemplate(template);
    final after = await _secureStorageService.loadTemplateById(
      template.templateId,
    );
    if (after != null && after.isCustom) {
      await _secureStorageService.recordLocalSyncChange(
        vaultId: _identityService.vaultId,
        entityType: LocalSyncEntityType.template,
        entityId: after.templateId,
        action: before == null
            ? LocalSyncAction.create
            : LocalSyncAction.update,
        title: after.title,
        beforeSnapshot: before?.toJson(),
        afterSnapshot: after.toJson(),
        baseServerVersion: before?.serverVersion ?? after.serverVersion,
      );
    }
    await _syncService.reconcileDirtyState();
  }

  Future<void> deleteTemplate(String id) async {
    if (!isUnlocked) return;
    final usageCount = await _secureStorageService.countAccountsByTemplate(id);
    if (usageCount > 0) {
      throw TemplateInUseException(templateId: id, usageCount: usageCount);
    }
    final before = await _secureStorageService.loadTemplateById(id);
    await _secureStorageService.deleteTemplate(id);
    final after = await _secureStorageService.loadTemplateById(id);
    await _secureStorageService.recordLocalSyncChange(
      vaultId: _identityService.vaultId,
      entityType: LocalSyncEntityType.template,
      entityId: id,
      action: LocalSyncAction.delete,
      title: before?.title ?? after?.title ?? id,
      beforeSnapshot: before?.toJson(),
      afterSnapshot: after?.toJson(),
      baseServerVersion: before?.serverVersion ?? after?.serverVersion ?? 0,
    );
    await _syncService.reconcileDirtyState();
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
    _deviceAliasService = await DeviceAliasService.create();
    await _secureStorageService.initialize(deviceId: _identityService.deviceId);
    await _syncService.initialize();

    _notify();

    return SyncResult.success(
      pulled: result.pulled,
      pushed: result.pushed,
      version: _syncService.localVersion,
      conflictCount: result.conflictCount,
      notice: result.notice,
    );
  }

  Future<List<LocalSyncChange>> loadOpenLocalSyncChanges() async {
    if (!isUnlocked || !_identityService.hasIdentity) {
      return const <LocalSyncChange>[];
    }
    await _secureStorageService.ensurePendingSyncOutboxEntries(
      _identityService.vaultId,
    );
    return _secureStorageService.loadOpenLocalSyncChanges(
      vaultId: _identityService.vaultId,
    );
  }

  Future<SyncResult> approveAndSyncLocalChanges({
    Iterable<String>? changeIds,
  }) async {
    if (!isUnlocked || !_identityService.hasIdentity) {
      return SyncResult.failure('Vault is locked.');
    }

    await _secureStorageService.approveLocalSyncChanges(
      vaultId: _identityService.vaultId,
      ids: changeIds,
    );
    await _syncService.markDirty();
    final result = await syncNow();
    _notify();
    return result;
  }

  Future<void> discardLocalSyncChange(String changeId) async {
    if (!isUnlocked || !_identityService.hasIdentity) return;

    final change = await _secureStorageService.getLocalSyncChange(changeId);
    if (change == null) return;

    final before = change.beforeSnapshot;
    switch (change.entityType) {
      case LocalSyncEntityType.account:
        if (before == null) {
          await _secureStorageService.hardDeleteAccount(change.entityId);
        } else {
          await _secureStorageService.saveAccount(
            AccountItem.fromJson(before),
            isSyncMerge: true,
          );
        }
        break;
      case LocalSyncEntityType.template:
        if (before == null) {
          await _secureStorageService.hardDeleteTemplate(change.entityId);
        } else {
          await _secureStorageService.saveTemplate(
            AccountTemplate.fromJson(before),
            isSyncMerge: true,
          );
        }
        break;
      case LocalSyncEntityType.totpCredential:
        if (before == null) {
          await _secureStorageService.hardDeleteTotpCredential(change.entityId);
        } else {
          await _secureStorageService.saveTotpCredential(
            TotpCredential.fromJson(before),
            isSyncMerge: true,
          );
        }
        break;
    }

    await _secureStorageService.deleteLocalSyncChange(changeId);
    await _syncService.reconcileDirtyState();
    _notify();
  }

  SyncState get syncState => _syncService.state;
  String? get syncErrorMessage => _syncService.errorMessage;
  String? get syncStatusNote => _syncService.statusNote;
  bool get isSyncConnected => _syncService.isConnected;
  int get syncVersion => _syncService.localVersion;
  bool get hasDirtyData => _syncService.isDirty;

  Future<String?> getSyncServerUrl() async {
    return _syncServerUrlStore.read(
      vaultId: _identityService.hasIdentity ? _identityService.vaultId : null,
    );
  }

  Future<void> setSyncServerUrl(String url) async {
    if (!isUnlocked) return;

    await _syncServerUrlStore.write(url, vaultId: _identityService.vaultId);
    await disconnectFromSyncServer();
    _notify();
  }

  Future<String?> _exportEncryptedVaultDump() async {
    return _vaultDumpCoordinator.exportEncryptedVaultDump();
  }

  /// 导出独立备份包（不包含身份密钥的加密数据快照）。
  ///
  /// 与配对码不同，备份包仅返回密文字符串，适合离线保存到文件或剪贴板。
  /// 恢复时必须提供同一 vault 的 vaultId + privateKey + symmetricKey。
  Future<String?> exportBackupPackage() async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    return await _exportEncryptedVaultDump();
  }

  /// 测试恢复独立备份包，验证其能否被正确解密和解析。
  ///
  /// 本方法**不会**修改当前 vault 身份、不会写入本地数据库、不会切换 vault。
  /// 失败时返回 [VaultBackupTestResult.valid] == false 并附带错误信息。
  Future<VaultBackupTestResult> testRecoverBackupPackage(
    String vaultDumpJson, {
    required String vaultId,
    required String privateKey,
    required String symmetricKey,
  }) async {
    try {
      final plan = await _vaultDumpCoordinator.validateEncryptedVaultDump(
        vaultDumpJson: vaultDumpJson,
        vaultId: vaultId,
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      return VaultBackupTestResult(
        valid: true,
        accountCount: plan.accounts.length,
        templateCount: plan.templates.length,
      );
    } on VaultDumpImportException catch (error) {
      return VaultBackupTestResult(
        valid: false,
        errorMessage: error.message,
        accountCount: 0,
        templateCount: 0,
      );
    }
  }

  Future<String> exportSecureVaultLinkCode(
    String password, {
    bool includeData = false,
  }) async {
    final serverUrl = await _resolveSyncServerUrl(allowEmpty: true);
    final vaultDump = includeData ? await _exportEncryptedVaultDump() : null;
    return _identityService.exportSecureLinkCode(
      password,
      syncServerUrl: serverUrl.isEmpty ? null : serverUrl,
      vaultDump: vaultDump,
    );
  }

  Future<VaultImportPreviewSummary> previewVaultImport(
    VaultIdentityImportPreview preview,
  ) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }

    final VaultDumpImportPlan? dumpPlan;
    try {
      dumpPlan = await _validateIncomingVaultDump(preview);
    } on VaultDumpImportException catch (error) {
      throw VaultImportException(error.message);
    }

    final hasLocalData = await _hasLocalVaultDataForImport();
    final currentVaultId = _identityService.hasIdentity
        ? _identityService.vaultId
        : null;

    return VaultImportPreviewSummary(
      vaultId: preview.vaultId,
      vaultIdMatchesCurrent: currentVaultId == preview.vaultId,
      accountCount: dumpPlan?.accounts.length ?? 0,
      templateCount: dumpPlan?.templates.length ?? 0,
      hasLocalData: hasLocalData,
      includesDataSnapshot: dumpPlan != null && dumpPlan.hasData,
    );
  }

  Future<VaultImportPreviewSummary> previewSecureVaultLinkCode(
    String secureCode,
    String password,
  ) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    final preview = await _identityService.previewSecureLinkCode(
      secureCode,
      password,
    );
    return previewVaultImport(preview);
  }

  Future<void> importVaultLinkCode(
    String code, {
    bool forceOverwrite = false,
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }

    final preview = await _identityService.previewTransferCode(code);
    await _importVaultIdentityPreview(preview, forceOverwrite: forceOverwrite);
  }

  Future<void> importSecureVaultLinkCode(
    String secureCode,
    String password, {
    bool forceOverwrite = false,
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }

    final preview = await _identityService.previewSecureLinkCode(
      secureCode,
      password,
    );
    await _importVaultIdentityPreview(preview, forceOverwrite: forceOverwrite);
  }

  Future<void> importVaultIdentityPreview(
    VaultIdentityImportPreview preview, {
    bool forceOverwrite = false,
  }) async {
    if (!isUnlocked) {
      throw StateError('Vault is locked.');
    }
    await _importVaultIdentityPreview(preview, forceOverwrite: forceOverwrite);
  }

  Future<void> _importVaultIdentityPreview(
    VaultIdentityImportPreview preview, {
    required bool forceOverwrite,
  }) async {
    final VaultDumpImportPlan? dumpPlan;
    try {
      dumpPlan = await _validateIncomingVaultDump(preview);
    } on VaultDumpImportException catch (error) {
      throw VaultImportException(error.message);
    }
    final hadLocalData = await _hasLocalVaultDataForImport();
    if (hadLocalData && !forceOverwrite) {
      throw const VaultImportPreconditionException(
        'This device already has local vault data. Confirm overwrite before importing.',
      );
    }

    final previousIdentity = _identityService.hasIdentity
        ? _identityService.currentImportPreview()
        : null;
    var identityApplied = false;

    try {
      await _syncService.disconnect();
      await _identityService.applyImportPreview(preview);
      identityApplied = true;

      if (dumpPlan != null) {
        if (dumpPlan.hasData) {
          await _vaultDumpCoordinator.importValidatedVaultDump(dumpPlan);
        } else if (hadLocalData) {
          await _secureStorageService.clearAllData();
        }
      } else if (hadLocalData) {
        await _secureStorageService.clearAllData();
      }

      final syncServerUrl = preview.syncServerUrl;
      if (syncServerUrl != null && syncServerUrl.isNotEmpty) {
        await _syncServerUrlStore.write(
          syncServerUrl,
          vaultId: preview.vaultId,
        );
      }

      await _syncService.initialize();
      _notify();
    } on VaultDumpImportException catch (error) {
      if (identityApplied && previousIdentity != null) {
        await _identityService.applyImportPreview(previousIdentity);
        await _syncService.initialize();
      }
      throw VaultImportException(error.message);
    } catch (error) {
      if (identityApplied && previousIdentity != null) {
        await _identityService.applyImportPreview(previousIdentity);
        await _syncService.initialize();
      }
      throw VaultImportException('Vault import failed: $error');
    }
  }

  Future<VaultDumpImportPlan?> _validateIncomingVaultDump(
    VaultIdentityImportPreview preview,
  ) async {
    final vaultDump = preview.vaultDump;
    if (vaultDump == null || vaultDump.isEmpty) {
      return null;
    }

    return await _vaultDumpCoordinator.validateEncryptedVaultDump(
      vaultDumpJson: vaultDump,
      vaultId: preview.vaultId,
      privateKey: preview.privateKey,
      symmetricKey: preview.symmetricKey,
    );
  }

  Future<bool> _hasLocalVaultDataForImport() async {
    final accounts = await _secureStorageService.loadAccounts(
      includeDeleted: true,
    );
    final templates = await _secureStorageService.loadCustomTemplates(
      includeDeleted: true,
    );
    return accounts.isNotEmpty ||
        templates.isNotEmpty ||
        _syncService.localVersion > 0 ||
        _syncService.isDirty;
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
    final status = await _vaultPairingService.getHostSessionStatus(
      serverUrl: serverUrl,
      sessionId: sessionId,
      hostDeviceId: _identityService.deviceId,
    );
    final pendingRequest = status.pendingRequest;
    if (pendingRequest == null || pendingRequest.requestId != requestId) {
      throw const VaultPairingServiceException(
        'Pairing request is no longer pending. Refresh and try again.',
      );
    }
    if (pendingRequest.requesterPublicKey.isEmpty) {
      throw const VaultPairingServiceException(
        'Pairing request is missing the requester public key.',
      );
    }

    final vaultDump = await _exportEncryptedVaultDump();
    // LAN pairing encrypts with the requester's public key, so the cleartext
    // transfer code is safe in transit — unlike exportSecureLinkCode which
    // uses password-derived encryption.
    // ignore: deprecated_member_use_from_same_package
    final transferCode = _identityService.exportTransferCode(
      syncServerUrl: serverUrl.isEmpty ? null : serverUrl,
      vaultDump: vaultDump,
    );
    final wrappedVaultBundle = await VaultPairingCrypto.encryptBundle(
      plainBundle: transferCode,
      requesterPublicKey: pendingRequest.requesterPublicKey,
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
    final keyPair = await VaultPairingCrypto.createKeyPair();
    final joinResult = await _vaultPairingService.joinSession(
      serverUrl: serverUrl,
      pairingCode: pairingCode.trim(),
      requesterDeviceId: _identityService.deviceId,
      requesterPublicKey: keyPair.publicKey,
    );
    _vaultPairingJoinKeysByRequestId[joinResult.requestId] = keyPair;
    return joinResult;
  }

  Future<PairingBundleResult> fetchAndImportVaultPairingBundle({
    required String sessionId,
    required String requestId,
    bool forceOverwrite = false,
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
      final keyPair = _vaultPairingJoinKeysByRequestId[requestId];
      if (keyPair == null) {
        throw const VaultPairingServiceException(
          'Pairing key expired locally. Rejoin the pairing session.',
        );
      }
      final transferCode = await VaultPairingCrypto.decryptBundle(
        wrappedBundle: wrappedBundle,
        keyPair: keyPair,
      );
      await importVaultLinkCode(transferCode, forceOverwrite: forceOverwrite);
      _vaultPairingJoinKeysByRequestId.remove(requestId);
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
    // LAN pairing encrypts with the requester's public key, so the cleartext
    // transfer code is safe in transit — unlike exportSecureLinkCode which
    // uses password-derived encryption.
    // ignore: deprecated_member_use_from_same_package
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

  Future<void> joinLanVaultPairingWithCode(
    String pairingCode, {
    bool forceOverwrite = false,
  }) async {
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
    await importVaultLinkCode(transferCode, forceOverwrite: forceOverwrite);
  }

  Future<void> setAutoLockDuration(AutoLockDuration duration) async {
    await _autoLockService.setDuration(duration);
    _notify();
  }

  AutoLockDuration get autoLockDuration => _autoLockService.duration;

  Future<String> _resolveSyncServerUrl({bool allowEmpty = false}) async {
    return _syncServerUrlStore.resolve(
      vaultId: _identityService.hasIdentity ? _identityService.vaultId : null,
      allowEmpty: allowEmpty,
    );
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
    unawaited(_closeStorageForLock());
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

class VaultImportPreconditionException implements Exception {
  final String message;

  const VaultImportPreconditionException(this.message);

  @override
  String toString() => 'VaultImportPreconditionException($message)';
}

class VaultImportException implements Exception {
  final String message;

  const VaultImportException(this.message);

  @override
  String toString() => 'VaultImportException($message)';
}
