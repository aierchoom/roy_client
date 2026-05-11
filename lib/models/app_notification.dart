import 'dart:convert';

enum AppNotificationType { passwordExpiry, weakPassword }

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final String? accountId;
  final int createdAt;
  final bool isRead;
  final Map<String, dynamic> params;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.accountId,
    required this.createdAt,
    this.isRead = false,
    this.params = const {},
  });

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    Map<String, dynamic> parsedParams = {};
    final paramsStr = row['params'] as String?;
    if (paramsStr != null && paramsStr.isNotEmpty) {
      try {
        parsedParams = jsonDecode(paramsStr) as Map<String, dynamic>;
      } catch (_) {}
    }

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
      params: parsedParams,
    );
  }

  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'body': body,
      'account_id': accountId,
      'created_at': createdAt,
      'is_read': isRead ? 1 : 0,
      'params': jsonEncode(params),
    };
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
      params: params,
    );
  }

  /// Resolve localized title from type + params.
  String localizedTitle(bool isZh) {
    return switch (type) {
      AppNotificationType.passwordExpiry =>
        isZh ? '密码过期提醒' : 'Password Expiry Reminder',
      AppNotificationType.weakPassword =>
        isZh ? '弱密码提醒' : 'Weak Password Alert',
    };
  }

  /// Resolve localized body from type + params.
  String localizedBody(bool isZh) {
    return switch (type) {
      AppNotificationType.passwordExpiry => isZh
        ? '「${params['accountName']}」的密码已 ${params['daysSince']} 天未修改，建议尽快更新。'
        : '"${params['accountName']}" password unchanged for ${params['daysSince']} day(s). Consider updating it.',
      AppNotificationType.weakPassword => isZh
        ? '「${params['accountName']}」的密码强度为 ${params['level']}（${params['score']}/100），建议尽快更新。'
        : '"${params['accountName']}" password strength is ${params['level']} (${params['score']}/100). Consider updating it.',
    };
  }
}
