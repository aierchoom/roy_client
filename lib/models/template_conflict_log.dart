import 'package:uuid/uuid.dart';

import 'hlc.dart';

class TemplateConflictLog {
  final String id;
  final String templateId;
  final String fieldKey;
  final String attributeName; // 'label', 'type', 'order', 'isRequired', etc.
  final String localValue;
  final String remoteValue;
  final Hlc localHlc;
  final Hlc remoteHlc;
  final int savedAt;

  TemplateConflictLog({
    String? id,
    required this.templateId,
    required this.fieldKey,
    required this.attributeName,
    required this.localValue,
    required this.remoteValue,
    required this.localHlc,
    required this.remoteHlc,
    int? savedAt,
  }) : id = id ?? const Uuid().v4(),
       savedAt = savedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory TemplateConflictLog.fromJson(Map<String, dynamic> json) {
    return TemplateConflictLog(
      id: json['id'] is String ? json['id'] as String : null,
      templateId: json['templateId'] is String ? json['templateId'] as String : '',
      fieldKey: json['fieldKey'] is String ? json['fieldKey'] as String : '',
      attributeName: json['attributeName'] is String ? json['attributeName'] as String : '',
      localValue: json['localValue'] is String ? json['localValue'] as String : '',
      remoteValue: json['remoteValue'] is String ? json['remoteValue'] as String : '',
      localHlc: json['localHlc'] is String
          ? Hlc.parse(json['localHlc'] as String)
          : Hlc.zero('local'),
      remoteHlc: json['remoteHlc'] is String
          ? Hlc.parse(json['remoteHlc'] as String)
          : Hlc.zero('local'),
      savedAt: json['savedAt'] is int ? json['savedAt'] as int : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'templateId': templateId,
    'fieldKey': fieldKey,
    'attributeName': attributeName,
    'localValue': localValue,
    'remoteValue': remoteValue,
    'localHlc': localHlc.toString(),
    'remoteHlc': remoteHlc.toString(),
    'savedAt': savedAt,
  };

  TemplateConflictLog copyWith({
    String? id,
    String? templateId,
    String? fieldKey,
    String? attributeName,
    String? localValue,
    String? remoteValue,
    Hlc? localHlc,
    Hlc? remoteHlc,
    int? savedAt,
  }) {
    return TemplateConflictLog(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      fieldKey: fieldKey ?? this.fieldKey,
      attributeName: attributeName ?? this.attributeName,
      localValue: localValue ?? this.localValue,
      remoteValue: remoteValue ?? this.remoteValue,
      localHlc: localHlc ?? this.localHlc,
      remoteHlc: remoteHlc ?? this.remoteHlc,
      savedAt: savedAt ?? this.savedAt,
    );
  }
}
