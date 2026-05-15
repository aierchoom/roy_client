import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/app_notification.dart';

void main() {
  group('AppNotification', () {
    const notification = AppNotification(
      id: 'notif_1',
      type: AppNotificationType.passwordExpiry,
      title: 'Password Expiry',
      body: 'Your password is old',
      accountId: 'acc_1',
      createdAt: 1700000000000,
      isRead: false,
      params: {'accountName': 'Test', 'daysSince': 100},
    );

    test('constructs with required fields', () {
      expect(notification.id, 'notif_1');
      expect(notification.type, AppNotificationType.passwordExpiry);
      expect(notification.isRead, false);
      expect(notification.params, {'accountName': 'Test', 'daysSince': 100});
    });

    test('fromRow deserializes database row', () {
      final row = {
        'id': 'notif_2',
        'type': 'weakPassword',
        'title': 'Weak',
        'body': 'Body',
        'account_id': 'acc_2',
        'created_at': 1700000001000,
        'is_read': 1,
        'params': '{"score":30}',
      };
      final n = AppNotification.fromRow(row);
      expect(n.id, 'notif_2');
      expect(n.type, AppNotificationType.weakPassword);
      expect(n.isRead, true);
      expect(n.params, {'score': 30});
    });

    test('fromRow handles null optional fields', () {
      final row = {
        'id': 'notif_3',
        'type': 'passwordExpiry',
        'title': null,
        'body': null,
        'account_id': null,
        'created_at': null,
        'is_read': 0,
        'params': null,
      };
      final n = AppNotification.fromRow(row);
      expect(n.title, '');
      expect(n.body, '');
      expect(n.accountId, null);
      expect(n.createdAt, 0);
      expect(n.isRead, false);
      expect(n.params, {});
    });

    test('fromRow falls back to passwordExpiry for unknown type', () {
      final row = {
        'id': 'notif_4',
        'type': 'unknown',
        'title': 'T',
        'body': 'B',
        'created_at': 0,
        'is_read': 0,
      };
      final n = AppNotification.fromRow(row);
      expect(n.type, AppNotificationType.passwordExpiry);
    });

    test('toRow round-trips with fromRow', () {
      final row = notification.toRow();
      final restored = AppNotification.fromRow(row);
      expect(restored.id, notification.id);
      expect(restored.type, notification.type);
      expect(restored.title, notification.title);
      expect(restored.body, notification.body);
      expect(restored.accountId, notification.accountId);
      expect(restored.createdAt, notification.createdAt);
      expect(restored.isRead, notification.isRead);
      expect(restored.params, notification.params);
    });

    test('copyWith updates isRead', () {
      final updated = notification.copyWith(isRead: true);
      expect(updated.isRead, true);
      expect(updated.id, notification.id);
      expect(updated.type, notification.type);
    });

    test('localizedTitle resolves zh and en', () {
      expect(
        notification.localizedTitle(true),
        '密码过期提醒',
      );
      expect(
        notification.localizedTitle(false),
        'Password Expiry Reminder',
      );
    });

    test('localizedBody resolves zh and en with params', () {
      final n = AppNotification(
        id: 'n',
        type: AppNotificationType.weakPassword,
        title: 'T',
        body: 'B',
        createdAt: 0,
        params: {'accountName': 'GitHub', 'level': '弱', 'score': 25},
      );
      expect(
        n.localizedBody(true),
        contains('GitHub'),
      );
      expect(
        n.localizedBody(true),
        contains('25/100'),
      );
      expect(
        n.localizedBody(false),
        contains('GitHub'),
      );
    });
  });
}
