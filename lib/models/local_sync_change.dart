import 'dart:convert';

enum LocalSyncEntityType { account, template, totpCredential }

enum LocalSyncAction { create, update, delete }

enum LocalSyncStatus {
  pendingReview,
  approved,
  pushing,
  pushed,
  failed,
  conflict,
  reverted,
}

LocalSyncEntityType localSyncEntityTypeFromString(Object? value) {
  final name = value?.toString();
  return LocalSyncEntityType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => LocalSyncEntityType.account,
  );
}

LocalSyncAction localSyncActionFromString(Object? value) {
  final name = value?.toString();
  return LocalSyncAction.values.firstWhere(
    (action) => action.name == name,
    orElse: () => LocalSyncAction.update,
  );
}

LocalSyncStatus localSyncStatusFromString(Object? value) {
  final name = value?.toString();
  return LocalSyncStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => LocalSyncStatus.pendingReview,
  );
}

class LocalSyncChange {
  final String id;
  final String vaultId;
  final LocalSyncEntityType entityType;
  final String entityId;
  final LocalSyncAction action;
  final String title;
  final String? beforeJson;
  final String? afterJson;
  final Map<String, dynamic> diff;
  final int baseServerVersion;
  final LocalSyncStatus status;
  final int createdAt;
  final int updatedAt;
  final int? approvedAt;
  final int? pushedAt;
  final String? errorMessage;

  const LocalSyncChange({
    required this.id,
    required this.vaultId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.title,
    required this.beforeJson,
    required this.afterJson,
    required this.diff,
    required this.baseServerVersion,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    this.pushedAt,
    this.errorMessage,
  });

  factory LocalSyncChange.fromDatabaseRow(Map<String, dynamic> row) {
    final diffRaw = row['diff_json'] as String?;
    return LocalSyncChange(
      id: row['id'] as String,
      vaultId: row['vault_id'] as String? ?? '',
      entityType: localSyncEntityTypeFromString(row['entity_type']),
      entityId: row['entity_id'] as String? ?? '',
      action: localSyncActionFromString(row['action']),
      title: row['title'] as String? ?? '',
      beforeJson: row['before_json'] as String?,
      afterJson: row['after_json'] as String?,
      diff: _decodeMap(diffRaw) ?? const <String, dynamic>{},
      baseServerVersion: row['base_server_version'] as int? ?? 0,
      status: localSyncStatusFromString(row['status']),
      createdAt: row['created_at'] as int? ?? 0,
      updatedAt: row['updated_at'] as int? ?? 0,
      approvedAt: row['approved_at'] as int?,
      pushedAt: row['pushed_at'] as int?,
      errorMessage: row['error_message'] as String?,
    );
  }

  bool get isDelete => action == LocalSyncAction.delete;

  bool get isAccount => entityType == LocalSyncEntityType.account;

  bool get isTotpCredential =>
      entityType == LocalSyncEntityType.totpCredential;

  bool get canPush =>
      status == LocalSyncStatus.pendingReview ||
      status == LocalSyncStatus.failed ||
      status == LocalSyncStatus.conflict;

  List<String> get changedFields {
    final raw = diff['changed_fields'];
    if (raw is List) {
      return raw.map((field) => field.toString()).toList(growable: false);
    }
    return const <String>[];
  }

  Map<String, dynamic>? get beforeSnapshot => _decodeMap(beforeJson);

  Map<String, dynamic>? get afterSnapshot => _decodeMap(afterJson);

  LocalSyncChange copyWith({
    LocalSyncStatus? status,
    int? approvedAt,
    int? pushedAt,
    String? errorMessage,
  }) {
    return LocalSyncChange(
      id: id,
      vaultId: vaultId,
      entityType: entityType,
      entityId: entityId,
      action: action,
      title: title,
      beforeJson: beforeJson,
      afterJson: afterJson,
      diff: diff,
      baseServerVersion: baseServerVersion,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      pushedAt: pushedAt ?? this.pushedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static String encodeSnapshot(Map<String, dynamic>? snapshot) {
    return jsonEncode(snapshot);
  }
}

Map<String, dynamic>? _decodeMap(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return null;
}
