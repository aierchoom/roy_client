import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';

import '../../models/account_template.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../services/secure_storage_service.dart' hide TemplateInUseException;
import '../../services/service_manager.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_layout.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_selectable_scrollable.dart';
import '../../widgets/green_add_button.dart';
import 'template_edit_view.dart';

class TemplateListView extends StatelessWidget {
  const TemplateListView({super.key});

  String _text(BuildContext context, String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
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
          title: Text(_text(context, '模板已被更新', 'Template Updated')),
          content: Text(
            _text(
              context,
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
              child: Text(_text(context, '重载', 'Reload')),
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
            '\u8be5\u6a21\u677f\u4ecd\u88ab $usageCount \u4e2a\u8d26\u6237\u4f7f\u7528\uff0c\u6682\u65f6\u4e0d\u80fd\u5220\u9664\u3002',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('\u5220\u9664\u6a21\u677f'),
        content: Text(
          '\u786e\u8ba4\u5220\u9664\u201c${template.title}\u201d\u5417\uff1f',
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
              '\u8be5\u6a21\u677f\u4ecd\u88ab ${e.usageCount} \u4e2a\u8d26\u6237\u4f7f\u7528\uff0c\u6682\u65f6\u4e0d\u80fd\u5220\u9664\u3002',
            ),
          ),
        );
      }
    }
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
      title: _text(context, '\u6a21\u677f\u4e2d\u5fc3', 'Template Hub'),
      subtitle: _text(
        context,
        '\u4e3a\u8d26\u6237\u9875\u7edf\u4e00\u8bbe\u8ba1\u5b57\u6bb5\u7ed3\u6784\u4e0e\u5f55\u5165\u4f53\u9a8c',
        'Design field structures and editing experiences for account pages',
      ),
      metrics: [
        _buildToneChip(
          context,
          icon: Icons.dashboard_customize_outlined,
          label:
              '$totalTemplates ${_text(context, '\u4e2a\u6a21\u677f', 'Templates')}',
          tint: theme.colorScheme.primary,
        ),
        _buildToneChip(
          context,
          icon: Icons.tune_outlined,
          label:
              '$customTemplates ${_text(context, '\u4e2a\u81ea\u5b9a\u4e49', 'Custom')}',
          tint: theme.colorScheme.primary,
        ),
        _buildToneChip(
          context,
          icon: Icons.inventory_2_outlined,
          label:
              '$usedTemplates ${_text(context, '\u4e2a\u5728\u7528', 'In Use')}',
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.panel),
          border: Border.all(color: theme.colorScheme.outlineVariant),
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
            const SizedBox(height: AppSpacing.md),
            Text(
              isCustomSection
                  ? '\u8fd8\u6ca1\u6709\u81ea\u5b9a\u4e49\u6a21\u677f'
                  : '\u5f53\u524d\u6ca1\u6709\u53ef\u5c55\u793a\u7684\u5185\u7f6e\u6a21\u677f',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isCustomSection
                  ? '\u521b\u5efa\u540e\u4f1a\u7acb\u5373\u51fa\u73b0\u5728\u8fd9\u91cc\uff0c\u4f5c\u4e3a\u53ef\u590d\u7528\u7684\u6a21\u677f\u5361\u7247\u3002'
                  : '\u5185\u7f6e\u6a21\u677f\u4f1a\u81ea\u52a8\u5c55\u793a\u5728\u8fd9\u91cc\u3002',
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
        final layout = AppLayout.of(context);
        final crossAxisCount = layout.isCompact ? 1 : (layout.isMedium ? 2 : 3);

        final cards = [
          for (final template in templates)
            _TemplateCard(
              template: template,
              usageCount: _usageCount(provider, template),
              onOpen: template.isCustom
                  ? () => _openEditor(context, initial: template)
                  : null,
              onDelete: template.isCustom
                  ? () => _deleteTemplate(context, template)
                  : null,
            ),
        ];

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withAlpha(
                AppAlphas.outline,
              ),
            ),
          ),
          child: crossAxisCount == 1
              ? Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i < cards.length - 1)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: AppSpacing.lg,
                          endIndent: AppSpacing.lg,
                          color: theme.colorScheme.outlineVariant.withAlpha(
                            AppAlphas.divider,
                          ),
                        ),
                    ],
                  ],
                )
              : GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: layout.isMedium ? 1.65 : 1.45,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  crossAxisSpacing: AppSpacing.lg,
                  mainAxisSpacing: AppSpacing.lg,
                  children: cards,
                ),
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.templatesTitle)),
      body: AdaptivePage(
        desktopMaxWidth: 1320,
        child: AppSelectableScrollable(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 120),
            children: [
              _buildHeroCard(context, provider),
              const SizedBox(height: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    context,
                    title: '\u81ea\u5b9a\u4e49\u6a21\u677f',
                    subtitle:
                        '\u6309\u4f60\u7684\u4f7f\u7528\u4e60\u60ef\u7ec4\u7ec7\u5b57\u6bb5\uff0c\u505a\u6210\u771f\u6b63\u53ef\u590d\u7528\u7684\u6a21\u677f\u5361\u7247\u3002',
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
                    title: '\u5185\u7f6e\u6a21\u677f',
                    subtitle:
                        '\u5e38\u89c1\u8d26\u6237\u4e0e\u8eab\u4efd\u4fe1\u606f\u7684\u9ed8\u8ba4\u6a21\u677f\uff0c\u53ef\u76f4\u63a5\u4f5c\u4e3a\u8d77\u70b9\u4f7f\u7528\u3002',
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
        ),
      ),
      floatingActionButton: GreenAddButton(
        heroTag: 'add-template-fab',
        onPressed: () => _openEditor(context),
        tooltip: l10n.addTemplate,
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final AccountTemplate template;
  final int usageCount;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  const _TemplateCard({
    required this.template,
    required this.usageCount,
    this.onOpen,
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
      child: InkWell(
        onTap: onOpen,
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
    );
  }
}

class _TemplateCardContent extends StatelessWidget {
  final AccountTemplate template;
  final int usageCount;
  final Color accent;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;
  final bool compact;

  const _TemplateCardContent({
    required this.template,
    required this.usageCount,
    required this.accent,
    required this.onOpen,
    required this.onDelete,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact) ...[
          _TemplateBadge(template: template, accent: accent),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
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
                  height: 1.3,
                ),
              ),
            ],
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
        _InfoChip(
          icon: Icons.inventory_2_outlined,
          label: '已使用 $usageCount 次',
          tint: accent,
        ),
      ],
    );

    final actions = template.isCustom
        ? Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('编辑'),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: '删除模板',
              ),
            ],
          )
        : const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: AppSpacing.md),
        meta,
        const SizedBox(height: AppSpacing.md),
        _FieldPreviewTags(template: template, accent: accent),
        if (template.isCustom) ...[
          const SizedBox(height: AppSpacing.md),
          actions,
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
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppSurfaces.soft(theme.colorScheme, tint: accent, tintAlpha: 12),
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(color: accent.withAlpha(AppAlphas.low)),
      ),
      child: Text(
        template.badgeText,
        style: theme.textTheme.titleSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withAlpha(14),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: accent.withAlpha(38)),
      ),
      child: Text(
        template.isCustom ? '自定义' : '内置',
        style: theme.textTheme.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: accent.withAlpha(28)),
            ),
            child: Text(
              field.label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: accent,
                height: 1.1,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppSurfaces.soft(theme.colorScheme, tint: tint, tintAlpha: 12),
        borderRadius: BorderRadius.circular(AppRadii.panel),
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
