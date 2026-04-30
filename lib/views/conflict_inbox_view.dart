import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account_item.dart';
import '../providers/enhanced_app_provider.dart';
import '../services/service_manager.dart';
import '../sync/crdt_merge_engine.dart';

class ConflictInboxView extends StatefulWidget {
  const ConflictInboxView({super.key});

  @override
  State<ConflictInboxView> createState() => _ConflictInboxViewState();
}

class _ConflictInboxViewState extends State<ConflictInboxView> {
  List<_ConflictGroup> _groups = [];
  bool _isLoading = true;

  String _t(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final storage = ServiceManager.instance.storageService;
    final appProvider = context.read<EnhancedAppProvider>();
    final allAccounts = appProvider.allAccounts;

    final groups = <_ConflictGroup>[];
    for (final account in allAccounts) {
      final logs = await storage.getConflictLogs(account.id);
      if (logs.isNotEmpty) {
        groups.add(_ConflictGroup(account: account, logs: logs));
      }
    }

    if (!mounted) return;
    setState(() {
      _groups = groups;
      _isLoading = false;
    });
  }

  Future<void> _dismissLog(String logId) async {
    await ServiceManager.instance.storageService.deleteConflictLog(logId);
    await _load();
  }

  Future<void> _acceptLog(AccountItem account, ConflictLog log) async {
    final storage = ServiceManager.instance.storageService;
    final fieldKey = log.fieldKey;

    late final AccountItem updated;
    if (fieldKey == 'record.remote_missing') {
      updated = account.copyWith(
        syncStatus: SyncStatus.pendingPush,
        serverVersion: 0,
      );
    } else if (fieldKey == 'name') {
      updated = account.copyWith(
        name: log.fieldValue,
        syncStatus: SyncStatus.pendingPush,
      );
    } else if (fieldKey == 'email') {
      updated = account.copyWith(
        email: log.fieldValue,
        syncStatus: SyncStatus.pendingPush,
      );
    } else if (fieldKey.startsWith('data.')) {
      final dataKey = fieldKey.substring(5);
      final newData = Map<String, String>.from(account.data);
      newData[dataKey] = log.fieldValue;
      updated = account.copyWith(
        data: newData,
        syncStatus: SyncStatus.pendingPush,
      );
    } else {
      return;
    }

    await storage.saveAccount(updated);
    await storage.deleteConflictLog(log.id);

    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final message = fieldKey == 'record.remote_missing'
          ? _t(
              '已保留本地版本，并准备覆盖远端缺失记录',
              'Local version kept and queued to overwrite the missing remote record',
            )
          : _t('已恢复该版本并准备推送', 'Value restored and queued for push');
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar.large(
                  title: Text(_t('冲突收件箱', 'Conflict Inbox')),
                  actions: [
                    if (_groups.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.refresh_outlined),
                        tooltip: _t('刷新', 'Refresh'),
                        onPressed: _load,
                      ),
                  ],
                ),
                if (_groups.isEmpty)
                  SliverFillRemaining(
                    child: _EmptyState(text: _t('没有冲突记录', 'No conflicts')),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ConflictGroupCard(
                        group: _groups[index],
                        onDismiss: _dismissLog,
                        onAccept: (log) =>
                            _acceptLog(_groups[index].account, log),
                        textBuilder: _t,
                      ),
                      childCount: _groups.length,
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
              ],
            ),
    );
  }
}

class _ConflictGroup {
  final AccountItem account;
  final List<ConflictLog> logs;

  const _ConflictGroup({required this.account, required this.logs});
}

class _ConflictGroupCard extends StatelessWidget {
  final _ConflictGroup group;
  final void Function(String logId) onDismiss;
  final void Function(ConflictLog log) onAccept;
  final String Function(String zh, String en) textBuilder;

  const _ConflictGroupCard({
    required this.group,
    required this.onDismiss,
    required this.onAccept,
    required this.textBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withAlpha(60),
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(80),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withAlpha(24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.merge_type_outlined,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.account.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${group.logs.length} ${textBuilder('个冲突项', 'conflict item(s)')}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ...group.logs.map(
              (log) => _ConflictLogRow(
                log: log,
                account: group.account,
                onDismiss: () => onDismiss(log.id),
                onAccept: () => onAccept(log),
                textBuilder: textBuilder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictLogRow extends StatelessWidget {
  final ConflictLog log;
  final AccountItem account;
  final VoidCallback onDismiss;
  final VoidCallback onAccept;
  final String Function(String zh, String en) textBuilder;

  const _ConflictLogRow({
    required this.log,
    required this.account,
    required this.onDismiss,
    required this.onAccept,
    required this.textBuilder,
  });

  bool get _isRemoteMissingConflict => log.fieldKey == 'record.remote_missing';

  String get _conflictTypeLabel {
    if (_isRemoteMissingConflict) {
      return textBuilder('远端缺失', 'Remote missing');
    }
    return textBuilder('字段并发修改', 'Concurrent field edit');
  }

  String get _suggestionLabel {
    if (_isRemoteMissingConflict) {
      return textBuilder(
        '检查后可选择覆盖远端',
        'Review, then optionally overwrite remote',
      );
    }
    return textBuilder(
      '检查后选择保留当前值或恢复被覆盖值',
      'Review, then keep current or restore overwritten value',
    );
  }

  String get _fieldLabel {
    if (_isRemoteMissingConflict) {
      return textBuilder('远端记录缺失', 'Remote Record Missing');
    }
    if (log.fieldKey == 'name') return textBuilder('名称', 'Name');
    if (log.fieldKey == 'email') return textBuilder('邮箱', 'Email');
    if (log.fieldKey.startsWith('data.')) return log.fieldKey.substring(5);
    return log.fieldKey;
  }

  String _getCurrentValue() {
    if (_isRemoteMissingConflict) {
      final values = <String>[
        if (account.name.isNotEmpty)
          '${textBuilder('名称', 'Name')}: ${account.name}',
        if (account.email.isNotEmpty)
          '${textBuilder('邮箱', 'Email')}: ${account.email}',
        ...account.data.entries.map((entry) => '${entry.key}: ${entry.value}'),
      ];
      return values.isEmpty
          ? textBuilder('本地记录为空', 'Local record is empty')
          : values.join('\n');
    }

    if (log.fieldKey == 'name') return account.name;
    if (log.fieldKey == 'email') return account.email;
    if (log.fieldKey.startsWith('data.')) {
      return account.data[log.fieldKey.substring(5)] ?? '';
    }
    return '';
  }

  String _getConflictValue() {
    if (_isRemoteMissingConflict) {
      return textBuilder(
        '远端当前不存在这条记录',
        'This record does not exist on the remote side',
      );
    }
    return log.fieldValue;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final winnerValue = _getCurrentValue();
    final loserValue = _getConflictValue();
    final isSameValue = !_isRemoteMissingConflict && winnerValue == loserValue;

    if (isSameValue) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _fieldLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(log.savedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${textBuilder('类型', 'Type')}: $_conflictTypeLabel · '
                '${textBuilder('来源', 'Source')}: ${log.hlc.nodeId} · '
                '${textBuilder('建议', 'Suggested')}: $_suggestionLabel',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _ValueChip(
                label: _isRemoteMissingConflict
                    ? textBuilder('本地保留版本', 'Local Version')
                    : textBuilder('当前值（采纳方）', 'Current (Winner)'),
                value: winnerValue,
                color: theme.colorScheme.primary,
                bgColor: theme.colorScheme.primaryContainer.withAlpha(60),
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 8),
              _ValueChip(
                label: _isRemoteMissingConflict
                    ? textBuilder('远端状态', 'Remote State')
                    : textBuilder('被覆盖值（冲突方）', 'Overwritten (Conflict)'),
                value: loserValue,
                color: theme.colorScheme.error,
                bgColor: theme.colorScheme.errorContainer.withAlpha(60),
                icon: Icons.cancel_outlined,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: Text(
                        textBuilder('忽略', 'Dismiss'),
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: onDismiss,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(
                        _isRemoteMissingConflict ? Icons.upload : Icons.undo,
                        size: 16,
                      ),
                      label: Text(
                        _isRemoteMissingConflict
                            ? textBuilder('覆盖远端', 'Overwrite Remote')
                            : textBuilder('使用此值', 'Use This'),
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: onAccept,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ],
    );
  }

  String _formatTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ValueChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _ValueChip({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            value.isEmpty
                ? textBuilderFallback(context, '（空）', '(empty)')
                : value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String textBuilderFallback(BuildContext context, String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: theme.colorScheme.primary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
