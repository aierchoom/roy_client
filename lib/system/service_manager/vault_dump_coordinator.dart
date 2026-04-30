import '../../models/account_item.dart';
import '../../models/account_template.dart';
import '../../services/identity_service.dart';
import '../../services/secure_storage_service.dart';
import '../../sync/sync_payload_codec.dart';

class VaultDumpImportException implements Exception {
  final String message;

  const VaultDumpImportException(this.message);

  @override
  String toString() => 'VaultDumpImportException($message)';
}

class VaultDumpImportPlan {
  final List<AccountTemplate> templates;
  final List<AccountItem> accounts;

  const VaultDumpImportPlan({required this.templates, required this.accounts});

  bool get hasData => templates.isNotEmpty || accounts.isNotEmpty;
}

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

    return await SyncPayloadCodec.encodePayload(
      payloadJson: payloadJson,
      vaultId: identityService.vaultId,
      nodeId: identityService.deviceId,
      privateKey: identityService.privateKey,
      symmetricKey: identityService.symmetricKey,
    );
  }

  Future<void> importEncryptedVaultDump(String vaultDumpJson) async {
    if (!identityService.hasIdentity) {
      throw const VaultDumpImportException(
        'Vault identity is not initialized.',
      );
    }

    final plan = await validateEncryptedVaultDump(
      vaultDumpJson: vaultDumpJson,
      vaultId: identityService.vaultId,
      privateKey: identityService.privateKey,
      symmetricKey: identityService.symmetricKey,
    );
    await importValidatedVaultDump(plan);
  }

  Future<VaultDumpImportPlan> validateEncryptedVaultDump({
    required String vaultDumpJson,
    required String vaultId,
    required String privateKey,
    required String symmetricKey,
  }) async {
    if (vaultDumpJson.trim().isEmpty) {
      throw const VaultDumpImportException('Vault dump is empty.');
    }

    try {
      final payloadJson = await SyncPayloadCodec.decodePayload(
        encodedPayload: vaultDumpJson,
        expectedVaultId: vaultId,
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );

      final accountsList = _readOptionalList(payloadJson, 'accounts');
      final templatesList = _readOptionalList(payloadJson, 'templates');

      return VaultDumpImportPlan(
        templates: templatesList
            .map((templateJson) => AccountTemplate.fromJson(templateJson))
            .toList(growable: false),
        accounts: accountsList
            .map(
              (accountJson) => AccountItem.fromJson(
                accountJson,
              ).copyWith(syncStatus: SyncStatus.synchronized),
            )
            .toList(growable: false),
      );
    } on VaultDumpImportException {
      rethrow;
    } on SyncPayloadException catch (error) {
      throw VaultDumpImportException(error.message);
    } catch (error) {
      throw VaultDumpImportException('Vault dump is invalid: $error');
    }
  }

  Future<void> importValidatedVaultDump(VaultDumpImportPlan plan) async {
    if (!plan.hasData) return;

    try {
      await storageService.replaceAllDataForImport(
        templates: plan.templates,
        accounts: plan.accounts,
      );
    } catch (error) {
      throw VaultDumpImportException('Failed to write vault dump: $error');
    }
  }

  List<Map<String, dynamic>> _readOptionalList(
    Map<String, dynamic> payloadJson,
    String key,
  ) {
    final rawList = payloadJson[key];
    if (rawList == null) return const [];
    if (rawList is! List) {
      throw VaultDumpImportException('Vault dump $key must be a list.');
    }
    return rawList
        .map((item) {
          if (item is! Map) {
            throw VaultDumpImportException(
              'Vault dump $key contains invalid item.',
            );
          }
          return Map<String, dynamic>.from(item);
        })
        .toList(growable: false);
  }
}
