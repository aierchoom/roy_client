import 'package:flutter/foundation.dart';

import '../../models/account_item.dart';
import '../../models/account_template.dart';
import '../../services/identity_service.dart';
import '../../services/secure_storage_service.dart';
import '../../sync/sync_payload_codec.dart';

class VaultDumpCoordinator {
  final IdentityService identityService;
  final SecureStorageService storageService;

  const VaultDumpCoordinator({
    required this.identityService,
    required this.storageService,
  });

  Future<String?> exportEncryptedVaultDump() async {
    if (!identityService.hasIdentity) return null;

    final accountsList = await storageService.loadAccounts(
      includeDeleted: true,
    );
    final templatesList = await storageService.loadCustomTemplates();

    final payloadJson = {
      'accounts': accountsList.map((account) => account.toJson()).toList(),
      'templates': templatesList.map((template) => template.toJson()).toList(),
    };

    return SyncPayloadCodec.encodePayload(
      payloadJson: payloadJson,
      vaultId: identityService.vaultId,
      nodeId: identityService.deviceId,
      privateKey: identityService.privateKey,
      symmetricKey: identityService.symmetricKey,
    );
  }

  Future<void> importEncryptedVaultDump(String vaultDumpJson) async {
    if (!identityService.hasIdentity) return;

    try {
      final payloadJson = SyncPayloadCodec.decodePayload(
        encodedPayload: vaultDumpJson,
        expectedVaultId: identityService.vaultId,
        privateKey: identityService.privateKey,
        symmetricKey: identityService.symmetricKey,
      );

      final accountsList = payloadJson['accounts'] as List?;
      final templatesList = payloadJson['templates'] as List?;

      if (templatesList != null || accountsList != null) {
        await storageService.clearAllData();
      }

      if (templatesList != null) {
        for (final templateJson in templatesList) {
          final template = AccountTemplate.fromJson(
            Map<String, dynamic>.from(templateJson),
          );
          await storageService.saveTemplate(template, isSyncMerge: true);
        }
      }

      if (accountsList != null) {
        for (final accountJson in accountsList) {
          final account = AccountItem.fromJson(
            Map<String, dynamic>.from(accountJson),
          );
          await storageService.saveAccount(
            account.copyWith(syncStatus: SyncStatus.synchronized),
            isSyncMerge: true,
          );
        }
      }
    } catch (error) {
      debugPrint('Failed to import vault dump: $error');
    }
  }
}
