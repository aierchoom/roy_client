import '../../models/account_item.dart';
import '../../models/account_template.dart';
import '../../models/totp_credential.dart';
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
  final List<TotpCredential> totpCredentials;

  const VaultDumpImportPlan({
    required this.templates,
    required this.accounts,
    this.totpCredentials = const [],
  });

  bool get hasData =>
      templates.isNotEmpty || accounts.isNotEmpty || totpCredentials.isNotEmpty;
}

/// Vault dump 协调器：负责加密导出和验证导入。
///
/// **备份包（Backup Package）与配对转存（Pairing Dump）的边界**
/// - 备份包：通过 [exportEncryptedVaultDump] 生成的独立加密数据快照，用于灾难恢复。
///   仅包含账号和模板密文，不携带身份密钥；恢复时需额外提供 vaultId、privateKey、
///   symmetricKey 才能解密。可长期离线保存。
/// - 配对转存：嵌在配对码 / 恢复码内的可选数据 payload（`vaultDump` 字段），用于新设备
///   快速重建。配对码本身已经携带身份密钥，因此转存只是其附属数据包。
/// - 两者使用同一套 AEAD 加密格式，但生命周期和携带方式不同：备份包独立存活，
///   配对转存依附于身份传输链路。
///
/// T14 状态重建规则：
/// - syncStatus：保留源状态，不再强制覆盖为 synchronized。
/// - outbox / conflict_log：由 replaceAllDataForImport 清空，因为 dump 不携带历史。
/// - dirty / version：由调用方（SyncService.initialize）重新读取；新设备首次导入时为 0/false。
/// - 已知限制：pendingPush/pendingReview/conflict 状态的账号在新设备上缺少 outbox/conflict_log
///   记录，不会自动进入推送/审阅流程，需用户手动编辑或依赖首次 pull 时服务器版本覆盖。
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
    final templatesList = await storageService.loadAllTemplates();
    final totpList = await storageService.loadTotpCredentials(
      includeDeleted: true,
    );

    final payloadJson = {
      'accounts': accountsList.map((account) => account.toJson()).toList(),
      'templates': templatesList.map((template) => template.toJson()).toList(),
      'totp_credentials': totpList.map((c) => c.toJson()).toList(),
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
      final totpList = _readOptionalList(payloadJson, 'totp_credentials');

      return VaultDumpImportPlan(
        templates: templatesList
            .map((templateJson) => AccountTemplate.fromJson(templateJson))
            .toList(growable: false),
        accounts: accountsList
            .map((accountJson) => AccountItem.fromJson(accountJson))
            .toList(growable: false),
        totpCredentials: totpList
            .map((json) => TotpCredential.fromJson(json))
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
        totpCredentials: plan.totpCredentials,
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
