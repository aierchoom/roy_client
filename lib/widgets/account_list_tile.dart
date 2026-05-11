import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';
import '../theme/app_text_styles.dart';
import '../models/account_item.dart';
import '../models/account_template.dart';
import '../services/sensitive_clipboard_service.dart';

class AccountFieldDisplayData {
  final String label;
  final String value;
  final bool isSecret;
  final bool canCopy;
  final IconData icon;
  final String? key;

  const AccountFieldDisplayData({
    required this.label,
    required this.value,
    required this.isSecret,
    this.canCopy = true,
    required this.icon,
    this.key,
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
  final VoidCallback? onTogglePin;
  final String Function(BuildContext, String, String) localeText;
  final String? Function(String accountId)? resolveAccountName;
  final List<String> highlightedFieldKeys;

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
    this.onTogglePin,
    required this.localeText,
    this.resolveAccountName,
    this.highlightedFieldKeys = const [],
  });

  @override
  State<AccountListTile> createState() => _AccountListTileState();
}

class _AccountListTileState extends State<AccountListTile>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
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
          key: key,
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

  /// Build a slash-separated summary of up to 5 labelled field values for
  /// the collapsed state. Secret fields are masked.
  String _buildCollapsedSummary(List<AccountFieldDisplayData> allFields) {
    final parts = <String>[];
    final seen = <String>{};

    for (final field in allFields) {
      final trimmed = field.value.trim();
      if (trimmed.isEmpty) continue;
      if (seen.contains(trimmed)) continue;
      final value = field.isSecret ? '••••' : trimmed;
      parts.add('${field.label}: $value');
      seen.add(trimmed);
      if (parts.length >= 5) break;
    }

    return parts.join(' / ');
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
        Icon(
          Icons.schedule_outlined,
          size: 13,
          color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
        ),
        const SizedBox(width: 4),
        Text(
          '${widget.localeText(context, '创建于', 'Created')} $dateStr',
          style: AppTextStyles.caption(context).copyWith(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(140),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: syncColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          syncLabel,
          style: AppTextStyles.caption(context).copyWith(
            color: syncColor.withAlpha(200),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

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

  String? _passwordCopyValue() {
    if (widget.template == null) return null;
    for (final field in widget.template!.fields) {
      if (field.attributes.type == AccountFieldType.password ||
          field.attributes.isSecret) {
        final v = widget.account.data[field.fieldKey]?.toString().trim();
        if (v != null && v.isNotEmpty) return v;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = _tileAccent(theme);
    final isSearch = widget.density == AccountListTileDensity.search;
    final fieldEntries = _buildFieldEntries(context);
    final summary = _buildCollapsedSummary(fieldEntries);
    final primaryValue = _primaryCopyValue();
    final passwordValue = _passwordCopyValue();
    final horizontalPadding = isSearch ? AppSpacing.md : AppSpacing.lg;
    final verticalPadding = isSearch ? AppSpacing.md : 14.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _isExpanded
            ? colorScheme.surfaceContainerHighest.withAlpha(
                theme.brightness == Brightness.light ? 60 : 40,
              )
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onEdit,
          onLongPress: () => _showContextMenu(context),
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header row ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (widget.account.isPinned) ...[
                                Icon(
                                  Icons.push_pin,
                                  size: 14,
                                  color: accent,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  '${widget.localeText(context, '名称', 'Name')}: ${widget.account.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyLarge(context)
                                      ?.copyWith(
                                    fontWeight: FontWeight.w400,
                                    color: colorScheme.onSurface,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              if (fieldEntries.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                _FieldCountTag(
                                  count: fieldEntries.length,
                                  label: widget.localeText(
                                    context,
                                    '个字段',
                                    'fields',
                                  ),
                                ),
                              ],
                              if (widget.linkedTotpCredentialCount > 0) ...[
                                const SizedBox(width: 8),
                                _TinyBadge(
                                  icon: Icons.verified_user_outlined,
                                  label: widget.localeText(
                                    context,
                                    '2FA enabled',
                                    '2FA enabled',
                                  ),
                                  color: colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          if (!_isExpanded && summary.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 2,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: accent.withAlpha(100),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    summary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodySmall(context)
                                        ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Action buttons
                    if (primaryValue != null)
                      _IconButtonCompact(
                        tooltip: widget.localeText(context, '复制', 'Copy'),
                        icon: Icons.copy_outlined,
                        onPressed: () => _copyValue(
                          context,
                          widget.localeText(context, '主要字段', 'Primary'),
                          primaryValue,
                        ),
                      ),
                    if (passwordValue != null)
                      _IconButtonCompact(
                        tooltip: widget.localeText(context, '复制密码', 'Copy password'),
                        icon: Icons.key_outlined,
                        onPressed: () => _copyValue(
                          context,
                          widget.localeText(context, '密码', 'Password'),
                          passwordValue,
                        ),
                      ),
                    _IconButtonCompact(
                      tooltip: widget.localeText(context, '详情', 'Details'),
                      icon: Icons.expand_more_rounded,
                      onPressed: _toggleExpanded,
                      rotation: _isExpanded ? 0.5 : 0,
                    ),
                  ],
                ),

                // ── Expanded content ──
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: AnimatedOpacity(
                    opacity: _isExpanded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        // Field section
                        if (fieldEntries.isNotEmpty) ...[
                          _SectionLabel(
                            text: widget.localeText(
                              context,
                              '字段详情',
                              'Field Details',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (var i = 0; i < fieldEntries.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    i == fieldEntries.length - 1 ? 0 : AppSpacing.xs,
                              ),
                              child: _FieldRow(
                                label: fieldEntries[i].label,
                                value: fieldEntries[i].value,
                                isSecret: fieldEntries[i].isSecret,
                                canCopy: fieldEntries[i].canCopy,
                                icon: fieldEntries[i].icon,
                                accent: accent,
                                isHighlighted: widget.highlightedFieldKeys
                                    .contains(fieldEntries[i].key),
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
                        ],

                        // Divider + meta
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Divider(height: 1),
                        ),
                        _buildMetaInfo(context, accent),

                        // Bottom action bar
                        const SizedBox(height: AppSpacing.md),
                        _ActionBar(
                          onEdit: widget.onEdit,
                          onCopyAll: () => _copyValue(
                            context,
                            widget.localeText(context, '全部信息', 'All Information'),
                            _buildCopyAllText(context),
                          ),
                          onDelete: widget.onDelete,
                          localeText: widget.localeText,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
            if (widget.onTogglePin != null)
              ListTile(
                leading: Icon(
                  widget.account.isPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                ),
                title: Text(
                  widget.account.isPinned
                      ? widget.localeText(context, '取消置顶', 'Unpin')
                      : widget.localeText(context, '置顶', 'Pin'),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  widget.onTogglePin!();
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
            if (_passwordCopyValue() != null)
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: Text(widget.localeText(context, '复制密码', 'Copy password')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _copyValue(
                    context,
                    widget.localeText(context, '密码', 'Password'),
                    _passwordCopyValue()!,
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

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FieldCountTag extends StatelessWidget {
  final int count;
  final String label;

  const _FieldCountTag({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(
          theme.brightness == Brightness.light ? 12 : 18,
        ),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(
            theme.brightness == Brightness.light ? 40 : 30,
          ),
          width: 0.5,
        ),
      ),
      child: Text(
        '$count $label',
        style: AppTextStyles.caption(context).copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TinyBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.caption(context).copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButtonCompact extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final double rotation;

  const _IconButtonCompact({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.rotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      icon: AnimatedRotation(
        duration: const Duration(milliseconds: 200),
        turns: rotation,
        child: Icon(
          icon,
          size: 20,
          color: colorScheme.onSurfaceVariant.withAlpha(AppAlphas.medium),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: AppTextStyles.labelSmall(context)?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withAlpha(168),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _FieldRow extends StatefulWidget {
  final String label;
  final String value;
  final bool isSecret;
  final bool canCopy;
  final IconData icon;
  final Color accent;
  final bool isHighlighted;
  final VoidCallback onCopy;
  final String copyTooltip;

  const _FieldRow({
    required this.label,
    required this.value,
    required this.isSecret,
    this.canCopy = true,
    required this.icon,
    required this.accent,
    this.isHighlighted = false,
    required this.onCopy,
    required this.copyTooltip,
  });

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  bool _isRevealed = false;

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? theme.colorScheme.error.withAlpha(
                theme.brightness == Brightness.light ? 20 : 30,
              )
            : null,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: widget.isHighlighted
            ? Border.all(color: theme.colorScheme.error.withAlpha(80))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Field icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: widget.accent.withAlpha(12),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 14, color: widget.accent),
          ),
          const SizedBox(width: 10),
          // Label (fixed width)
          SizedBox(
            width: 72,
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall(context)?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Value
          Expanded(
            child: Text(
              displayValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium(context)?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(230),
                fontWeight: FontWeight.w500,
                height: 1.35,
                fontFamily: widget.isSecret
                    ? 'RobotoMono'
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Actions
          if (widget.isSecret)
            _FieldActionButton(
              tooltip: _isRevealed ? 'Hide secret' : 'Show secret',
              icon: _isRevealed
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              onPressed: () => setState(() => _isRevealed = !_isRevealed),
              accent: widget.accent,
            ),
          if (widget.canCopy && (!widget.isSecret || _isRevealed))
            _FieldActionButton(
              tooltip: widget.copyTooltip,
              icon: Icons.content_copy_outlined,
              onPressed: widget.onCopy,
              accent: widget.accent,
            ),
        ],
      ),
    );
  }
}

class _FieldActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color accent;

  const _FieldActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: Icon(
        icon,
        size: 16,
        color: accent.withAlpha(180),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onCopyAll;
  final VoidCallback onDelete;
  final String Function(BuildContext, String, String) localeText;

  const _ActionBar({
    required this.onEdit,
    required this.onCopyAll,
    required this.onDelete,
    required this.localeText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.edit_outlined,
            label: localeText(context, '编辑', 'Edit'),
            onPressed: onEdit,
            foregroundColor: colorScheme.primary,
            backgroundColor: colorScheme.primary.withAlpha(12),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionButton(
            icon: Icons.copy_all_outlined,
            label: localeText(context, '复制全部', 'Copy all'),
            onPressed: onCopyAll,
            foregroundColor: colorScheme.onSurfaceVariant,
            backgroundColor: colorScheme.surfaceContainerHighest.withAlpha(
              theme.brightness == Brightness.light ? 100 : 60,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionButton(
            icon: Icons.delete_outline,
            label: localeText(context, '删除', 'Delete'),
            onPressed: onDelete,
            foregroundColor: colorScheme.error,
            backgroundColor: colorScheme.error.withAlpha(12),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color backgroundColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foregroundColor.withAlpha(200)),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTextStyles.labelSmall(context)?.copyWith(
                  color: foregroundColor.withAlpha(220),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Legacy public exports for backward compatibility.
// These redirect to the new private implementations.
class AccountFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isSecret;
  final bool canCopy;
  final IconData icon;
  final Color accent;
  final bool isHighlighted;
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
    this.isHighlighted = false,
    required this.onCopy,
    required this.copyTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldRow(
      label: label,
      value: value,
      isSecret: isSecret,
      canCopy: canCopy,
      icon: icon,
      accent: accent,
      isHighlighted: isHighlighted,
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
  final bool isHighlighted;
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
    this.isHighlighted = false,
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
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? theme.colorScheme.error.withAlpha(theme.brightness == Brightness.light ? 20 : 30)
            : theme.colorScheme.surfaceContainerHighest.withAlpha(
                theme.brightness == Brightness.light ? 120 : 60,
              ),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: widget.isHighlighted
            ? Border.all(color: theme.colorScheme.error.withAlpha(80))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.accent.withAlpha(14),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 16, color: widget.accent),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 6),
                Text(
                  displayValue,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(230),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
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
          if (widget.canCopy && (!widget.isSecret || _isRevealed))
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
