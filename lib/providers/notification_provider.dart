import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';
import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../services/secure_storage_service.dart';

class NotificationProvider extends ChangeNotifier {
  final SecureStorageService _storage;
  final NotificationService _notificationService;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  int _expiryDays = 90;
  bool _isLoading = false;
  bool _pushEnabled = false;

  NotificationProvider(this._storage, this._notificationService) {
    _loadSettings();
  }

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  int get expiryDays => _expiryDays;
  bool get isLoading => _isLoading;
  bool get pushEnabled => _pushEnabled;

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _expiryDays = prefs.getInt('notification_password_expiry_days') ?? 90;
      _pushEnabled = prefs.getBool('notification_push_enabled') ?? false;
    } catch (e) {
      AppLogger.d('Failed to load notification settings: $e');
    }
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();
    try {
      _notifications = await _storage.loadNotifications();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (e) {
      AppLogger.d('Failed to load notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> generateNotifications({
    required List<AccountItem> accounts,
    required List<AccountTemplate> templates,
  }) async {
    try {
      await _notificationService.generatePasswordExpiryNotifications(
        accounts: accounts,
        templates: templates,
        expiryDays: _expiryDays,
      );
      await _notificationService.generateWeakPasswordNotifications(
        accounts: accounts,
        templates: templates,
      );
      await loadNotifications();
    } catch (e) {
      AppLogger.d('Failed to generate notifications: $e');
    }
  }

  Future<void> markRead(String id) async {
    await _storage.markNotificationRead(id);
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    await _storage.markAllNotificationsRead();
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    await _storage.deleteNotification(id);
    _notifications.removeWhere((n) => n.id == id);
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> updateExpiryDays(int days) async {
    _expiryDays = days;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('notification_password_expiry_days', days);
    } catch (e) {
      AppLogger.d('Failed to save expiry days: $e');
    }
    notifyListeners();
  }

  Future<void> scheduleDailyReminder() async {
    await _notificationService.scheduleDailyCheck();
    _pushEnabled = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_push_enabled', true);
    } catch (e) {
      AppLogger.d('Failed to save push setting: $e');
    }
    notifyListeners();
  }

  Future<void> cancelDailyReminder() async {
    await _notificationService.cancelAllScheduled();
    _pushEnabled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_push_enabled', false);
    } catch (e) {
      AppLogger.d('Failed to save push setting: $e');
    }
    notifyListeners();
  }
}
