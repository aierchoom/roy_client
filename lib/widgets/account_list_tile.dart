import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';
import '../models/account_item.dart';
import '../models/account_template.dart';
import '../services/sensitive_clipboard_service.dart';

class AccountFieldDisplayData {
  final String label;
  final String value;
  final bool isSecret;
  final bool canCopy;
  final IconData icon;

  const AccountFieldDisplayData({
    required this.label,
    required this.value,
    required this.isSecret,
    this.canCopy = true,
    required this.icon,
  });
}

enum AccountListTileDensity { library, search }

class AccountListTile extends StatefulWidget {
  final AccountItem account;
  final AccountTemplate? template;
  final bool hasMissingTemplate;
  final int legacyFieldCount;
  final int linkedTotpCredentialCount;
  final AccountListTileDensity density;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(BuildContext, String, String) localeText;
  final String? Function(String accountId)? resolveAccountName;

  const AccountListTile({
    super.key,
    required this.account,
    required this.template,
    required this.hasMissingTemplate,
    required this.legacyFieldCount,
    this.linkedTotpCredentialCount = 0,
    this.density = AccountListTileDensity.library,
    required this.onEdit,
    required this.onDelete,
    required this.localeText,
    this.resolveAccountName,
  });

  @override
  State<AccountListTile> createState() => _AccountListTileState();
}

class _AccountListTileState extends State<AccountListTile> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
  }

  Future<void> _copyValue(
    BuildContext context,
    String label,
    String value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.localeText(
              context,
              '$label 暂无可复制内容',
              'No content available to copy for $label',
            ),
          ),
        ),
      );
      return;
    }

    await SensitiveClipboardService.copy(
      text: trimmed,
      level: ClipboardRiskLevel.high,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 220,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              widget.localeText(this.context, '已复制', 'Copied'),
            ),
          ],
        ),
      ),
    );
  }

  String _buildCopyAllText(BuildContext context) {
    final lines = <String>[
      '${widget.localeText(context, '账户名称', 'Account Name')}: ${widget.account.name}',
    ];

    if (widget.account.email.isNotEmpty) {
      lines.add(
        '${widget.localeText(context, '邮箱', 'Email')}: ${widget.account.email}',
      );
    }

    for (final field in _buildFieldEntries(context)) {
      lines.add('${field.label}: ${field.value}');
    }

    return lines.join('\n');
  }

  List<AccountFieldDisplayData> _buildFieldEntries(BuildContext context) {
    final fields = <AccountFieldDisplayData>[];
    final usedKeys = <String>{};
    final seen = <String>{};

    void addField(
      String label,
      String value, {
      bool isSecret = false,
      String? key,
      AccountFieldType? type,
      bool isReference = false,
    }) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      final displayValue = trimmed;

      final dedupeKey = '${label.toLowerCase()}|$displayValue';
      if (seen.contains(dedupeKey)) return;
      seen.add(dedupeKey);

      fields.add(
        AccountFieldDisplayData(
          label: label,
          value: displayValue,
          isSecret: isSecret,
          icon: _iconForField(
            label: label,
            key: key,
            type: type,
            isSecret: isSecret,
            isReference: isReference,
          ),
        ),
      );
    }

    addField(
      widget.localeText(context, '邮箱', 'Email'),
      widget.account.email,
      key: 'email',
      type: AccountFieldType.email,
    );

    if (widget.template != null) {
      for (final field in widget.template!.fields) {
        usedKeys.add(field.fieldKey);
        String displayValue =
            widget.account.data[field.fieldKey]?.toString() ?? '';
        if (field.attributes.type == AccountFieldType.accountLink &&
            displayValue.isNotEmpty) {
          final resolved = widget.resolveAccountName?.call(displayValue);
          if (resolved != null && resolved.isNotEmpty) {
            displayValue = resolved;
          }
        }
        addField(
          field.label,
          displayValue,
          isSecret: field.attributes.isSecret,
          key: field.fieldKey,
          type: field.attributes.type,
          isReference: field.attributes.isReference,
        );
      }
    }

    for (final entry in widget.account.data.entries) {
      if (usedKeys.contains(entry.key)) continue;
      addField(
        _formatKeyLabel(entry.key),
        entry.value?.toString() ?? '',
        key: entry.key,
      );
    }

    return fields;
  }

  String _formatKeyLabel(String key) {
    final parts = key
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return key;

    return parts
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }

  bool _looksLikeDateField(String source) {
    final normalized = source.toLowerCase();
    return normalized.contains('date') ||
        normalized.contains('time') ||
        normalized.contains('expiry') ||
        normalized.contains('deadline') ||
        normalized.contains('日期') ||
        normalized.contains('时间') ||
        normalized.contains('到期');
  }

  IconData _iconForField({
    required String label,
    String? key,
    AccountFieldType? type,
    required bool isSecret,
    bool isReference = false,
  }) {
    if (isSecret) return Icons.lock_outline_rounded;
    if (isReference) return Icons.verified_user_outlined;

    final composite = '${key ?? ''} $label';
    if (_looksLikeDateField(composite)) {
      return Icons.event_outlined;
    }

    switch (type) {
      case AccountFieldType.text:
        return Icons.text_fields_outlined;
      case AccountFieldType.password:
        return Icons.password_outlined;
      case AccountFieldType.number:
        return Icons.onetwothree_outlined;
      case AccountFieldType.email:
        return Icons.email_outlined;
      case AccountFieldType.phone:
        return Icons.phone_outlined;
      case AccountFieldType.url:
        return Icons.link_outlined;
      case AccountFieldType.time:
        return Icons.schedule_outlined;
      case AccountFieldType.custom:
        return Icons.extension_outlined;
      case AccountFieldType.accountLink:
        return Icons.account_tree_outlined;
      case AccountFieldType.unknown:
        return Icons.help_outline_outlined;
      case AccountFieldType.longText:
        return Icons.notes_outlined;
      case AccountFieldType.list:
        return Icons.list_outlined;
      case null:
        final lower = composite.toLowerCase();
        if (lower.contains('email') || composite.contains('邮箱')) {
          return Icons.email_outlined;
        }
        if (lower.contains('phone') || composite.contains('电话')) {
          return Icons.phone_outlined;
        }
        if (lower.contains('url') ||
            lower.contains('site') ||
            lower.contains('link') ||
            composite.contains('网址')) {
          return Icons.link_outlined;
        }
        if (lower.contains('number') ||
            lower.contains('card') ||
            lower.contains('pin') ||
            composite.contains('数字') ||
            composite.contains('卡号')) {
          return Icons.onetwothree_outlined;
        }
        return Icons.text_fields_outlined;
    }
  }

  Color _tileAccent(ThemeData theme) {
    return theme.colorScheme.primary;
  }

  String _maskedPreview(String value) {
    final compact = value.replaceAll(RegExp(r'[\s\-]+'), '');
    if (compact.isEmpty) return '';
    return '••••';
  }

  /// Build the subtitle: field labels + values (up to 3).
  String _buildSubtitle(BuildContext context) {
    final segments = <String>[];

    void addSegment(String label, String value, {bool isSecret = false}) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      final displayValue = isSecret ? _maskedPreview(trimmed) : trimmed;
      segments.add('$label: $displayValue');
    }

    if (widget.template != null) {
      for (final field in widget.template!.fields) {
        addSegment(
          field.label,
          widget.account.data[field.fieldKey]?.toString() ?? '',
          isSecret: field.attributes.isSecret,
        );
        if (segments.length >= 3) break;
      }
    }

    if (segments.isEmpty && widget.account.email.isNotEmpty) {
      addSegment(
        widget.localeText(context, '邮箱', 'Email'),
        widget.account.email,
      );
    }

    return segments.join('  ·  ');
  }

  /// Build meta info row (created at, sync status, etc.).
  Widget _buildMetaInfo(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    final created = DateTime.fromMillisecondsSinceEpoch(
      widget.account.createdAt,
    );
    final dateStr =
        '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';

    final syncLabel = switch (widget.account.syncStatus) {
      SyncStatus.synchronized => widget.localeText(context, '已同步', 'Synced'),
      SyncStatus.pendingPush => widget.localeText(context, '待推送', 'Pending'),
      SyncStatus.conflict => widget.localeText(context, '冲突', 'Conflict'),
    };
    final syncColor = switch (widget.account.syncStatus) {
      SyncStatus.synchronized => theme.colorScheme.primary,
      SyncStatus.pendingPush => theme.colorScheme.tertiary,
      SyncStatus.conflict => theme.colorScheme.error,
    };

    return Row(
      children: [
        Icon(Icons.schedule_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant.withAlpha(150)),
        const SizedBox(width: 6),
        Text(
          '${widget.localeText(context, '创建于', 'Created')} $dateStr',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: syncColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          syncLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: syncColor.withAlpha(200),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// Find the primary copyable field value for quick-copy.
  String? _primaryCopyValue() {
    if (widget.template != null) {
      for (final field in widget.template!.fields) {
        if (field.attributes.isPrimary && !field.attributes.isSecret) {
          final v = widget.account.data[field.fieldKey]?.toString().trim();
          if (v != null && v.isNotEmpty) return v;
        }
      }
    }
    if (widget.account.email.isNotEmpty) return widget.account.email;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _tileAccent(theme);
    final isSearch = widget.density == AccountListTileDensity.search;
    final fieldEntries = _buildFieldEntries(context);
    final subtitle = _buildSubtitle(context);
    final primaryValue = _primaryCopyValue();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onEdit,
        onLongPress: () => _showContextMenu(context),
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: EdgeInsets.all(isSearch ? AppSpacing.lg : AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading diamond badge
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppSurfaces.soft(
                      theme.colorScheme,
                      tint: accent,
                      tintAlpha: 18,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.button),
                    border: Border.all(color: accent.withAlpha(AppAlphas.low)),
                  ),
                  alignment: Alignment.center,
                  child: Transform.rotate(
                    angle: -math.pi / 4,
                    child: Text(
                      widget.template?.badgeText ?? '?',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant
                              .withAlpha(AppAlphas.emphasis),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Actions
              if (primaryValue != null)
                IconButton(
                  tooltip: widget.localeText(context, '复制', 'Copy'),
                  onPressed: () => _copyValue(
                    context,
                    widget.localeText(context, '主要字段', 'Primary'),
                    primaryValue,
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(36, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                  ),
                  icon: Icon(
                    Icons.copy_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant
                        .withAlpha(AppAlphas.medium),
                  ),
                ),
              IconButton(
                tooltip: widget.localeText(context, '详情', 'Details'),
                onPressed: _toggleExpanded,
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                ),
                icon: AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: _isExpanded ? 0.5 : 0,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 22,
                    color: theme.colorScheme.onSurfaceVariant
                        .withAlpha(AppAlphas.medium),
                  ),
                ),
              ),
            ],
          ),
          // Expanded detail fields
          if (_isExpanded && fieldEntries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppSurfaces.soft(theme.colorScheme, tint: accent, tintAlpha: 8),
                borderRadius: BorderRadius.circular(AppRadii.control),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(AppAlphas.subtle),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < fieldEntries.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == fieldEntries.length - 1 ? 0 : AppSpacing.sm,
                      ),
                      child: AccountFieldRow(
                        label: fieldEntries[i].label,
                        value: fieldEntries[i].value,
                        isSecret: fieldEntries[i].isSecret,
                        canCopy: fieldEntries[i].canCopy,
                        icon: fieldEntries[i].icon,
                        accent: accent,
                        onCopy: () => _copyValue(
                          context,
                          fieldEntries[i].label,
                          fieldEntries[i].value,
                        ),
                        copyTooltip: widget.localeText(
                          context,
                          '复制 ${fieldEntries[i].label}',
                          'Copy ${fieldEntries[i].label}',
                        ),
                      ),
                    ),
                  const Divider(height: AppSpacing.xl),
                  _buildMetaInfo(context, accent),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(widget.localeText(context, '编辑', 'Edit')),
              onTap: () {
                Navigator.pop(sheetContext);
                widget.onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: Text(widget.localeText(context, '复制全部', 'Copy all')),
              onTap: () {
                Navigator.pop(sheetContext);
                _copyValue(
                  context,
                  widget.localeText(context, '全部信息', 'All Information'),
                  _buildCopyAllText(context),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                widget.localeText(context, '删除', 'Delete'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                widget.onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AccountFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isSecret;
  final bool canCopy;
  final IconData icon;
  final Color accent;
  final VoidCallback onCopy;
  final String copyTooltip;

  const AccountFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.isSecret,
    this.canCopy = true,
    required this.icon,
    required this.accent,
    required this.onCopy,
    required this.copyTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return AccountFieldRowBody(
      label: label,
      value: value,
      isSecret: isSecret,
      canCopy: canCopy,
      icon: icon,
      accent: accent,
      onCopy: onCopy,
      copyTooltip: copyTooltip,
    );
  }
}

class AccountFieldRowBody extends StatefulWidget {
  final String label;
  final String value;
  final bool isSecret;
  final bool canCopy;
  final IconData icon;
  final Color accent;
  final VoidCallback onCopy;
  final String copyTooltip;

  const AccountFieldRowBody({
    super.key,
    required this.label,
    required this.value,
    required this.isSecret,
    this.canCopy = true,
    required this.icon,
    required this.accent,
    required this.onCopy,
    required this.copyTooltip,
  });

  @override
  State<AccountFieldRowBody> createState() => _AccountFieldRowBodyState();
}

class _AccountFieldRowBodyState extends State<AccountFieldRowBody> {
  bool _isRevealed = true;

  String _maskSecret(String value) {
    final length = value.length;
    final count = math.max(4, math.min(length, 10));
    return List.filled(count, '*').join();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = widget.isSecret && !_isRevealed
        ? _maskSecret(widget.value)
        : widget.value;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(
          theme.brightness == Brightness.light ? 180 : 80,
        ),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: widget.accent.withAlpha(14),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 15, color: widget.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(168),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  displayValue,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(214),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (widget.isSecret)
            IconButton(
              tooltip: _isRevealed ? 'Hide secret' : 'Show secret',
              onPressed: () => setState(() => _isRevealed = !_isRevealed),
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              icon: Icon(
                _isRevealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: widget.accent.withAlpha(190),
              ),
            ),
          if (widget.canCopy)
            IconButton(
              tooltip: widget.copyTooltip,
              onPressed: widget.onCopy,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              icon: Icon(
                Icons.content_copy_outlined,
                color: widget.accent.withAlpha(190),
              ),
            ),
        ],
      ),
    );
  }
}
