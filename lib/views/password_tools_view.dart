import 'package:flutter/material.dart';

import '../l10n/app_text_extension.dart';
import '../services/service_manager.dart';
import '../services/sensitive_clipboard_service.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/password_generator_sheet.dart';
import '../theme/app_design_tokens.dart';

class PasswordToolsView extends StatefulWidget {
  const PasswordToolsView({super.key});

  @override
  State<PasswordToolsView> createState() => _PasswordToolsViewState();
}

class _PasswordToolsViewState extends State<PasswordToolsView> {
  PasswordGeneratorResult? _lastResult;

  Future<void> _showPasswordGenerator(BuildContext context) async {
    final result = await showPasswordGeneratorSheet(
      context,
      initialOptions:
          _lastResult?.options ?? PasswordGeneratorOptions.defaults(length: 20),
      title: context.text('\u5bc6\u7801\u751f\u6210\u5668', 'Password Generator'),
      subtitle: context.text(
        '\u50cf 1Password \u4e00\u6837\u8c03\u6574\u957f\u5ea6\u548c\u5b57\u7b26\u7c7b\u578b\uff0c\u7136\u540e\u590d\u5236\u6216\u4fdd\u7559\u751f\u6210\u7ed3\u679c\u3002',
        'Adjust length and character types like 1Password, then copy or keep the result.',
      ),
      applyLabel: context.text('\u4fdd\u7559\u7ed3\u679c', 'Keep Result'),
    );
    if (result == null || !mounted) return;

    setState(() {
      _lastResult = result;
    });
  }

  Future<void> _copyLastPassword(BuildContext context) async {
    final password = _lastResult?.password ?? '';
    if (password.isEmpty) return;

    await SensitiveClipboardService.copy(
      text: password,
      level: ClipboardRiskLevel.high,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.text(
            '\u5df2\u590d\u5236\u751f\u6210\u7684\u5bc6\u7801',
            'Generated password copied',
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.tertiaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withAlpha(
                AppAlphas.surfaceOverlay,
              ),
              borderRadius: BorderRadius.circular(AppRadii.panel),
            ),
            child: Icon(
              Icons.password_outlined,
              size: 28,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.text('\u5bc6\u7801\u5de5\u5177', 'Password Tools'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.text(
                    '\u96c6\u4e2d\u751f\u6210\u9ad8\u5f3a\u5ea6\u5bc6\u7801\uff0c\u65b9\u4fbf\u65b0\u5efa\u6216\u66ff\u6362\u654f\u611f\u4fe1\u606f\u3002',
                    'Generate strong passwords for new or updated credentials in one place.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withAlpha(160),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withAlpha(AppAlphas.strong),
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLatestPasswordCard(BuildContext context) {
    final theme = Theme.of(context);
    final password = _lastResult?.password;

    if (password == null || password.isEmpty) {
      return _buildSectionCard(
        context: context,
        title: context.text(
          '\u5c1a\u672a\u751f\u6210\u5bc6\u7801',
          'No Password Generated Yet',
        ),
        subtitle: context.text(
          '\u6253\u5f00\u751f\u6210\u5668\u540e\uff0c\u8fd9\u91cc\u4f1a\u4fdd\u7559\u6700\u8fd1\u4e00\u6b21\u7ed3\u679c\uff0c\u65b9\u4fbf\u4f60\u518d\u6b21\u590d\u5236\u6216\u5bf9\u7167\u3002',
          'Once you open the generator, the latest result stays here for quick copying and review.',
        ),
        child: OutlinedButton.icon(
          onPressed: () => _showPasswordGenerator(context),
          icon: const Icon(Icons.password_outlined),
          label: Text(
            context.text('\u6253\u5f00\u751f\u6210\u5668', 'Open Generator'),
          ),
        ),
      );
    }

    final strength = ServiceManager.calculatePasswordStrength(password);

    return _buildSectionCard(
      context: context,
      title: context.text('\u6700\u8fd1\u4e00\u6b21\u7ed3\u679c', 'Latest Result'),
      subtitle: context.text(
        '\u7ee7\u7eed\u8c03\u6574\u53c2\u6570\uff0c\u6216\u8005\u76f4\u63a5\u590d\u5236\u8fd9\u6b21\u751f\u6210\u7684\u5bc6\u7801\u3002',
        'Keep tuning the options or copy this generated password directly.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                AppAlphas.outline,
              ),
              borderRadius: BorderRadius.circular(AppRadii.panel),
            ),
            child: SelectableText(
              password,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.text(
              '\u5f3a\u5ea6\uff1a$strength / 100',
              'Strength: $strength / 100',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyLastPassword(context),
                  icon: const Icon(Icons.content_copy_outlined),
                  label: Text(context.text('\u590d\u5236', 'Copy')),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showPasswordGenerator(context),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    context.text('\u8c03\u6574\u5e76\u91cd\u751f', 'Adjust & Refresh'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.text('\u5bc6\u7801\u5de5\u5177', 'Password Tools')),
      ),
      body: AdaptivePage(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _buildHeroCard(context),
            const SizedBox(height: AppSpacing.lg),
            _buildSectionCard(
              context: context,
              title: context.text('\u5bc6\u7801\u751f\u6210', 'Password Generator'),
              subtitle: context.text(
                '\u7528\u66f4\u63a5\u8fd1 1Password \u7684\u65b9\u5f0f\uff0c\u81ea\u5b9a\u4e49\u957f\u5ea6\u3001\u5b57\u7b26\u7c7b\u578b\u548c\u5f3a\u5ea6\u3002',
                'Use a more 1Password-like flow to customize length, character types, and strength.',
              ),
              child: _buildActionTile(
                context: context,
                title: context.text(
                  '\u6253\u5f00\u751f\u6210\u5668',
                  'Open Generator',
                ),
                subtitle: context.text(
                  '\u81ea\u5b9a\u4e49\u957f\u5ea6\u3001\u7ec4\u6210\u548c\u5f3a\u5ea6',
                  'Customize length, composition, and strength',
                ),
                icon: Icons.password_outlined,
                onTap: () => _showPasswordGenerator(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildLatestPasswordCard(context),
          ],
        ),
      ),
    );
  }
}
