import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/account_item.dart';
import '../../models/account_template.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_layout.dart';
import '../../widgets/adaptive_page.dart';
import '../accounts/account_edit_view.dart';
import '../../widgets/account_list_tile.dart';
import '../../widgets/app_selectable_scrollable.dart';

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _ClearSearchIntent extends Intent {
  const _ClearSearchIntent();
}

class HomeSearchView extends StatefulWidget {
  const HomeSearchView({super.key});

  @override
  State<HomeSearchView> createState() => _HomeSearchViewState();
}

class _HomeSearchViewState extends State<HomeSearchView> {
  final SearchController _searchController = SearchController();
  final FocusNode _searchFocusNode = FocusNode();
  final Set<String> _selectedTemplateIds = {};

  String get _query => _searchController.text.trim().toLowerCase();

  Set<String> _templateIdSet(List<AccountTemplate> templates) {
    return templates.map((template) => template.templateId).toSet();
  }

  Set<String> _activeSelectedTemplateIds(List<AccountTemplate> templates) {
    final availableTemplateIds = _templateIdSet(templates);
    return _selectedTemplateIds.where(availableTemplateIds.contains).toSet();
  }

  String? _templateTitleById(List<AccountTemplate> templates, String id) {
    for (final template in templates) {
      if (template.templateId == id) return template.title;
    }
    return null;
  }

  void _pruneUnavailableTemplateFilters(List<AccountTemplate> templates) {
    if (_selectedTemplateIds.isEmpty) return;

    final availableTemplateIds = _templateIdSet(templates);
    final hasUnavailableFilter = _selectedTemplateIds.any(
      (id) => !availableTemplateIds.contains(id),
    );
    if (!hasUnavailableFilter) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedTemplateIds.removeWhere(
          (id) => !availableTemplateIds.contains(id),
        );
      });
    });
  }

  Future<void> _openAccount(BuildContext context, AccountItem account) async {
    final provider = context.read<EnhancedAppProvider>();
    final result = await Navigator.push<AccountItem>(
      context,
      MaterialPageRoute(builder: (_) => AccountEditView(initial: account)),
    );

    if (result == null || !mounted) return;
    await provider.updateAccount(result);
  }

  Future<void> _deleteAccount(BuildContext context, AccountItem account) async {
    final provider = context.read<EnhancedAppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.text('删除账户', 'Delete Account')),
        content: Text(
          context.text(
            '确定要删除“${account.name}”吗？此操作不可撤销。',
            'Are you sure you want to delete "${account.name}"? This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.text('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(context.text('删除', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.deleteAccount(account.id);
    }
  }

  List<AccountItem> _buildResults(
    List<AccountItem> accounts,
    EnhancedAppProvider provider,
  ) {
    final activeTemplateIds = _activeSelectedTemplateIds(provider.allTemplates);
    final filtered = accounts.where((account) {
      final template = provider.getTemplate(account.templateId);
      final matchesTemplate =
          activeTemplateIds.isEmpty ||
          activeTemplateIds.contains(account.templateId);

      final matchesQuery =
          _query.isEmpty ||
          account.name.toLowerCase().contains(_query) ||
          account.email.toLowerCase().contains(_query) ||
          (template?.title.toLowerCase().contains(_query) ?? false) ||
          account.data.values.any(
            (value) => value.toLowerCase().contains(_query),
          );

      return matchesTemplate && matchesQuery;
    }).toList();

    if (_query.isEmpty) {
      return [];
    }

    return filtered;
  }

  int _legacyFieldCount(AccountItem account, AccountTemplate? template) =>
      account.legacyFieldCount(template);

  Widget _buildTemplateMultiSelect(
    BuildContext context,
    List<AccountTemplate> templates,
  ) {
    final theme = Theme.of(context);
    final activeTemplateIds = _activeSelectedTemplateIds(templates);

    String label;
    if (activeTemplateIds.isEmpty) {
      label = context.text('全部模板', 'All Templates');
    } else if (activeTemplateIds.length == 1) {
      final id = activeTemplateIds.first;
      label =
          _templateTitleById(templates, id) ??
          context.text('全部模板', 'All Templates');
    } else {
      label = context.text(
        '已选 ${activeTemplateIds.length} 个模板',
        '${activeTemplateIds.length} templates selected',
      );
    }

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surface),
        elevation: const WidgetStatePropertyAll(6),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.dialog),
          ),
        ),
      ),
      builder: (context, controller, child) {
        return OutlinedButton(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.panel),
            ),
            side: BorderSide.none,
            backgroundColor: theme.colorScheme.surface.withAlpha(180),
            foregroundColor: theme.colorScheme.onSurface,
            minimumSize: const Size.fromHeight(56),
            maximumSize: const Size.fromHeight(56),
          ),
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (activeTemplateIds.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _selectedTemplateIds.clear()),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            context.text('选择模板', 'Filter by Templates'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        MenuItemButton(
          closeOnActivate: false,
          onPressed: () => setState(() => _selectedTemplateIds.clear()),
          leadingIcon: const Icon(Icons.all_inclusive, size: 20),
          child: Text(context.text('全部模板', 'All Templates')),
        ),
        const PopupMenuDivider(),
        ...templates.map((t) {
          final isSelected = activeTemplateIds.contains(t.templateId);
          return CheckboxMenuButton(
            closeOnActivate: false,
            value: isSelected,
            onChanged: (val) {
              setState(() {
                final availableTemplateIds = _templateIdSet(templates);
                _selectedTemplateIds.removeWhere(
                  (id) => !availableTemplateIds.contains(id),
                );
                if (val == true) {
                  _selectedTemplateIds.add(t.templateId);
                } else {
                  _selectedTemplateIds.remove(t.templateId);
                }
              });
            },
            child: Row(
              children: [
                Icon(t.icon, size: 18),
                const SizedBox(width: AppSpacing.md),
                Text(t.title),
              ],
            ),
          );
        }),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    EnhancedAppProvider provider,
    List<AccountItem> results,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(AppAlphas.strong),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.text('搜索', 'Search'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.text(
                        '从这里按关键字和模板直接定位账户。',
                        'Find accounts here by keywords and templates.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
              _QuickBadge(
                label: context.text(
                  '共 ${provider.allAccounts.length} 条账户',
                  '${provider.allAccounts.length} accounts',
                ),
              ),
              _QuickBadge(
                label: context.text(
                  '当前结果 ${results.length} 条',
                  '${results.length} results now',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTemplateMultiSelect(context, provider.allTemplates),
              const SizedBox(height: 14),
              SearchBar(
                controller: _searchController,
                focusNode: _searchFocusNode,
                padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                ),
                onChanged: (_) => setState(() {}),
                leading: const Icon(Icons.search),
                hintText: context.text(
                  '搜索账户...',
                  'Search accounts...',
                ),
                elevation: const WidgetStatePropertyAll<double>(0),
                backgroundColor: WidgetStatePropertyAll<Color>(
                  theme.colorScheme.surface.withAlpha(180),
                ),
                shape: WidgetStatePropertyAll<OutlinedBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.panel),
                  ),
                ),
                trailing: [
                  if (_query.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel(
    BuildContext context,
    List<AccountItem> results,
    EnhancedAppProvider provider,
  ) {
    final theme = Theme.of(context);
    final activeTemplateIds = _activeSelectedTemplateIds(provider.allTemplates);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(AppAlphas.strong),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.text('最近使用', 'Recently Used'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _query.isEmpty && activeTemplateIds.isEmpty
                  ? context.text(
                      '未输入关键字时，默认显示最近 6 条账户。',
                      'When no keyword is entered, the latest 6 accounts are shown.',
                    )
                  : context.text(
                      '当前匹配 ${results.length} 条结果。',
                      '${results.length} results match the current filters.',
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: results.isEmpty
                  ? _SearchEmptyState(
                      title: context.text(
                        '没有找到匹配项',
                        'No matching accounts',
                      ),
                      subtitle: context.text(
                        '试试切换模板或更换关键字再搜一次。',
                        'Try another template or keyword.',
                      ),
                    )
                  : AppSelectableScrollable(
                      child: ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final account = results[index];
                          final template = provider.getTemplate(
                            account.templateId,
                          );
                          final legacyFieldCount = _legacyFieldCount(
                            account,
                            template,
                          );
                          return AccountListTile(
                            account: account,
                            template: template,
                            hasMissingTemplate: template == null,
                            legacyFieldCount: legacyFieldCount,
                            linkedTotpCredentialCount: provider
                                .totpCredentialsForAccount(account.id)
                                .length,
                            density: AccountListTileDensity.search,
                            onEdit: () => _openAccount(context, account),
                            onDelete: () => _deleteAccount(context, account),
                            onTogglePin: () => provider.togglePin(account.id),
                            localeText: (ctx, zh, en) => context.text(zh, en),
                            resolveAccountName: (id) =>
                                provider.resolveAccountName(id),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EnhancedAppProvider>();
    final accounts = provider.allAccounts;
    _pruneUnavailableTemplateFilters(provider.allTemplates);
    final results = _buildResults(accounts, provider);

    final isPointer = AppLayout.isPointerDeviceOf(context);
    return Shortcuts(
      shortcuts: isPointer
          ? {
              const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                  const _FocusSearchIntent(),
              const SingleActivator(LogicalKeyboardKey.escape):
                  const _ClearSearchIntent(),
            }
          : const {},
      child: Actions(
        actions: {
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _searchFocusNode.requestFocus();
              return null;
            },
          ),
          _ClearSearchIntent: CallbackAction<_ClearSearchIntent>(
            onInvoke: (_) {
              _searchController.clear();
              setState(() {});
              return null;
            },
          ),
        },
        child: AdaptivePage(
          desktopMaxWidth: 1200,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  SizedBox(height: constraints.maxHeight * 0.03),
                  AdaptiveSection(
                    maxWidth: AppSectionWidths.hero,
                    alignment: Alignment.center,
                    child: _buildHeroCard(context, provider, results),
                  ),
                  const SizedBox(height: 18),
                  if (_query.isNotEmpty)
                    Expanded(
                      child: AdaptiveSection(
                        maxWidth: AppSectionWidths.panel,
                        child: _buildSearchPanel(context, results, provider),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}

class _QuickBadge extends StatelessWidget {
  final String label;

  const _QuickBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimaryContainer.withAlpha(AppAlphas.tint),
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SearchEmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 44, color: theme.colorScheme.outline),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
