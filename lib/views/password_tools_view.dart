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
      title: context.text('密码生成器', 'Password Generator'),
      subtitle: context.text(
        '像 1Password 一样调整长度和字符类型，然后复制或保留生成结果。',
        'Adjust length and character types like 1Password, then copy or keep the result.',
      ),
      applyLabel: context.text('保留结果', 'Keep Result'),
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
            '已复制生成的密码',
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
                  context.text('密码工具', 'Password Tools'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.text(
                    '集中生成高强度密码，方便新建或替换敏感信息。',
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
          '尚未生成密码',
          'No Password Generated Yet',
        ),
        subtitle: context.text(
          '打开生成器后，这里会保留最近一次结果，方便你再次复制或对照。',
          'Once you open the generator, the latest result stays here for quick copying and review.',
        ),
        child: OutlinedButton.icon(
          onPressed: () => _showPasswordGenerator(context),
          icon: const Icon(Icons.password_outlined),
          label: Text(
            context.text('打开生成器', 'Open Generator'),
          ),
        ),
      );
    }

    final strength = ServiceManager.calculatePasswordStrength(password);

    return _buildSectionCard(
      context: context,
      title: context.text('最近一次结果', 'Latest Result'),
      subtitle: context.text(
        '继续调整参数，或者直接复制这次生成的密码。',
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
              '强度：$strength / 100',
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
                  label: Text(context.text('复制', 'Copy')),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showPasswordGenerator(context),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    context.text('调整并重生', 'Adjust & Refresh'),
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
        title: Text(context.text('密码工具', 'Password Tools')),
      ),
      body: AdaptivePage(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _buildHeroCard(context),
            const SizedBox(height: AppSpacing.lg),
            _buildSectionCard(
              context: context,
              title: context.text('密码生成', 'Password Generator'),
              subtitle: context.text(
                '用更接近 1Password 的方式，自定义长度、字符类型和强度。',
                'Use a more 1Password-like flow to customize length, character types, and strength.',
              ),
              child: _buildActionTile(
                context: context,
                title: context.text(
                  '打开生成器',
                  'Open Generator',
                ),
                subtitle: context.text(
                  '自定义长度、组成和强度',
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
