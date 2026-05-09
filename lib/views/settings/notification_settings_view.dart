import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_text_extension.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_design_tokens.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_settings_group.dart';
import '../../widgets/app_settings_tile.dart';

class NotificationSettingsView extends StatelessWidget {
  const NotificationSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.text('通知设置', 'Notification Settings')),
      ),
      body: AdaptivePage(
        desktopMaxWidth: 860,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            AppPageHeader(
              icon: Icons.notifications_outlined,
              title: context.text('通知设置', 'Notification Settings'),
              subtitle: context.text('密码过期提醒阈值与推送', 'Password expiry threshold & push'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSettingsGroup(
              children: [
                AppSettingsTile(
                  icon: Icons.timer_outlined,
                  title: context.text('密码过期提醒天数', 'Password Expiry Days'),
                  subtitle: context.text('超过此天数未修改密码时发送提醒', 'Remind when password hasn\'t changed for this many days'),
                  onTap: () => _showExpiryDaysPicker(context, provider),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withAlpha(100),
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                    child: Text(
                      '${provider.expiryDays} ${context.text('天', 'days')}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                AppSettingsTile(
                  icon: Icons.push_pin_outlined,
                  title: context.text('推送通知', 'Push Notifications'),
                  subtitle: context.text('每日定时检查并发送系统推送', 'Daily check with system push'),
                  onTap: () => _togglePush(context, provider),
                  trailing: Switch(
                    value: provider.pushEnabled,
                    onChanged: (v) => _togglePush(context, provider),
                  ),
                  showChevron: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExpiryDaysPicker(BuildContext context, NotificationProvider provider) {
    const options = [30, 60, 90, 180, 365];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                context.text('选择提醒天数', 'Select reminder days'),
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            ...options.map((days) => ListTile(
              title: Text('$days ${context.text('天', 'days')}'),
              trailing: provider.expiryDays == days
                  ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                  : null,
              onTap: () {
                provider.updateExpiryDays(days);
                Navigator.of(ctx).pop();
              },
            )),
          ],
        ),
      ),
    );
  }

  void _togglePush(BuildContext context, NotificationProvider provider) {
    if (provider.pushEnabled) {
      provider.cancelDailyReminder();
    } else {
      provider.scheduleDailyReminder();
    }
  }
}
