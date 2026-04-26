import 'hlc.dart';

enum SyncStatus { synchronized, pendingPush, conflict }

class AccountItem {
  final String id;
  final String name;
  final String email;
  final String templateId; // Corresponds to `template` in old code
  final Map<String, String> data; // Custom fields data
  final int createdAt;

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
    required this.data,
    required this.createdAt,
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
      data:
          (json['data'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v?.toString() ?? ''),
          ) ??
          {},
      createdAt:
          json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      nameHlc: json['nameHlc'] != null ? Hlc.parse(json['nameHlc']) : dummyHlc,
      emailHlc: json['emailHlc'] != null ? Hlc.parse(json['emailHlc']) : dummyHlc,
      dataHlc: (json['dataHlc'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Hlc.parse(v.toString())),
          ) ?? {},
      serverVersion: json['serverVersion'] as int? ?? 0,
      syncStatus: SyncStatus.values[json['syncStatus'] as int? ?? SyncStatus.pendingPush.index],
      isDeleted: json['isDeleted'] == 1 || json['isDeleted'] == true,
      deleteHlc: json['deleteHlc'] != null ? Hlc.parse(json['deleteHlc']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'template': templateId,
      'templateId': templateId,
      'data': data,
      'createdAt': createdAt,
      'nameHlc': nameHlc.toString(),
      'emailHlc': emailHlc.toString(),
      'dataHlc': dataHlc.map((k, v) => MapEntry(k, v.toString())),
      'serverVersion': serverVersion,
      'syncStatus': syncStatus.index,
      'isDeleted': isDeleted ? 1 : 0,
      'deleteHlc': deleteHlc?.toString(),
    };
  }

  AccountItem copyWith({
    String? id,
    String? name,
    String? email,
    String? templateId,
    Map<String, String>? data,
    int? createdAt,
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
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
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
