import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/app_notification.dart';
import 'enhanced_crypto_service.dart';
import 'secure_storage_service.dart';

class NotificationService {
  final SecureStorageService _storage;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  NotificationService(this._storage);

  static const _channelId = 'secret_roy_notifications';
  static const _channelName = 'SecretRoy 通知';
  static const _channelDesc = '密码安全提醒通知';

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      final localName = DateTime.now().timeZoneName;
      final location = tz.timeZoneDatabase.locations[localName] ??
          tz.timeZoneDatabase.locations.values.first;
      tz.setLocalLocation(location);

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings();
      const settings = InitializationSettings(android: android, iOS: darwin, macOS: darwin);
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (e) {
      AppLogger.d('NotificationService init failed: $e');
    }
  }

  /// Scan accounts and generate password-expiry notifications.
  Future<List<AppNotification>> generatePasswordExpiryNotifications({
    required List<AccountItem> accounts,
    required List<AccountTemplate> templates,
    int expiryDays = 90,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final threshold = now - Duration(days: expiryDays).inMilliseconds;
    final existing = await _storage.loadNotifications();
    final existingAccountIds = existing
        .where((n) => n.type == AppNotificationType.passwordExpiry)
        .map((n) => n.accountId)
        .toSet();

    final created = <AppNotification>[];

    for (final account in accounts) {
      if (account.modifiedAt > threshold) continue;
      if (existingAccountIds.contains(account.id)) continue;

      final template = templates.where(
        (t) => t.templateId == account.templateId,
      ).firstOrNull;
      final hasPassword = template?.fields.any(
            (f) => f.attributes.type == AccountFieldType.password ||
                f.attributes.isSecret,
      ) ?? false;
      if (!hasPassword) continue;

      final daysSince = (now - account.modifiedAt) ~/ Duration.millisecondsPerDay;
      final notification = AppNotification(
        id: const Uuid().v4(),
        type: AppNotificationType.passwordExpiry,
        title: '密码过期提醒',
        body: '「${account.name}」的密码已 $daysSince 天未修改，建议尽快更新。',
        accountId: account.id,
        createdAt: now,
      );

      await _storage.saveNotification(notification);
      created.add(notification);
    }

    return created;
  }

  Future<List<AppNotification>> generateWeakPasswordNotifications({
    required List<AccountItem> accounts,
    required List<AccountTemplate> templates,
    int strengthThreshold = 40,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _storage.loadNotifications();
    final existingAccountIds = existing
        .where((n) => n.type == AppNotificationType.weakPassword)
        .map((n) => n.accountId)
        .toSet();

    final created = <AppNotification>[];

    for (final account in accounts) {
      if (existingAccountIds.contains(account.id)) continue;

      final template = templates.where(
        (t) => t.templateId == account.templateId,
      ).firstOrNull;
      if (template == null) continue;

      String? weakPasswordValue;
      for (final field in template.fields) {
        if (field.attributes.type == AccountFieldType.password ||
            field.attributes.isSecret) {
          final v = account.data[field.fieldKey]?.toString().trim();
          if (v != null && v.isNotEmpty) {
            final score = EnhancedCryptoService.calculatePasswordStrength(v);
            if (score < strengthThreshold) {
              weakPasswordValue = v;
              break;
            }
          }
        }
      }
      if (weakPasswordValue == null) continue;

      final score =
          EnhancedCryptoService.calculatePasswordStrength(weakPasswordValue);
      final level = EnhancedCryptoService.getPasswordStrengthLevel(score);
      final notification = AppNotification(
        id: const Uuid().v4(),
        type: AppNotificationType.weakPassword,
        title: '弱密码提醒',
        body: '「${account.name}」的密码强度为 $level（$score/100），建议尽快更新。',
        accountId: account.id,
        createdAt: now,
      );

      await _storage.saveNotification(notification);
      created.add(notification);
    }

    return created;
  }

  Future<void> scheduleDailyCheck({int hour = 9, int minute = 0}) async {
    if (!_initialized) await init();
    try {
      const android = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.defaultImportance,
      );
      const darwin = DarwinNotificationDetails();
      const details = NotificationDetails(android: android, iOS: darwin, macOS: darwin);

      await _plugin.zonedSchedule(
        0,
        '密码安全提醒',
        '请检查是否有长期未修改的密码',
        _nextInstanceOfTime(hour, minute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      AppLogger.d('Failed to schedule notification: $e');
    }
  }

  Future<void> cancelAllScheduled() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      AppLogger.d('Failed to cancel notifications: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
