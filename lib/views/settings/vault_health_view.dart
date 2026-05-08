import 'package:flutter/material.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/vault_health_report.dart';
import '../../services/service_manager.dart';
import '../../services/vault_health_calculator.dart';
import '../../widgets/adaptive_page.dart';
import '../../theme/app_design_tokens.dart';

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
    return switch (grade) {
      VaultHealthGrade.excellent => Colors.green,
      VaultHealthGrade.good => Colors.lightGreen,
      VaultHealthGrade.warning => Colors.orange,
      VaultHealthGrade.critical => Colors.red,
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
    return switch (level) {
      VaultHealthRiskLevel.high => Colors.red,
      VaultHealthRiskLevel.medium => Colors.orange,
      VaultHealthRiskLevel.low => Colors.blue,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(context.text('无法计算体检报告', 'Cannot calculate health report'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.text('请确保保险库已解锁', 'Make sure the vault is unlocked'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          item.isPass ? Icons.check_circle : Icons.warning,
          color: item.isPass ? Colors.green : riskColor,
        ),
        title: Text(item.title),
        subtitle: Text(item.description),
        trailing: Chip(
          label: Text(
            _riskLabel(context, item.riskLevel),
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: riskColor.withAlpha(32),
          side: BorderSide.none,
          padding: EdgeInsets.zero,
        ),
        onTap: item.action != null ? () => _handleAction(item.action!) : null,
      ),
    );
  }

  Widget _buildAllPassBanner() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.verified, color: Colors.green),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                context.text('所有体检项均已通过，继续保持！', 'All health checks passed. Keep it up!'),
                style: const TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(VaultHealthAction action) {
    // TODO: Wire up navigation when integrated with ServiceManager
    switch (action.type) {
      case VaultHealthActionType.navigateToAccountEdit:
        // Navigator push to account edit or list
        break;
      case VaultHealthActionType.navigateToOutbox:
        // Navigate to home outbox
        break;
      case VaultHealthActionType.navigateToConflictInbox:
        // Navigate to conflict inbox
        break;
      case VaultHealthActionType.navigateToExport:
        // Show export dialog
        break;
      case VaultHealthActionType.navigateToSyncSettings:
        // Navigate to sync settings
        break;
      case VaultHealthActionType.none:
        break;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.year}-${_pad(time.month)}-${_pad(time.day)} ${_pad(time.hour)}:${_pad(time.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
