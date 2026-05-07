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
      id: json['id'] as String,
      templateId: json['templateId'] as String,
      fieldKey: json['fieldKey'] as String,
      attributeName: json['attributeName'] as String,
      localValue: json['localValue'] as String,
      remoteValue: json['remoteValue'] as String,
      localHlc: Hlc.parse(json['localHlc'] as String),
      remoteHlc: Hlc.parse(json['remoteHlc'] as String),
      savedAt: json['savedAt'] as int,
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
}
