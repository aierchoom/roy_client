import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/account_template.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../services/secure_storage_service.dart' hide TemplateInUseException;
import '../../services/service_manager.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_layout.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_selectable_scrollable.dart';

import 'template_edit_view.dart';

class TemplateListBody extends StatefulWidget {
  const TemplateListBody({super.key});

  @override
  State<TemplateListBody> createState() => _TemplateListBodyState();
}

class _TemplateListBodyState extends State<TemplateListBody> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openEditor(
    BuildContext context, {
    AccountTemplate? initial,
  }) async {
    final result = await Navigator.push<AccountTemplate>(
      context,
      MaterialPageRoute(builder: (_) => TemplateEditView(initial: initial)),
    );
    if (result == null || !context.mounted) {
      return;
    }

    final provider = context.read<EnhancedAppProvider>();
    if (initial == null) {
      await provider.addCustomTemplate(result);
      return;
    }

    try {
      await provider.updateCustomTemplate(result);
    } on TemplateStaleException {
      if (!context.mounted) return;
      final shouldReload = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.text( '模板已被更新', 'Template Updated')),
          content: Text(
            context.text(
              '该模板已被同步更新，你的本地编辑已过期。是否重载最新版本后继续编辑？',
              'This template has been updated by sync. Your local edit is stale. Reload the latest version and continue editing?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.text( '重载', 'Reload')),
            ),
          ],
        ),
      );
      if (shouldReload == true && context.mounted) {
        await provider.refresh();
        final refreshed = provider.getTemplate(result.templateId);
        if (refreshed != null && context.mounted) {
          await _openEditor(context, initial: refreshed);
        }
      }
    }
  }

  int _usageCount(EnhancedAppProvider provider, AccountTemplate template) {
    return provider.countAccountsByTemplate(template.templateId);
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

  Future<void> _deleteTemplate(
    BuildContext context,
    AccountTemplate template,
  ) async {
    final provider = context.read<EnhancedAppProvider>();
    final usageCount = _usageCount(provider, template);

    if (usageCount > 0) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '该模板仍被 $usageCount 个账户使用，暂时不能删除。',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除模板'),
        content: Text(
          '确认删除“${template.title}”吗？',
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

    if (confirmed == true && context.mounted) {
      try {
        await provider.deleteCustomTemplate(template.templateId);
      } on TemplateInUseException catch (e) {
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '该模板仍被 ${e.usageCount} 个账户使用，暂时不能删除。',
            ),
          ),
        );
      }
    }
  }

  void _showCopiedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.exportCopied)),
    );
  }

  void _exportSingle(BuildContext context, AccountTemplate template) {
    final json = encodeTemplateExport([template]);
    Clipboard.setData(ClipboardData(text: json));
    _showCopiedSnackBar(context);
  }

  Future<void> _openImportDialog(BuildContext context) async {
    final provider = context.read<EnhancedAppProvider>();
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.importTemplate),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: l10n.importHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.import),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final existingIds = provider.allTemplates.map((t) => t.templateId).toSet();
      final templates = parseTemplateExport(
        controller.text,
        existingIds: existingIds,
      );
      if (templates.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noTemplatesToImport)),
        );
        return;
      }
      for (final template in templates) {
        await provider.addCustomTemplate(template);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importSuccess(templates.length))),
      );
    } on FormatException catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importFailed)),
      );
    }
  }

  Future<void> _openBatchExportDialog(BuildContext context) async {
    final provider = context.read<EnhancedAppProvider>();
    final l10n = AppLocalizations.of(context)!;
    final customTemplates = provider.customTemplates;

    if (customTemplates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noTemplatesToExport)),
      );
      return;
    }

    final selected = <String>{...customTemplates.map((t) => t.templateId)};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.batchExportTitle),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.selectTemplates,
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  ...customTemplates.map((t) => CheckboxListTile(
                    value: selected.contains(t.templateId),
                    title: Text(t.title),
                    subtitle: Text(
                      '${t.fields.length} ${context.text('字段', 'fields')}',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (v) {
                      setDialogState(() {
                        if (v == true) {
                          selected.add(t.templateId);
                        } else {
                          selected.remove(t.templateId);
                        }
                      });
                    },
                  )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(l10n.export),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final toExport = customTemplates
        .where((t) => selected.contains(t.templateId))
        .toList();
    final json = encodeTemplateExport(toExport);
    Clipboard.setData(ClipboardData(text: json));
    _showCopiedSnackBar(context);
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isDesktop = AppLayout.isExpanded(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              (isDesktop
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.titleMedium)
                  ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context, EnhancedAppProvider provider) {
    final theme = Theme.of(context);
    final totalTemplates = provider.allTemplates.length;
    final customTemplates = provider.customTemplates.length;
    final usedTemplates = provider.allAccounts
        .map((account) => account.templateId)
        .toSet()
        .length;
    return AppPageHeader(
      icon: Icons.view_list_outlined,
      title: context.text( '模板中心', 'Template Hub'),
      subtitle: context.text('为账户页统一设计字段结构与录入体验',
        'Design field structures and editing experiences for account pages',
      ),
      metrics: [
        _buildToneChip(
          context,
          icon: Icons.dashboard_customize_outlined,
          label:
              '$totalTemplates ${context.text( '个模板', 'Templates')}',
          tint: theme.colorScheme.primary,
        ),
        _buildToneChip(
          context,
          icon: Icons.tune_outlined,
          label:
              '$customTemplates ${context.text( '个自定义', 'Custom')}',
          tint: theme.colorScheme.primary,
        ),
        _buildToneChip(
          context,
          icon: Icons.inventory_2_outlined,
          label:
              '$usedTemplates ${context.text( '个在用', 'In Use')}',
          tint: theme.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildTemplateGrid(
    BuildContext context, {
    required List<AccountTemplate> templates,
    required bool isCustomSection,
  }) {
    final provider = context.watch<EnhancedAppProvider>();
    final theme = Theme.of(context);

    if (templates.isEmpty) {
      final accent = isCustomSection
          ? theme.colorScheme.primary
          : theme.colorScheme.secondary;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.panel),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(60),
          ),
          boxShadow: AppShadows.card(theme, depth: 0.3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withAlpha(14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.layers_clear_outlined,
                size: 28,
                color: accent.withAlpha(180),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isCustomSection
                  ? '还没有自定义模板'
                  : '当前没有可展示的内置模板',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isCustomSection
                  ? '创建后会立即出现在这里，作为可复用的模板卡片。'
                  : '内置模板会自动展示在这里。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppLayout.of(context);
        final crossAxisCount = layout.isCompact ? 1 : 2;

        final cards = [
          for (final template in templates)
            _TemplateCard(
              template: template,
              usageCount: _usageCount(provider, template),
              onOpen: template.isCustom
                  ? () => _openEditor(context, initial: template)
                  : null,
              onExport: template.isCustom
                  ? () => _exportSingle(context, template)
                  : null,
              onDelete: template.isCustom
                  ? () => _deleteTemplate(context, template)
                  : null,
            ),
        ];

        return crossAxisCount == 1
            ? Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    cards[i],
                    if (i < cards.length - 1)
                      const SizedBox(height: AppSpacing.md),
                  ],
                ],
              )
            : GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1.65,
                padding: const EdgeInsets.all(AppSpacing.xl),
                crossAxisSpacing: AppSpacing.xl,
                mainAxisSpacing: AppSpacing.xl,
                children: cards,
              );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EnhancedAppProvider>();
    final customTemplates = provider.customTemplates;
    final builtinTemplates = provider.allTemplates
        .where((template) => !template.isCustom)
        .toList();
    final l10n = AppLocalizations.of(context)!;

    return AppSelectableScrollable(
      controller: _scrollController,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 120),
        children: [
            _buildHeroCard(context, provider),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addTemplate),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openImportDialog(context),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(l10n.importTemplate),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openBatchExportDialog(context),
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: Text(l10n.exportTemplate),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  context,
                  title: '自定义模板',
                  subtitle:
                      '按你的使用习惯组织字段，做成真正可复用的模板卡片。',
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTemplateGrid(
                  context,
                  templates: customTemplates,
                  isCustomSection: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  context,
                  title: '内置模板',
                  subtitle:
                      '常见账户与身份信息的默认模板，可直接作为起点使用。',
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTemplateGrid(
                  context,
                  templates: builtinTemplates,
                  isCustomSection: false,
                ),
              ],
            ),
          ],
        ),
      );
  }
}

class _TemplateCard extends StatelessWidget {
  final AccountTemplate template;
  final int usageCount;
  final VoidCallback? onOpen;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;

  const _TemplateCard({
    required this.template,
    required this.usageCount,
    this.onOpen,
    this.onExport,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = template.isCustom
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(AppRadii.panel),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadii.panel),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(50),
                ),
                boxShadow: AppShadows.card(theme, depth: 0.4),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 720;
                    final content = _TemplateCardContent(
                      template: template,
                      usageCount: usageCount,
                      accent: accent,
                      onOpen: onOpen,
                      onExport: onExport,
                      onDelete: onDelete,
                      compact: isCompact,
                    );
                    if (isCompact) return content;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TemplateBadge(template: template, accent: accent),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: content),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          if (template.isCustom)
            Positioned(
              top: 12,
              right: -2,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 48,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withAlpha(60),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '自定义',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TemplateCardContent extends StatelessWidget {
  final AccountTemplate template;
  final int usageCount;
  final Color accent;
  final VoidCallback? onOpen;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;
  final bool compact;

  const _TemplateCardContent({
    required this.template,
    required this.usageCount,
    required this.accent,
    required this.onOpen,
    required this.onExport,
    required this.onDelete,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                template.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _TemplateTypeChip(template: template, accent: accent),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          template.subTitle.isEmpty ? '暂无模板描述' : template.subTitle,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );

    final meta = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _InfoChip(
          icon: Icons.tune_outlined,
          label: '${template.fields.length} 字段',
          tint: accent,
        ),
        if (usageCount > 0)
          _InfoChip(
            icon: Icons.inventory_2_outlined,
            label: '已使用 $usageCount 次',
            tint: accent,
          ),
      ],
    );

    final actions = template.isCustom
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconActionButton(
                icon: Icons.edit_outlined,
                tooltip: '编辑模板',
                onTap: onOpen,
                accent: accent,
              ),
              const SizedBox(width: AppSpacing.xs),
              _IconActionButton(
                icon: Icons.upload_outlined,
                tooltip: '导出模板',
                onTap: onExport,
                accent: accent,
              ),
              const SizedBox(width: AppSpacing.xs),
              _IconActionButton(
                icon: Icons.delete_outline,
                tooltip: '删除模板',
                onTap: onDelete,
                accent: accent,
                isDestructive: true,
              ),
            ],
          )
        : const SizedBox.shrink();

    final bottomActions = template.isCustom
        ? actions
        : _BuiltinTemplateFooter(accent: accent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TemplateBadge(template: template, accent: accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: header),
            ],
          ),
        ] else
          header,
        const SizedBox(height: AppSpacing.lg),
        if (compact) ...[
          meta,
          const SizedBox(height: AppSpacing.md),
          _FieldPreviewTags(template: template, accent: accent),
          const SizedBox(height: AppSpacing.lg),
          bottomActions,
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    meta,
                    const SizedBox(height: AppSpacing.md),
                    _FieldPreviewTags(
                      template: template,
                      accent: accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: bottomActions,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TemplateBadge extends StatelessWidget {
  final AccountTemplate template;
  final Color accent;

  const _TemplateBadge({required this.template, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withAlpha(40),
            accent.withAlpha(80),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withAlpha(50)),
      ),
      child: Text(
        template.badgeText,
        style: theme.textTheme.titleMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TemplateTypeChip extends StatelessWidget {
  final AccountTemplate template;
  final Color accent;

  const _TemplateTypeChip({required this.template, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withAlpha(18),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: accent.withAlpha(40)),
      ),
      child: Text(
        template.isCustom ? '自定义' : '内置',
        style: theme.textTheme.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _FieldPreviewTags extends StatelessWidget {
  final AccountTemplate template;
  final Color accent;

  const _FieldPreviewTags({required this.template, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayFields = template.fields.take(5).toList();
    final remaining = template.fields.length - displayFields.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final field in displayFields)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withAlpha(12),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: accent.withAlpha(50),
              ),
            ),
            child: Text(
              field.label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: accent.withAlpha(200),
                height: 1.1,
              ),
            ),
          ),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              '+$remaining',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withAlpha(16),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: tint.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint.withAlpha(180)),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tint.withAlpha(220),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color accent;
  final bool isDestructive;

  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    required this.accent,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDestructive
                  ? theme.colorScheme.errorContainer.withAlpha(40)
                  : theme.colorScheme.surfaceContainerHighest.withAlpha(60),
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _BuiltinTemplateFooter extends StatelessWidget {
  final Color accent;

  const _BuiltinTemplateFooter({required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withAlpha(28),
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(color: accent.withAlpha(55)),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.touch_app_outlined,
            size: 16,
            color: accent.withAlpha(160),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '点击卡片使用此模板',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(140),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class TemplateListView extends StatelessWidget {
  const TemplateListView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.templatesTitle)),
      body: const AdaptivePage(
        desktopMaxWidth: 1320,
        child: TemplateListBody(),
      ),
    );
  }
}
