import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/account_item.dart';
import '../../models/account_template.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_layout.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/green_add_button.dart';
import '../../widgets/account_list_tile.dart';
import 'account_edit_view.dart';

class AccountListView extends StatefulWidget {
  const AccountListView({super.key});

  @override
  State<AccountListView> createState() => _AccountListViewState();
}

enum _VaultCategoryFilter { all, accounts, secureNotes }

class _AccountListViewState extends State<AccountListView> {
  String? _activeTemplateId;
  _VaultCategoryFilter _categoryFilter = _VaultCategoryFilter.all;

  Future<void> _openEditor(BuildContext context, {AccountItem? initial}) async {
    final result = await Navigator.push<AccountItem>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountEditView(
          initial: initial,
          initialTemplateId: initial == null ? _activeTemplateId : null,
        ),
      ),
    );
    if (result == null || !context.mounted) return;

    final provider = context.read<EnhancedAppProvider>();
    if (initial == null) {
      await provider.addAccount(result);
      if (!context.mounted) return;
      if (_activeTemplateId != null && _activeTemplateId != result.templateId) {
        setState(() {
          _activeTemplateId = provider.getTemplate(result.templateId) == null
              ? null
              : result.templateId;
        });
      }
      return;
    }

    await provider.updateAccount(result);
  }

  Future<void> _deleteAccount(BuildContext context, AccountItem account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.text( '\u5220\u9664\u8d26\u6237', 'Delete Account'),
        ),
        content: Text(
          context.text(
            '\u786e\u8ba4\u5220\u9664\u201c${account.name}\u201d\u5417\uff1f\u8be5\u64cd\u4f5c\u4e0d\u53ef\u64a4\u9500\u3002',
            'Delete "${account.name}"? This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.text( '\u53d6\u6d88', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.text( '\u5220\u9664', 'Delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<EnhancedAppProvider>().deleteAccount(account.id);
    }
  }

  Future<void> _pushAllLocalChanges(BuildContext context) async {
    final provider = context.read<EnhancedAppProvider>();
    final result = await provider.pushAllLocalSyncChanges();
    if (!mounted || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    if (result.success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.text( '\u63a8\u9001\u6210\u529f', 'Push succeeded'),
          ),
        ),
      );
    } else if (result.error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.text(
              '\u63a8\u9001\u5931\u8d25\uff1a${result.error}',
              'Push failed: ${result.error}',
            ),
          ),
        ),
      );
    }
  }

  Widget _buildSyncPrompt(BuildContext context, EnhancedAppProvider provider) {
    final changes = provider.localSyncChanges;
    if (changes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.text(
                    '\u5f85\u540c\u6b65\u53d8\u66f4 ${changes.length} \u9879',
                    '${changes.length} change(s) waiting to sync',
                  ),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.text(
                    '\u70b9\u51fb\u63a8\u9001\u5c06\u672c\u5730\u4fee\u6539\u540c\u6b65\u5230\u5176\u4ed6\u8bbe\u5907',
                    'Tap push to sync local changes to your other devices',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _pushAllLocalChanges(context),
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(context.text( '\u63a8\u9001', 'Push')),
          ),
        ],
      ),
    );
  }

  List<AccountItem> _filteredAccounts(List<AccountItem> accounts) {
    if (_activeTemplateId == null) return accounts;
    return accounts
        .where((account) => account.templateId == _activeTemplateId)
        .toList();
  }

  int _legacyFieldCount(AccountItem account, AccountTemplate? template) =>
      account.legacyFieldCount(template);

  List<AccountItem> _categoryFilteredAccounts(EnhancedAppProvider provider) {
    final base = _filteredAccounts(provider.allAccounts);
    switch (_categoryFilter) {
      case _VaultCategoryFilter.accounts:
        return base
            .where(
              (a) =>
                  provider.getTemplate(a.templateId)?.category !=
                  TemplateCategory.note,
            )
            .toList();
      case _VaultCategoryFilter.secureNotes:
        return base
            .where(
              (a) =>
                  provider.getTemplate(a.templateId)?.category ==
                  TemplateCategory.note,
            )
            .toList();
      case _VaultCategoryFilter.all:
        return base;
    }
  }

  List<_AccountGroup> _buildGroups(EnhancedAppProvider provider) {
    final filtered = _categoryFilteredAccounts(provider);
    final templates = provider.allTemplates;
    final groups = <_AccountGroup>[];

    for (final template in templates) {
      final items = filtered
          .where((account) => account.templateId == template.templateId)
          .toList();
      if (items.isEmpty) continue;
      groups.add(_AccountGroup(template: template, accounts: items));
    }

    final unknownAccounts = filtered
        .where((account) => provider.getTemplate(account.templateId) == null)
        .toList();
    if (unknownAccounts.isNotEmpty) {
      groups.add(_AccountGroup(template: null, accounts: unknownAccounts));
    }

    return groups;
  }

  Widget _buildHeroCard(BuildContext context, EnhancedAppProvider provider) {
    final theme = Theme.of(context);
    final items = _categoryFilteredAccounts(provider);
    final totalItems = items.length;
    final usedTemplates = items.map((item) => item.templateId).toSet().length;
    final secretItems = items.where((item) {
      final template = provider.getTemplate(item.templateId);
      return template?.fields.any((f) => f.attributes.isSecret) ?? false;
    }).length;

    String title;
    String subtitle;
    String countLabel;
    switch (_categoryFilter) {
      case _VaultCategoryFilter.accounts:
        title = context.text( '\u8d26\u53f7\u4e2d\u5fc3', 'Account Hub');
        subtitle = context.text(
          '\u4f60\u7684\u767b\u5f55\u51ed\u8bc1\u548c\u7f51\u7ad9\u8d26\u53f7',
          'Your login credentials',
        );
        countLabel = context.text( '\u4e2a\u8d26\u53f7', 'Accounts');
      case _VaultCategoryFilter.secureNotes:
        title = context.text( '\u5b89\u5168\u7b14\u8bb0', 'Secure Notes');
        subtitle = context.text(
          '\u52a0\u5bc6\u5b58\u50a8\u7684\u654f\u611f\u6587\u672c\u548c\u5bc6\u94a5',
          'Encrypted sensitive text and keys',
        );
        countLabel = context.text( '\u4e2a\u7b14\u8bb0', 'Notes');
      case _VaultCategoryFilter.all:
        title = context.text( '\u4fdd\u9669\u5e93', 'Vault');
        subtitle = context.text(
          '\u4f60\u7684\u52a0\u5bc6\u4fe1\u606f\u5e93',
          'Your encrypted vault',
        );
        countLabel = context.text( '\u4e2a\u6761\u76ee', 'Items');
    }

    return AppPageHeader(
      icon: Icons.shield_outlined,
      title: title,
      subtitle: subtitle,
      metrics: [
        _StatChip(
          value: '$totalItems',
          label: countLabel,
          onColor: theme.colorScheme.primary,
        ),
        _StatChip(
          value: '$usedTemplates',
          label: context.text( '\u4e2a\u6a21\u677f', 'Templates'),
          onColor: theme.colorScheme.primary,
        ),
        _StatChip(
          value: '$secretItems',
          label: context.text( '\u4e2a\u4fdd\u5bc6', 'Secrets'),
          onColor: theme.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    String title;
    String message;
    switch (_categoryFilter) {
      case _VaultCategoryFilter.secureNotes:
        title = context.text(
          '\u6682\u65e0\u5b89\u5168\u7b14\u8bb0',
          'No Secure Notes',
        );
        message = context.text(
          '\u5c1a\u672a\u521b\u5efa\u4efb\u4f55\u5b89\u5168\u7b14\u8bb0\uff0c\u70b9\u51fb\u53f3\u4e0b\u89d2\u6309\u94ae\u65b0\u5efa\u3002',
          'No secure notes yet. Tap the button to create one.',
        );
      case _VaultCategoryFilter.accounts:
        title = context.text( '\u6682\u65e0\u8d26\u53f7', 'No Accounts');
        message = context.text(
          '\u5f53\u524d\u6a21\u677f\u7b5b\u9009\u4e0b\u6ca1\u6709\u53ef\u663e\u793a\u7684\u8d26\u53f7\uff0c\u53ef\u4ee5\u5207\u6362\u6a21\u677f\u6216\u65b0\u5efa\u8d26\u53f7\u3002',
          'No accounts are available under the current template filter.',
        );
      case _VaultCategoryFilter.all:
        title = context.text( '\u6682\u65e0\u6761\u76ee', 'No Items');
        message = context.text(
          '\u4fdd\u9669\u5e93\u4e2d\u8fd8\u6ca1\u6709\u4efb\u4f55\u5185\u5bb9\uff0c\u70b9\u51fb\u53f3\u4e0b\u89d2\u6309\u94ae\u5f00\u59cb\u6dfb\u52a0\u3002',
          'Your vault is empty. Tap the button to add items.',
        );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 44,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SegmentedButton<_VaultCategoryFilter>(
        segments: [
          ButtonSegment(
            value: _VaultCategoryFilter.all,
            label: Text(context.text( '全部', 'All')),
            icon: const Icon(Icons.dashboard_outlined),
          ),
          ButtonSegment(
            value: _VaultCategoryFilter.accounts,
            label: Text(context.text( '账号', 'Accounts')),
            icon: const Icon(Icons.lock_outline),
          ),
          ButtonSegment(
            value: _VaultCategoryFilter.secureNotes,
            label: Text(context.text( '安全笔记', 'Notes')),
            icon: const Icon(Icons.note_outlined),
          ),
        ],
        selected: <_VaultCategoryFilter>{_categoryFilter},
        onSelectionChanged: (newSelection) {
          setState(() {
            _categoryFilter = newSelection.first;
          });
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return theme.colorScheme.primaryContainer;
            }
            return theme.colorScheme.surface;
          }),
        ),
      ),
    );
  }

  Future<void> _showAddMenu(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(context.text( '新建账号', 'New Account')),
              subtitle: Text(
                context.text(
                  '存储网站、App 或服务登录信息',
                  'Store website, app or service credentials',
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'account'),
            ),
            ListTile(
              leading: const Icon(Icons.note_outlined),
              title: Text(context.text( '新建安全笔记', 'New Secure Note')),
              subtitle: Text(
                context.text(
                  '存储 API Key、助记词、私钥等敏感文本',
                  'Store API keys, mnemonics, private keys',
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'note'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'note') {
      setState(() => _categoryFilter = _VaultCategoryFilter.secureNotes);
    }
    await _openEditor(context);
  }

  Widget _buildModernTemplateDropdown(
    BuildContext context,
    List<AccountTemplate> templates,
    List<AccountItem> allAccounts,
  ) {
    final theme = Theme.of(context);
    final sortedTemplates = List<AccountTemplate>.from(templates)
      ..sort((a, b) => a.title.compareTo(b.title));

    final activeTemplate = templates
        .where((t) => t.templateId == _activeTemplateId)
        .firstOrNull;
    final label = activeTemplate?.title ?? context.text( '全部汇总', 'Dashboard');
    final icon = activeTemplate?.icon ?? Icons.dashboard_outlined;

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surface),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
        ),
      ),
      builder: (context, controller, child) {
        return InkWell(
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(
                AppAlphas.high,
              ),
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: theme.colorScheme.primary.withAlpha(AppAlphas.low),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                if (_activeTemplateId != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTemplateId = null),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: theme.colorScheme.primary.withAlpha(150),
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: theme.colorScheme.primary.withAlpha(150),
                  ),
              ],
            ),
          ),
        );
      },
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            context.text( '切换模版', 'Switch Template'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        MenuItemButton(
          onPressed: () => setState(() => _activeTemplateId = null),
          leadingIcon: const Icon(Icons.dashboard_outlined, size: 20),
          child: Text(context.text( '全部汇总', 'Dashboard')),
        ),
        const Divider(indent: 12, endIndent: 12, height: 16),
        ...sortedTemplates.map((template) {
          final count = allAccounts
              .where((a) => a.templateId == template.templateId)
              .length;
          final isSelected = _activeTemplateId == template.templateId;

          return MenuItemButton(
            onPressed: () =>
                setState(() => _activeTemplateId = template.templateId),
            leadingIcon: Icon(
              template.icon,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            trailingIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            child: Text(
              template.title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    EnhancedAppProvider provider,
    _AccountGroup group,
    List<_AccountGroup> allGroups,
  ) {
    final theme = Theme.of(context);
    final template = group.template;
    final title = template?.title ?? context.text( '其它', 'Other');
    final subtitle = template?.subTitle.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _GroupCountChip(count: group.accounts.length),
                ],
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withAlpha(
              theme.brightness == Brightness.light ? 230 : 90,
            ),
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withAlpha(
                theme.brightness == Brightness.light ? 60 : 40,
              ),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: group.accounts.asMap().entries.map((entry) {
              final index = entry.key;
              final account = entry.value;
              final accountTemplate = provider.getTemplate(account.templateId);
              final legacyFieldCount = _legacyFieldCount(
                account,
                accountTemplate,
              );
              return Column(
                children: [
                  AccountListTile(
                    account: account,
                    template: accountTemplate,
                    hasMissingTemplate: accountTemplate == null,
                    legacyFieldCount: legacyFieldCount,
                    linkedTotpCredentialCount: provider
                        .totpCredentialsForAccount(account.id)
                        .length,
                    onEdit: () => _openEditor(context, initial: account),
                    onDelete: () => _deleteAccount(context, account),
                    localeText: (ctx, zh, en) => ctx.text(zh, en),
                    resolveAccountName: (id) => provider.resolveAccountName(id),
                  ),
                  if (index < group.accounts.length - 1)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: theme.colorScheme.outlineVariant.withAlpha(50),
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        SizedBox(
          height: allGroups.indexOf(group) < allGroups.length - 1 ? 18 : 24,
        ),
      ],
    );
  }

  Widget _buildAccountPanel(
    BuildContext context,
    EnhancedAppProvider provider,
  ) {
    final groups = _buildGroups(provider);
    final layout = AppLayout.of(context);

    if (groups.isEmpty) {
      return _buildEmptyState(context);
    }

    if (layout.isExpanded) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = (constraints.maxWidth - AppSpacing.lg) / 2;
          return Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: groups.map((group) {
              return SizedBox(
                width: columnWidth,
                child: _buildGroupSection(context, provider, group, groups),
              );
            }).toList(),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.map((group) {
        return _buildGroupSection(context, provider, group, groups);
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EnhancedAppProvider>();
    final isDesktop = AppLayout.isExpanded(context);
    final fabBottomOffset = isDesktop ? 24.0 : 28.0;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: constraints.maxHeight,
            maxWidth: constraints.maxWidth,
          ),
          child: Stack(
            children: [
              AdaptivePage(
                desktopMaxWidth: 1200,
                child: Column(
                  children: [
                    // Fixed Header section
                    Container(
                      color: Colors.transparent,
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          AdaptiveSection(
                            maxWidth: AppSectionWidths.panel,
                            child: _buildHeroCard(context, provider),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          AdaptiveSection(
                            maxWidth: AppSectionWidths.panel,
                            child: _buildCategoryFilterBar(context),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AdaptiveSection(
                            maxWidth: AppSectionWidths.panel,
                            child: _buildSyncPrompt(context, provider),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AdaptiveSection(
                            maxWidth: AppSectionWidths.panel,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        context.text(
                                          '账户资源库',
                                          'Account Library',
                                        ),
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      _buildModernTemplateDropdown(
                                        context,
                                        provider.allTemplates,
                                        provider.allAccounts,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                    // Scrollable list
                    Expanded(
                      child: Stack(
                        children: [
                          ScrollConfiguration(
                            behavior: ScrollConfiguration.of(
                              context,
                            ).copyWith(physics: const ClampingScrollPhysics()),
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(
                                8,
                                0,
                                8,
                                fabBottomOffset + 80,
                              ),
                              children: [
                                AdaptiveSection(
                                  maxWidth: AppSectionWidths.panel,
                                  child: _buildAccountPanel(context, provider),
                                ),
                              ],
                            ),
                          ),
                          // Bottom Fade interaction hint
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 60,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      theme.scaffoldBackgroundColor.withAlpha(
                                        0,
                                      ),
                                      theme.scaffoldBackgroundColor.withAlpha(
                                        180,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                bottom: fabBottomOffset,
                child: SafeArea(
                  top: false,
                  minimum: EdgeInsets.zero,
                  child: GreenAddButton(
                    heroTag: 'add-account-fab',
                    onPressed: () => _showAddMenu(context),
                    tooltip: context.text( '新建', 'Add'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountGroup {
  final AccountTemplate? template;
  final List<AccountItem> accounts;

  const _AccountGroup({required this.template, required this.accounts});
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color onColor;

  const _StatChip({
    required this.value,
    required this.label,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: onColor.withAlpha(AppAlphas.tint),
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: onColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: onColor.withAlpha(190),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCountChip extends StatelessWidget {
  final int count;

  const _GroupCountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(
          AppAlphas.outline,
        ),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '\u5171 $count \u6761',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
