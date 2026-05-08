import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:secret_roy/core/app_logger.dart';

import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/vault_health_report.dart';
import 'enhanced_crypto_service.dart';
import 'identity_service.dart';
import 'secure_storage_service.dart';

class VaultHealthCalculator {
  final SecureStorageService _storage;
  final IdentityService _identity;

  VaultHealthCalculator({
    required SecureStorageService storage,
    required IdentityService identity,
  }) : _storage = storage,
       _identity = identity;

  Future<VaultHealthReport> calculate() async {
    final items = <VaultHealthItem>[];

    // A. 保险库运行体检
    items.add(await _checkDatabaseEncryption());
    items.add(await _checkBackupAge());
    items.add(await _checkVaultIdentity());
    items.add(await _checkSyncAuth());
    items.add(await _checkPendingSyncChanges());
    items.add(await _checkConflicts());

    // B. 账号安全体检
    final accounts = await _storage.loadAccounts();
    final allTemplates = await _storage.loadAllTemplates();
    final totpCredentials = await _storage.loadTotpCredentials();

    items.add(VaultHealthCalculator.checkWeakPasswords(accounts));
    items.add(VaultHealthCalculator.checkReusedPasswords(accounts));
    items.add(VaultHealthCalculator.checkStaleRecords(accounts));
    items.add(
      VaultHealthCalculator.checkIncompleteRecords(accounts, allTemplates),
    );
    items.add(
      VaultHealthCalculator.checkMissing2FA(
        accounts,
        allTemplates,
        totpCredentials,
      ),
    );

    final score = VaultHealthCalculator.calculateScore(items);
    final grade = VaultHealthCalculator.scoreToGrade(score);

    return VaultHealthReport(
      score: score,
      grade: grade,
      items: items,
      calculatedAt: DateTime.now(),
    );
  }

  Future<VaultHealthItem> _checkDatabaseEncryption() async {
    try {
      final dbPath = await _storage.getDatabaseFilePath();
      final encryptedPath = dbPath.replaceAll('.db', '.db.enc');
      final exists = File(encryptedPath).existsSync();
      return VaultHealthItem(
        id: 'db_encryption',
        title: '本地数据库加密',
        riskLevel: VaultHealthRiskLevel.high,
        isPass: exists,
        description: exists ? '数据库已加密存储' : '未检测到加密数据库文件，数据存在泄露风险',
      );
    } catch (e) {
      AppLogger.d('Health check db_encryption failed: $e');
      return const VaultHealthItem(
        id: 'db_encryption',
        title: '本地数据库加密',
        riskLevel: VaultHealthRiskLevel.high,
        isPass: false,
        description: '无法检测数据库加密状态',
      );
    }
  }

  Future<VaultHealthItem> _checkBackupAge() async {
    try {
      final lastSyncStr = await _storage.getSetting(
        'sync_last_time_${_identity.vaultId}',
      );
      if (lastSyncStr == null) {
        return const VaultHealthItem(
          id: 'backup_age',
          title: '备份状态',
          riskLevel: VaultHealthRiskLevel.high,
          isPass: false,
          description: '从未进行同步备份',
          action: VaultHealthAction(
            type: VaultHealthActionType.navigateToSyncSettings,
          ),
        );
      }
      final lastSync = DateTime.tryParse(lastSyncStr);
      if (lastSync == null) {
        return const VaultHealthItem(
          id: 'backup_age',
          title: '备份状态',
          riskLevel: VaultHealthRiskLevel.medium,
          isPass: true,
          description: '备份时间无法解析',
        );
      }
      final daysSince = DateTime.now().difference(lastSync).inDays;
      return VaultHealthItem(
        id: 'backup_age',
        title: '备份状态',
        riskLevel: VaultHealthRiskLevel.high,
        isPass: daysSince <= 30,
        description: daysSince <= 30
            ? '最近备份 $daysSince 天前'
            : '备份已过期 $daysSince 天，建议立即同步或导出',
        action: const VaultHealthAction(
          type: VaultHealthActionType.navigateToExport,
        ),
      );
    } catch (e) {
      AppLogger.d('Health check backup_age failed: $e');
      return const VaultHealthItem(
        id: 'backup_age',
        title: '备份状态',
        riskLevel: VaultHealthRiskLevel.medium,
        isPass: true,
        description: '无法检测备份状态',
      );
    }
  }

  Future<VaultHealthItem> _checkVaultIdentity() async {
    final hasId = _identity.hasIdentity;
    return VaultHealthItem(
      id: 'vault_identity',
      title: 'Vault 身份完整性',
      riskLevel: VaultHealthRiskLevel.high,
      isPass: hasId,
      description: hasId ? 'Vault 身份和设备身份完整' : 'Vault 身份缺失或损坏，建议重新配对',
      action: hasId
          ? null
          : const VaultHealthAction(
              type: VaultHealthActionType.navigateToSyncSettings,
            ),
    );
  }

  Future<VaultHealthItem> _checkSyncAuth() async {
    final hasToken =
        _identity.vaultApiToken != null && _identity.vaultApiToken!.isNotEmpty;
    return VaultHealthItem(
      id: 'sync_auth',
      title: '同步认证状态',
      riskLevel: VaultHealthRiskLevel.low,
      isPass: hasToken,
      description: hasToken
          ? 'Vault-level API token 已配置'
          : '尚未获取同步认证 token，首次同步将自动签发',
    );
  }

  Future<VaultHealthItem> _checkPendingSyncChanges() async {
    try {
      final changes = await _storage.loadOpenLocalSyncChanges(
        vaultId: _identity.vaultId,
      );
      final count = changes.length;
      return VaultHealthItem(
        id: 'pending_sync',
        title: '待同步变更',
        riskLevel: VaultHealthRiskLevel.medium,
        isPass: count == 0,
        description: count == 0 ? '没有待审阅的本地变更' : '有 $count 条本地变更待审阅推送',
        action: count > 0
            ? const VaultHealthAction(
                type: VaultHealthActionType.navigateToOutbox,
              )
            : null,
      );
    } catch (e) {
      AppLogger.d('Health check pending_sync failed: $e');
      return const VaultHealthItem(
        id: 'pending_sync',
        title: '待同步变更',
        riskLevel: VaultHealthRiskLevel.medium,
        isPass: true,
        description: '无法检测待同步状态',
      );
    }
  }

  Future<VaultHealthItem> _checkConflicts() async {
    try {
      final accounts = await _storage.loadAccounts();
      int conflictCount = 0;
      for (final account in accounts) {
        final logs = await _storage.getConflictLogs(account.id);
        if (logs.isNotEmpty) conflictCount++;
      }
      return VaultHealthItem(
        id: 'conflicts',
        title: '同步冲突',
        riskLevel: VaultHealthRiskLevel.medium,
        isPass: conflictCount == 0,
        description: conflictCount == 0
            ? '没有未处理的同步冲突'
            : '有 $conflictCount 个账号存在未处理冲突',
        action: conflictCount > 0
            ? const VaultHealthAction(
                type: VaultHealthActionType.navigateToConflictInbox,
              )
            : null,
      );
    } catch (e) {
      AppLogger.d('Health check conflicts failed: $e');
      return const VaultHealthItem(
        id: 'conflicts',
        title: '同步冲突',
        riskLevel: VaultHealthRiskLevel.medium,
        isPass: true,
        description: '无法检测冲突状态',
      );
    }
  }

  static VaultHealthItem checkWeakPasswords(List<AccountItem> accounts) {
    final weakAccounts = <String>[];
    for (final account in accounts) {
      if (account.isDeleted) continue;
      final password = (account.data['password'] ?? '').toString();
      if (password.isEmpty) continue;
      final strength = EnhancedCryptoService.calculatePasswordStrength(
        password,
      );
      if (strength < 40) {
        weakAccounts.add(account.name);
      }
    }
    return VaultHealthItem(
      id: 'weak_passwords',
      title: '弱密码检测',
      riskLevel: VaultHealthRiskLevel.high,
      isPass: weakAccounts.isEmpty,
      description: weakAccounts.isEmpty
          ? '未发现弱密码'
          : '发现 ${weakAccounts.length} 个弱密码账号',
      action: weakAccounts.isNotEmpty
          ? VaultHealthAction(type: VaultHealthActionType.navigateToAccountEdit)
          : null,
    );
  }

  static VaultHealthItem checkReusedPasswords(List<AccountItem> accounts) {
    final passwordCounts = <String, int>{};
    for (final account in accounts) {
      if (account.isDeleted) continue;
      final password = (account.data['password'] ?? '').toString();
      if (password.isEmpty) continue;
      // Use SHA-256 hash as map key to avoid keeping plaintext passwords in memory
      final hash = sha256.convert(utf8.encode(password)).toString();
      passwordCounts[hash] = (passwordCounts[hash] ?? 0) + 1;
    }
    final reusedCount = passwordCounts.values.where((c) => c > 1).length;
    return VaultHealthItem(
      id: 'reused_passwords',
      title: '重复密码检测',
      riskLevel: VaultHealthRiskLevel.high,
      isPass: reusedCount == 0,
      description: reusedCount == 0 ? '未发现重复使用的密码' : '发现 $reusedCount 组重复使用的密码',
      action: reusedCount > 0
          ? VaultHealthAction(type: VaultHealthActionType.navigateToAccountEdit)
          : null,
    );
  }

  static VaultHealthItem checkStaleRecords(List<AccountItem> accounts) {
    final now = DateTime.now();
    final staleAccounts = <String>[];
    for (final account in accounts) {
      if (account.isDeleted) continue;
      // Use modified_at from the account if available, otherwise createdAt
      final age = now.difference(
        DateTime.fromMillisecondsSinceEpoch(account.createdAt),
      );
      if (age.inDays > 180) {
        staleAccounts.add(account.name);
      }
    }
    return VaultHealthItem(
      id: 'stale_records',
      title: '陈旧记录',
      riskLevel: VaultHealthRiskLevel.medium,
      isPass: staleAccounts.isEmpty,
      description: staleAccounts.isEmpty
          ? '没有超过 180 天未更新的密码'
          : '有 ${staleAccounts.length} 个账号超过 180 天未更新',
      action: staleAccounts.isNotEmpty
          ? VaultHealthAction(type: VaultHealthActionType.navigateToAccountEdit)
          : null,
    );
  }

  static VaultHealthItem checkIncompleteRecords(
    List<AccountItem> accounts,
    List<AccountTemplate> templates,
  ) {
    final incompleteAccounts = <String>[];
    for (final account in accounts) {
      if (account.isDeleted) continue;
      final url = (account.data['url'] ?? '').toString();
      if (url.isEmpty) {
        incompleteAccounts.add(account.name);
      }
    }
    return VaultHealthItem(
      id: 'incomplete_records',
      title: '不完整记录',
      riskLevel: VaultHealthRiskLevel.low,
      isPass: incompleteAccounts.isEmpty,
      description: incompleteAccounts.isEmpty
          ? '所有账号都有 URL 信息'
          : '有 ${incompleteAccounts.length} 个账号缺少 URL',
      action: incompleteAccounts.isNotEmpty
          ? VaultHealthAction(type: VaultHealthActionType.navigateToAccountEdit)
          : null,
    );
  }

  static VaultHealthItem checkMissing2FA(
    List<AccountItem> accounts,
    List<AccountTemplate> templates,
    List<dynamic> totpCredentials,
  ) {
    // Accounts that use website template but have no linked TOTP
    final missing2faAccounts = <String>[];
    for (final account in accounts) {
      if (account.isDeleted) continue;
      final template = templates.cast<AccountTemplate?>().firstWhere(
        (t) => t?.templateId == account.templateId,
        orElse: () => null,
      );
      if (template == null) continue;
      // Check if template has a totp field
      final hasTotpField = template.fields.any((f) => f.attributes.isReference);
      if (!hasTotpField) continue;
      // Check if account has linked TOTP
      final hasLinkedTotp = totpCredentials.any(
        (c) => c.linkedAccountIds.contains(account.id),
      );
      if (!hasLinkedTotp) {
        missing2faAccounts.add(account.name);
      }
    }
    return VaultHealthItem(
      id: 'missing_2fa',
      title: '缺少 2FA',
      riskLevel: VaultHealthRiskLevel.medium,
      isPass: missing2faAccounts.isEmpty,
      description: missing2faAccounts.isEmpty
          ? '已配置 2FA 的账号均已关联'
          : '有 ${missing2faAccounts.length} 个支持 2FA 的账号未关联 TOTP',
    );
  }

  static int calculateScore(List<VaultHealthItem> items) {
    int score = 100;
    for (final item in items) {
      if (item.isPass) continue;
      switch (item.riskLevel) {
        case VaultHealthRiskLevel.high:
          score -= 15;
        case VaultHealthRiskLevel.medium:
          score -= 8;
        case VaultHealthRiskLevel.low:
          score -= 3;
      }
    }
    return score.clamp(0, 100);
  }

  static VaultHealthGrade scoreToGrade(int score) {
    if (score >= 90) return VaultHealthGrade.excellent;
    if (score >= 70) return VaultHealthGrade.good;
    if (score >= 50) return VaultHealthGrade.warning;
    return VaultHealthGrade.critical;
  }
}
