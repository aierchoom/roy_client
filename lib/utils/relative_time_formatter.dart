import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

class RelativeTimeFormatter {
  static String format(BuildContext context, int? millisecondsSinceEpoch) {
    if (millisecondsSinceEpoch == null) return '';

    final dt = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
    final now = DateTime.now();
    final diff = now.difference(dt);
    final l10n = AppLocalizations.of(context)!;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

    if (diff.inMinutes < 1) {
      return l10n.justNow;
    }
    if (diff.inHours < 1) {
      return l10n.minutesAgo(diff.inMinutes);
    }
    if (_isSameDay(now, dt)) {
      final time = DateFormat.Hm().format(dt);
      return l10n.today(time);
    }
    if (_isYesterday(now, dt)) {
      final time = DateFormat.Hm().format(dt);
      return l10n.yesterday(time);
    }
    if (diff.inDays < 7) {
      final weekday = isZh ? _zhWeekday(dt.weekday) : DateFormat.E().format(dt);
      final time = DateFormat.Hm().format(dt);
      return '$weekday $time';
    }
    if (now.year == dt.year) {
      return isZh
          ? DateFormat('M月d日 HH:mm').format(dt)
          : DateFormat('MMM d HH:mm').format(dt);
    }
    return isZh
        ? DateFormat('yyyy年M月d日').format(dt)
        : DateFormat('MMM d, yyyy').format(dt);
  }

  static String formatAbsolute(BuildContext context, int? millisecondsSinceEpoch) {
    if (millisecondsSinceEpoch == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return isZh
        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(dt)
        : DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _isYesterday(DateTime now, DateTime dt) {
    final yesterday = now.subtract(const Duration(days: 1));
    return yesterday.year == dt.year && yesterday.month == dt.month && yesterday.day == dt.day;
  }

  static String _zhWeekday(int weekday) {
    const names = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[weekday];
  }
}
