import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/local_sync_change.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
import 'package:secret_roy/sync/sync_service.dart';

/// 保险库数据仓库：封装 Account、Template、TOTP Credential 的持久化与同步变更记录。
///
/// 将 ServiceManager 中的数据操作职责拆分为独立的 repository，
/// 保持 ServiceManager 作为 facade 仅负责状态管理与通知。
class VaultDataRepository {
  final SecureStorageService _storage;
  final IdentityService _identity;
  final SyncService _sync;

  VaultDataRepository({
    required SecureStorageService storage,
    required IdentityService identity,
    required SyncService sync,
  })  : _storage = storage,
        _identity = identity,
        _sync = sync;

  // === Account ===

  Future<void> saveAccount(AccountItem account) async {
    final before = await _storage.getAccountById(
      account.id,
      includeDeleted: true,
    );
    await _storage.saveAccount(account);
    final after = await _storage.getAccountById(
      account.id,
      includeDeleted: true,
    );
    if (after != null) {
      await _storage.recordLocalSyncChange(
        vaultId: _identity.vaultId,
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
    await _sync.reconcileDirtyState();
  }

  Future<void> deleteAccount(String id) async {
    final before = await _storage.getAccountById(
      id,
      includeDeleted: true,
    );
    await _storage.deleteAccount(id);
    final after = await _storage.getAccountById(
      id,
      includeDeleted: true,
    );
    await _storage.recordLocalSyncChange(
      vaultId: _identity.vaultId,
      entityType: LocalSyncEntityType.account,
      entityId: id,
      action: LocalSyncAction.delete,
      title: before?.name ?? after?.name ?? id,
      beforeSnapshot: before?.toJson(),
      afterSnapshot: after?.toJson(),
      baseServerVersion: before?.serverVersion ?? after?.serverVersion ?? 0,
    );
    await _sync.reconcileDirtyState();
  }

  Future<void> togglePin(String id) async {
    final before = await _storage.getAccountById(
      id,
      includeDeleted: true,
    );
    await _storage.togglePin(id);
    final after = await _storage.getAccountById(
      id,
      includeDeleted: true,
    );
    await _storage.recordLocalSyncChange(
      vaultId: _identity.vaultId,
      entityType: LocalSyncEntityType.account,
      entityId: id,
      action: LocalSyncAction.update,
      title: before?.name ?? after?.name ?? id,
      beforeSnapshot: before?.toJson(),
      afterSnapshot: after?.toJson(),
      baseServerVersion: before?.serverVersion ?? after?.serverVersion ?? 0,
    );
    await _sync.reconcileDirtyState();
  }

  Future<AccountItem?> getAccountById(String id) => _storage.getAccountById(id);

  Future<int> countAccountsByTemplate(String templateId) =>
      _storage.countAccountsByTemplate(templateId);

  // === TOTP Credential ===

  Future<void> saveTotpCredential(TotpCredential credential) async {
    final before = await _storage.getTotpCredentialById(
      credential.id,
      includeDeleted: true,
    );
    await _storage.saveTotpCredential(credential);
    final after = await _storage.getTotpCredentialById(
      credential.id,
      includeDeleted: true,
    );
    if (after != null) {
      await _storage.recordLocalSyncChange(
        vaultId: _identity.vaultId,
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
    await _sync.reconcileDirtyState();
  }

  Future<void> deleteTotpCredential(String id) async {
    final before = await _storage.getTotpCredentialById(
      id,
      includeDeleted: true,
    );
    await _storage.deleteTotpCredential(id);
    final after = await _storage.getTotpCredentialById(
      id,
      includeDeleted: true,
    );
    await _storage.recordLocalSyncChange(
      vaultId: _identity.vaultId,
      entityType: LocalSyncEntityType.totpCredential,
      entityId: id,
      action: LocalSyncAction.delete,
      title: before?.displayLabel ?? after?.displayLabel ?? id,
      beforeSnapshot: before?.toJson(),
      afterSnapshot: after?.toJson(),
      baseServerVersion: before?.serverVersion ?? after?.serverVersion ?? 0,
    );
    await _sync.reconcileDirtyState();
  }

  // === Template ===

  Future<void> saveTemplate(AccountTemplate template) async {
    final before = await _storage.loadTemplateById(template.templateId);
    await _storage.saveTemplate(template);
    final after = await _storage.loadTemplateById(template.templateId);
    if (after != null && after.isCustom) {
      await _storage.recordLocalSyncChange(
        vaultId: _identity.vaultId,
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
    await _sync.reconcileDirtyState();
  }

  Future<void> deleteTemplate(String id) async {
    final usageCount = await _storage.countAccountsByTemplate(id);
    if (usageCount > 0) {
      throw TemplateInUseException(templateId: id, usageCount: usageCount);
    }
    final before = await _storage.loadTemplateById(id);
    await _storage.deleteTemplate(id);
    final after = await _storage.loadTemplateById(id);
    await _storage.recordLocalSyncChange(
      vaultId: _identity.vaultId,
      entityType: LocalSyncEntityType.template,
      entityId: id,
      action: LocalSyncAction.delete,
      title: before?.title ?? after?.title ?? id,
      beforeSnapshot: before?.toJson(),
      afterSnapshot: after?.toJson(),
      baseServerVersion: before?.serverVersion ?? after?.serverVersion ?? 0,
    );
    await _sync.reconcileDirtyState();
  }

  // === Sync Outbox ===

  Future<List<LocalSyncChange>> loadOpenLocalSyncChanges() async {
    await _storage.ensurePendingSyncOutboxEntries(_identity.vaultId);
    return _storage.loadOpenLocalSyncChanges(
      vaultId: _identity.vaultId,
    );
  }

  Future<void> approveLocalSyncChanges({Iterable<String>? ids}) async {
    await _storage.approveLocalSyncChanges(
      vaultId: _identity.vaultId,
      ids: ids,
    );
    await _sync.markDirty();
  }

  Future<void> discardLocalSyncChange(String changeId) async {
    final change = await _storage.getLocalSyncChange(changeId);
    if (change == null) return;

    final before = change.beforeSnapshot;
    switch (change.entityType) {
      case LocalSyncEntityType.account:
        if (before == null) {
          await _storage.hardDeleteAccount(change.entityId);
        } else {
          await _storage.saveAccount(
            AccountItem.fromJson(before),
            isSyncMerge: true,
          );
        }
        break;
      case LocalSyncEntityType.template:
        if (before == null) {
          await _storage.hardDeleteTemplate(change.entityId);
        } else {
          await _storage.saveTemplate(
            AccountTemplate.fromJson(before),
            isSyncMerge: true,
          );
        }
        break;
      case LocalSyncEntityType.totpCredential:
        if (before == null) {
          await _storage.hardDeleteTotpCredential(change.entityId);
        } else {
          await _storage.saveTotpCredential(
            TotpCredential.fromJson(before),
            isSyncMerge: true,
          );
        }
        break;
    }

    await _storage.deleteLocalSyncChange(changeId);
    await _sync.reconcileDirtyState();
  }
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
