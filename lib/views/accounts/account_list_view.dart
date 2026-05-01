import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account_item.dart';
import '../../models/account_template.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../theme/app_design_tokens.dart';
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

class _AccountListViewState extends State<AccountListView> {
  String? _activeTemplateId;

  String _text(BuildContext context, String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

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
          _text(context, '\u5220\u9664\u8d26\u6237', 'Delete Account'),
        ),
        content: Text(
          _text(
            context,
            '\u786e\u8ba4\u5220\u9664\u201c${account.name}\u201d\u5417\uff1f\u8be5\u64cd\u4f5c\u4e0d\u53ef\u64a4\u9500\u3002',
            'Delete "${account.name}"? This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_text(context, '\u53d6\u6d88', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _text(context, '\u5220\u9664', 'Delete'),
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

  List<AccountItem> _filteredAccounts(List<AccountItem> accounts) {
    if (_activeTemplateId == null) return accounts;
    return accounts
        .where((account) => account.templateId == _activeTemplateId)
        .toList();
  }

  int _legacyFieldCount(AccountItem account, AccountTemplate? template) {
    final visibleKeys =
        template?.fields.map((field) => field.fieldKey).toSet() ?? <String>{};
    return account.data.entries.where((entry) {
      if (visibleKeys.contains(entry.key)) return false;
      return entry.value.trim().isNotEmpty;
    }).length;
  }

  List<_AccountGroup> _buildGroups(EnhancedAppProvider provider) {
    final filtered = _filteredAccounts(provider.allAccounts);
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
    final totalAccounts = provider.allAccounts.length;
    final usedTemplates = provider.allAccounts
        .map((item) => item.templateId)
        .toSet()
        .length;
    final customAccounts = provider.allAccounts
        .where(
          (item) => provider.getTemplate(item.templateId)?.isCustom ?? false,
        )
        .length;

    return AppPageHeader(
      icon: Icons.shield_outlined,
      title: _text(context, '\u8d26\u6237\u4e2d\u5fc3', 'Account Hub'),
      subtitle: _text(
        context,
        '\u4f60\u7684\u52a0\u5bc6\u4fe1\u606f\u5e93',
        'Your encrypted vault',
      ),
      metrics: [
        _StatChip(
          value: '$totalAccounts',
          label: _text(context, '\u4e2a\u8d26\u6237', 'Accounts'),
          onColor: theme.colorScheme.primary,
        ),
        _StatChip(
          value: '$usedTemplates',
          label: _text(context, '\u4e2a\u6a21\u677f', 'Templates'),
          onColor: theme.colorScheme.primary,
        ),
        _StatChip(
          value: '$customAccounts',
          label: _text(context, '\u4e2a\u81ea\u5b9a\u4e49', 'Custom'),
          onColor: theme.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

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
          const SizedBox(height: 16),
          Text(
            _text(context, '\u6682\u65e0\u8d26\u6237', 'No Accounts'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _text(
              context,
              '\u5f53\u524d\u6a21\u677f\u7b5b\u9009\u4e0b\u6ca1\u6709\u53ef\u663e\u793a\u7684\u8d26\u6237\uff0c\u53ef\u4ee5\u5207\u6362\u6a21\u677f\u6216\u65b0\u5efa\u8d26\u6237\u3002',
              'No accounts are available under the current template filter.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
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
    final label = activeTemplate?.title ?? _text(context, '全部汇总', 'Dashboard');
    final icon = activeTemplate?.icon ?? Icons.dashboard_outlined;

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surface),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      builder: (context, controller, child) {
        return InkWell(
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withAlpha(40),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
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
            _text(context, '切换模版', 'Switch Template'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        MenuItemButton(
          onPressed: () => setState(() => _activeTemplateId = null),
          leadingIcon: const Icon(Icons.dashboard_outlined, size: 20),
          child: Text(_text(context, '全部汇总', 'Dashboard')),
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
                borderRadius: BorderRadius.circular(10),
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

  Widget _buildAccountPanel(
    BuildContext context,
    EnhancedAppProvider provider,
  ) {
    final theme = Theme.of(context);
    final groups = _buildGroups(provider);

    if (groups.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.map((group) {
        final template = group.template;
        final title = template?.title ?? _text(context, '其它', 'Other');
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
                    const SizedBox(height: 4),
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
                  final accountTemplate = provider.getTemplate(
                    account.templateId,
                  );
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
                        localeText: _text,
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
              height: groups.indexOf(group) < groups.length - 1 ? 18 : 24,
            ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EnhancedAppProvider>();
    final isDesktop = AppBreakpoints.isDesktop(context);
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
                          const SizedBox(height: 16),
                          AdaptiveSection(
                            maxWidth: AppSectionWidths.panel,
                            child: _buildHeroCard(context, provider),
                          ),
                          const SizedBox(height: 20),
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
                                        _text(
                                          context,
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
                    onPressed: () => _openEditor(context),
                    tooltip: _text(context, '新建账户', 'Add Account'),
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
        color: onColor.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
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
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(999),
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
