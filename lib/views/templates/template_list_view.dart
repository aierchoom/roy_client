import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';

import '../../models/account_template.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../services/service_manager.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/green_add_button.dart';
import 'template_edit_view.dart';

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

    await provider.updateCustomTemplate(result);
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
    final isDesktop = AppBreakpoints.isDesktop(context);

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
    final heroSurface = _softSurface(
      theme,
      tint: theme.colorScheme.primary,
      tintAlpha: 12,
    );

    return Container(
      padding: const EdgeInsets.all(20),
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
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: heroEdge),
        boxShadow: _softCardShadows(theme, depth: 1.05),
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
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: heroEdge.withAlpha(90)),
                  boxShadow: _softCardShadows(theme, depth: 0.45),
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
                      _text(
                        context,
                        '\u6a21\u677f\u4e2d\u5fc3',
                        'Template Hub',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _text(
                        context,
                        '\u4e3a\u8d26\u6237\u9875\u7edf\u4e00\u8bbe\u8ba1\u5b57\u6bb5\u7ed3\u6784\u4e0e\u5f55\u5165\u4f53\u9a8c',
                        'Design field structures and editing experiences for account pages',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withAlpha(
                          180,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildToneChip(
                context,
                icon: Icons.dashboard_customize_outlined,
                label:
                    '$totalTemplates ${_text(context, '\u4e2a\u6a21\u677f', 'Templates')}',
                tint: theme.colorScheme.onPrimaryContainer,
              ),
              _buildToneChip(
                context,
                icon: Icons.tune_outlined,
                label:
                    '$customTemplates ${_text(context, '\u4e2a\u81ea\u5b9a\u4e49', 'Custom')}',
                tint: theme.colorScheme.onPrimaryContainer,
              ),
              _buildToneChip(
                context,
                icon: Icons.inventory_2_outlined,
                label:
                    '$usedTemplates ${_text(context, '\u4e2a\u5728\u7528', 'In Use')}',
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _softSurface(theme, tint: accent, tintAlpha: 8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withAlpha(34)),
          boxShadow: _softCardShadows(theme, depth: 0.64),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _softSurface(theme, tint: accent, tintAlpha: 14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withAlpha(44)),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.layers_clear_outlined, size: 24, color: accent),
            ),
            const SizedBox(height: 12),
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.templatesTitle)),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                Theme.of(context).colorScheme.primary.withAlpha(10),
                Theme.of(context).scaffoldBackgroundColor,
              ),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: AdaptivePage(
          desktopMaxWidth: 1320,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _buildHeroCard(context, provider),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: _softSurface(
                    Theme.of(context),
                    tint: Theme.of(context).colorScheme.primary,
                    tintAlpha: 8,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withAlpha(30),
                  ),
                  boxShadow: _softCardShadows(Theme.of(context), depth: 0.56),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      context,
                      title: '\u81ea\u5b9a\u4e49\u6a21\u677f',
                      subtitle:
                          '\u6309\u4f60\u7684\u4f7f\u7528\u4e60\u60ef\u7ec4\u7ec7\u5b57\u6bb5\uff0c\u505a\u6210\u771f\u6b63\u53ef\u590d\u7528\u7684\u6a21\u677f\u5361\u7247\u3002',
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
                  color: _softSurface(
                    Theme.of(context),
                    tint: Theme.of(context).colorScheme.secondary,
                    tintAlpha: 8,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withAlpha(30),
                  ),
                  boxShadow: _softCardShadows(Theme.of(context), depth: 0.56),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      context,
                      title: '\u5185\u7f6e\u6a21\u677f',
                      subtitle:
                          '\u5e38\u89c1\u8d26\u6237\u4e0e\u8eab\u4efd\u4fe1\u606f\u7684\u9ed8\u8ba4\u6a21\u677f\uff0c\u53ef\u76f4\u63a5\u4f5c\u4e3a\u8d77\u70b9\u4f7f\u7528\u3002',
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
    final isDesktop = AppBreakpoints.isDesktop(context);
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
            color: _softSurface(theme, tint: accent, tintAlpha: 6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: edgeColor),
            boxShadow: _softCardShadows(theme, depth: 0.7),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 18 : 14),
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
                        // Leading ID Section
                        if (template.isCustom)
                          Transform.rotate(
                            angle: -0.1,
                            child: Container(
                              width: isDesktop ? 44 : 38,
                              height: isDesktop ? 44 : 38,
                              decoration: BoxDecoration(
                                color: accent.withAlpha(255),
                                borderRadius: BorderRadius.circular(8),
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
                                color: _softSurface(
                                  theme,
                                  tint: accent,
                                  tintAlpha: 12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: accent.withAlpha(70),
                                  width: 1.4,
                                ),
                                boxShadow: _softCardShadows(theme, depth: 0.34),
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
                        SizedBox(height: isDesktop ? 12 : 10),
                        Padding(
                          padding: EdgeInsets.only(
                            right: template.isCustom
                                ? (compactHeader ? 0 : 112)
                                : (compactHeader ? 0 : 66),
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: '名称：',
                                  style: TextStyle(fontWeight: FontWeight.w900),
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
                          '模板描述：${template.subTitle.isEmpty ? '暂无模板描述' : template.subTitle}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withAlpha(180),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(isDesktop ? 18 : 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
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
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '字段预览',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _FieldPreviewTags(template: template, accent: accent),
                        if (template.isCustom) ...[
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: onOpen,
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('编辑'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: onDelete,
                                icon: const Icon(Icons.delete_outline),
                                tooltip: '删除模板',
                              ),
                            ],
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
        // Corner Badge (Sticker vs Standard)
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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withAlpha(50)),
        ),
        child: Text(
          '\u5185\u7f6e\u6a21\u677f',
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
        borderRadius: BorderRadius.circular(4),
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
        'CUSTOM / \u81ea\u5b9a\u4e49',
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
    }
  }

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
              color: _softSurface(theme, tint: accent, tintAlpha: 10),
              borderRadius: BorderRadius.circular(12),
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
        color: _softSurface(theme, tint: tint, tintAlpha: 12),
        borderRadius: BorderRadius.circular(14),
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
