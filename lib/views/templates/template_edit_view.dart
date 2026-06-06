import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/account_item.dart';
import '../../models/account_template.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../utils/field_presets.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/edit_metadata_row.dart';
import '../../widgets/green_add_button.dart';
import '../../widgets/template_edit_widgets.dart';
import '../../widgets/template_inheritance_picker.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_layout.dart';

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
  List<String> _parentTemplateIds = [];

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _titleCtrl.text = widget.initial!.title;
      _subtitleCtrl.text = widget.initial!.subTitle;
      _fields = List<AccountField>.of(widget.initial!.fields);
      _parentTemplateIds = List<String>.of(widget.initial!.parentTemplateIds);
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

    final resolvedForSave = _getResolvedFields();
    if (resolvedForSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少添加一个字段或选择一个父模板。'),
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
      iconCodePoint: null,
      category: inferTemplateCategory(title: title, fields: _fields),
      fields: List<AccountField>.of(_fields),
      parentTemplateIds: List<String>.of(_parentTemplateIds),
      isCustom: true,
      createdAt: widget.initial?.createdAt,
      modifiedAt: widget.initial?.modifiedAt,
      lastEditedBy: widget.initial?.lastEditedBy,
      lastEditedAt: widget.initial?.lastEditedAt,
      hlc: widget.initial?.hlc,
      serverVersion: widget.initial?.serverVersion ?? 0,
      syncStatus: widget.initial?.syncStatus ?? SyncStatus.pendingPush,
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

  String _sampleValueForField(AccountField field) {
    if (field.attributes.isSecret) return '••••••••';
    if (field.attributes.isReference) return '关联 2FA';

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
      case AccountFieldType.unknown:
        return field.attributes.hint ?? '';
      case AccountFieldType.accountLink:
        return '关联账户';
      case AccountFieldType.templateRef:
        return '关联模板';
      case AccountFieldType.subForm:
        return '嵌套子表单';
      case AccountFieldType.longText:
        return '多行文本';
      case AccountFieldType.list:
        return '列表';
    }
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
        color: AppSurfaces.soft(theme.colorScheme, tint: accent, tintAlpha: 16),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: accent.withAlpha(AppAlphas.low)),
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

  List<AccountTemplate> _safeGetAllTemplates() {
    try {
      return context.read<EnhancedAppProvider>().allTemplates;
    } catch (_) {
      return [];
    }
  }

  Future<void> _editField({AccountField? initial, int? index}) async {
    final originallyPersisted =
        initial != null &&
        (widget.initial?.fields.any(
              (field) => field.fieldKey == initial.fieldKey,
            ) ??
            false);

    final result = await showDialog<FieldEditorResult>(
      context: context,
      builder: (dialogContext) {
        final templates = _safeGetAllTemplates();
        final selfId = widget.initial?.templateId;
        final templateMap = <String, String>{
          for (final t in templates)
            if (t.templateId != selfId) t.templateId: t.title,
        };
        return FieldEditorDialog(
          initial: initial,
          originallyPersisted: originallyPersisted,
          fieldTypeLabelBuilder: fieldTypeLabel,
          availableTemplates: templateMap,
        );
      },
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
        title: const Text('删除字段'),
        content: Text(
          usageCount > 0
              ? '确认从模板中删除“${field.label}”吗？\n\n该模板目前被 $usageCount 个账户使用。删除后，系统会保留历史账户中的原始值，避免在后续保存时被默默删掉。'
              : '确认从模板中删除“${field.label}”吗？',
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          ? '未命名模板'
          : _titleCtrl.text.trim(),
    );
    final heroEdge = theme.colorScheme.primary.withAlpha(42);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              theme.colorScheme.primary.withAlpha(AppAlphas.subtle),
              theme.colorScheme.primaryContainer,
            ),
            Color.alphaBlend(
              theme.colorScheme.tertiary.withAlpha(AppAlphas.tint),
              theme.colorScheme.tertiaryContainer,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: heroEdge),
        boxShadow: AppShadows.card(theme, depth: 1.1),
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
                  color: theme.colorScheme.surface.withAlpha(AppAlphas.surface),
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                  boxShadow: AppShadows.card(theme, depth: 0.45),
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
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '模板描述：${_subtitleCtrl.text.trim().isEmpty ? '先把字段结构设计清楚，后续录入和维护都会轻松很多。' : _subtitleCtrl.text.trim()}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withAlpha(
                          210,
                        ),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimaryContainer.withAlpha(
                          18,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        context.text(
                          '模板徽标 $badgeText',
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
                label: '${_fields.length} ${context.text('个字段', 'fields')}',
                tint: theme.colorScheme.onPrimaryContainer,
              ),
              _buildToneChip(
                context,
                icon: Icons.auto_awesome_mosaic_outlined,
                label: context.text('浅色样式优化中', 'Light mode refined'),
                tint: theme.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppSurfaces.soft(
                theme.colorScheme,
                tint: theme.colorScheme.primary,
                tintAlpha: 22,
              ),
              borderRadius: BorderRadius.circular(AppRadii.panel),
              border: Border.all(color: heroEdge.withAlpha(AppAlphas.strong)),
            ),
            child: Text(
              context.text(
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
              EditorMetric(
                label: '字段数',
                value: '${_fields.length}',
              ),
              EditorMetric(
                label: '必填',
                value:
                    '${_fields.where((field) => field.attributes.isRequired).length}',
              ),
              EditorMetric(
                label: '保密',
                value:
                    '${_fields.where((field) => field.attributes.isSecret).length}',
              ),
            ],
          ),
          if (widget.initial != null) ...[
            const SizedBox(height: 10),
            EditMetadataRow(
              editedAt: widget.initial!.lastEditedAt ?? widget.initial!.modifiedAt,
              editedBy: widget.initial!.lastEditedBy,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.soft(
          theme.colorScheme,
          tint: theme.colorScheme.primary,
          tintAlpha: 8,
        ),
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(AppAlphas.high),
        ),
        boxShadow: AppShadows.card(theme, depth: 0.82),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '基本信息',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '设置模板名称与副标题，上方的徽标与下方的预览会同步更新，让浅色模式下的变化更有存在感。',
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
            const SizedBox(height: AppSpacing.md),
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
                color: AppSurfaces.soft(
                  theme.colorScheme,
                  tint: theme.colorScheme.primary,
                  tintAlpha: 14,
                ),
                borderRadius: BorderRadius.circular(AppRadii.panel),
                border: Border.all(
                  color: theme.colorScheme.primary.withAlpha(AppAlphas.low),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withAlpha(
                        AppAlphas.surface,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.panel),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      templateBadgeText(
                        _titleCtrl.text.trim().isEmpty
                            ? '未命名模板'
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
                              ? '未命名模板'
                              : _titleCtrl.text.trim(),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _subtitleCtrl.text.trim().isEmpty
                              ? '这个模板会用来组织账户字段。'
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
                              label: '徽标已联动',
                            ),
                            _buildToneChip(
                              context,
                              icon: Icons.preview_outlined,
                              label:
                                  '预览会实时更新',
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

  Widget _buildTargetTemplatePreview(
    BuildContext context,
    AccountField field,
    ThemeData theme,
    Color accent,
  ) {
    final targetId = field.attributes.type == AccountFieldType.subForm
        ? field.attributes.subTemplateId
        : field.attributes.targetTemplateId;
    if (targetId == null) return const SizedBox.shrink();

    final templates = _safeGetAllTemplates();
    final target = templates.cast<AccountTemplate?>().firstWhere(
          (t) => t?.templateId == targetId,
          orElse: () => null,
        );
    if (target == null) return const SizedBox.shrink();

    final previewFields = target.fields.take(5).toList();
    final isSubForm = field.attributes.type == AccountFieldType.subForm;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppSurfaces.soft(theme.colorScheme,
              tint: accent, tintAlpha: 8),
          borderRadius: BorderRadius.circular(AppRadii.panel),
          border: Border.all(color: accent.withAlpha(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSubForm
                      ? Icons.dynamic_feed_outlined
                      : Icons.account_tree_outlined,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '目标模板: ${target.title}'
                    '${isSubForm ? " (子表单)" : ""}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                Text(
                  '${target.fields.length} 字段',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (previewFields.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: previewFields.map((f) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withAlpha(140),
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(fieldTypeIcon(f.attributes.type),
                            size: 12, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          f.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(
    BuildContext context,
    int index,
    AccountField field, {
    bool isInherited = false,
    String? sourceTemplateTitle,
  }) {
    final theme = Theme.of(context);
    final accent = isInherited
        ? theme.colorScheme.onSurfaceVariant
        : field.attributes.isSecret
        ? theme.colorScheme.tertiary
        : field.attributes.isRequired
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.soft(theme.colorScheme, tint: accent, tintAlpha: 6),
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: accent.withAlpha(36)),
        boxShadow: AppShadows.card(theme, depth: 0.72),
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
                  fieldTypeIcon(field.attributes.type),
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
                        color: AppSurfaces.soft(
                          theme.colorScheme,
                          tint: accent,
                          tintAlpha: 24,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.panel),
                      ),
                      child: Icon(
                        fieldTypeIcon(field.attributes.type),
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
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.chip,
                                  ),
                                  border: Border.all(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(AppAlphas.subtle),
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
                                    .withAlpha(AppAlphas.outline),
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
                                const SizedBox(width: AppSpacing.xs),
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
                      icon: fieldTypeIcon(field.attributes.type),
                      label: fieldTypeLabel(field.attributes.type),
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
                if (field.attributes.type == AccountFieldType.templateRef ||
                    field.attributes.type == AccountFieldType.subForm)
                  _buildTargetTemplatePreview(
                    context,
                    field,
                    theme,
                    accent,
                  ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppSurfaces.soft(
                      theme.colorScheme,
                      tint: accent,
                      tintAlpha: 10,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.panel),
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
                              fieldTypeIcon(field.attributes.type),
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
                if (isInherited) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.account_tree_outlined,
                          size: 14, color: accent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          sourceTemplateTitle != null
                              ? '继承自 "$sourceTemplateTitle"'
                              : '继承字段',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                if (!isInherited)
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

  Widget _buildInheritanceSection(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    EnhancedAppProvider? provider;
    try {
      provider = context.read<EnhancedAppProvider>();
    } catch (_) {
      return const SizedBox.shrink();
    }
    final allTemplates = provider.allTemplates;
    final parentTemplates = allTemplates
        .where((t) => _parentTemplateIds.contains(t.templateId))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.soft(
          theme.colorScheme,
          tint: colors.tertiary,
          tintAlpha: 10,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(88)),
        boxShadow: AppShadows.card(theme, depth: 0.55),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree_outlined, color: colors.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '父模板继承',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '选择一个或多个模板作为字段来源。继承字段不可编辑，需在原模板修改。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (parentTemplates.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: parentTemplates.map((t) {
                  return Chip(
                    label: Text(t.title),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() {
                      _parentTemplateIds.remove(t.templateId);
                    }),
                    backgroundColor: colors.tertiary.withAlpha(30),
                    side: BorderSide(color: colors.tertiary.withAlpha(80)),
                  );
                }).toList(),
              ),
            ],
            if (parentTemplates.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _resolveFieldsPreview(allTemplates),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showInheritancePicker(context, allTemplates),
                  icon: const Icon(Icons.add_outlined, size: 18),
                  label: const Text('添加父模板'),
                ),
                if (_parentTemplateIds.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _parentTemplateIds.clear()),
                    child: const Text('清除全部'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns all fields visible in this template: inherited fields first,
  /// then own fields. Own fields with the same [AccountField.fieldKey] as an
  /// inherited field override it.
  List<_ResolvedField> _getResolvedFields() {
    final templates = _safeGetAllTemplates();
    final templateById = <String, AccountTemplate>{
      for (final t in templates) t.templateId: t,
    };

    final inherited = <String, _ResolvedField>{};
    final seenKeys = <String>{};
    final visited = <String>{};

    void collect(String id, int depth) {
      if (depth > 5 || !visited.add(id)) return;
      final parent = templateById[id];
      if (parent == null) return;
      for (final pid in parent.parentTemplateIds) {
        collect(pid, depth + 1);
      }
      for (final field in parent.fields) {
        if (!seenKeys.contains(field.fieldKey)) {
          seenKeys.add(field.fieldKey);
          inherited[field.fieldKey] = _ResolvedField(
            field: field,
            sourceTemplateTitle: parent.title,
            isInherited: true,
          );
        }
      }
    }

    for (final id in _parentTemplateIds) {
      collect(id, 0);
    }

    // Own fields override inherited.
    for (final own in _fields) {
      inherited[own.fieldKey] = _ResolvedField(
        field: own,
        isInherited: false,
      );
    }

    // Return inherited first, then own, preserving order.
    final result = <_ResolvedField>[];
    for (final e in inherited.values) {
      if (e.isInherited) result.add(e);
    }
    for (final own in _fields) {
      result.add(_ResolvedField(field: own, isInherited: false));
    }
    return result;
  }

  String _resolveFieldsPreview(List<AccountTemplate> allTemplates) {
    final resolved = _getResolvedFields();
    final inherited = resolved.where((r) => r.isInherited).length;
    return '已解析字段：${resolved.length} 个（继承 $inherited + 自有 ${_fields.length}）';
  }

  Future<void> _showInheritancePicker(
    BuildContext context,
    List<AccountTemplate> allTemplates,
  ) async {
    final parentGraph = <String, List<String>>{};
    for (final t in allTemplates) {
      parentGraph[t.templateId] = t.parentTemplateIds;
    }

    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => TemplateInheritancePicker(
        availableTemplates: allTemplates,
        selfTemplateId: widget.initial?.templateId ?? '',
        currentlySelected: _parentTemplateIds,
        parentGraph: parentGraph,
      ),
    );

    if (result != null && mounted) {
      setState(() => _parentTemplateIds = result);
    }
  }

  Widget _buildFieldSectionHeader(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = _getResolvedFields();
    final total = resolved.length;
    final requiredCount = resolved
        .where((r) => r.field.attributes.isRequired)
        .length;
    final inheritedCount = resolved.where((r) => r.isInherited).length;

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.soft(
          theme.colorScheme,
          tint: theme.colorScheme.secondary,
          tintAlpha: 10,
        ),
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(AppAlphas.high),
        ),
        boxShadow: AppShadows.card(theme, depth: 0.62),
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
                    '模板字段',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '这里定义的每个字段都会直接出现在账户编辑页中，现在也会同时带出预览感和操作分层。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildToneChip(
                        context,
                        icon: Icons.view_stream_outlined,
                        label: '共 $total 个字段',
                      ),
                      if (inheritedCount > 0)
                        _buildToneChip(
                          context,
                          icon: Icons.account_tree_outlined,
                          label: '继承 $inheritedCount',
                          tint: theme.colorScheme.tertiary,
                        ),
                      _buildToneChip(
                        context,
                        icon: Icons.star_outline_rounded,
                        label: '必填 $requiredCount',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
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
            children: [
              overview,
              const SizedBox(height: AppSpacing.xxl),
              details,
            ],
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

  Future<void> _applyFieldPreset(FieldPreset preset) async {
    final selectedIndices = await showDialog<List<int>>(
      context: context,
      builder: (_) => FieldPresetPreviewDialog(preset: preset),
    );
    if (selectedIndices == null || selectedIndices.isEmpty) return;
    if (!mounted) return;

    final existingKeys = _fields.map((f) => f.fieldKey).toSet();
    final keysSoFar = <String>{};
    final newFields = <AccountField>[];

    for (final index in selectedIndices) {
      final field = preset.fields[index];
      final uniqueKey = generateUniqueFieldKey(field.fieldKey, {
        ...existingKeys,
        ...keysSoFar,
      });
      keysSoFar.add(uniqueKey);
      newFields.add(
        AccountField(
          fieldKey: uniqueKey,
          label: field.label,
          description: field.description,
          attributes: field.attributes,
        ),
      );
    }

    setState(() => _fields.addAll(newFields));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已添加 ${preset.name} 字段组，共 ${newFields.length} 个字段',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildFieldPresetBar(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final preset in kFieldPresets)
          ActionChip(
            avatar: Icon(
              preset.icon,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            label: Text(preset.name),
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: AppSurfaces.soft(
              theme.colorScheme,
              tint: theme.colorScheme.primary,
              tintAlpha: AppAlphas.tint,
            ),
            side: BorderSide(
              color: theme.colorScheme.primary.withAlpha(AppAlphas.low),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            onPressed: () => _applyFieldPreset(preset),
          ),
      ],
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

        final resolved = _getResolvedFields();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (int i = 0; i < resolved.length; i++)
              SizedBox(
                width: itemWidth,
                child: _buildFieldCard(
                  context,
                  i,
                  resolved[i].field,
                  isInherited: resolved[i].isInherited,
                  sourceTemplateTitle: resolved[i].sourceTemplateTitle,
                ),
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
    final fabBottomOffset = AppLayout.isExpanded(context) ? 24.0 : 20.0;

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
              AppSurfaces.soft(
                theme.colorScheme,
                tint: theme.colorScheme.primary,
                tintAlpha: 16,
              ),
              theme.scaffoldBackgroundColor,
              AppSurfaces.soft(
                theme.colorScheme,
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
              if (widget.initial?.isCustom != false) ...[
                const SizedBox(height: AppSpacing.xxl),
                _buildInheritanceSection(context),
              ],
              const SizedBox(height: AppSpacing.xxl),
              _buildFieldSectionHeader(context),
              const SizedBox(height: AppSpacing.md),
              _buildFieldPresetBar(context),
              const SizedBox(height: AppSpacing.md),
              if (_getResolvedFields().isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  decoration: BoxDecoration(
                    color: AppSurfaces.soft(
                      theme.colorScheme,
                      tint: theme.colorScheme.secondary,
                      tintAlpha: 12,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.dialog),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    boxShadow: AppShadows.card(theme, depth: 0.55),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withAlpha(
                            AppAlphas.surface,
                          ),
                          borderRadius: BorderRadius.circular(AppRadii.panel),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.post_add_outlined,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '当前还没有字段',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '可以先加入你最常保存的信息，比如用户名、密码、卡号、编号或备注等字段。',
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
          tooltip: '保存模板',
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

/// A field with its resolution metadata for template inheritance.
class _ResolvedField {
  final AccountField field;
  final bool isInherited;
  final String? sourceTemplateTitle;

  const _ResolvedField({
    required this.field,
    this.isInherited = false,
    this.sourceTemplateTitle,
  });
}
