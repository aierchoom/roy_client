// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'sync_service.dart';

extension SyncServiceConflict on SyncService {
  Future<void> _handleConflict(
    String serverUrl,
    ConflictException conflict,
  ) async {
    final itemId = conflict.itemId;
    if (itemId == null) {
      return;
    }

    final localAccount = await _storageService.getAccountById(
      itemId,
      includeDeleted: true,
    );
    if (localAccount == null) {
      final localCredential = await _storageService.getTotpCredentialById(
        itemId,
        includeDeleted: true,
      );
      if (localCredential != null) {
        await _handleTotpCredentialConflict(serverUrl, conflict);
        return;
      }
      final localTemplate = await _storageService.loadTemplateById(itemId);
      if (localTemplate != null) {
        await _handleTemplateRemoteMissingConflict(serverUrl, itemId);
        return;
      }
    }

    switch (conflict.conflictType) {
      case 'remote_missing':
        await _handleRemoteMissingConflict(serverUrl, itemId);
        return;
      case 'stale_base_version':
        await _handleStaleBaseConflict(serverUrl, itemId);
        return;
      case 'concurrent_edit':
        await _handleConcurrentEditConflict(serverUrl, itemId);
        return;
      case 'concurrent_delete':
        await _handleConcurrentDeleteConflict(serverUrl, itemId);
        return;
      default:
        if (conflict.serverActual == 0) {
          await _handleRemoteMissingConflict(serverUrl, itemId);
          return;
        }
        await _handleVersionConflict(
          serverUrl,
          itemId,
          conflict.serverIsDeleted == true
              ? 'concurrent_delete'
              : 'stale_base_version',
          fallbackNotice: conflict.serverIsDeleted == true
              ? 'Remote delete was accepted for this item. Restore from history only if this was unexpected.'
              : 'Remote changes were merged locally after a stale-base conflict.',
        );
        return;
    }
  }

  Future<void> _handleTotpCredentialConflict(
    String serverUrl,
    ConflictException conflict,
  ) async {
    final itemId = conflict.itemId;
    if (itemId == null) return;

    final localCredential = await _storageService.getTotpCredentialById(
      itemId,
      includeDeleted: true,
    );
    if (localCredential == null) return;

    if (conflict.conflictType == 'remote_missing' ||
        conflict.serverActual == 0) {
      await _storageService.saveTotpCredential(
        localCredential.copyWith(
          serverVersion: 0,
          syncStatus: localCredential.isDeleted
              ? SyncStatus.synchronized
              : SyncStatus.pendingPush,
        ),
        isSyncMerge: true,
      );
      _queuedConflictNotice = localCredential.isDeleted
          ? 'Remote 2FA item was already missing. Local delete is marked synchronized.'
          : 'Remote 2FA item was missing. Sync will retry it as a new item.';
      return;
    }

    await _pullAndMergeLatestSnapshot(serverUrl);
    final mergedCredential = await _storageService.getTotpCredentialById(
      itemId,
      includeDeleted: true,
    );
    if (mergedCredential == null) return;

    _queuedConflictNotice =
        mergedCredential.syncStatus == SyncStatus.pendingPush
        ? 'Remote 2FA changes were merged locally. Sync will retry with the reconciled item.'
        : 'Remote 2FA changes were merged locally.';
  }

  Future<void> _handleServerReset() async {
    final vaultId = _identityService.vaultId;
    _localVersion = 0;
    await _storageService.setSetting(_syncVersionKey(vaultId), '0');
    await _storageService.clearLocalSyncChanges(vaultId);
    await _storageService.markAllSynchronizedItemsAsPendingPush();
    _queuedConflictNotice =
        'Server vault was reset. All local data will be re-pushed to recover.';
  }

  Future<void> _handleRemoteMissingConflict(
    String serverUrl,
    String itemId,
  ) async {
    await _pullLatestSnapshot(serverUrl);

    final localItem = await _storageService.getAccountById(
      itemId,
      includeDeleted: true,
    );
    if (localItem == null) {
      return;
    }

    if (localItem.isDeleted) {
      await _storageService.saveAccount(
        localItem.copyWith(
          syncStatus: SyncStatus.synchronized,
          serverVersion: 0,
        ),
        isSyncMerge: true,
      );
      _queuedConflictNotice =
          'Remote record was already missing. Local delete is marked synchronized.';
      return;
    }

    final conflictLog = ConflictLog(
      id: 'remote-missing-${localItem.id}',
      accountId: localItem.id,
      fieldKey: 'record.remote_missing',
      fieldValue: '',
      hlc: localItem.nameHlc,
    );

    await _storageService.saveAccount(
      localItem.copyWith(syncStatus: SyncStatus.synchronized, serverVersion: 0),
      isSyncMerge: true,
    );
    await _storageService.saveConflictLogs([conflictLog]);

    _queuedConflictCount += 1;
    _queuedConflictNotice =
        'Remote record missing. Review the conflict inbox before overwriting.';
  }

  Future<void> _handleTemplateRemoteMissingConflict(
    String serverUrl,
    String itemId,
  ) async {
    await _pullLatestSnapshot(serverUrl);

    final localItem = await _storageService.loadTemplateById(itemId);
    if (localItem == null) {
      return;
    }

    if (localItem.isDeleted) {
      await _storageService.saveTemplate(
        localItem.copyWith(
          syncStatus: SyncStatus.synchronized,
          serverVersion: 0,
        ),
        isSyncMerge: true,
      );
      _queuedConflictNotice =
          'Remote template was already missing. Local delete is marked synchronized.';
      return;
    }

    await _storageService.saveTemplate(
      localItem.copyWith(syncStatus: SyncStatus.synchronized, serverVersion: 0),
      isSyncMerge: true,
    );

    _queuedConflictCount += 1;
    _queuedConflictNotice =
        'Remote template missing. Review the conflict inbox before overwriting.';
  }

  Future<void> _handleStaleBaseConflict(String serverUrl, String itemId) async {
    await _handleVersionConflict(
      serverUrl,
      itemId,
      'stale_base_version',
      fallbackNotice:
          'Remote changes were merged locally after a stale-base conflict.',
    );
  }

  Future<void> _handleConcurrentEditConflict(
    String serverUrl,
    String itemId,
  ) async {
    await _handleVersionConflict(
      serverUrl,
      itemId,
      'concurrent_edit',
      fallbackNotice:
          'Concurrent remote edits were merged locally. Review the conflict inbox before overwriting.',
    );
  }

  Future<void> _handleConcurrentDeleteConflict(
    String serverUrl,
    String itemId,
  ) async {
    await _handleVersionConflict(
      serverUrl,
      itemId,
      'concurrent_delete',
      fallbackNotice:
          'Remote delete was accepted for this item. Restore from history only if this was unexpected.',
    );
  }

  Future<void> _handleVersionConflict(
    String serverUrl,
    String itemId,
    String conflictType, {
    required String fallbackNotice,
  }) async {
    final beforeCount = (await _storageService.getConflictLogs(itemId)).length;
    await _pullAndMergeLatestSnapshot(serverUrl);

    final afterCount = (await _storageService.getConflictLogs(itemId)).length;
    final localItem = await _storageService.getAccountById(
      itemId,
      includeDeleted: true,
    );
    if (localItem == null) {
      return;
    }

    if (localItem.syncStatus == SyncStatus.conflict) {
      _queuedConflictCount += max(1, afterCount - beforeCount);
      _queuedConflictNotice = switch (conflictType) {
        'concurrent_delete' =>
          'Remote delete conflicted with local changes. Review the conflict inbox before restoring.',
        'concurrent_edit' =>
          'Concurrent remote edits were merged locally. Review the conflict inbox before overwriting.',
        _ =>
          'Remote changes were merged locally. Review the conflict inbox before overwriting.',
      };
      return;
    }

    if (localItem.syncStatus == SyncStatus.pendingPush) {
      _queuedConflictNotice = switch (conflictType) {
        'concurrent_delete' =>
          'Remote delete was merged with local data. Sync will retry with the reconciled record.',
        'concurrent_edit' =>
          'Concurrent remote edits were merged locally. Sync will retry with the reconciled record.',
        _ =>
          'Remote changes were merged locally. Sync will retry with the reconciled record.',
      };
      return;
    }

    if (_queuedConflictNotice == null || _queuedConflictNotice!.isEmpty) {
      _queuedConflictNotice = fallbackNotice;
    }
  }
}
