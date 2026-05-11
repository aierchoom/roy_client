import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
import 'package:secret_roy/sync/sync_service.dart';

import 'sync_server_url_store.dart';
import 'vault_dump_coordinator.dart';
import 'vault_import_types.dart';

/// 保险库导入导出协调器：封装备份包、安全链接码、导入预览与执行。
///
/// 将 ServiceManager 中的导入导出职责拆分为独立的 coordinator，
/// 保持 ServiceManager 作为 facade 仅负责状态管理与通知。
class VaultImportExportCoordinator {
  final VaultDumpCoordinator _dumpCoordinator;
  final IdentityService _identityService;
  final SecureStorageService _storageService;
  final SyncService _syncService;
  final SyncServerUrlStore _syncServerUrlStore;

  VaultImportExportCoordinator({
    required VaultDumpCoordinator dumpCoordinator,
    required IdentityService identityService,
    required SecureStorageService storageService,
    required SyncService syncService,
    required SyncServerUrlStore syncServerUrlStore,
  })  : _dumpCoordinator = dumpCoordinator,
        _identityService = identityService,
        _storageService = storageService,
        _syncService = syncService,
        _syncServerUrlStore = syncServerUrlStore;

  Future<String?> exportEncryptedVaultDump() async {
    return _dumpCoordinator.exportEncryptedVaultDump();
  }

  Future<VaultBackupTestResult> testRecoverBackupPackage(
    String vaultDumpJson, {
    required String vaultId,
    required String privateKey,
    required String symmetricKey,
  }) async {
    try {
      final plan = await _dumpCoordinator.validateEncryptedVaultDump(
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
    required Future<String> Function() resolveSyncServerUrl,
  }) async {
    final serverUrl = await resolveSyncServerUrl();
    final vaultDump = includeData ? await exportEncryptedVaultDump() : null;
    return _identityService.exportSecureLinkCode(
      password,
      syncServerUrl: serverUrl.isEmpty ? null : serverUrl,
      vaultDump: vaultDump,
    );
  }

  Future<VaultImportPreviewSummary> previewVaultImport(
    VaultIdentityImportPreview preview,
  ) async {
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
    final preview = await _identityService.previewTransferCode(code);
    await importVaultIdentityPreview(preview, forceOverwrite: forceOverwrite);
  }

  Future<void> importSecureVaultLinkCode(
    String secureCode,
    String password, {
    bool forceOverwrite = false,
  }) async {
    final preview = await _identityService.previewSecureLinkCode(
      secureCode,
      password,
    );
    await importVaultIdentityPreview(preview, forceOverwrite: forceOverwrite);
  }

  Future<void> importVaultIdentityPreview(
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
          await _dumpCoordinator.importValidatedVaultDump(dumpPlan);
        } else if (hadLocalData) {
          await _storageService.clearAllData();
        }
      } else if (hadLocalData) {
        await _storageService.clearAllData();
      }

      final syncServerUrl = preview.syncServerUrl;
      if (syncServerUrl != null && syncServerUrl.isNotEmpty) {
        await _syncServerUrlStore.write(
          syncServerUrl,
          vaultId: preview.vaultId,
        );
      }

      await _syncService.initialize();
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

    return await _dumpCoordinator.validateEncryptedVaultDump(
      vaultDumpJson: vaultDump,
      vaultId: preview.vaultId,
      privateKey: preview.privateKey,
      symmetricKey: preview.symmetricKey,
    );
  }

  Future<bool> _hasLocalVaultDataForImport() async {
    final accounts = await _storageService.loadAccounts(
      includeDeleted: true,
    );
    final templates = await _storageService.loadCustomTemplates(
      includeDeleted: true,
    );
    return accounts.isNotEmpty ||
        templates.isNotEmpty ||
        _syncService.localVersion > 0 ||
        _syncService.isDirty;
  }
}
