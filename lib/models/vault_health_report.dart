enum VaultHealthGrade {
  excellent, // 90-100
  good, // 70-89
  warning, // 50-69
  critical, // 0-49
}

enum VaultHealthRiskLevel {
  high,
  medium,
  low,
}

enum VaultHealthActionType {
  none,
  navigateToAccountEdit,
  navigateToOutbox,
  navigateToConflictInbox,
  navigateToExport,
  navigateToSyncSettings,
}

class VaultHealthAction {
  final VaultHealthActionType type;
  final String? targetId;

  const VaultHealthAction({required this.type, this.targetId});
}

class VaultHealthItem {
  final String id;
  final String title;
  final VaultHealthRiskLevel riskLevel;
  final bool isPass;
  final String description;
  final VaultHealthAction? action;

  const VaultHealthItem({
    required this.id,
    required this.title,
    required this.riskLevel,
    required this.isPass,
    required this.description,
    this.action,
  });
}

class VaultHealthReport {
  final int score;
  final VaultHealthGrade grade;
  final List<VaultHealthItem> items;
  final DateTime calculatedAt;

  const VaultHealthReport({
    required this.score,
    required this.grade,
    required this.items,
    required this.calculatedAt,
  });

  List<VaultHealthItem> get failedItems =>
      items.where((i) => !i.isPass).toList();

  List<VaultHealthItem> get highRiskItems =>
      items.where((i) => i.riskLevel == VaultHealthRiskLevel.high && !i.isPass).toList();

  List<VaultHealthItem> get mediumRiskItems =>
      items.where((i) => i.riskLevel == VaultHealthRiskLevel.medium && !i.isPass).toList();

  List<VaultHealthItem> get lowRiskItems =>
      items.where((i) => i.riskLevel == VaultHealthRiskLevel.low && !i.isPass).toList();
}
