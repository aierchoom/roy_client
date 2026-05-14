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
import '../../widgets/inbox/inbox_empty_state.dart';
import '../accounts/account_edit_view.dart';
import '../conflict_inbox_view.dart';
import '../settings/vault_health_view.dart';
import '../sync/local_sync_queue_view.dart';

enum _InboxItemType { sync, conflict, health, notification }

class _InboxItem {
  final String id;
  final _InboxItemType type;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isUnread;
  final DateTime? timestamp;

  const _InboxItem({
    required this.id,
    required this.type,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isUnread = false,
    this.timestamp,
  });

  bool get isAction => type != _InboxItemType.notification || isUnread;
}

class NotificationCenterView extends StatefulWidget {
  const NotificationCenterView({super.key});

  @override
  State<NotificationCenterView> createState() => _NotificationCenterViewState();
}

class _NotificationCenterViewState extends State<NotificationCenterView> {
  Future<VaultHealthReport>? _healthReportFuture;
  Future<List<AccountItem>>? _accountsFuture;

  @override
  void initState() {
    super.initState();
    _refreshHealthReport();
    _accountsFuture = ServiceManager.instance.storageService.loadAccounts();
  }

  void _refreshHealthReport() {
    final manager = ServiceManager.instance;
    final calculator = VaultHealthCalculator(
      storage: manager.storageService,
      identity: manager.identityService,
    );
    _healthReportFuture = calculator.calculate();
  }

  Future<void> _navigateToAccountEdit(AccountItem account) async {
    if (!mounted) return;
    await Navigator.push<AccountItem>(
      context,
      MaterialPageRoute(builder: (_) => AccountEditView(initial: account)),
    );
  }

  Future<void> _navigateToAccountEditById(String accountId) async {
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
    final appProvider = context.watch<EnhancedAppProvider>();

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _healthReportFuture ?? Future.value(null),
        _accountsFuture ?? Future.value(<AccountItem>[]),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final report = snapshot.data?[0] as VaultHealthReport?;
        final accounts = snapshot.data?[1] as List<AccountItem>? ?? <AccountItem>[];
        final items = _buildInboxItems(context, provider, appProvider, report, accounts);

        if (items.isEmpty) {
          return _buildEmptyState(context);
        }

        final groups = <String, List<_InboxItem>>{};
        for (final item in items) {
          final key = switch (item.type) {
            _InboxItemType.conflict => 'conflict',
            _InboxItemType.sync => 'sync',
            _InboxItemType.health => 'health',
            _InboxItemType.notification => 'notification',
          };
          groups.putIfAbsent(key, () => []).add(item);
        }

        final theme = Theme.of(context);

        return RefreshIndicator(
          onRefresh: () async => setState(() {
            _refreshHealthReport();
            _accountsFuture = ServiceManager.instance.storageService.loadAccounts();
          }),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              if (groups['conflict']?.isNotEmpty == true)
                _ExpandableSection(
                  title: context.text('冲突', 'Conflicts'),
                  count: groups['conflict']!.length,
                  items: groups['conflict']!,
                  leading: Icon(Icons.merge_type_outlined, size: 24, color: theme.colorScheme.error),
                ),
              if (groups['sync']?.isNotEmpty == true) ...[
                if (groups['conflict']?.isNotEmpty == true) const SizedBox(height: 16),
                _ExpandableSection(
                  title: context.text('待同步', 'Sync'),
                  count: groups['sync']!.length,
                  items: groups['sync']!,
                  leading: Icon(Icons.cloud_upload_outlined, size: 24, color: theme.colorScheme.primary),
                ),
              ],
              if (groups['health']?.isNotEmpty == true) ...[
                if (groups['conflict']?.isNotEmpty == true || groups['sync']?.isNotEmpty == true)
                  const SizedBox(height: 16),
                _ExpandableSection(
                  title: context.text('Vault 体检', 'Vault Health'),
                  count: groups['health']!.length,
                  items: groups['health']!,
                  leading: report != null ? _HealthStatusIcon(report: report) : null,
                ),
              ],
              if (groups['notification']?.isNotEmpty == true) ...[
                if (groups['conflict']?.isNotEmpty == true ||
                    groups['sync']?.isNotEmpty == true ||
                    groups['health']?.isNotEmpty == true)
                  const SizedBox(height: 16),
                _ExpandableSection(
                  title: context.text('通知', 'Notifications'),
                  count: groups['notification']!.length,
                  items: groups['notification']!,
                  leading: Icon(Icons.notifications_outlined, size: 24, color: theme.colorScheme.primary),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<_InboxItem> _buildInboxItems(
    BuildContext context,
    NotificationProvider provider,
    EnhancedAppProvider appProvider,
    VaultHealthReport? report,
    List<AccountItem> accounts,
  ) {
    final items = <_InboxItem>[];
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final errorColor = theme.colorScheme.error;
    final accountMap = {for (final a in accounts) a.id: a};

    // 1. Conflict
    final conflictCount = appProvider.conflictCount;
    if (conflictCount > 0) {
      items.add(_InboxItem(
        id: 'conflict',
        type: _InboxItemType.conflict,
        icon: Icons.merge_type_outlined,
        color: errorColor,
        title: context.text('发现 $conflictCount 个同步冲突', '$conflictCount sync conflict(s) detected'),
        subtitle: context.text('点击查看并手动解决冲突字段', 'Tap to review and resolve field conflicts'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConflictInboxView()),
          );
        },
      ));
    }

    // 2. Sync
    final changes = appProvider.localSyncChanges;
    if (changes.isNotEmpty) {
      items.add(_InboxItem(
        id: 'sync',
        type: _InboxItemType.sync,
        icon: Icons.cloud_upload_outlined,
        color: accent,
        title: context.text('待同步变更 ${changes.length} 项', '${changes.length} change(s) waiting to sync'),
        subtitle: context.text('点击查看并推送到其他设备', 'Tap to review and push to other devices'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LocalSyncQueueView()),
          );
        },
      ));
    }

    // 3. Health issues 扁平化
    if (report != null) {
      for (final item in report.failedItems) {
        final targetIds = item.action?.targetIds ?? [];
        final color = _riskToColor(item.riskLevel, theme);
        final icon = _riskToIcon(item.riskLevel);

        if (targetIds.isEmpty) {
          items.add(_InboxItem(
            id: item.id,
            type: _InboxItemType.health,
            icon: icon,
            color: color,
            title: item.title,
            subtitle: item.description,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VaultHealthView()),
              ).then((_) => setState(_refreshHealthReport));
            },
          ));
        } else {
          for (final accountId in targetIds) {
            final account = accountMap[accountId];
            final accountName = account?.name ?? context.text('未知账号', 'Unknown account');
            items.add(_InboxItem(
              id: '${item.id}_$accountId',
              type: _InboxItemType.health,
              icon: icon,
              color: color,
              title: accountName,
              subtitle: item.title,
              onTap: account != null
                  ? () => _navigateToAccountEdit(account)
                  : () => _navigateToAccountEditById(accountId),
            ));
          }
        }
      }
    }

    // 4. 普通通知（过滤体检已覆盖的）
    final weakIds = _extractTargetIds(report, 'weak_passwords');
    final staleIds = _extractTargetIds(report, 'stale_records');

    for (final n in provider.notifications) {
      if (n.type == AppNotificationType.weakPassword && weakIds.contains(n.accountId)) {
        continue;
      }
      if (n.type == AppNotificationType.passwordExpiry && staleIds.contains(n.accountId)) {
        continue;
      }

      final color = _notificationColor(n.type, theme);
      final icon = _notificationIcon(n.type);
      final isUnread = !n.isRead;

      items.add(_InboxItem(
        id: n.id,
        type: _InboxItemType.notification,
        icon: icon,
        color: color,
        title: n.localizedTitle(Localizations.localeOf(context).languageCode == 'zh'),
        subtitle: n.localizedBody(Localizations.localeOf(context).languageCode == 'zh'),
        onTap: () {
          if (isUnread) provider.markRead(n.id);
          if (n.accountId != null) {
            _navigateToAccountEditById(n.accountId!);
          }
        },
        isUnread: isUnread,
        timestamp: DateTime.fromMillisecondsSinceEpoch(n.createdAt),
      ));
    }

    // 5. 排序
    items.sort((a, b) {
      final pa = _itemPriority(a);
      final pb = _itemPriority(b);
      if (pa != pb) return pa.compareTo(pb);
      if (a.timestamp != null && b.timestamp != null) {
        return b.timestamp!.compareTo(a.timestamp!);
      }
      if (a.timestamp != null) return -1;
      if (b.timestamp != null) return 1;
      return 0;
    });

    // 去重（按 id）
    final seen = <String>{};
    return items.where((item) => seen.add(item.id)).toList();
  }

  static Set<String> _extractTargetIds(VaultHealthReport? report, String itemId) {
    if (report == null) return {};
    return report.failedItems
        .where((i) => i.id == itemId)
        .expand((i) => i.action?.targetIds ?? <String>[])
        .toSet();
  }

  static int _itemPriority(_InboxItem item) {
    return switch (item.type) {
      _InboxItemType.conflict => 1,
      _InboxItemType.sync => 2,
      _InboxItemType.notification when item.isUnread => 3,
      _InboxItemType.health => 4,
      _InboxItemType.notification => 5,
    };
  }

  static Color _riskToColor(VaultHealthRiskLevel level, ThemeData theme) {
    final vt = theme.extension<AppVisualTokens>()!;
    return switch (level) {
      VaultHealthRiskLevel.high => theme.colorScheme.error,
      VaultHealthRiskLevel.medium => vt.warning,
      VaultHealthRiskLevel.low => theme.colorScheme.primary,
    };
  }

  static IconData _riskToIcon(VaultHealthRiskLevel level) {
    return switch (level) {
      VaultHealthRiskLevel.high => Icons.error_outline,
      VaultHealthRiskLevel.medium => Icons.warning_amber_rounded,
      VaultHealthRiskLevel.low => Icons.info_outline,
    };
  }

  static Color _notificationColor(AppNotificationType type, ThemeData theme) {
    final vt = theme.extension<AppVisualTokens>()!;
    return switch (type) {
      AppNotificationType.passwordExpiry => theme.colorScheme.error,
      AppNotificationType.weakPassword => vt.warning,
    };
  }

  static IconData _notificationIcon(AppNotificationType type) {
    return switch (type) {
      AppNotificationType.passwordExpiry => Icons.lock_clock_outlined,
      AppNotificationType.weakPassword => Icons.shield_outlined,
    };
  }

  Widget _buildEmptyState(BuildContext context) {
    return InboxEmptyState(
      icon: Icons.notifications_none_rounded,
      title: context.text('暂无通知', 'No notifications'),
      subtitle: context.text('安全提醒与待处理变更会在这里显示', 'Security alerts and pending changes will appear here'),
    );
  }
}

class _HealthStatusIcon extends StatelessWidget {
  final VaultHealthReport report;

  const _HealthStatusIcon({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _gradeColor(report.grade, theme.brightness);

    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: report.score / 100,
            strokeWidth: 3,
            backgroundColor: theme.colorScheme.outlineVariant.withAlpha(60),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            '${report.score}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static Color _gradeColor(VaultHealthGrade grade, Brightness brightness) {
    final vt = AppVisualTokens.fromBrightness(brightness);
    return switch (grade) {
      VaultHealthGrade.excellent => vt.success,
      VaultHealthGrade.good => vt.success,
      VaultHealthGrade.warning => vt.warning,
      VaultHealthGrade.critical => vt.warning,
    };
  }
}

class _ExpandableSection extends StatefulWidget {
  final String title;
  final int count;
  final List<_InboxItem> items;
  final Widget? leading;

  const _ExpandableSection({
    required this.title,
    required this.count,
    required this.items,
    this.leading,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(AppAlphas.subtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(AppRadii.panel),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(AppRadii.panel),
                ),
              ),
              child: Row(
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: 10),
                  ],
                  Text(
                    widget.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: widget.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _InboxCard(item: item),
                )).toList(),
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _InboxCard extends StatelessWidget {
  final _InboxItem item;

  const _InboxCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAction = item.isAction;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(
              color: isAction
                  ? item.color.withAlpha(AppAlphas.low)
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
                  color: item.color.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                alignment: Alignment.center,
                child: Icon(item.icon, size: 20, color: item.color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.isUnread) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: item.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    if (item.timestamp != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _timeAgo(context, item.timestamp!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(BuildContext context, DateTime timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestamp.millisecondsSinceEpoch;
    final days = diff ~/ Duration.millisecondsPerDay;
    if (days > 0) return context.text('$days 天前', '$days day(s) ago');
    final hours = diff ~/ Duration.millisecondsPerHour;
    if (hours > 0) return context.text('$hours 小时前', '$hours hour(s) ago');
    return context.text('刚刚', 'Just now');
  }
}
