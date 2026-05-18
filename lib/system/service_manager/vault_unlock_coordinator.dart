import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:secret_roy/core/app_logger.dart';
import 'package:secret_roy/core/crypto_random.dart';
import 'package:secret_roy/services/auto_lock_service.dart';
import 'package:secret_roy/services/biometric_auth_service.dart';
import 'package:secret_roy/services/database_file_cipher.dart';
import 'package:secret_roy/services/enhanced_crypto_service.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/lan_pairing_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';

import 'package:secret_roy/sync/lan_sync_coordinator.dart';
import 'package:secret_roy/sync/sync_service.dart';

/// 保险库解锁/锁定/密码管理协调器。
///
/// 将 ServiceManager 中的解锁、锁定、密码变更、无密码模式、
/// 生物识别设置等职责拆分为独立的 coordinator，保持 ServiceManager
/// 作为 facade 仅负责状态管理与通知。
class VaultUnlockCoordinator {
  final EnhancedCryptoService _cryptoService;
  final SecureStorageService _secureStorageService;
  final IdentityService _identityService;
  final AutoLockService _autoLockService;
  final SyncService _syncService;
  final BiometricAuthService _biometricService;
  final LanPairingService _lanPairingService;
  final LanSyncCoordinator _lanSyncCoordinator;

  static const String _noPasswordPseudoKey = 'no_password_pseudo_key';

  VaultUnlockCoordinator({
    required EnhancedCryptoService cryptoService,
    required SecureStorageService secureStorageService,
    required IdentityService identityService,
    required AutoLockService autoLockService,
    required SyncService syncService,
    required BiometricAuthService biometricService,
    required LanPairingService lanPairingService,
    required LanSyncCoordinator lanSyncCoordinator,
  })  : _cryptoService = cryptoService,
        _secureStorageService = secureStorageService,
        _identityService = identityService,
        _autoLockService = autoLockService,
        _syncService = syncService,
        _biometricService = biometricService,
        _lanPairingService = lanPairingService,
        _lanSyncCoordinator = lanSyncCoordinator;

  // === Unlock ===

  /// 执行解锁后的完整初始化流程。
  ///
  /// 返回 [DatabaseFileCipher] 表示成功，返回 null 表示密码无效。
  /// 可能抛出 [IdentityCorruptedException] 或其他异常。
  Future<DatabaseFileCipher?> initializeAndUnlock(String password) async {
    final hasDatabase = await _secureStorageService.isDatabaseInitialized();
    await _identityService.initialize(
      allowGenerateVaultIdentity: !hasDatabase,
    );

    final didUnlock = await _cryptoService.initMasterKey(password);
    AppLogger.d('initializeAndUnlock: didUnlock=$didUnlock');
    if (!didUnlock) {
      AppLogger.d('initializeAndUnlock: password invalid, closing storage');
      await _secureStorageService.close();
      _secureStorageService.clearDatabaseCipher();
      await _syncService.disconnect();
      return null;
    }

    final cipher = _cryptoService.createDatabaseFileCipher();
    _secureStorageService.setDatabaseCipher(cipher);
    await _secureStorageService.initialize(
      deviceId: _identityService.deviceId,
    );
    _autoLockService.unlock();
    await _syncService.initialize();
    await _secureStorageService.ensurePendingSyncOutboxEntries(
      _identityService.vaultId,
    );
    unawaited(_syncService.connect());
    AppLogger.d('initializeAndUnlock: success, returning cipher');
    return cipher;
  }

  /// 使用生物识别解锁，返回从安全存储中恢复的密码。
  ///
  /// 返回 null 表示生物识别未启用或验证失败。
  Future<String?> unlockWithBiometric() async {
    final biometricStatus = await _biometricService.getStatus();
    if (biometricStatus != BiometricAuthStatus.enabled) {
      return null;
    }
    return _biometricService.unlockWithBiometric();
  }

  // === Lock / Logout ===

  /// 锁定保险库：停止服务、断开同步、关闭加密存储。
  Future<void> lock() async {
    _autoLockService.lock();
    await performStorageCleanup();
  }

  Future<void> performStorageCleanup() async {
    await closeStorage();
    await _syncService.disconnect();
    await _lanPairingService.stopHosting();
    await _lanSyncCoordinator.abort();
  }

  /// 登出：锁定后清除加密密钥。
  Future<void> logout() async {
    await lock();
    _cryptoService.logout();
  }

  Future<void> closeStorage() async {
    try {
      await _secureStorageService.close();
    } catch (e) {
      AppLogger.d('Failed to close encrypted storage while locking: $e');
    } finally {
      _secureStorageService.clearDatabaseCipher();
    }
  }

  // === No-Password Mode ===

  /// 启用无密码模式，返回生成的伪密码。
  Future<String> enableNoPasswordMode({String? preGeneratedPseudoKey}) async {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: 'no_password_mode', value: 'true');
    // Biometric unlock with an empty password offers no security benefit;
    // disable it when entering no-password mode.
    await disableBiometric();

    final pseudoPassword = preGeneratedPseudoKey ?? generateNoPasswordPseudoKey();
    await secureStorage.write(key: _noPasswordPseudoKey, value: pseudoPassword);

    return pseudoPassword;
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

  static String generateNoPasswordPseudoKey() {
    return base64Encode(CryptoRandom.bytes(32));
  }

  Future<String> resolveEffectivePassword(String inputPassword) async {
    if (inputPassword.isNotEmpty) return inputPassword;

    if (!await isNoPasswordMode()) return inputPassword;

    final pseudoKey = await readNoPasswordPseudoKey();
    if (pseudoKey != null && pseudoKey.isNotEmpty) {
      return pseudoKey;
    }

    // Legacy: old no-password mode without pseudo key
    return inputPassword;
  }

  Future<String?> readNoPasswordPseudoKey() async {
    const secureStorage = FlutterSecureStorage();
    return secureStorage.read(key: _noPasswordPseudoKey);
  }

  Future<bool> migrateNoPasswordToPseudoKey() async {
    try {
      final pseudoPassword = generateNoPasswordPseudoKey();
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
        AppLogger.d(
          '[VaultUnlockCoordinator] Migrated no-password mode to pseudo-key',
        );
      } else {
        AppLogger.d(
          '[VaultUnlockCoordinator] No-password pseudo-key migration failed: '
          'updateMasterPassword returned false',
        );
      }
      return success;
    } catch (e, stack) {
      AppLogger.d(
        '[VaultUnlockCoordinator] No-password pseudo-key migration failed: $e',
      );
      AppLogger.d(stack.toString());
      return false;
    }
  }

  // === Password Change ===

  Future<bool> changeMasterPassword(
    String oldPassword,
    String newPassword,
  ) async {
    final effectiveNewPassword = newPassword.isEmpty
        ? generateNoPasswordPseudoKey()
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

  // === Biometric ===

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
}
