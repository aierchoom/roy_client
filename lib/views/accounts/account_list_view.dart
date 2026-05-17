import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../debug/qa_debug_menu.dart';
import '../../l10n/app_text_extension.dart';
import '../../models/account_item.dart';
import '../../models/account_template.dart';
import '../../models/totp_credential.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../services/sensitive_clipboard_service.dart';
import '../../services/totp_service.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_layout.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/inbox/inbox_hero_metrics.dart';
import '../../widgets/green_add_button.dart';
import '../../widgets/account_list_tile.dart';
import 'account_edit_view.dart';
import 'totp_credential_edit_view.dart';
import '../templates/template_list_view.dart';

class AccountListView extends StatefulWidget {
  final bool showTemplates;
  final ValueChanged<bool>? onShowTemplatesChanged;

  const AccountListView({
    super.key,
    this.showTemplates = false,
    this.onShowTemplatesChanged,
  });

  @override
  State<AccountListView> createState() => _AccountListViewState();
}

enum _VaultCategoryFilter { all, totp }

class _AccountListViewState extends State<AccountListView> {
  String? _activeTemplateId;
  _VaultCategoryFilter _categoryFilter = _VaultCategoryFilter.all;
  Timer? _totpTimer;

  @override
  void initState() {
    super.initState();
    _totpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _categoryFilter == _VaultCategoryFilter.totp) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _totpTimer?.cancel();
    super.dispose();
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
        title: Text(context.text('删除账户', 'Delete Account')),
        content: Text(
          context.text(
            '确认删除“${account.name}”吗？该操作不可撤销。',
            'Delete "${account.name}"? This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.text('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.text('删除', 'Delete'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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

  int _legacyFieldCount(AccountItem account, AccountTemplate? template) =>
      account.legacyFieldCount(template);

  List<AccountItem> _categoryFilteredAccounts(EnhancedAppProvider provider) {
    return _filteredAccounts(provider.allAccounts);
  }

  List<_AccountGroup> _buildGroups(EnhancedAppProvider provider) {
    final filtered = _categoryFilteredAccounts(provider);
    // Pinned items first within each group
    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return 0;
    });
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
      case _VaultCategoryFilter.all:
        title = context.text('保险库', 'Vault');
        subtitle = context.text('你的加密信息库', 'Your encrypted vault');
        countLabel = context.text('个条目', 'Items');
      case _VaultCategoryFilter.totp:
        title = '2FA';
        subtitle = context.text('动态验证码管理', 'Authenticator code management');
        countLabel = context.text('项', 'Items');
    }

    if (_categoryFilter == _VaultCategoryFilter.totp) {
      final credentials = provider.totpCredentials;
      final linkedCount = credentials.fold<int>(
        0,
        (sum, c) => sum + c.linkedAccountIds.length,
      );
      return AppPageHeader(
        icon: Icons.verified_user_outlined,
        title: title,
        subtitle: subtitle,
        metrics: [
          MetricChip(
            value: '${credentials.length}',
            label: countLabel,
            color: theme.colorScheme.primary,
          ),
          MetricChip(
            value: '$linkedCount',
            label: context.text('关联', 'Links'),
            color: theme.colorScheme.primary,
          ),
        ],
      );
    }

    return AppPageHeader(
      icon: Icons.shield_outlined,
      title: title,
      subtitle: subtitle,
      metrics: [
        MetricChip(
          value: '$totalItems',
          label: countLabel,
          color: theme.colorScheme.primary,
        ),
        MetricChip(
          value: '$usedTemplates',
          label: context.text('个模板', 'Templates'),
          color: theme.colorScheme.primary,
        ),
        MetricChip(
          value: '$secretItems',
          label: context.text('个保密', 'Secrets'),
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    String title;
    String message;
    switch (_categoryFilter) {
      case _VaultCategoryFilter.all:
        title = context.text('暂无条目', 'No Items');
        message = context.text(
          '保险库中还没有任何内容，点击右下角按钮开始添加。',
          'Your vault is empty. Tap the button to add items.',
        );
      case _VaultCategoryFilter.totp:
        title = context.text('暂无 2FA', 'No 2FA Items');
        message = context.text(
          '尚无动态验证码，点击右下角按钮添加。',
          'No authenticator codes yet. Tap the button to add one.',
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
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SegmentedButton<_VaultCategoryFilter>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: _VaultCategoryFilter.all,
            label: Text(context.text('全部', 'All')),
            icon: const Icon(Icons.dashboard_outlined, size: 16),
          ),
          ButtonSegment(
            value: _VaultCategoryFilter.totp,
            label: const Text('2FA'),
            icon: const Icon(Icons.verified_user_outlined, size: 16),
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
              return theme.colorScheme.primary;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return theme.colorScheme.onPrimary;
            }
            return theme.colorScheme.onSurfaceVariant;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BorderSide(color: theme.colorScheme.primary, width: 1);
            }
            return BorderSide(
              color: theme.colorScheme.outlineVariant.withAlpha(60),
              width: 0.5,
            );
          }),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          textStyle: WidgetStateProperty.all(
            theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          iconSize: WidgetStateProperty.all(16),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
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
    final label = activeTemplate?.title ?? context.text('全部汇总', 'Dashboard');
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
        return GestureDetector(
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
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
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
            context.text('切换模版', 'Switch Template'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        MenuItemButton(
          onPressed: () => setState(() => _activeTemplateId = null),
          leadingIcon: const Icon(Icons.dashboard_outlined, size: 20),
          child: Text(context.text('全部汇总', 'Dashboard')),
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
    final title = template?.title ?? context.text('其它', 'Other');
    final subtitle = template?.subTitle.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (template != null) ...[
                    Transform.rotate(
                      angle: -0.1,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: template.isCustom
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(
                            color: template.isCustom
                                ? Colors.white.withAlpha(180)
                                : theme.colorScheme.primary.withAlpha(60),
                            width: template.isCustom ? 1.5 : 1,
                          ),
                          boxShadow: template.isCustom
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withAlpha(
                                      100,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(-1, 3),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withAlpha(
                                      30,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          template.badgeText,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: template.isCustom
                                ? Colors.white
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                    onTogglePin: () => provider.togglePin(account.id),
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

  // ── TOTP helpers ──

  Future<void> _openTotpEditor(
    BuildContext context, {
    TotpCredential? initial,
  }) async {
    final result = await Navigator.push<TotpCredential>(
      context,
      MaterialPageRoute(
        builder: (_) => TotpCredentialEditView(initial: initial),
      ),
    );
    if (result == null || !context.mounted) return;
    final provider = context.read<EnhancedAppProvider>();
    if (initial == null) {
      await provider.addTotpCredential(result);
    } else {
      await provider.updateTotpCredential(result);
    }
  }

  void _showQaDebugSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('QA Debug', style: Theme.of(ctx).textTheme.titleLarge),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add, color: Colors.green),
                title: const Text('+1 随机账户'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  QaDebugMenu.injectRandomAccounts(context, 1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_box, color: Colors.green),
                title: const Text('+5 随机账户'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  QaDebugMenu.injectRandomAccounts(context, 5);
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_add, color: Colors.green),
                title: const Text('+10 随机账户'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  QaDebugMenu.injectRandomAccounts(context, 10);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: Colors.blue,
                ),
                title: const Text('按模板新增'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showTemplatePickerForMock(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('清空所有账户'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  QaDebugMenu.clearAllAccounts(context);
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  void _showTemplatePickerForMock(BuildContext context) {
    final provider = context.read<EnhancedAppProvider>();
    final templates = provider.allTemplates;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择模板', style: Theme.of(ctx).textTheme.titleLarge),
              const Divider(),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  itemBuilder: (_, i) {
                    final t = templates[i];
                    return ListTile(
                      leading: Icon(t.displayIcon),
                      title: Text(t.title),
                      subtitle: Text('${t.fields.length} 个字段'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TemplateCountButton(
                            label: '+1',
                            onTap: () {
                              Navigator.of(ctx).pop();
                              QaDebugMenu.injectAccountFromTemplate(context, t);
                            },
                          ),
                          const SizedBox(width: 4),
                          _TemplateCountButton(
                            label: '+5',
                            onTap: () {
                              Navigator.of(ctx).pop();
                              QaDebugMenu.injectAccountsFromTemplate(
                                context,
                                t,
                                5,
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          _TemplateCountButton(
                            label: '+10',
                            onTap: () {
                              Navigator.of(ctx).pop();
                              QaDebugMenu.injectAccountsFromTemplate(
                                context,
                                t,
                                10,
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTotpCredential(
    BuildContext context,
    TotpCredential credential,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.text('删除 2FA', 'Delete 2FA')),
        content: Text(
          context.text(
            '确认删除"${credential.displayLabel}"吗？',
            'Delete "${credential.displayLabel}"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.text('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.text('删除', 'Delete'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<EnhancedAppProvider>().deleteTotpCredential(
        credential.id,
      );
    }
  }

  Future<void> _copyTotpCode(BuildContext context, TotpCode code) async {
    await SensitiveClipboardService.copy(
      text: code.value,
      level: ClipboardRiskLevel.high,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.text('验证码已复制', 'Code copied.'))),
    );
  }

  Widget _buildTotpCredentialCard(
    BuildContext context,
    EnhancedAppProvider provider,
    TotpCredential credential,
  ) {
    final theme = Theme.of(context);
    final linkedAccounts = credential.linkedAccountIds
        .map(provider.getAccount)
        .whereType<AccountItem>()
        .toList(growable: false);

    late final TotpCode code;
    try {
      code = const TotpService().generate(credential.config);
    } catch (error) {
      return ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(credential.displayLabel),
        subtitle: Text(error.toString()),
        trailing: IconButton(
          tooltip: context.text('编辑', 'Edit'),
          onPressed: () => _openTotpEditor(context, initial: credential),
          icon: const Icon(Icons.edit_outlined),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
          ClipRect(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        credential.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      linkedAccounts.isEmpty
                          ? context.text('未关联账号', 'No linked account')
                          : linkedAccounts.map((a) => a.name).join(' / '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
                IconButton(
                  tooltip: context.text('编辑', 'Edit'),
                  onPressed: () => _openTotpEditor(context, initial: credential),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: context.text('删除', 'Delete'),
                  onPressed: () => _deleteTotpCredential(context, credential),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  code.value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.text('复制验证码', 'Copy code'),
                onPressed: () => _copyTotpCode(context, code),
                icon: const Icon(Icons.content_copy_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: code.secondsRemaining / code.period,
            minHeight: 5,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ],
      ),
    );
  }

  Widget _buildTotpPanel(BuildContext context, EnhancedAppProvider provider) {
    final credentials = provider.totpCredentials;
    if (credentials.isEmpty) return _buildEmptyState(context);

    final layout = AppLayout.of(context);
    final children = credentials.map((c) {
      return _buildTotpCredentialCard(context, provider, c);
    }).toList();

    if (layout.isExpanded) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = (constraints.maxWidth - AppSpacing.lg) / 2;
          return Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: children.map((child) {
              return SizedBox(width: columnWidth, child: child);
            }).toList(),
          );
        },
      );
    }

    return Column(
      children: credentials.map((credential) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildTotpCredentialCard(context, provider, credential),
        );
      }).toList(),
    );
  }

  Widget _buildAccountPanel(
    BuildContext context,
    EnhancedAppProvider provider,
  ) {
    final groups = _buildGroups(provider);

    if (groups.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          if (!widget.showTemplates) ...[
                            const SizedBox(height: AppSpacing.lg),
                            AdaptiveSection(
                              maxWidth: AppSectionWidths.panel,
                              child: _buildHeroCard(context, provider),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AdaptiveSection(
                              maxWidth: AppSectionWidths.panel,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: ClipRect(
                                  child: OverflowBar(
                                    spacing: AppSpacing.sm,
                                    overflowSpacing: AppSpacing.sm,
                                    overflowAlignment: OverflowBarAlignment.start,
                                    children: [
                                      _buildCategoryFilterBar(context),
                                      if (_categoryFilter !=
                                          _VaultCategoryFilter.totp)
                                        _buildModernTemplateDropdown(
                                          context,
                                          provider.allTemplates,
                                          provider.allAccounts,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                    // Scrollable content
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: widget.showTemplates
                            ? const TemplateListBody(key: ValueKey('templates'))
                            : Stack(
                                key: const ValueKey('accounts'),
                                children: [
                                  ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(context)
                                        .copyWith(
                                          physics:
                                              const ClampingScrollPhysics(),
                                        ),
                                    child: RefreshIndicator(
                                      onRefresh: () => provider.refresh(),
                                      child: ListView(
                                        padding: EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          fabBottomOffset + 80,
                                        ),
                                        children: [
                                          if (_categoryFilter ==
                                              _VaultCategoryFilter.totp)
                                            _buildTotpPanel(context, provider)
                                          else
                                            _buildAccountPanel(
                                              context,
                                              provider,
                                            ),
                                        ],
                                      ),
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
                                              theme.scaffoldBackgroundColor
                                                  .withAlpha(0),
                                              theme.scaffoldBackgroundColor
                                                  .withAlpha(180),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.showTemplates) ...[
                if (kDebugMode)
                  Positioned(
                    right: 20,
                    bottom: fabBottomOffset + 72,
                    child: SafeArea(
                      top: false,
                      minimum: EdgeInsets.zero,
                      child: FloatingActionButton.small(
                        heroTag: 'qa-debug-fab',
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        onPressed: () => _showQaDebugSheet(context),
                        child: const Icon(Icons.bug_report),
                      ),
                    ),
                  ),
                Positioned(
                  right: 20,
                  bottom: fabBottomOffset,
                  child: SafeArea(
                    top: false,
                    minimum: EdgeInsets.zero,
                    child: GreenAddButton(
                      heroTag: _categoryFilter == _VaultCategoryFilter.totp
                          ? 'add-totp-fab'
                          : 'add-account-fab',
                      onPressed: _categoryFilter == _VaultCategoryFilter.totp
                          ? () => _openTotpEditor(context)
                          : () => _openEditor(context),
                      tooltip: context.text('新建', 'Add'),
                    ),
                  ),
                ),
              ],
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
        '共 $count 条',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TemplateCountButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TemplateCountButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withAlpha(100),
            ),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
