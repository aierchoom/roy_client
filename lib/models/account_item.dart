import 'package:flutter/foundation.dart';

import 'account_template.dart';
import 'hlc.dart';

enum SyncStatus { synchronized, pendingPush, conflict }

SyncStatus syncStatusFromJson(
  Object? value, {
  SyncStatus fallback = SyncStatus.pendingPush,
}) {
  if (value is SyncStatus) return value;

  if (value is int) {
    return value >= 0 && value < SyncStatus.values.length
        ? SyncStatus.values[value]
        : fallback;
  }

  if (value is String) {
    final numericValue = int.tryParse(value);
    if (numericValue != null) {
      return syncStatusFromJson(numericValue, fallback: fallback);
    }

    for (final status in SyncStatus.values) {
      if (status.name == value) return status;
    }
  }

  return fallback;
}

@immutable
class AccountFieldMeta {
  final String type;
  final String label;
  final String? sourceTemplateId;
  final int? sourceTemplateVersion;

  const AccountFieldMeta({
    required this.type,
    required this.label,
    this.sourceTemplateId,
    this.sourceTemplateVersion,
  });

  factory AccountFieldMeta.fromJson(Map<String, dynamic> json) {
    return AccountFieldMeta(
      type: json['type'] as String? ?? 'text',
      label: json['label'] as String? ?? '',
      sourceTemplateId: json['sourceTemplateId'] as String?,
      sourceTemplateVersion: json['sourceTemplateVersion'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'label': label,
    'sourceTemplateId': sourceTemplateId,
    'sourceTemplateVersion': sourceTemplateVersion,
  };
}

@immutable
class AccountItem {
  final String id;
  final String name;
  final String email;
  final String templateId; // Corresponds to `template` in old code
  final int templateVersion;
  final Map<String, dynamic> data; // Custom fields data
  final Map<String, AccountFieldMeta> fieldMeta;
  final int createdAt;
  final int modifiedAt;
  final String? lastEditedBy;
  final int? lastEditedAt;

  // Sync specific fields
  final Hlc nameHlc;
  final Hlc emailHlc;
  final Map<String, Hlc> dataHlc;
  final int serverVersion;
  final SyncStatus syncStatus;
  final bool isDeleted;
  final Hlc? deleteHlc;

  AccountItem({
    required this.id,
    required this.name,
    required this.email,
    required this.templateId,
    this.templateVersion = 0,
    required this.data,
    this.fieldMeta = const {},
    required this.createdAt,
    this.modifiedAt = 0,
    this.lastEditedBy,
    this.lastEditedAt,
    required this.nameHlc,
    required this.emailHlc,
    required this.dataHlc,
    this.serverVersion = 0,
    this.syncStatus = SyncStatus.pendingPush,
    this.isDeleted = false,
    this.deleteHlc,
  });

  factory AccountItem.fromJson(Map<String, dynamic> json) {
    final dummyHlc = Hlc.zero('local');

    return AccountItem(
      id:
          json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      templateId:
          json['template'] as String? ?? json['templateId'] as String? ?? '',
      templateVersion: json['templateVersion'] as int? ?? 0,
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : {},
      fieldMeta:
          (json['fieldMeta'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              AccountFieldMeta.fromJson(v as Map<String, dynamic>),
            ),
          ) ??
          const {},
      createdAt:
          json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      modifiedAt: json['modifiedAt'] as int? ?? 0,
      lastEditedBy: json['lastEditedBy'] as String?,
      lastEditedAt: json['lastEditedAt'] as int?,
      nameHlc: json['nameHlc'] != null ? Hlc.parse(json['nameHlc']) : dummyHlc,
      emailHlc: json['emailHlc'] != null
          ? Hlc.parse(json['emailHlc'])
          : dummyHlc,
      dataHlc:
          (json['dataHlc'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Hlc.parse(v.toString())),
          ) ??
          {},
      serverVersion: json['serverVersion'] as int? ?? 0,
      syncStatus: syncStatusFromJson(json['syncStatus']),
      isDeleted: json['isDeleted'] == 1 || json['isDeleted'] == true,
      deleteHlc: json['deleteHlc'] != null
          ? Hlc.parse(json['deleteHlc'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'template': templateId,
      'templateId': templateId,
      'templateVersion': templateVersion,
      'data': data,
      'fieldMeta': fieldMeta.map((k, v) => MapEntry(k, v.toJson())),
      'createdAt': createdAt,
      'modifiedAt': modifiedAt,
      'lastEditedBy': lastEditedBy,
      'lastEditedAt': lastEditedAt,
      'nameHlc': nameHlc.toString(),
      'emailHlc': emailHlc.toString(),
      'dataHlc': dataHlc.map((k, v) => MapEntry(k, v.toString())),
      'serverVersion': serverVersion,
      'syncStatus': syncStatus.name,
      'isDeleted': isDeleted,
      'deleteHlc': deleteHlc?.toString(),
    };
  }

  /// Count of data fields not covered by the template (legacy/orphan fields).
  int legacyFieldCount(AccountTemplate? template) {
    final visibleKeys =
        template?.fields.map((field) => field.fieldKey).toSet() ?? <String>{};
    return data.entries.where((entry) {
      if (visibleKeys.contains(entry.key)) return false;
      return entry.value.trim().isNotEmpty;
    }).length;
  }

  AccountItem copyWith({
    String? id,
    String? name,
    String? email,
    String? templateId,
    int? templateVersion,
    Map<String, dynamic>? data,
    Map<String, AccountFieldMeta>? fieldMeta,
    int? createdAt,
    int? modifiedAt,
    String? lastEditedBy,
    int? lastEditedAt,
    Hlc? nameHlc,
    Hlc? emailHlc,
    Map<String, Hlc>? dataHlc,
    int? serverVersion,
    SyncStatus? syncStatus,
    bool? isDeleted,
    Hlc? deleteHlc,
  }) {
    return AccountItem(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      templateId: templateId ?? this.templateId,
      templateVersion: templateVersion ?? this.templateVersion,
      data: data ?? this.data,
      fieldMeta: fieldMeta ?? this.fieldMeta,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      nameHlc: nameHlc ?? this.nameHlc,
      emailHlc: emailHlc ?? this.emailHlc,
      dataHlc: dataHlc ?? this.dataHlc,
      serverVersion: serverVersion ?? this.serverVersion,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      deleteHlc: deleteHlc ?? this.deleteHlc,
    );
  }
}
