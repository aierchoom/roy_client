import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/account_item.dart';

import '../../providers/enhanced_app_provider.dart';
import '../../services/sensitive_clipboard_service.dart';
import '../../theme/app_design_tokens.dart';
import '../../widgets/adaptive_page.dart';
import 'account_edit_view.dart';

class AccountSubsetView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<String> accountIds;
  final String? highlightFieldKey;
  final String? groupByFieldKey;

  const AccountSubsetView({
    super.key,
    required this.title,
    this.subtitle,
    required this.accountIds,
    this.highlightFieldKey,
    this.groupByFieldKey,
  });

  List<List<AccountItem>> _groupAccounts(List<AccountItem> accounts) {
    if (groupByFieldKey == null) return accounts.map((a) => [a]).toList();

    final groups = <String, List<AccountItem>>{};
    for (final account in accounts) {
      final value = (account.data[groupByFieldKey!] ?? '').toString();
      if (value.isEmpty) continue;
      final hash = sha256.convert(utf8.encode(value)).toString();
      groups.putIfAbsent(hash, () => []).add(account);
    }
    final sorted = groups.values.toList()
      ..sort((a, b) {
        final sizeCompare = b.length.compareTo(a.length);
        if (sizeCompare != 0) return sizeCompare;
        return a.first.name.compareTo(b.first.name);
      });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EnhancedAppProvider>();
    final accounts = provider.allAccounts
        .where((a) => accountIds.contains(a.id))
        .toList();
    final groups = _groupAccounts(accounts);
    final isGrouped = groupByFieldKey != null;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AdaptivePage(
        child: accounts.isEmpty
            ? _buildEmptyState(context)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: groups.length,
                itemBuilder: (context, groupIndex) {
                  final group = groups[groupIndex];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: groupIndex < groups.length - 1 ? 16 : 0,
                    ),
                    child: isGrouped
                        ? _GroupCard(
                            group: group,
                            provider: provider,
                            highlightFieldKey: highlightFieldKey,
                            groupByFieldKey: groupByFieldKey!,
                          )
                        : _AccountCard(
                            account: group.first,
                            provider: provider,
                            highlightFieldKey: highlightFieldKey,
                          ),
                  );
                },
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
          Icon(Icons.folder_open_outlined,
              size: 64, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.text('没有可显示的账号', 'No accounts to display'),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<AccountItem> group;
  final EnhancedAppProvider provider;
  final String? highlightFieldKey;
  final String groupByFieldKey;

  const _GroupCard({
    required this.group,
    required this.provider,
    required this.highlightFieldKey,
    required this.groupByFieldKey,
  });

  String _groupLabel(BuildContext context) {
    final count = group.length;
    return context.text(
      '$count 个账号共享此密码',
      '$count account${count > 1 ? 's' : ''} share this password',
    );
  }

  String get _hashPrefix {
    final value = (group.first.data[groupByFieldKey] ?? '').toString();
    if (value.isEmpty) return '';
    final hash = sha256.convert(utf8.encode(value)).toString();
    return hash.substring(0, math.min(8, hash.length));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(
          color: errorColor.withAlpha(AppAlphas.low),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: errorColor.withAlpha(10),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.panel),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: errorColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.key_outlined,
                      size: 16, color: errorColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _groupLabel(context),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hash: $_hashPrefix...',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: errorColor.withAlpha(180),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...group.asMap().entries.map((entry) {
            final isLast = entry.key == group.length - 1;
            return Column(
              children: [
                _AccountCard(
                  account: entry.value,
                  provider: provider,
                  highlightFieldKey: highlightFieldKey,
                ),
                if (!isLast) const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _AccountCard extends StatefulWidget {
  final AccountItem account;
  final EnhancedAppProvider provider;
  final String? highlightFieldKey;

  const _AccountCard({
    required this.account,
    required this.provider,
    this.highlightFieldKey,
  });

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _expanded = false;

  Color get _accentColor {
    return Theme.of(context).colorScheme.primary;
  }

  String get _badgeText {
    final template = widget.provider.getTemplate(widget.account.templateId);
    return template?.badgeText ?? '?';
  }

  List<_FieldEntry> _buildFieldEntries() {
    final entries = <_FieldEntry>[];
    final account = widget.account;

    if (account.email.isNotEmpty) {
      entries.add(_FieldEntry(
        label: 'Email',
        value: account.email,
        icon: Icons.email_outlined,
      ));
    }

    account.data.forEach((key, value) {
      final str = value?.toString() ?? '';
      if (str.isEmpty) return;
      entries.add(_FieldEntry(
        label: key,
        value: str,
        icon: _iconForKey(key),
        isHighlighted: widget.highlightFieldKey == key,
      ));
    });

    return entries;
  }

  IconData _iconForKey(String key) {
    return switch (key.toLowerCase()) {
      'password' => Icons.lock_outlined,
      'url' || 'website' => Icons.link_outlined,
      'username' => Icons.person_outline,
      'phone' => Icons.phone_outlined,
      'note' || 'notes' => Icons.notes_outlined,
      _ => Icons.text_fields_outlined,
    };
  }

  Future<void> _copy(String value, String label) async {
    await SensitiveClipboardService.copy(
      text: value,
      level: ClipboardRiskLevel.high,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 220,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_rounded, size: 16),
            const SizedBox(width: 8),
            Text(context.text('已复制 $label', 'Copied $label')),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor() async {
    final result = await Navigator.push<AccountItem>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountEditView(initial: widget.account),
      ),
    );
    if (result == null || !context.mounted) return;
    await widget.provider.updateAccount(result);
  }

  Future<void> _delete() async {
    final account = widget.account;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.text('删除账户', 'Delete Account')),
        content: Text(
          context.text(
            '确定要删除"${account.name}"吗？此操作不可撤销。',
            'Are you sure you want to delete "${account.name}"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.text('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.text('删除', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await widget.provider.deleteAccount(account.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = widget.account;
    final accent = _accentColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Leading icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _badgeText,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        if (account.email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            account.email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _openEditor,
                        icon: Icon(Icons.edit_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: _delete,
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: theme.colorScheme.error),
                        visualDensity: VisualDensity.compact,
                      ),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: _expanded ? 0.5 : 0,
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 14),
                _buildExpandedFields(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedFields(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _buildFieldEntries();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(
          theme.brightness == Brightness.light ? 80 : 40,
        ),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.text('字段详情', 'Field Details'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(168),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < entries.length; i++) ...[
            _FieldRow(
              entry: entries[i],
              onCopy: () => _copy(entries[i].value, entries[i].label),
            ),
            if (i < entries.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _FieldEntry {
  final String label;
  final String value;
  final IconData icon;
  final bool isHighlighted;

  const _FieldEntry({
    required this.label,
    required this.value,
    required this.icon,
    this.isHighlighted = false,
  });
}

class _FieldRow extends StatelessWidget {
  final _FieldEntry entry;
  final VoidCallback onCopy;

  const _FieldRow({required this.entry, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isHighlighted
            ? Colors.red.withAlpha(
                theme.brightness == Brightness.light ? 20 : 30)
            : theme.colorScheme.surface.withAlpha(
                theme.brightness == Brightness.light ? 120 : 60),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: entry.isHighlighted
            ? Border.all(color: Colors.red.withAlpha(80))
            : null,
      ),
      child: Row(
        children: [
          Icon(entry.icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(168),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(230),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: Icon(Icons.copy_outlined,
                size: 16, color: theme.colorScheme.onSurfaceVariant),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
