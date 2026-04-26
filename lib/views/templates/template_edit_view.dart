import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';

import '../../models/account_template.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/green_add_button.dart';

class TemplateEditView extends StatefulWidget {
  final AccountTemplate? initial;

  const TemplateEditView({super.key, this.initial});

  @override
  State<TemplateEditView> createState() => _TemplateEditViewState();
}

class _TemplateEditViewState extends State<TemplateEditView> {
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();

  List<AccountField> _fields = [];

  String _text(String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _titleCtrl.text = widget.initial!.title;
      _subtitleCtrl.text = widget.initial!.subTitle;
      _fields = List<AccountField>.of(widget.initial!.fields);
    }
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleCtrl.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.requireTemplateTitle)));
      return;
    }

    if (_fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u8bf7\u81f3\u5c11\u6dfb\u52a0\u4e00\u4e2a\u5b57\u6bb5\u3002',
          ),
        ),
      );
      return;
    }

    final template = AccountTemplate(
      templateId:
          widget.initial?.templateId ??
          'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      subTitle: _subtitleCtrl.text.trim(),
      icon: null,
      category: inferTemplateCategory(title: title, fields: _fields),
      fields: List<AccountField>.of(_fields),
      isCustom: true,
    );

    Navigator.pop(context, template);
  }

  String _normalizeFieldKey(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'field' : normalized;
  }

  String _buildUniqueFieldKey(String seed, {int? ignoreIndex}) {
    final baseKey = _normalizeFieldKey(seed);
    var candidate = baseKey;
    var suffix = 2;

    while (_fields.asMap().entries.any(
      (entry) => entry.key != ignoreIndex && entry.value.fieldKey == candidate,
    )) {
      candidate = '${baseKey}_$suffix';
      suffix += 1;
    }

    return candidate;
  }

  String _fieldTypeLabel(AccountFieldType type) {
    switch (type) {
      case AccountFieldType.text:
        return '\u6587\u672c';
      case AccountFieldType.password:
        return '\u5bc6\u7801';
      case AccountFieldType.number:
        return '\u6570\u5b57';
      case AccountFieldType.email:
        return '\u90ae\u7bb1';
      case AccountFieldType.phone:
        return '\u7535\u8bdd';
      case AccountFieldType.url:
        return '\u7f51\u5740';
      case AccountFieldType.time:
        return '\u65f6\u95f4';
      case AccountFieldType.custom:
        return '\u81ea\u5b9a\u4e49';
    }
  }

  IconData _fieldTypeIcon(AccountFieldType type) {
    switch (type) {
      case AccountFieldType.text:
        return Icons.notes_outlined;
      case AccountFieldType.password:
        return Icons.password_outlined;
      case AccountFieldType.number:
        return Icons.pin_outlined;
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
    }
  }

  String _sampleValueForField(AccountField field) {
    if (field.attributes.isSecret) return '••••••••';

    switch (field.attributes.type) {
      case AccountFieldType.email:
        return 'name@example.com';
      case AccountFieldType.phone:
        return '138 0000 0000';
      case AccountFieldType.url:
        return 'https://example.com';
      case AccountFieldType.number:
        return '123456';
      case AccountFieldType.time:
        return 'YYYY-MM-DD HH:mm';
      case AccountFieldType.password:
        return '••••••••';
      case AccountFieldType.text:
      case AccountFieldType.custom:
        return field.attributes.hint ?? '';
    }
  }

  List<BoxShadow> _softCardShadows(ThemeData theme, {double depth = 1}) {
    if (theme.brightness != Brightness.light) {
      return const [];
    }

    return [
      BoxShadow(
        color: theme.colorScheme.shadow.withAlpha(
          (10 * depth).round().clamp(0, 255),
        ),
        blurRadius: 28 * depth,
        offset: Offset(0, 16 * depth),
      ),
      BoxShadow(
        color: theme.colorScheme.primary.withAlpha(
          (6 * depth).round().clamp(0, 255),
        ),
        blurRadius: 12 * depth,
        offset: Offset(0, 6 * depth),
      ),
    ];
  }

  Color _softSurface(ThemeData theme, {Color? tint, int tintAlpha = 18}) {
    final base = theme.colorScheme.surface;
    if (tint == null) {
      return base;
    }
    if (theme.brightness != Brightness.light) {
      return theme.colorScheme.surfaceContainerHigh;
    }
    return Color.alphaBlend(tint.withAlpha(tintAlpha), base);
  }

  Widget _buildToneChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? tint,
  }) {
    final theme = Theme.of(context);
    final accent = tint ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _softSurface(theme, tint: accent, tintAlpha: 16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withAlpha(48)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editField({AccountField? initial, int? index}) async {
    final originallyPersisted =
        initial != null &&
        (widget.initial?.fields.any(
              (field) => field.fieldKey == initial.fieldKey,
            ) ??
            false);

    final result = await showDialog<_FieldEditorResult>(
      context: context,
      builder: (dialogContext) => _FieldEditorDialog(
        initial: initial,
        originallyPersisted: originallyPersisted,
        fieldTypeLabelBuilder: _fieldTypeLabel,
      ),
    );

    if (result == null) return;

    final rawKey = originallyPersisted
        ? initial.fieldKey
        : (result.rawKey.trim().isEmpty ? result.label : result.rawKey);
    final fieldKey = originallyPersisted
        ? rawKey
        : _buildUniqueFieldKey(rawKey, ignoreIndex: index);

    setState(() {
      final field = AccountField(
        fieldKey: fieldKey,
        label: result.label,
        description: result.description,
        attributes: result.attributes,
      );
      if (index == null) {
        _fields.add(field);
      } else {
        _fields[index] = field;
      }
    });
  }

  void _moveField(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= _fields.length) return;

    setState(() {
      final field = _fields.removeAt(fromIndex);
      _fields.insert(toIndex, field);
    });
  }

  Future<void> _confirmRemoveField(int index) async {
    final field = _fields[index];
    final usageCount = widget.initial == null
        ? 0
        : context.read<EnhancedAppProvider>().countAccountsByTemplate(
            widget.initial!.templateId,
          );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('\u5220\u9664\u5b57\u6bb5'),
        content: Text(
          usageCount > 0
              ? '\u786e\u8ba4\u4ece\u6a21\u677f\u4e2d\u5220\u9664\u201c${field.label}\u201d\u5417\uff1f\n\n\u8be5\u6a21\u677f\u76ee\u524d\u88ab $usageCount \u4e2a\u8d26\u6237\u4f7f\u7528\u3002\u5220\u9664\u540e\uff0c\u7cfb\u7edf\u4f1a\u4fdd\u7559\u5386\u53f2\u8d26\u6237\u4e2d\u7684\u539f\u59cb\u503c\uff0c\u907f\u514d\u5728\u540e\u7eed\u4fdd\u5b58\u65f6\u88ab\u9ed8\u9ed8\u5220\u6389\u3002'
              : '\u786e\u8ba4\u4ece\u6a21\u677f\u4e2d\u5220\u9664\u201c${field.label}\u201d\u5417\uff1f',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              AppLocalizations.of(context)!.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _fields.removeAt(index));
    }
  }

  Widget _buildOverviewCard(BuildContext context) {
    final theme = Theme.of(context);
    final badgeText = templateBadgeText(
      _titleCtrl.text.trim().isEmpty
          ? '\u672a\u547d\u540d\u6a21\u677f'
          : _titleCtrl.text.trim(),
    );
    final heroEdge = theme.colorScheme.primary.withAlpha(42);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              theme.colorScheme.primary.withAlpha(24),
              theme.colorScheme.primaryContainer,
            ),
            Color.alphaBlend(
              theme.colorScheme.tertiary.withAlpha(18),
              theme.colorScheme.tertiaryContainer,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: heroEdge),
        boxShadow: _softCardShadows(theme, depth: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(232),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _softCardShadows(theme, depth: 0.45),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: '名称：',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          TextSpan(
                            text: _titleCtrl.text.trim().isEmpty
                                ? '未命名模板'
                                : _titleCtrl.text.trim(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '模板描述：${_subtitleCtrl.text.trim().isEmpty ? '先把字段结构设计清楚，后续录入和维护都会轻松很多。' : _subtitleCtrl.text.trim()}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withAlpha(
                          210,
                        ),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimaryContainer.withAlpha(
                          18,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _text(
                          '\u6a21\u677f\u5fbd\u6807 $badgeText',
                          'Badge $badgeText',
                        ),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildToneChip(
                context,
                icon: Icons.grid_view_outlined,
                label: '${_fields.length} ${_text('个字段', 'fields')}',
                tint: theme.colorScheme.onPrimaryContainer,
              ),
              _buildToneChip(
                context,
                icon: Icons.auto_awesome_mosaic_outlined,
                label: _text('浅色样式优化中', 'Light mode refined'),
                tint: theme.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _softSurface(
                theme,
                tint: theme.colorScheme.primary,
                tintAlpha: 22,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: heroEdge.withAlpha(90)),
            ),
            child: Text(
              _text(
                '这张卡现在承担模板首页的“封面”职责：先建立名称气质，再往下进入字段结构和预览。',
                'This cover now sets the visual tone before the field structure and preview area below.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _EditorMetric(
                label: '\u5b57\u6bb5\u6570',
                value: '${_fields.length}',
              ),
              _EditorMetric(
                label: '\u5fc5\u586b',
                value:
                    '${_fields.where((field) => field.attributes.isRequired).length}',
              ),
              _EditorMetric(
                label: '\u4fdd\u5bc6',
                value:
                    '${_fields.where((field) => field.attributes.isSecret).length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: _softSurface(
          theme,
          tint: theme.colorScheme.primary,
          tintAlpha: 8,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(88),
        ),
        boxShadow: _softCardShadows(theme, depth: 0.82),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\u57fa\u672c\u4fe1\u606f',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '\u8bbe\u7f6e\u6a21\u677f\u540d\u79f0\u4e0e\u526f\u6807\u9898\uff0c\u4e0a\u65b9\u7684\u5fbd\u6807\u4e0e\u4e0b\u65b9\u7684\u9884\u89c8\u4f1a\u540c\u6b65\u66f4\u65b0\uff0c\u8ba9\u6d45\u8272\u6a21\u5f0f\u4e0b\u7684\u53d8\u5316\u66f4\u6709\u5b58\u5728\u611f\u3002',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.templateTitleField,
                prefixIcon: const Icon(Icons.title_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtitleCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.templateSubtitleField,
                prefixIcon: const Icon(Icons.short_text_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _softSurface(
                  theme,
                  tint: theme.colorScheme.primary,
                  tintAlpha: 14,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.primary.withAlpha(40),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withAlpha(232),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      templateBadgeText(
                        _titleCtrl.text.trim().isEmpty
                            ? '\u672a\u547d\u540d\u6a21\u677f'
                            : _titleCtrl.text.trim(),
                      ),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titleCtrl.text.trim().isEmpty
                              ? '\u672a\u547d\u540d\u6a21\u677f'
                              : _titleCtrl.text.trim(),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitleCtrl.text.trim().isEmpty
                              ? '\u8fd9\u4e2a\u6a21\u677f\u4f1a\u7528\u6765\u7ec4\u7ec7\u8d26\u6237\u5b57\u6bb5\u3002'
                              : _subtitleCtrl.text.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildToneChip(
                              context,
                              icon: Icons.auto_awesome_mosaic_outlined,
                              label: '\u5fbd\u6807\u5df2\u8054\u52a8',
                            ),
                            _buildToneChip(
                              context,
                              icon: Icons.preview_outlined,
                              label:
                                  '\u9884\u89c8\u4f1a\u5b9e\u65f6\u66f4\u65b0',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(BuildContext context, int index, AccountField field) {
    final theme = Theme.of(context);
    final accent = field.attributes.isSecret
        ? theme.colorScheme.tertiary
        : field.attributes.isRequired
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;

    return Container(
      decoration: BoxDecoration(
        color: _softSurface(theme, tint: accent, tintAlpha: 6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withAlpha(36)),
        boxShadow: _softCardShadows(theme, depth: 0.72),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Opacity(
                opacity: 0.05,
                child: Icon(
                  _fieldTypeIcon(field.attributes.type),
                  size: 100,
                  color: accent,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _softSurface(theme, tint: accent, tintAlpha: 24),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _fieldTypeIcon(field.attributes.type),
                        color: accent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: '名称：',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      TextSpan(
                                        text: field.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    12,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(24),
                                  ),
                                ),
                                child: Text(
                                  'Key：${field.fieldKey}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if ((field.description ?? '').isNotEmpty) ...[
                            Text(
                              '描述：${field.description!}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.4,
                                color: theme.colorScheme.onSurface.withAlpha(
                                  200,
                                ),
                              ),
                            ),
                          ] else ...[
                            Text(
                              '未设置字段描述',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withAlpha(120),
                              ),
                            ),
                          ],
                          if ((field.attributes.hint ?? '').isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 12,
                                  color: theme.colorScheme.primary.withAlpha(
                                    160,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '提示：${field.attributes.hint!}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildToneChip(
                      context,
                      icon: _fieldTypeIcon(field.attributes.type),
                      label: _fieldTypeLabel(field.attributes.type),
                      tint: accent,
                    ),
                    if (field.attributes.isRequired)
                      _buildToneChip(
                        context,
                        icon: Icons.star_rounded,
                        label: '必填',
                        tint: theme.colorScheme.primary,
                      ),
                    if (field.attributes.isSecret)
                      _buildToneChip(
                        context,
                        icon: Icons.lock_person_outlined,
                        label: '保密',
                        tint: theme.colorScheme.tertiary,
                      ),
                    if (!field.attributes.isEditable)
                      _buildToneChip(
                        context,
                        icon: Icons.block_flipped,
                        label: '只读',
                        tint: theme.colorScheme.onSurfaceVariant,
                      ),
                    if (field.attributes.isSearchable)
                      _buildToneChip(
                        context,
                        icon: Icons.search_rounded,
                        label: '可搜索',
                        tint: theme.colorScheme.secondary,
                      ),
                    if (field.attributes.isPrimary)
                      _buildToneChip(
                        context,
                        icon: Icons.stars_outlined,
                        label: '主字段',
                        tint: theme.colorScheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _softSurface(theme, tint: accent, tintAlpha: 10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent.withAlpha(34)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '在账户编辑页中预览',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      IgnorePointer(
                        child: TextFormField(
                          enabled: false,
                          initialValue: _sampleValueForField(field),
                          decoration: InputDecoration(
                            labelText: field.label,
                            hintText: field.attributes.hint,
                            helperText: field.description?.isNotEmpty == true
                                ? field.description
                                : null,
                            helperMaxLines: 2,
                            prefixIcon: Icon(
                              _fieldTypeIcon(field.attributes.type),
                            ),
                            suffixIcon: field.attributes.isSecret
                                ? const Icon(Icons.visibility_off_outlined)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _editField(initial: field, index: index),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('编辑字段'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: '上移',
                      onPressed: index == 0
                          ? null
                          : () => _moveField(index, index - 1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: '下移',
                      onPressed: index == _fields.length - 1
                          ? null
                          : () => _moveField(index, index + 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton(
                      tooltip: '删除字段',
                      onPressed: () => _confirmRemoveField(index),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldSectionHeader(BuildContext context) {
    final theme = Theme.of(context);
    final total = _fields.length;
    final requiredCount = _fields
        .where((field) => field.attributes.isRequired)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: _softSurface(
          theme,
          tint: theme.colorScheme.secondary,
          tintAlpha: 10,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(88),
        ),
        boxShadow: _softCardShadows(theme, depth: 0.62),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u6a21\u677f\u5b57\u6bb5',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\u8fd9\u91cc\u5b9a\u4e49\u7684\u6bcf\u4e2a\u5b57\u6bb5\u90fd\u4f1a\u76f4\u63a5\u51fa\u73b0\u5728\u8d26\u6237\u7f16\u8f91\u9875\u4e2d\uff0c\u73b0\u5728\u4e5f\u4f1a\u540c\u65f6\u5e26\u51fa\u9884\u89c8\u611f\u548c\u64cd\u4f5c\u5206\u5c42\u3002',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildToneChip(
                        context,
                        icon: Icons.view_stream_outlined,
                        label: '\u5171 $total \u4e2a\u5b57\u6bb5',
                      ),
                      _buildToneChip(
                        context,
                        icon: Icons.star_outline_rounded,
                        label: '\u5fc5\u586b $requiredCount',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GreenAddButton(
              heroTag: 'add-template-field-fab',
              small: true,
              onPressed: () => _editField(),
              tooltip: AppLocalizations.of(context)!.addField,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    final overview = _buildOverviewCard(context);
    final details = _buildDetailsCard(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        if (!isWide) {
          return Column(
            children: [overview, const SizedBox(height: 24), details],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: overview),
            const SizedBox(width: 18),
            Expanded(flex: 7, child: details),
          ],
        );
      },
    );
  }

  Widget _buildFieldGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final width = constraints.maxWidth;
        final columns = width >= 980 ? 2 : 1;
        final itemWidth = columns == 1
            ? width
            : (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final entry in _fields.asMap().entries)
              SizedBox(
                width: itemWidth,
                child: _buildFieldCard(context, entry.key, entry.value),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fabBottomOffset = AppBreakpoints.isDesktop(context) ? 24.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null ? l10n.addTemplate : l10n.editTemplate,
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _softSurface(
                theme,
                tint: theme.colorScheme.primary,
                tintAlpha: 16,
              ),
              theme.scaffoldBackgroundColor,
              _softSurface(
                theme,
                tint: theme.colorScheme.tertiary,
                tintAlpha: 8,
              ),
            ],
            stops: const [0, 0.24, 1],
          ),
        ),
        child: AdaptivePage(
          desktopMaxWidth: 1320,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 120),
            children: [
              _buildTopSection(context),
              const SizedBox(height: 24),
              _buildFieldSectionHeader(context),
              const SizedBox(height: 12),
              if (_fields.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _softSurface(
                      theme,
                      tint: theme.colorScheme.secondary,
                      tintAlpha: 12,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    boxShadow: _softCardShadows(theme, depth: 0.55),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withAlpha(232),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.post_add_outlined,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '\u5f53\u524d\u8fd8\u6ca1\u6709\u5b57\u6bb5',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '\u53ef\u4ee5\u5148\u52a0\u5165\u4f60\u6700\u5e38\u4fdd\u5b58\u7684\u4fe1\u606f\uff0c\u6bd4\u5982\u7528\u6237\u540d\u3001\u5bc6\u7801\u3001\u5361\u53f7\u3001\u7f16\u53f7\u6216\u5907\u6ce8\u7b49\u5b57\u6bb5\u3002',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                )
              else
                _buildFieldGrid(context),
            ],
          ),
        ),
      ),
      floatingActionButton: SafeArea(
        minimum: EdgeInsets.only(right: 4, bottom: fabBottomOffset),
        child: GreenAddButton(
          heroTag: widget.initial == null
              ? 'save-template-fab-new'
              : 'save-template-fab-edit',
          tooltip: '\u4fdd\u5b58\u6a21\u677f',
          icon: Icons.check,
          onPressed: _save,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }
}

class _EditorMetric extends StatelessWidget {
  final String label;
  final String value;

  const _EditorMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimaryContainer.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withAlpha(210),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldEditorResult {
  final String label;
  final String rawKey;
  final String? description;
  final AccountFieldAttributes attributes;

  const _FieldEditorResult({
    required this.label,
    required this.rawKey,
    required this.description,
    required this.attributes,
  });
}

class _FieldEditorDialog extends StatefulWidget {
  final AccountField? initial;
  final bool originallyPersisted;
  final String Function(AccountFieldType) fieldTypeLabelBuilder;

  const _FieldEditorDialog({
    required this.initial,
    required this.originallyPersisted,
    required this.fieldTypeLabelBuilder,
  });

  @override
  State<_FieldEditorDialog> createState() => _FieldEditorDialogState();
}

class _FieldEditorDialogState extends State<_FieldEditorDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _hintCtrl;
  late final TextEditingController _descriptionCtrl;

  late AccountFieldType _type;
  late bool _isRequired;
  late bool _isSecret;
  late bool _isEditable;
  late bool _isSearchable;
  late bool _isCopyable;
  late bool _isPrimary;
  late TimeFieldFormat _timeFormat;

  String _text(String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _labelCtrl = TextEditingController(text: initial?.label ?? '');
    _keyCtrl = TextEditingController(text: initial?.fieldKey ?? '');
    _hintCtrl = TextEditingController(text: initial?.attributes.hint ?? '');
    _descriptionCtrl = TextEditingController(text: initial?.description ?? '');

    _type = initial?.attributes.type ?? AccountFieldType.text;
    _isRequired = initial?.attributes.isRequired ?? false;
    _isSecret = initial?.attributes.isSecret ?? false;
    _isEditable = initial?.attributes.isEditable ?? true;
    _isSearchable = initial?.attributes.isSearchable ?? false;
    _isCopyable = initial?.attributes.isCopyable ?? true;
    _isPrimary = initial?.attributes.isPrimary ?? false;
    _timeFormat = initial?.attributes.timeFormat ?? TimeFieldFormat.full;
  }

  void _submit() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('\u8bf7\u8f93\u5165\u5b57\u6bb5\u540d\u79f0\u3002'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _FieldEditorResult(
        label: label,
        rawKey: widget.originallyPersisted
            ? (widget.initial?.fieldKey ?? '')
            : _keyCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        attributes: AccountFieldAttributes(
          type: _type,
          isPrimary: _isPrimary,
          isRequired: _isRequired,
          isSecret: _isSecret,
          isEditable: _isEditable,
          isSearchable: _isSearchable,
          isCopyable: _isCopyable,
          timeFormat: _timeFormat,
          hint: _hintCtrl.text.trim().isEmpty ? null : _hintCtrl.text.trim(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _keyCtrl.dispose();
    _hintCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? '\u65b0\u589e\u5b57\u6bb5'
            : '\u7f16\u8f91\u5b57\u6bb5',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _labelCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '\u5b57\u6bb5\u540d\u79f0',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keyCtrl,
                enabled: !widget.originallyPersisted,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: '\u5b57\u6bb5\u6807\u8bc6',
                  helperText: widget.originallyPersisted
                      ? '\u5df2\u6709\u5b57\u6bb5\u6807\u8bc6\u5df2\u9501\u5b9a\uff0c\u907f\u514d\u5f71\u54cd\u5df2\u4fdd\u5b58\u7684\u8d26\u6237\u6570\u636e\u3002'
                      : '\u7528\u4e8e\u4fdd\u5b58\u6570\u636e\uff0c\u5efa\u8bae\u4f7f\u7528\u82f1\u6587\u5b57\u6bcd\u3001\u6570\u5b57\u548c\u4e0b\u5212\u7ebf\u3002',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountFieldType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: '\u5b57\u6bb5\u7c7b\u578b',
                ),
                items: AccountFieldType.values
                    .map(
                      (fieldType) => DropdownMenuItem(
                        value: fieldType,
                        child: Text(widget.fieldTypeLabelBuilder(fieldType)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _type = value);
                },
              ),
              if (_type == AccountFieldType.time) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<TimeFieldFormat>(
                  initialValue: _timeFormat,
                  decoration: const InputDecoration(
                    labelText: '\u65f6\u95f4\u683c\u5f0f',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: TimeFieldFormat.full,
                      child: Text(
                        _text(
                          '\u5168\u683c\u5f0f (YYYY-MM-DD HH:mm)',
                          'Full (YYYY-MM-DD HH:mm)',
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: TimeFieldFormat.date,
                      child: Text(
                        _text(
                          '\u4ec5\u65e5\u671f (YYYY-MM-DD)',
                          'Date only (YYYY-MM-DD)',
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: TimeFieldFormat.monthYear,
                      child: Text(
                        _text('\u6708/\u5e74 (MM/YY)', 'Month/Year (MM/YY)'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: TimeFieldFormat.time,
                      child: Text(
                        _text(
                          '\u4ec5\u65f6\u95f4 (HH:mm)',
                          'Time only (HH:mm)',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _timeFormat = value);
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _hintCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '\u63d0\u793a\u6587\u672c',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '\u5b57\u6bb5\u8bf4\u660e',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isRequired,
                contentPadding: EdgeInsets.zero,
                title: const Text('\u5fc5\u586b'),
                onChanged: (value) => setState(() => _isRequired = value),
              ),
              SwitchListTile(
                value: _isSecret,
                contentPadding: EdgeInsets.zero,
                title: const Text('\u4fdd\u5bc6\u5b57\u6bb5'),
                onChanged: (value) => setState(() => _isSecret = value),
              ),
              SwitchListTile(
                value: _isEditable,
                contentPadding: EdgeInsets.zero,
                title: const Text('\u5141\u8bb8\u7f16\u8f91'),
                onChanged: (value) => setState(() => _isEditable = value),
              ),
              SwitchListTile(
                value: _isSearchable,
                contentPadding: EdgeInsets.zero,
                title: const Text('\u53ef\u641c\u7d22'),
                onChanged: (value) => setState(() => _isSearchable = value),
              ),
              SwitchListTile(
                value: _isCopyable,
                contentPadding: EdgeInsets.zero,
                title: const Text('\u5141\u8bb8\u590d\u5236'),
                onChanged: (value) => setState(() => _isCopyable = value),
              ),
              SwitchListTile(
                value: _isPrimary,
                contentPadding: EdgeInsets.zero,
                title: const Text('\u4e3b\u5b57\u6bb5'),
                onChanged: (value) => setState(() => _isPrimary = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('\u4fdd\u5b58\u5b57\u6bb5'),
        ),
      ],
    );
  }
}
