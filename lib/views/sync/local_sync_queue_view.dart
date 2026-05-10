import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/local_sync_change.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../sync/sync_service.dart';
import '../../theme/app_design_tokens.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/inbox/inbox_empty_state.dart';

class LocalSyncQueueView extends StatelessWidget {
  const LocalSyncQueueView({super.key});

  Future<void> _pushChange(BuildContext context, LocalSyncChange change) async {
    final provider = context.read<EnhancedAppProvider>();
    final result = await provider.pushLocalSyncChange(change.id);
    if (!context.mounted) return;
    _showResultSnack(context, result);
  }

  Future<void> _pushAll(BuildContext context) async {
    final provider = context.read<EnhancedAppProvider>();
    final result = await provider.pushAllLocalSyncChanges();
    if (!context.mounted) return;
    _showResultSnack(context, result);
  }

  Future<void> _discardChange(
    BuildContext context,
    LocalSyncChange change,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.text( '撤销本地变更', 'Discard Local Change')),
          content: Text(
            context.text('将把"${change.title}"恢复到本次变更前的状态，此变更不会推送到其他设备。',
              'This restores "${change.title}" to its previous local state and will not push it to other devices.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.text( '取消', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.text( '撤销', 'Discard')),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<EnhancedAppProvider>();
      await provider.discardLocalSyncChange(change.id);
    }
  }

  void _showResultSnack(BuildContext context, SyncResult result) {
    final message = result.success
        ? context.text( '已推送已确认的本地变更。', 'Approved local changes pushed.')
        : context.text('同步失败：${result.error}',
            'Sync failed: ${result.error}',
          );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showDetails(BuildContext context, LocalSyncChange change) {
    final fields = _changeFields(context, change);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${_actionLabel(context, change.action)} · ${_entityLabel(context, change.entityType)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: fields
                      .map(
                        (f) => Chip(
                          label: Text(f),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                if (change.isDelete) ...[
                  const SizedBox(height: 14),
                  Text(
                    context.text('这是删除类变更。推送后，其他可信设备会直接同步该删除，除非存在本地冲突。',
                      'This is a delete change. Once pushed, other trusted devices will apply it unless they have local conflicts.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _discardChange(context, change);
                        },
                        child: Text(context.text( '撤销', 'Discard')),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _pushChange(context, change);
                        },
                        child: Text(context.text( '推送', 'Push')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _actionLabel(BuildContext context, LocalSyncAction action) {
    return switch (action) {
      LocalSyncAction.create => context.text( '新增', 'Create'),
      LocalSyncAction.update => context.text( '修改', 'Update'),
      LocalSyncAction.delete => context.text( '删除', 'Delete'),
    };
  }

  String _entityLabel(BuildContext context, LocalSyncEntityType type) {
    return switch (type) {
      LocalSyncEntityType.account => context.text( '账号', 'Account'),
      LocalSyncEntityType.template => context.text( '模板', 'Template'),
      LocalSyncEntityType.totpCredential => context.text( '2FA', '2FA'),
    };
  }

  List<String> _changeFields(BuildContext context, LocalSyncChange change) {
    if (change.changedFields.isEmpty) {
      return [context.text( '记录内容', 'Record content')];
    }
    return change.changedFields
        .map((field) {
          return switch (field) {
            'record.created' => context.text( '新建记录', 'New record'),
            'record.deleted' => context.text( '删除记录', 'Deleted record'),
            'record.updated' => context.text( '记录内容', 'Record content'),
            'name' => context.text( '名称', 'Name'),
            'email' => context.text( '邮箱', 'Email'),
            'template' || 'templateId' => context.text( '模板', 'Template'),
            _ when field.startsWith('data.') => field.substring(5),
            _ => field,
          };
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EnhancedAppProvider>();
    final changes = provider.localSyncChanges;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.text( '待同步变更', 'Pending Sync Changes')),
        actions: [
          if (changes.isNotEmpty)
            TextButton.icon(
              onPressed: () => _pushAll(context),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(context.text( '推送全部', 'Push All')),
            ),
        ],
      ),
      body: AdaptivePage(
        child: changes.isEmpty
            ? InboxEmptyState(
                icon: Icons.cloud_done_outlined,
                title: context.text('没有待同步的变更', 'No pending sync changes'),
                subtitle: context.text('所有本地变更已同步', 'All local changes have been synced'),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: changes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final change = changes[index];
                  return _ChangeCard(
                    change: change,
                    actionLabel: _actionLabel(context, change.action),
                    entityLabel: _entityLabel(context, change.entityType),
                    fields: _changeFields(context, change),
                    onTap: () => _showDetails(context, change),
                    onPush: () => _pushChange(context, change),
                    onDiscard: () => _discardChange(context, change),
                  );
                },
              ),
      ),
    );
  }
}

class _ChangeCard extends StatelessWidget {
  final LocalSyncChange change;
  final String actionLabel;
  final String entityLabel;
  final List<String> fields;
  final VoidCallback onTap;
  final VoidCallback onPush;
  final VoidCallback onDiscard;

  const _ChangeCard({
    required this.change,
    required this.actionLabel,
    required this.entityLabel,
    required this.fields,
    required this.onTap,
    required this.onPush,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDelete = change.action == LocalSyncAction.delete;
    final tint = isDelete ? theme.colorScheme.error : theme.colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(AppAlphas.strong),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isDelete
                        ? Icons.delete_outline_rounded
                        : Icons.edit_note_rounded,
                    color: tint,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      change.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).cancelButtonLabel,
                    onPressed: onDiscard,
                    icon: const Icon(Icons.undo_rounded, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Push',
                    onPressed: onPush,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$actionLabel · $entityLabel · ${fields.take(5).join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (isDelete)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    '删除类变更推送后会被其他设备直接同步',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
