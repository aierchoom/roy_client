import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/app_notification.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_design_tokens.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/app_page_header.dart';
import '../conflict_inbox_view.dart';
import '../sync/local_sync_queue_view.dart';

class NotificationCenterView extends StatelessWidget {
  const NotificationCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final appProvider = context.watch<EnhancedAppProvider>();
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final hasSyncChanges = appProvider.localSyncChanges.isNotEmpty;
    final hasConflicts = appProvider.conflictCount > 0;
    final hasAlerts = hasSyncChanges || hasConflicts;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.text('通知中心', 'Notifications')),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () => provider.markAllRead(),
              child: Text(
                context.text('全部已读', 'Mark all read'),
                style: TextStyle(color: accent),
              ),
            ),
        ],
      ),
      body: AdaptivePage(
        desktopMaxWidth: 860,
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.notifications.isEmpty && !hasAlerts
                ? _buildEmptyState(context)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      _buildHeroCard(context, provider, appProvider),
                      const SizedBox(height: 16),
                      if (hasConflicts) ...[
                        _buildConflictCard(context, appProvider),
                        const SizedBox(height: 10),
                      ],
                      if (hasSyncChanges) ...[
                        _buildSyncCard(context, appProvider),
                        const SizedBox(height: 10),
                      ],
                      ...provider.notifications.map(
                        (n) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _NotificationCard(
                            notification: n,
                            onMarkRead: () => provider.markRead(n.id),
                            onDelete: () => provider.deleteNotification(n.id),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, NotificationProvider provider, EnhancedAppProvider appProvider) {
    final accent = Theme.of(context).colorScheme.primary;
    final syncCount = appProvider.localSyncChanges.length;
    final conflictCount = appProvider.conflictCount;

    return AppPageHeader(
      icon: Icons.notifications_outlined,
      title: context.text('通知中心', 'Notifications'),
      subtitle: context.text('安全提醒与待处理变更', 'Security alerts and pending changes'),
      metrics: [
        _buildMetricChip(context, '${provider.notifications.length + syncCount + conflictCount}', context.text('条通知', 'Items'), accent),
        _buildMetricChip(context, '${provider.unreadCount}', context.text('未读', 'Unread'), accent),
        if (conflictCount > 0)
          _buildMetricChip(context, '$conflictCount', context.text('冲突', 'Conflicts'), accent),
        if (syncCount > 0)
          _buildMetricChip(context, '$syncCount', context.text('待同步', 'Sync'), accent),
      ],
    );
  }

  Widget _buildMetricChip(BuildContext context, String value, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withAlpha(AppAlphas.tint),
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: accent, fontSize: 14)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: accent.withAlpha(190), fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildConflictCard(BuildContext context, EnhancedAppProvider appProvider) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    final count = appProvider.conflictCount;

    return Material(
      color: theme.colorScheme.errorContainer.withAlpha(60),
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConflictInboxView()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(color: errorColor.withAlpha(AppAlphas.low)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: errorColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.merge_type_outlined, size: 20, color: errorColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.text('发现 $count 个同步冲突', '$count sync conflict(s) detected'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.text('点击查看并手动解决冲突字段', 'Tap to review and resolve field conflicts'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncCard(BuildContext context, EnhancedAppProvider appProvider) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final changes = appProvider.localSyncChanges;

    return Material(
      color: theme.colorScheme.primaryContainer.withAlpha(60),
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LocalSyncQueueView()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(color: accent.withAlpha(AppAlphas.low)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.cloud_upload_outlined, size: 20, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.text('待同步变更 ${changes.length} 项', '${changes.length} change(s) waiting to sync'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.text('点击查看并推送到其他设备', 'Tap to review and push to other devices'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 64, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            context.text('暂无通知', 'No notifications'),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            context.text('安全提醒与待处理变更会在这里显示', 'Security alerts and pending changes will appear here'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notification,
    required this.onMarkRead,
    required this.onDelete,
  });

  IconData _typeIcon() {
    switch (notification.type) {
      case AppNotificationType.passwordExpiry:
        return Icons.lock_clock_outlined;
    }
  }

  Color _typeColor(ThemeData theme) {
    switch (notification.type) {
      case AppNotificationType.passwordExpiry:
        return theme.colorScheme.error;
    }
  }

  String _timeAgo(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - notification.createdAt;
    final days = diff ~/ Duration.millisecondsPerDay;
    if (days > 0) return context.text('$days 天前', '$days day(s) ago');
    final hours = diff ~/ Duration.millisecondsPerHour;
    if (hours > 0) return context.text('$hours 小时前', '$hours hour(s) ago');
    return context.text('刚刚', 'Just now');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColor(theme);
    final isUnread = !notification.isRead;

    return Material(
      color: isUnread
          ? color.withAlpha(8)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: InkWell(
        onTap: isUnread ? onMarkRead : null,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(
              color: isUnread
                  ? color.withAlpha(AppAlphas.low)
                  : theme.colorScheme.outlineVariant.withAlpha(AppAlphas.subtle),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(_typeIcon(), size: 20, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isUnread) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(context),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(AppAlphas.medium),
                ),
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
