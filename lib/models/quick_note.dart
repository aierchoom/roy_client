import 'account_item.dart';

class QuickNote {
  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int serverVersion;
  final SyncStatus syncStatus;
  final bool isDeleted;

  const QuickNote({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.serverVersion = 0,
    this.syncStatus = SyncStatus.pendingPush,
    this.isDeleted = false,
  });

  String get title {
    for (final line in content.split('\n')) {
      final stripped = _stripMarkdown(line).trim();
      if (stripped.isNotEmpty) return stripped;
    }
    return '随手记';
  }

  String get preview {
    final compact = content
        .split('\n')
        .map(_stripMarkdown)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join(' · ');
    if (compact.isEmpty) return '空白笔记';
    return compact.length > 48 ? '${compact.substring(0, 48)}…' : compact;
  }

  QuickNote copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? serverVersion,
    SyncStatus? syncStatus,
    bool? isDeleted,
  }) {
    return QuickNote(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverVersion: serverVersion ?? this.serverVersion,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'serverVersion': serverVersion,
      'syncStatus': syncStatus.name,
      'isDeleted': isDeleted,
    };
  }

  factory QuickNote.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return QuickNote(
      id: json['id'] as String? ?? 'note_${now.microsecondsSinceEpoch}',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
      serverVersion: json['serverVersion'] as int? ?? 0,
      syncStatus: syncStatusFromJson(json['syncStatus']),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }

  static String _stripMarkdown(String value) {
    return value
        .replaceFirst(RegExp(r'^\s*#{1,6}\s+'), '')
        .replaceFirst(RegExp(r'^\s*-\s+\[[ xX]\]\s+'), '')
        .replaceFirst(RegExp(r'^\s*[-*]\s+'), '')
        .replaceFirst(RegExp(r'^\s*>\s?'), '')
        .replaceAll(RegExp(r'[*_`~]'), '')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
        );
  }
}

class QuickNotesSnapshot {
  final List<QuickNote> notes;
  final String activeNoteId;

  const QuickNotesSnapshot({required this.notes, required this.activeNoteId});
}
