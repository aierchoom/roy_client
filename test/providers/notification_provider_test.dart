import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/app_notification.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/providers/notification_provider.dart';
import 'package:secret_roy/services/notification_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sync/sync_server_test_harness.dart';

class _FakeNotificationService extends NotificationService {
  bool scheduled = false;
  bool cancelled = false;

  _FakeNotificationService() : super(FakeSecureStorageService());

  @override
  Future<void> init() async {}

  @override
  Future<List<AppNotification>> generatePasswordExpiryNotifications({
    required List<AccountItem> accounts,
    required List<AccountTemplate> templates,
    int expiryDays = 90,
  }) async {
    return [];
  }

  @override
  Future<List<AppNotification>> generateWeakPasswordNotifications({
    required List<AccountItem> accounts,
    required List<AccountTemplate> templates,
    int strengthThreshold = 40,
  }) async {
    return [];
  }

  @override
  Future<void> scheduleDailyCheck({int hour = 9, int minute = 0}) async {
    scheduled = true;
  }

  @override
  Future<void> cancelAllScheduled() async {
    cancelled = true;
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationProvider', () {
    late FakeSecureStorageService storage;
    late _FakeNotificationService service;
    late NotificationProvider provider;

    setUp(() {
      storage = FakeSecureStorageService();
      service = _FakeNotificationService();
      provider = NotificationProvider(storage, service);
    });

    test('initial state has default settings', () {
      expect(provider.notifications, isEmpty);
      expect(provider.unreadCount, 0);
      expect(provider.expiryDays, 90);
      expect(provider.pushEnabled, false);
      expect(provider.isLoading, false);
    });

    test('loadNotifications populates list and unread count', () async {
      final n1 = AppNotification(
        id: 'n1',
        type: AppNotificationType.passwordExpiry,
        title: 'T1',
        body: 'B1',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        isRead: false,
      );
      final n2 = AppNotification(
        id: 'n2',
        type: AppNotificationType.weakPassword,
        title: 'T2',
        body: 'B2',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        isRead: true,
      );
      storage.notifications.addAll([n1, n2]);

      await provider.loadNotifications();

      expect(provider.notifications.length, 2);
      expect(provider.unreadCount, 1);
      expect(provider.isLoading, false);
    });

    test('markRead updates notification and unread count', () async {
      final n = AppNotification(
        id: 'n1',
        type: AppNotificationType.passwordExpiry,
        title: 'T',
        body: 'B',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        isRead: false,
      );
      storage.notifications.add(n);
      await provider.loadNotifications();
      expect(provider.unreadCount, 1);

      await provider.markRead('n1');

      expect(provider.notifications.first.isRead, true);
      expect(provider.unreadCount, 0);
      expect(storage.notifications.first.isRead, true);
    });

    test('markAllRead marks all as read', () async {
      storage.notifications.addAll([
        AppNotification(
          id: 'n1',
          type: AppNotificationType.passwordExpiry,
          title: 'T1',
          body: 'B1',
          createdAt: 0,
          isRead: false,
        ),
        AppNotification(
          id: 'n2',
          type: AppNotificationType.weakPassword,
          title: 'T2',
          body: 'B2',
          createdAt: 0,
          isRead: false,
        ),
      ]);
      await provider.loadNotifications();
      expect(provider.unreadCount, 2);

      await provider.markAllRead();

      expect(provider.unreadCount, 0);
      expect(provider.notifications.every((n) => n.isRead), true);
    });

    test('deleteNotification removes from list', () async {
      storage.notifications.add(AppNotification(
        id: 'n1',
        type: AppNotificationType.passwordExpiry,
        title: 'T',
        body: 'B',
        createdAt: 0,
        isRead: false,
      ));
      await provider.loadNotifications();
      expect(provider.notifications.length, 1);

      await provider.deleteNotification('n1');

      expect(provider.notifications, isEmpty);
      expect(provider.unreadCount, 0);
      expect(storage.notifications, isEmpty);
    });

    test('updateExpiryDays persists value', () async {
      await provider.updateExpiryDays(60);
      expect(provider.expiryDays, 60);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('notification_password_expiry_days'), 60);
    });

    test('scheduleDailyReminder sets pushEnabled and persists', () async {
      await provider.scheduleDailyReminder();
      expect(provider.pushEnabled, true);
      expect(service.scheduled, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notification_push_enabled'), true);
    });

    test('cancelDailyReminder clears pushEnabled and persists', () async {
      await provider.scheduleDailyReminder();
      await provider.cancelDailyReminder();
      expect(provider.pushEnabled, false);
      expect(service.cancelled, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notification_push_enabled'), false);
    });

    test('generateNotifications delegates to service and reloads', () async {
      final account = AccountItem(
        id: 'acc_1',
        name: 'Test',
        email: 'test@test.com',
        templateId: 'builtin_generic_info',
        data: const {'password': '123456'},
        createdAt: DateTime.now().millisecondsSinceEpoch - const Duration(days: 100).inMilliseconds,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
        syncStatus: SyncStatus.synchronized,
      );
      final template = basicAccountTemplates.firstWhere(
        (t) => t.templateId == 'builtin_generic_info',
      );

      await provider.generateNotifications(
        accounts: [account],
        templates: [template],
      );

      expect(provider.isLoading, false);
    });
  });
}
