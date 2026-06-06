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
import '../../utils/relative_time_formatter.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/app_selectable_scrollable.dart';

import 'template_edit_view.dart';

String _templateCategoryLabel(TemplateCategory category) {
  switch (category) {
    case TemplateCategory.access:
      return '访问';
    case TemplateCategory.secret:
      return '密文';
    case TemplateCategory.payment:
      return '支付';
    case TemplateCategory.identity:
      return '身份';
    case TemplateCategory.license:
      return '授权';
    case TemplateCategory.custom:
      return '自定义';
  }
}

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
          title: Text(context.text('模板已被更新', 'Template Updated')),
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
              child: Text(context.text('重载', 'Reload')),
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
        SnackBar(content: Text('该模板仍被 $usageCount 个账户使用，暂时不能删除。')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确认删除"${template.title}"吗？'),
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

    if (confirmed == true && context.mounted) {
      try {
        await provider.deleteCustomTemplate(template.templateId);
      } on TemplateInUseException catch (e) {
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(content: Text('该模板仍被 ${e.usageCount} 个账户使用，暂时不能删除。')),
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
      final existingIds = provider.allTemplates
          .map((t) => t.templateId)
          .toSet();
      final templates = parseTemplateExport(
        controller.text,
        existingIds: existingIds,
      );
      if (templates.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.noTemplatesToImport)));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importFailed)));
    }
  }

  Future<void> _openBatchExportDialog(BuildContext context) async {
    final provider = context.read<EnhancedAppProvider>();
    final l10n = AppLocalizations.of(context)!;
    final customTemplates = provider.customTemplates;

    if (customTemplates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noTemplatesToExport)));
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
                  ...customTemplates.map(
                    (t) => CheckboxListTile(
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
                    ),
                  ),
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
    final heroEdge = theme.colorScheme.primary.withAlpha(42);
    final heroSurface = AppSurfaces.soft(
      theme.colorScheme,
      tint: theme.colorScheme.primary,
      tintAlpha: 12,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              theme.colorScheme.primary.withAlpha(22),
              heroSurface,
            ),
            Color.alphaBlend(
              theme.colorScheme.tertiary.withAlpha(16),
              theme.colorScheme.tertiaryContainer,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(color: heroEdge),
        boxShadow: AppShadows.card(theme, depth: 1.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(228),
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                  border: Border.all(color: heroEdge.withAlpha(90)),
                  boxShadow: AppShadows.card(theme, depth: 0.45),
                ),
                child: Icon(
                  Icons.view_list_outlined,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.text('模板中心', 'Template Hub'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.text(
                        '为账户页统一设计字段结构与录入体验',
                        'Design field structures and editing experiences for account pages',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withAlpha(
                          AppAlphas.emphasis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildToneChip(
                context,
                icon: Icons.dashboard_customize_outlined,
                label: '$totalTemplates ${context.text('个模板', 'Templates')}',
                tint: theme.colorScheme.onPrimaryContainer,
              ),
              _buildToneChip(
                context,
                icon: Icons.tune_outlined,
                label: '$customTemplates ${context.text('个自定义', 'Custom')}',
                tint: theme.colorScheme.onPrimaryContainer,
              ),
              _buildToneChip(
                context,
                icon: Icons.inventory_2_outlined,
                label: '$usedTemplates ${context.text('个在用', 'In Use')}',
                tint: theme.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateGrid(
    BuildContext context, {
    required List<AccountTemplate> templates,
    required bool isCustomSection,
  }) {
    final provider = context.watch<EnhancedAppProvider>();

    if (templates.isEmpty) {
      final theme = Theme.of(context);
      final accent = isCustomSection
          ? theme.colorScheme.primary
          : theme.colorScheme.secondary;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppSurfaces.soft(
            theme.colorScheme,
            tint: accent,
            tintAlpha: 8,
          ),
          borderRadius: BorderRadius.circular(AppRadii.dialog),
          border: Border.all(color: accent.withAlpha(34)),
          boxShadow: AppShadows.card(theme, depth: 0.64),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppSurfaces.soft(
                  theme.colorScheme,
                  tint: accent,
                  tintAlpha: 14,
                ),
                borderRadius: BorderRadius.circular(AppRadii.button),
                border: Border.all(color: accent.withAlpha(44)),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.layers_clear_outlined, size: 24, color: accent),
            ),
            const SizedBox(height: 12),
            Text(
              isCustomSection ? '还没有自定义模板' : '当前没有可展示的内置模板',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isCustomSection ? '创建后会立即出现在这里，作为可复用的模板卡片。' : '内置模板会自动展示在这里。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final width = constraints.maxWidth;
        final columns = width >= 1180
            ? 3
            : width >= 760
            ? 2
            : 1;
        final itemWidth = columns == 1
            ? width
            : (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final template in templates)
              SizedBox(
                width: itemWidth,
                child: _TemplateCard(
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
              ),
          ],
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              theme.colorScheme.primary.withAlpha(10),
              theme.scaffoldBackgroundColor,
            ),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: AppSelectableScrollable(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 120),
          children: [
            _buildHeroCard(context, provider),
            const SizedBox(height: 12),
            Wrap(
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
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: AppSurfaces.soft(
                  theme.colorScheme,
                  tint: theme.colorScheme.primary,
                  tintAlpha: 8,
                ),
                borderRadius: BorderRadius.circular(AppRadii.dialog),
                border: Border.all(
                  color: theme.colorScheme.primary.withAlpha(30),
                ),
                boxShadow: AppShadows.card(theme, depth: 0.56),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    context,
                    title: '自定义模板',
                    subtitle: '按你的使用习惯组织字段，做成真正可复用的模板卡片。',
                  ),
                  const SizedBox(height: 14),
                  _buildTemplateGrid(
                    context,
                    templates: customTemplates,
                    isCustomSection: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: AppSurfaces.soft(
                  theme.colorScheme,
                  tint: theme.colorScheme.secondary,
                  tintAlpha: 8,
                ),
                borderRadius: BorderRadius.circular(AppRadii.dialog),
                border: Border.all(
                  color: theme.colorScheme.secondary.withAlpha(30),
                ),
                boxShadow: AppShadows.card(theme, depth: 0.56),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    context,
                    title: '内置模板',
                    subtitle: '常见账户与身份信息的默认模板，可直接作为起点使用。',
                  ),
                  const SizedBox(height: 14),
                  _buildTemplateGrid(
                    context,
                    templates: builtinTemplates,
                    isCustomSection: false,
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final isDesktop = AppLayout.isExpanded(context);
    final edgeColor = template.isCustom
        ? theme.colorScheme.primary.withAlpha(34)
        : theme.colorScheme.secondary.withAlpha(34);
    final accent = template.isCustom
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;
    final compactHeader = !isDesktop;

    return Stack(
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppSurfaces.soft(
              theme.colorScheme,
              tint: accent,
              tintAlpha: 6,
            ),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: edgeColor),
            boxShadow: AppShadows.card(theme, depth: 0.7),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      isDesktop ? AppSpacing.xl : AppSpacing.lg,
                    ),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.alphaBlend(
                            accent.withAlpha(18),
                            theme.colorScheme.primaryContainer,
                          ),
                          Color.alphaBlend(
                            theme.colorScheme.tertiary.withAlpha(14),
                            theme.colorScheme.tertiaryContainer,
                          ),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border(bottom: BorderSide(color: edgeColor)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (template.isCustom)
                          Transform.rotate(
                            angle: -0.1,
                            child: Container(
                              width: isDesktop ? 44 : 38,
                              height: isDesktop ? 44 : 38,
                              decoration: BoxDecoration(
                                color: accent.withAlpha(255),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.sm,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withAlpha(100),
                                    blurRadius: 10,
                                    offset: const Offset(-2, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                template.badgeText,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontSize: isDesktop ? 15 : 13,
                                ),
                              ),
                            ),
                          )
                        else
                          Transform.rotate(
                            angle: -0.1,
                            child: Container(
                              width: isDesktop ? 44 : 38,
                              height: isDesktop ? 44 : 38,
                              decoration: BoxDecoration(
                                color: AppSurfaces.soft(
                                  theme.colorScheme,
                                  tint: accent,
                                  tintAlpha: 12,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.sm,
                                ),
                                border: Border.all(
                                  color: accent.withAlpha(70),
                                  width: 1.4,
                                ),
                                boxShadow: AppShadows.card(theme, depth: 0.34),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                template.badgeText,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: accent,
                                  fontSize: isDesktop ? 15 : 13,
                                ),
                              ),
                            ),
                          ),
                        SizedBox(
                          height: isDesktop ? AppSpacing.lg : AppSpacing.md,
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            right: template.isCustom
                                ? (compactHeader ? 0 : 112)
                                : (compactHeader ? 0 : 66),
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: context.text('名称：', 'Name: '),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                TextSpan(
                                  text: template.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${context.text('模板描述：', 'Description: ')}${template.subTitle.isEmpty ? context.text('暂无模板描述', 'No description') : template.subTitle}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withAlpha(AppAlphas.emphasis),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(
                      isDesktop ? AppSpacing.xl : AppSpacing.lg,
                    ),
                    child: _TemplateCardContent(
                      template: template,
                      usageCount: usageCount,
                      accent: accent,
                      onOpen: onOpen,
                      onExport: onExport,
                      onDelete: onDelete,
                      compact: compactHeader,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: template.isCustom ? (compactHeader ? 10 : 12) : 14,
          right: template.isCustom ? (compactHeader ? -6 : -8) : 14,
          child: _TemplateStatusBadge(
            template: template,
            accent: accent,
            compact: compactHeader,
          ),
        ),
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _InfoChip(
              icon: templateCategoryIcon(template.category),
              label: _templateCategoryLabel(template.category),
              tint: accent,
            ),
            _InfoChip(
              icon: Icons.tune_outlined,
              label:
                  '${template.fields.length} ${context.text('字段', 'fields')}',
              tint: accent,
            ),
            if (template.parentTemplateIds.isNotEmpty)
              _InfoChip(
                icon: Icons.account_tree_outlined,
                label:
                    '${context.text('继承', 'Inherits')} ${template.parentTemplateIds.length}',
                tint: accent,
              ),
            _InfoChip(
              icon: Icons.inventory_2_outlined,
              label:
                  '${context.text('已使用', 'Used')} $usageCount ${context.text('次', 'times')}',
              tint: accent,
            ),
            if (template.lastEditedAt != null || template.modifiedAt != null)
              _InfoChip(
                icon: Icons.history,
                label: RelativeTimeFormatter.format(
                  context,
                  template.lastEditedAt ?? template.modifiedAt,
                ),
                tint: accent,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.text('字段预览', 'Field Preview'),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _FieldPreviewTags(template: template, accent: accent),
        if (template.isCustom) ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.text('编辑', 'Edit')),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _IconActionButton(
                icon: Icons.upload_outlined,
                tooltip: context.text('导出模板', 'Export Template'),
                onTap: onExport,
                accent: accent,
              ),
              const SizedBox(width: AppSpacing.xs),
              _IconActionButton(
                icon: Icons.delete_outline,
                tooltip: context.text('删除模板', 'Delete Template'),
                onTap: onDelete,
                accent: accent,
                isDestructive: true,
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.xl),
          _BuiltinTemplateFooter(accent: accent),
        ],
      ],
    );
  }
}

class _TemplateStatusBadge extends StatelessWidget {
  final AccountTemplate template;
  final Color accent;
  final bool compact;

  const _TemplateStatusBadge({
    required this.template,
    required this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!template.isCustom) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: accent.withAlpha(15),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: accent.withAlpha(50)),
        ),
        child: Text(
          context.text('内置模板', 'Built-in'),
          style: theme.textTheme.labelSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: accent.withAlpha(240),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(compact ? 38 : 60),
            blurRadius: compact ? 6 : 8,
            offset: Offset(2, compact ? 3 : 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withAlpha(compact ? 110 : 120),
          width: compact ? 1.2 : 1.5,
        ),
      ),
      child: Text(
        'CUSTOM / ${context.text('自定义', 'Custom')}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: compact ? 0.4 : 0.8,
        ),
      ),
    );

    return Transform.rotate(angle: compact ? 0.12 : 0.15, child: badge);
  }
}

class _FieldPreviewTags extends StatelessWidget {
  final AccountTemplate template;
  final Color accent;

  const _FieldPreviewTags({required this.template, required this.accent});

  IconData _fieldTypeIcon(AccountFieldType type) {
    switch (type) {
      case AccountFieldType.text:
        return Icons.text_fields_rounded;
      case AccountFieldType.password:
        return Icons.password_rounded;
      case AccountFieldType.number:
        return Icons.numbers_rounded;
      case AccountFieldType.email:
        return Icons.email_rounded;
      case AccountFieldType.phone:
        return Icons.phone_android_rounded;
      case AccountFieldType.url:
        return Icons.link_rounded;
      case AccountFieldType.time:
        return Icons.event_note_rounded;
      case AccountFieldType.custom:
        return Icons.extension_rounded;
      case AccountFieldType.accountLink:
        return Icons.account_tree_rounded;
      case AccountFieldType.templateRef:
        return Icons.account_tree_rounded;
      case AccountFieldType.subForm:
        return Icons.dynamic_feed_rounded;
      case AccountFieldType.longText:
        return Icons.notes_rounded;
      case AccountFieldType.list:
        return Icons.format_list_bulleted_rounded;
      case AccountFieldType.unknown:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final field in template.fields)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppSurfaces.soft(
                theme.colorScheme,
                tint: accent,
                tintAlpha: 10,
              ),
              borderRadius: BorderRadius.circular(AppRadii.button),
              border: Border.all(color: accent.withAlpha(38)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _fieldTypeIcon(field.attributes.type),
                  size: 13,
                  color: accent.withAlpha(200),
                ),
                const SizedBox(width: 6),
                Text(
                  field.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                    height: 1.1,
                  ),
                ),
                if (field.attributes.isSecret) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.lock_rounded,
                    size: 11,
                    color: accent.withAlpha(160),
                  ),
                ],
              ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppSurfaces.soft(theme.colorScheme, tint: tint, tintAlpha: 12),
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(color: tint.withAlpha(34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: tint,
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
            child: Icon(icon, size: 18, color: color),
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
