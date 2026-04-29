import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_design_tokens.dart';
import '../models/account_item.dart';
import '../models/account_template.dart';

class AccountFieldDisplayData {
  final String label;
  final String value;
  final bool isSecret;
  final IconData icon;

  const AccountFieldDisplayData({
    required this.label,
    required this.value,
    required this.isSecret,
    required this.icon,
  });
}

enum AccountListTileDensity { library, search }

class AccountListTile extends StatefulWidget {
  final AccountItem account;
  final AccountTemplate? template;
  final bool hasMissingTemplate;
  final int legacyFieldCount;
  final AccountListTileDensity density;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(BuildContext, String, String) localeText;

  const AccountListTile({
    super.key,
    required this.account,
    required this.template,
    required this.hasMissingTemplate,
    required this.legacyFieldCount,
    this.density = AccountListTileDensity.library,
    required this.onEdit,
    required this.onDelete,
    required this.localeText,
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
              '$label \u6682\u65e0\u53ef\u590d\u5236\u5185\u5bb9',
              'No content available to copy for $label',
            ),
          ),
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: trimmed));
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
              widget.localeText(this.context, '\u5df2\u590d\u5236', 'Copied'),
            ),
          ],
        ),
      ),
    );
  }

  String _buildCopyAllText(BuildContext context) {
    final lines = <String>[
      '${widget.localeText(context, '\u8d26\u6237\u540d\u79f0', 'Account Name')}: ${widget.account.name}',
    ];

    if (widget.account.email.isNotEmpty) {
      lines.add(
        '${widget.localeText(context, '\u90ae\u7bb1', 'Email')}: ${widget.account.email}',
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
    }) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;

      final dedupeKey = '${label.toLowerCase()}|$trimmed';
      if (seen.contains(dedupeKey)) return;
      seen.add(dedupeKey);

      fields.add(
        AccountFieldDisplayData(
          label: label,
          value: trimmed,
          isSecret: isSecret,
          icon: _iconForField(
            label: label,
            key: key,
            type: type,
            isSecret: isSecret,
          ),
        ),
      );
    }

    addField(
      widget.localeText(context, '\u90ae\u7bb1', 'Email'),
      widget.account.email,
      key: 'email',
      type: AccountFieldType.email,
    );

    if (widget.template != null) {
      for (final field in widget.template!.fields) {
        usedKeys.add(field.fieldKey);
        addField(
          field.label,
          widget.account.data[field.fieldKey] ?? '',
          isSecret: field.attributes.isSecret,
          key: field.fieldKey,
          type: field.attributes.type,
        );
      }
    }

    for (final entry in widget.account.data.entries) {
      if (usedKeys.contains(entry.key)) continue;
      addField(_formatKeyLabel(entry.key), entry.value, key: entry.key);
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
        normalized.contains('\u65e5\u671f') ||
        normalized.contains('\u65f6\u95f4') ||
        normalized.contains('\u5230\u671f');
  }

  IconData _iconForField({
    required String label,
    String? key,
    AccountFieldType? type,
    required bool isSecret,
  }) {
    if (isSecret) return Icons.lock_outline_rounded;

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
      case null:
        final lower = composite.toLowerCase();
        if (lower.contains('email') || composite.contains('\u90ae\u7bb1')) {
          return Icons.email_outlined;
        }
        if (lower.contains('phone') || composite.contains('\u7535\u8bdd')) {
          return Icons.phone_outlined;
        }
        if (lower.contains('url') ||
            lower.contains('site') ||
            lower.contains('link') ||
            composite.contains('\u7f51\u5740')) {
          return Icons.link_outlined;
        }
        if (lower.contains('number') ||
            lower.contains('card') ||
            lower.contains('pin') ||
            composite.contains('\u6570\u5b57') ||
            composite.contains('\u5361\u53f7')) {
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
    if (compact.length <= 4) return '****';
    final suffix = compact.length >= 4
        ? compact.substring(compact.length - 4)
        : compact;
    return '**** $suffix';
  }

  Widget _buildSummaryContent(BuildContext context, {int maxLines = 1}) {
    final theme = Theme.of(context);
    final segments = <String>[];

    void addSegment(
      String label,
      String value, {
      bool isSecret = false,
      bool showLabel = true,
    }) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;

      final displayValue = isSecret ? _maskedPreview(trimmed) : trimmed;
      segments.add(showLabel ? '$label: $displayValue' : displayValue);
    }

    if (widget.template != null) {
      final primaryFields = widget.template!.fields.where(
        (field) => field.attributes.isPrimary,
      );
      for (final field in primaryFields) {
        addSegment(
          field.label,
          widget.account.data[field.fieldKey] ?? '',
          isSecret: field.attributes.isSecret,
        );
        if (segments.length >= 2) break;
      }
    }

    if (segments.length < 2 && widget.account.email.isNotEmpty) {
      addSegment(
        widget.localeText(context, '\u90ae\u7bb1', 'Email'),
        widget.account.email,
        showLabel: false,
      );
    }

    if (segments.length < 2 && widget.template != null) {
      for (final field in widget.template!.fields) {
        if (field.attributes.isPrimary) continue;
        addSegment(
          field.label,
          widget.account.data[field.fieldKey] ?? '',
          isSecret: field.attributes.isSecret,
        );
        if (segments.length >= 2) break;
      }
    }

    if (segments.isEmpty) {
      return Text(
        widget.localeText(
          context,
          '\u6682\u65e0\u53ef\u7528\u6458\u8981',
          'No summary information yet',
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Text(
      segments.join('  /  '),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
        height: 1.3,
      ),
    );
  }

  Widget _buildMetaLine(
    BuildContext context,
    Color accent, {
    required String templateName,
    required int fieldCount,
  }) {
    final theme = Theme.of(context);
    final fieldLabel = widget.localeText(
      context,
      '$fieldCount 个字段',
      '$fieldCount fields',
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.dashboard_customize_outlined, size: 14, color: accent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$templateName · $fieldLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(190),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChips(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    final chips = <Widget>[];

    if (widget.account.syncStatus == SyncStatus.conflict) {
      chips.add(
        _StatusChip(
          icon: Icons.warning_amber_rounded,
          label: widget.localeText(context, '\u51b2\u7a81', 'Conflict'),
          tint: Colors.amber.shade700,
        ),
      );
    }

    if (widget.hasMissingTemplate) {
      chips.add(
        _StatusChip(
          icon: Icons.error_outline_rounded,
          label: widget.localeText(
            context,
            '\u6a21\u677f\u7f3a\u5931',
            'Missing Template',
          ),
          tint: theme.colorScheme.error,
        ),
      );
    }

    if (widget.legacyFieldCount > 0) {
      chips.add(
        _StatusChip(
          icon: Icons.history_toggle_off_rounded,
          label: widget.localeText(
            context,
            '\u5386\u53f2\u5b57\u6bb5 ${widget.legacyFieldCount}',
            'Legacy ${widget.legacyFieldCount}',
          ),
          tint: accent,
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _buildIconAction({
    required BuildContext context,
    required Color accent,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      icon: Icon(icon, color: accent, size: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _tileAccent(theme);
    final isSearchResult = widget.density == AccountListTileDensity.search;
    final tileRadius = isSearchResult ? AppRadii.card : 0.0;
    final fieldEntries = _buildFieldEntries(context);
    final templateName =
        widget.template?.title ??
        widget.localeText(
          context,
          '\u672a\u77e5\u6a21\u677f',
          'Unknown Template',
        );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Material(
        color: isSearchResult
            ? theme.colorScheme.surfaceContainerHighest.withAlpha(110)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(tileRadius),
        child: InkWell(
          onTap: widget.onEdit,
          onLongPress: widget.onDelete,
          borderRadius: BorderRadius.circular(tileRadius),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tileRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    12,
                    isSearchResult ? 12 : 10,
                    10,
                    4,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.account.name,
                              maxLines: isSearchResult ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _buildSummaryContent(
                              context,
                              maxLines: isSearchResult ? 2 : 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    0,
                    10,
                    isSearchResult ? 12 : 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMetaLine(
                                  context,
                                  accent,
                                  templateName: templateName,
                                  fieldCount: fieldEntries.length,
                                ),
                                Builder(
                                  builder: (context) {
                                    final status = _buildStatusChips(
                                      context,
                                      accent,
                                    );
                                    if (status is SizedBox) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: status,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildIconAction(
                            context: context,
                            accent: accent,
                            icon: _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            tooltip: widget.localeText(
                              context,
                              '\u5207\u6362\u8be6\u60c5',
                              'Toggle details',
                            ),
                            onPressed: _toggleExpanded,
                          ),
                          const SizedBox(width: 2),
                          PopupMenuButton<String>(
                            tooltip: widget.localeText(
                              context,
                              '\u64cd\u4f5c',
                              'Options',
                            ),
                            onSelected: (value) {
                              if (value == 'edit') {
                                widget.onEdit();
                              } else if (value == 'copy_all') {
                                _copyValue(
                                  context,
                                  widget.localeText(
                                    context,
                                    '\u5168\u90e8\u4fe1\u606f',
                                    'All Information',
                                  ),
                                  _buildCopyAllText(context),
                                );
                              } else if (value == 'delete') {
                                widget.onDelete();
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.localeText(
                                        context,
                                        '\u7f16\u8f91',
                                        'Edit',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'copy_all',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.copy_all_outlined,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.localeText(
                                        context,
                                        '\u590d\u5236\u5168\u90e8',
                                        'Copy all',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.localeText(
                                        context,
                                        '\u5220\u9664',
                                        'Delete',
                                      ),
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            padding: EdgeInsets.zero,
                            icon: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.control,
                                ),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.more_horiz_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_isExpanded && fieldEntries.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withAlpha(80),
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.localeText(
                                  context,
                                  '\u8be6\u7ec6\u5b57\u6bb5',
                                  'Field Details',
                                ),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (var i = 0; i < fieldEntries.length; i++)
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: i == fieldEntries.length - 1
                                        ? 0
                                        : 8,
                                  ),
                                  child: AccountFieldRow(
                                    label: fieldEntries[i].label,
                                    value: fieldEntries[i].value,
                                    isSecret: fieldEntries[i].isSecret,
                                    icon: fieldEntries[i].icon,
                                    accent: accent,
                                    onCopy: () => _copyValue(
                                      context,
                                      fieldEntries[i].label,
                                      fieldEntries[i].value,
                                    ),
                                    copyTooltip: widget.localeText(
                                      context,
                                      '\u590d\u5236 ${fieldEntries[i].label}',
                                      'Copy ${fieldEntries[i].label}',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AccountFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isSecret;
  final IconData icon;
  final Color accent;
  final VoidCallback onCopy;
  final String copyTooltip;

  const AccountFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.isSecret,
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
  final IconData icon;
  final Color accent;
  final VoidCallback onCopy;
  final String copyTooltip;

  const AccountFieldRowBody({
    super.key,
    required this.label,
    required this.value,
    required this.isSecret,
    required this.icon,
    required this.accent,
    required this.onCopy,
    required this.copyTooltip,
  });

  @override
  State<AccountFieldRowBody> createState() => _AccountFieldRowBodyState();
}

class _AccountFieldRowBodyState extends State<AccountFieldRowBody> {
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

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withAlpha(16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tint),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.max(
                88,
                math.min(MediaQuery.sizeOf(context).width - 96, 240),
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tint,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
