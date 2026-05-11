import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/account_item.dart';
import '../../models/app_notification.dart';
import '../../models/vault_health_report.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/service_manager.dart';
import '../../services/vault_health_calculator.dart';
import '../../theme/app_design_tokens.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/inbox/inbox_action_card.dart';
import '../../widgets/inbox/inbox_empty_state.dart';
import '../../widgets/inbox/inbox_filter_bar.dart';
import '../../widgets/inbox/inbox_hero_metrics.dart';
import '../../widgets/inbox/inbox_models.dart';
import '../accounts/account_edit_view.dart';
import '../accounts/account_subset_view.dart';
import '../conflict_inbox_view.dart';
import '../settings/vault_health_view.dart';
import '../sync/local_sync_queue_view.dart';

enum _NotificationCategory { all, health, sync, conflict, notification }

class NotificationCenterView extends StatefulWidget {
  const NotificationCenterView({super.key});

  @override
  State<NotificationCenterView> createState() => _NotificationCenterViewState();
}

class _NotificationCenterViewState extends State<NotificationCenterView> {
  _NotificationCategory _selectedCategory = _NotificationCategory.all;
  Future<VaultHealthReport>? _healthReportFuture;

  @override
  void initState() {
    super.initState();
    _refreshHealthReport();
  }

  void _refreshHealthReport() {
    final manager = ServiceManager.instance;
    final calculator = VaultHealthCalculator(
      storage: manager.storageService,
      identity: manager.identityService,
    );
    _healthReportFuture = calculator.calculate();
  }

  Future<void> _navigateToAccountEdit(String accountId) async {
    final storage = ServiceManager.instance.storageService;
    final account = await storage.getAccountById(accountId);
    if (!mounted) return;
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.text('账号不存在或已被删除', 'Account not found or deleted')),
        ),
      );
      return;
    }
    await Navigator.push<AccountItem>(
      context,
      MaterialPageRoute(builder: (_) => AccountEditView(initial: account)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final accent = Theme.of(context).colorScheme.primary;

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
            : _buildBody(context, provider),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationProvider provider) {
    final appProvider = context.read<EnhancedAppProvider>();
    final hasSyncChanges = appProvider.localSyncChanges.isNotEmpty;
    final hasConflicts = appProvider.conflictCount > 0;
    final notifications = provider.notifications;

    final hasAnyContent = notifications.isNotEmpty ||
        hasSyncChanges ||
        hasConflicts ||
        _selectedCategory == _NotificationCategory.health ||
        _selectedCategory == _NotificationCategory.all;

    if (!hasAnyContent) {
      return _buildEmptyState(context);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _buildHero(context, provider, appProvider),
        const SizedBox(height: 12),
        InboxFilterBar<_NotificationCategory>(
          categories: const [
            (_NotificationCategory.all, '全部', 'All'),
            (_NotificationCategory.health, '体检', 'Health'),
            (_NotificationCategory.sync, '同步', 'Sync'),
            (_NotificationCategory.conflict, '冲突', 'Conflicts'),
            (_NotificationCategory.notification, '通知', 'Notifications'),
          ],
          selected: _selectedCategory,
          onSelected: (cat) => setState(() => _selectedCategory = cat),
        ),
        const SizedBox(height: 16),
        if (_showCategory(_NotificationCategory.health)) ...[
          _buildHealthSection(context),
          const SizedBox(height: 10),
        ],
        if (_showCategory(_NotificationCategory.conflict) && hasConflicts) ...[
          _buildConflictCard(context, appProvider),
          const SizedBox(height: 10),
        ],
        if (_showCategory(_NotificationCategory.sync) && hasSyncChanges) ...[
          _buildSyncCard(context, appProvider),
          const SizedBox(height: 10),
        ],
        if (_showCategory(_NotificationCategory.notification)) ...[
          ...notifications.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NotificationCard(
                notification: n,
                onMarkRead: () => provider.markRead(n.id),
                onDelete: () => provider.deleteNotification(n.id),
                onNavigateToAccount: n.accountId != null
                    ? () => _navigateToAccountEdit(n.accountId!)
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _showCategory(_NotificationCategory category) {
    return _selectedCategory == _NotificationCategory.all ||
        _selectedCategory == category;
  }

  Widget _buildHero(
    BuildContext context,
    NotificationProvider provider,
    EnhancedAppProvider appProvider,
  ) {
    final accent = Theme.of(context).colorScheme.primary;
    final vt = Theme.of(context).extension<AppVisualTokens>()!;
    final syncCount = appProvider.localSyncChanges.length;
    final conflictCount = appProvider.conflictCount;

    return FutureBuilder<VaultHealthReport>(
      future: _healthReportFuture,
      builder: (context, snapshot) {
        final report = snapshot.data;
        final healthIssues = report?.failedItems.length ?? 0;
        final totalItems = provider.notifications.length +
            syncCount +
            conflictCount +
            healthIssues;

        final metrics = <MetricData>[
          MetricData(value: '$totalItems', label: context.text('条通知', 'Items'), color: accent),
          MetricData(value: '${provider.unreadCount}', label: context.text('未读', 'Unread'), color: accent),
        ];
        if (healthIssues > 0) {
          metrics.add(MetricData(value: '$healthIssues', label: context.text('体检', 'Health'), color: vt.warning));
        }
        if (conflictCount > 0) {
          metrics.add(MetricData(value: '$conflictCount', label: context.text('冲突', 'Conflicts'), color: vt.warning));
        }
        if (syncCount > 0) {
          metrics.add(MetricData(value: '$syncCount', label: context.text('待同步', 'Sync'), color: accent));
        }

        return InboxHeroMetrics(
          icon: Icons.notifications_outlined,
          title: context.text('通知中心', 'Notifications'),
          subtitle: context.text('安全提醒与待处理变更', 'Security alerts and pending changes'),
          metrics: metrics,
        );
      },
    );
  }

  Widget _buildHealthSection(BuildContext context) {
    return FutureBuilder<VaultHealthReport>(
      future: _healthReportFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final report = snapshot.data;
        if (report == null) return const SizedBox.shrink();

        final failed = report.failedItems;
        final color = _gradeColor(report.grade);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHealthSummaryCard(context, report, color),
            if (failed.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...failed.map((item) => _buildHealthIssueCard(context, item)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHealthSummaryCard(
    BuildContext context,
    VaultHealthReport report,
    Color color,
  ) {
    final theme = Theme.of(context);
    final failedCount = report.failedItems.length;

    return ActionSummaryCard(
      iconColor: color,
      title: context.text('Vault 体检', 'Vault Health'),
      subtitle: failedCount == 0
          ? context.text('状态良好', 'All good')
          : context.text('发现 $failedCount 项问题', '$failedCount issue(s) found'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VaultHealthView()),
        ).then((_) => setState(_refreshHealthReport));
      },
      leading: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: report.score / 100,
              strokeWidth: 4,
              backgroundColor: theme.colorScheme.outlineVariant.withAlpha(60),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            Text(
              '${report.score}',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIssueCard(BuildContext context, VaultHealthItem item) {
    final targetIds = item.action?.targetIds ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ActionItemCard(
        severity: _riskToSeverity(item.riskLevel),
        title: item.title,
        subtitle: item.description,
        showChevron: targetIds.isNotEmpty,
        onTap: targetIds.isNotEmpty
            ? () async {
                if (targetIds.length == 1) {
                  await _navigateToAccountEdit(targetIds.first);
                } else {
                  final highlightFieldKey = switch (item.id) {
                    'weak_passwords' || 'reused_passwords' => 'password',
                    'incomplete_records' => 'url',
                    _ => null,
                  };
                  final groupByFieldKey = switch (item.id) {
                    'reused_passwords' => 'password',
                    _ => null,
                  };
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountSubsetView(
                        title: item.title,
                        subtitle: item.description,
                        accountIds: targetIds,
                        highlightFieldKey: highlightFieldKey,
                        groupByFieldKey: groupByFieldKey,
                      ),
                    ),
                  );
                }
              }
            : null,
      ),
    );
  }

  Widget _buildConflictCard(BuildContext context, EnhancedAppProvider appProvider) {
    final errorColor = Theme.of(context).colorScheme.error;
    final count = appProvider.conflictCount;

    return ActionSummaryCard(
      icon: Icons.merge_type_outlined,
      iconColor: errorColor,
      backgroundColor: Theme.of(context).colorScheme.errorContainer.withAlpha(60),
      title: context.text('发现 $count 个同步冲突', '$count sync conflict(s) detected'),
      subtitle: context.text('点击查看并手动解决冲突字段', 'Tap to review and resolve field conflicts'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConflictInboxView()),
        );
      },
    );
  }

  Widget _buildSyncCard(BuildContext context, EnhancedAppProvider appProvider) {
    final accent = Theme.of(context).colorScheme.primary;
    final changes = appProvider.localSyncChanges;

    return ActionSummaryCard(
      icon: Icons.cloud_upload_outlined,
      iconColor: accent,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(60),
      title: context.text('待同步变更 ${changes.length} 项', '${changes.length} change(s) waiting to sync'),
      subtitle: context.text('点击查看并推送到其他设备', 'Tap to review and push to other devices'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LocalSyncQueueView()),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return InboxEmptyState(
      icon: Icons.notifications_none_rounded,
      title: context.text('暂无通知', 'No notifications'),
      subtitle: context.text('安全提醒与待处理变更会在这里显示', 'Security alerts and pending changes will appear here'),
    );
  }

  static Color _gradeColor(VaultHealthGrade grade) {
    final vt = AppVisualTokens.fromBrightness(WidgetsBinding.instance.platformDispatcher.platformBrightness);
    return switch (grade) {
      VaultHealthGrade.excellent => vt.success,
      VaultHealthGrade.good => vt.success,
      VaultHealthGrade.warning => vt.warning,
      VaultHealthGrade.critical => vt.warning,
    };
  }

  static InboxSeverity _riskToSeverity(VaultHealthRiskLevel level) {
    return switch (level) {
      VaultHealthRiskLevel.high => InboxSeverity.critical,
      VaultHealthRiskLevel.medium => InboxSeverity.warning,
      VaultHealthRiskLevel.low => InboxSeverity.info,
    };
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;
  final VoidCallback? onNavigateToAccount;

  const _NotificationCard({
    required this.notification,
    required this.onMarkRead,
    required this.onDelete,
    this.onNavigateToAccount,
  });

  IconData _typeIcon() {
    switch (notification.type) {
      case AppNotificationType.passwordExpiry:
        return Icons.lock_clock_outlined;
      case AppNotificationType.weakPassword:
        return Icons.shield_outlined;
    }
  }

  Color _typeColor(ThemeData theme) {
    switch (notification.type) {
      case AppNotificationType.passwordExpiry:
        return theme.colorScheme.error;
      case AppNotificationType.weakPassword:
        return AppVisualTokens.fromBrightness(theme.brightness).warning;
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
      color: isUnread ? color.withAlpha(8) : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: InkWell(
        onTap: () {
          if (isUnread) onMarkRead();
          if (onNavigateToAccount != null) onNavigateToAccount!();
        },
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
                  borderRadius: BorderRadius.circular(AppRadii.card),
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
