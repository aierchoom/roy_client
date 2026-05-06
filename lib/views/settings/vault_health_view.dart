import 'package:flutter/material.dart';
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

  String _gradeLabel(VaultHealthGrade grade) {
    return switch (grade) {
      VaultHealthGrade.excellent => '优秀',
      VaultHealthGrade.good => '良好',
      VaultHealthGrade.warning => '需关注',
      VaultHealthGrade.critical => '危险',
    };
  }

  Color _riskColor(VaultHealthRiskLevel level) {
    return switch (level) {
      VaultHealthRiskLevel.high => Colors.red,
      VaultHealthRiskLevel.medium => Colors.orange,
      VaultHealthRiskLevel.low => Colors.blue,
    };
  }

  String _riskLabel(VaultHealthRiskLevel level) {
    return switch (level) {
      VaultHealthRiskLevel.high => '高风险',
      VaultHealthRiskLevel.medium => '中风险',
      VaultHealthRiskLevel.low => '低风险',
    };
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault 体检'),
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
          const Icon(Icons.health_and_safety_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '无法计算体检报告',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '请确保保险库已解锁',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
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
          _buildSectionTitle('高风险项'),
          const SizedBox(height: AppSpacing.sm),
          ...report.highRiskItems.map((item) => _buildItemCard(item)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (report.mediumRiskItems.isNotEmpty) ...[
          _buildSectionTitle('中风险项'),
          const SizedBox(height: AppSpacing.sm),
          ...report.mediumRiskItems.map((item) => _buildItemCard(item)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (report.lowRiskItems.isNotEmpty) ...[
          _buildSectionTitle('低风险项'),
          const SizedBox(height: AppSpacing.sm),
          ...report.lowRiskItems.map((item) => _buildItemCard(item)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (report.failedItems.isEmpty)
          _buildAllPassBanner(),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            '体检时间: ${_formatTime(report.calculatedAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
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
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                    Text(
                      _gradeLabel(report.grade),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              report.failedItems.isEmpty
                  ? '你的保险库状态良好'
                  : '发现 ${report.failedItems.length} 项需要关注',
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
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
            _riskLabel(item.riskLevel),
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
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.verified, color: Colors.green),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '所有体检项均已通过，继续保持！',
                style: TextStyle(color: Colors.green),
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
