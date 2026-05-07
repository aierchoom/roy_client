import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/account_item.dart';
import '../../models/account_template.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_layout.dart';
import '../../widgets/adaptive_page.dart';
import '../accounts/account_edit_view.dart';
import '../../widgets/account_list_tile.dart';
import '../../widgets/app_selectable_scrollable.dart';
import '../conflict_inbox_view.dart';
import '../sync/local_sync_queue_view.dart';

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

  String _text(String zh, String en) {
    if (!mounted) return en;
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

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
        title: Text(_text('\u5220\u9664\u8d26\u6237', 'Delete Account')),
        content: Text(
          _text(
            '\u786e\u5b9a\u8981\u5220\u9664\u201c${account.name}\u201d\u5417\uff1f\u6b64\u64cd\u4f5c\u4e0d\u53ef\u64a4\u9500\u3002',
            'Are you sure you want to delete "${account.name}"? This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_text('\u53d6\u6d88', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_text('\u5220\u9664', 'Delete')),
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

  int _legacyFieldCount(AccountItem account, AccountTemplate? template) {
    final visibleKeys =
        template?.fields.map((field) => field.fieldKey).toSet() ?? <String>{};
    return account.data.entries.where((entry) {
      if (visibleKeys.contains(entry.key)) return false;
      return entry.value.trim().isNotEmpty;
    }).length;
  }

  Widget _buildTemplateMultiSelect(
    BuildContext context,
    List<AccountTemplate> templates,
  ) {
    final theme = Theme.of(context);
    final activeTemplateIds = _activeSelectedTemplateIds(templates);

    String label;
    if (activeTemplateIds.isEmpty) {
      label = _text('\u5168\u90e8\u6a21\u677f', 'All Templates');
    } else if (activeTemplateIds.length == 1) {
      final id = activeTemplateIds.first;
      label =
          _templateTitleById(templates, id) ??
          _text('\u5168\u90e8\u6a21\u677f', 'All Templates');
    } else {
      label = _text(
        '\u5df2\u9009 ${activeTemplateIds.length} \u4e2a\u6a21\u677f',
        '${activeTemplateIds.length} templates selected',
      );
    }

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surface),
        elevation: const WidgetStatePropertyAll(6),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.dialog)),
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
            _text('\u9009\u62e9\u6a21\u677f', 'Filter by Templates'),
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
          child: Text(_text('\u5168\u90e8\u6a21\u677f', 'All Templates')),
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
    VoidCallback onOpenConflicts,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
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
                      _text('\u641c\u7d22', 'Search'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _text(
                        '\u4ece\u8fd9\u91cc\u6309\u5173\u952e\u5b57\u548c\u6a21\u677f\u76f4\u63a5\u5b9a\u4f4d\u8d26\u6237\u3002',
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
                label: _text(
                  '\u5171 ${provider.allAccounts.length} \u6761\u8d26\u6237',
                  '${provider.allAccounts.length} accounts',
                ),
              ),
              _QuickBadge(
                label: _text(
                  '\u5f53\u524d\u7ed3\u679c ${results.length} \u6761',
                  '${results.length} results now',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // ── Conflict Alert Banner (only shown when conflicts exist) ──
          if (provider.conflictCount > 0) ...[
            const SizedBox(height: 10),
            _ConflictAlertBanner(
              count: provider.conflictCount,
              onTap: onOpenConflicts,
              textBuilder: _text,
            ),
          ],
          if (provider.localSyncChanges.isNotEmpty) ...[
            const SizedBox(height: 10),
            _LocalSyncAlertBanner(
              count: provider.localSyncChanges.length,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LocalSyncQueueView(),
                  ),
                );
              },
              textBuilder: _text,
            ),
          ],
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
                hintText: _text(
                  '\u641c\u7d22\u8d26\u6237...',
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('\u6700\u8fd1\u4f7f\u7528', 'Recently Used'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _query.isEmpty && activeTemplateIds.isEmpty
                  ? _text(
                      '\u672a\u8f93\u5165\u5173\u952e\u5b57\u65f6\uff0c\u9ed8\u8ba4\u663e\u793a\u6700\u8fd1 6 \u6761\u8d26\u6237\u3002',
                      'When no keyword is entered, the latest 6 accounts are shown.',
                    )
                  : _text(
                      '\u5f53\u524d\u5339\u914d ${results.length} \u6761\u7ed3\u679c\u3002',
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
                      title: _text(
                        '\u6ca1\u6709\u627e\u5230\u5339\u914d\u9879',
                        'No matching accounts',
                      ),
                      subtitle: _text(
                        '\u8bd5\u8bd5\u5207\u6362\u6a21\u677f\u6216\u66f4\u6362\u5173\u952e\u5b57\u518d\u641c\u4e00\u6b21\u3002',
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
                            localeText: (ctx, zh, en) => _text(zh, en),
                            resolveAccountName: (id) => provider.resolveAccountName(id),
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
                    child: _buildHeroCard(context, provider, results, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ConflictInboxView(),
                        ),
                      );
                    }),
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

class _ConflictAlertBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  final String Function(String zh, String en) textBuilder;

  const _ConflictAlertBanner({
    required this.count,
    required this.onTap,
    required this.textBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        child: Ink(
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(color: theme.colorScheme.error.withAlpha(AppAlphas.high)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(AppAlphas.low),
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: Badge(
                    label: Text('$count'),
                    backgroundColor: Colors.white,
                    textColor: theme.colorScheme.error,
                    child: Icon(
                      Icons.merge_type_outlined,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        textBuilder(
                          '发现 $count 个同步冲突',
                          '$count sync conflict(s) detected',
                        ),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        textBuilder(
                          '点击查看并手动解决冲突字段',
                          'Tap to review and resolve field conflicts',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer.withAlpha(
                            190,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.error,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalSyncAlertBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  final String Function(String zh, String en) textBuilder;

  const _LocalSyncAlertBanner({
    required this.count,
    required this.onTap,
    required this.textBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        child: Ink(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withAlpha(96),
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(color: theme.colorScheme.primary.withAlpha(70)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(AppAlphas.low),
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: Badge(
                    label: Text('$count'),
                    backgroundColor: theme.colorScheme.primary,
                    textColor: theme.colorScheme.onPrimary,
                    child: Icon(
                      Icons.outbox_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        textBuilder(
                          '$count 项待同步变更',
                          '$count change(s) waiting to sync',
                        ),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        textBuilder(
                          '点击进入审阅并推送',
                          'Tap to review and push',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withAlpha(190),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
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
