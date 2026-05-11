/// 保险库导入预览摘要。
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
