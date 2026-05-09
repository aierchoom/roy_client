enum AppNotificationType { passwordExpiry }

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final String? accountId;
  final int createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.accountId,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as String,
      type: AppNotificationType.values.firstWhere(
        (t) => t.name == (row['type'] as String?),
        orElse: () => AppNotificationType.passwordExpiry,
      ),
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      accountId: row['account_id'] as String?,
      createdAt: row['created_at'] as int? ?? 0,
      isRead: (row['is_read'] as int?) == 1,
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      accountId: accountId,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
