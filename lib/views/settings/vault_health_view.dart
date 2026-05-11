import 'package:flutter/material.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/account_item.dart';
import '../../models/vault_health_report.dart';
import '../../services/service_manager.dart';
import '../../services/vault_health_calculator.dart';
import '../../theme/app_design_tokens.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/inbox/inbox_action_card.dart';
import '../../widgets/inbox/inbox_empty_state.dart';
import '../../widgets/inbox/inbox_models.dart';
import '../accounts/account_edit_view.dart';
import '../accounts/account_subset_view.dart';
import '../conflict_inbox_view.dart';
import '../sync/local_sync_queue_view.dart';
import '../sync_settings_view.dart';

class VaultHealthView extends StatefulWidget {
  const VaultHealthView({super.key});

  @override
  State<VaultHealthView> createState() => _VaultHealthViewState();
}

class _VaultHealthViewState extends State<VaultHealthView> {
  VaultHealthReport? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  Future<void> _calculate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final manager = ServiceManager.instance;
      final calculator = VaultHealthCalculator(
        storage: manager.storageService,
        identity: manager.identityService,
      );
      final report = await calculator.calculate();
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _report = null;
        _isLoading = false;
      });
    }
  }

  Color _gradeColor(VaultHealthGrade grade) {
    final vt = Theme.of(context).extension<AppVisualTokens>()!;
    return switch (grade) {
      VaultHealthGrade.excellent => vt.success,
      VaultHealthGrade.good => vt.success,
      VaultHealthGrade.warning => vt.warning,
      VaultHealthGrade.critical => vt.warning,
    };
  }

  String _gradeLabel(BuildContext context, VaultHealthGrade grade) {
    return switch (grade) {
      VaultHealthGrade.excellent => context.text('优秀', 'Excellent'),
      VaultHealthGrade.good => context.text('良好', 'Good'),
      VaultHealthGrade.warning => context.text('需关注', 'Needs Attention'),
      VaultHealthGrade.critical => context.text('危险', 'Critical'),
    };
  }

  Color _riskColor(VaultHealthRiskLevel level) {
    final vt = Theme.of(context).extension<AppVisualTokens>()!;
    return switch (level) {
      VaultHealthRiskLevel.high => vt.warning,
      VaultHealthRiskLevel.medium => vt.warning,
      VaultHealthRiskLevel.low => vt.info,
    };
  }

  String _riskLabel(BuildContext context, VaultHealthRiskLevel level) {
    return switch (level) {
      VaultHealthRiskLevel.high => context.text('高风险', 'High Risk'),
      VaultHealthRiskLevel.medium => context.text('中风险', 'Medium Risk'),
      VaultHealthRiskLevel.low => context.text('低风险', 'Low Risk'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.text('Vault 体检', 'Vault Health Check')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _calculate,
          ),
        ],
      ),
      body: AdaptivePage(
        desktopMaxWidth: 800,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : report == null
            ? _buildEmptyState()
            : _buildReport(report),
      ),
    );
  }

  Widget _buildEmptyState() {
    return InboxEmptyState(
      icon: Icons.health_and_safety_outlined,
      title: context.text('无法计算体检报告', 'Cannot calculate health report'),
      subtitle: context.text('请确保保险库已解锁', 'Make sure the vault is unlocked'),
    );
  }

  Widget _buildReport(VaultHealthReport report) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _buildScoreCard(report),
        const SizedBox(height: AppSpacing.xxl),
        if (report.highRiskItems.isNotEmpty) ...[
          _buildSectionTitle(context.text('高风险项', 'High Risk Items')),
          const SizedBox(height: AppSpacing.sm),
          ...report.highRiskItems.map((item) => _buildItemCard(item)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (report.mediumRiskItems.isNotEmpty) ...[
          _buildSectionTitle(context.text('中风险项', 'Medium Risk Items')),
          const SizedBox(height: AppSpacing.sm),
          ...report.mediumRiskItems.map((item) => _buildItemCard(item)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (report.lowRiskItems.isNotEmpty) ...[
          _buildSectionTitle(context.text('低风险项', 'Low Risk Items')),
          const SizedBox(height: AppSpacing.sm),
          ...report.lowRiskItems.map((item) => _buildItemCard(item)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (report.failedItems.isEmpty) _buildAllPassBanner(),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            context.text(
              '体检时间: ${_formatTime(report.calculatedAt)}',
              'Check time: ${_formatTime(report.calculatedAt)}',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCard(VaultHealthReport report) {
    final color = _gradeColor(report.grade);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: report.score / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${report.score}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold, color: color),
                    ),
                    Text(
                      _gradeLabel(context, report.grade),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              report.failedItems.isEmpty
                  ? context.text('你的保险库状态良好', 'Your vault is in good shape')
                  : context.text(
                      '发现 ${report.failedItems.length} 项需要关注',
                      '${report.failedItems.length} item(s) need attention',
                    ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildItemCard(VaultHealthItem item) {
    final riskColor = _riskColor(item.riskLevel);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ActionItemCard(
        severity: item.isPass ? InboxSeverity.success : _riskToSeverity(item.riskLevel),
        title: item.title,
        subtitle: item.description,
        showChevron: false,
        trailing: Chip(
          label: Text(
            _riskLabel(context, item.riskLevel),
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: riskColor.withAlpha(32),
          side: BorderSide.none,
          padding: EdgeInsets.zero,
        ),
        onTap: item.action != null ? () => _handleAction(item.action!, item.id) : null,
      ),
    );
  }

  static InboxSeverity _riskToSeverity(VaultHealthRiskLevel level) {
    return switch (level) {
      VaultHealthRiskLevel.high => InboxSeverity.critical,
      VaultHealthRiskLevel.medium => InboxSeverity.warning,
      VaultHealthRiskLevel.low => InboxSeverity.info,
    };
  }

  Widget _buildAllPassBanner() {
    final vt = Theme.of(context).extension<AppVisualTokens>()!;
    return Card(
      color: vt.successContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.verified, color: vt.success),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                context.text('所有体检项均已通过，继续保持！', 'All health checks passed. Keep it up!'),
                style: TextStyle(color: vt.success),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(VaultHealthAction action, String itemId) async {
    final highlightFieldKey = switch (itemId) {
      'weak_passwords' || 'reused_passwords' => 'password',
      'incomplete_records' => 'url',
      _ => null,
    };
    final groupByFieldKey = switch (itemId) {
      'reused_passwords' => 'password',
      _ => null,
    };
    switch (action.type) {
      case VaultHealthActionType.navigateToAccountEdit:
        await _navigateToAccountEdit(
          action.targetIds,
          highlightFieldKey: highlightFieldKey,
          groupByFieldKey: groupByFieldKey,
        );
        break;
      case VaultHealthActionType.navigateToOutbox:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LocalSyncQueueView()),
        );
        break;
      case VaultHealthActionType.navigateToConflictInbox:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConflictInboxView()),
        );
        break;
      case VaultHealthActionType.navigateToExport:
        // Export view not yet implemented; fall through to no-op
        break;
      case VaultHealthActionType.navigateToSyncSettings:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SyncSettingsView()),
        );
        break;
      case VaultHealthActionType.none:
        break;
    }
  }

  Future<void> _navigateToAccountEdit(
    List<String> targetIds, {
    String? highlightFieldKey,
    String? groupByFieldKey,
  }) async {
    if (targetIds.isEmpty) return;
    final storage = ServiceManager.instance.storageService;

    if (targetIds.length == 1) {
      final account = await storage.getAccountById(targetIds.first);
      if (!mounted) return;
      if (account == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.text('账号不存在或已被删除', 'Account not found or deleted'))),
        );
        return;
      }
      await Navigator.push<AccountItem>(
        context,
        MaterialPageRoute(builder: (_) => AccountEditView(initial: account)),
      );
      return;
    }

    // Multiple accounts: open subset view
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountSubsetView(
          title: context.text('问题账号', 'Problematic Accounts'),
          accountIds: targetIds,
          highlightFieldKey: highlightFieldKey,
          groupByFieldKey: groupByFieldKey,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.year}-${_pad(time.month)}-${_pad(time.day)} ${_pad(time.hour)}:${_pad(time.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
