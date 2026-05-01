import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/account_item.dart';
import '../../models/totp_credential.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../services/totp_service.dart';
import '../../theme/app_design_tokens.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/app_page_header.dart';
import 'totp_credential_edit_view.dart';

class TotpAccountListView extends StatefulWidget {
  const TotpAccountListView({super.key});

  @override
  State<TotpAccountListView> createState() => _TotpAccountListViewState();
}

class _TotpAccountListViewState extends State<TotpAccountListView> {
  Timer? _timer;

  String _text(BuildContext context, String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _openEditor(
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

  Future<void> _deleteCredential(
    BuildContext context,
    TotpCredential credential,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text(context, '\u5220\u9664 2FA', 'Delete 2FA')),
        content: Text(
          _text(
            context,
            '\u786e\u8ba4\u5220\u9664\u201c${credential.displayLabel}\u201d\u5417\uff1f',
            'Delete "${credential.displayLabel}"?',
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
      await context.read<EnhancedAppProvider>().deleteTotpCredential(
        credential.id,
      );
    }
  }

  Future<void> _copyCode(BuildContext context, TotpCode code) async {
    await Clipboard.setData(ClipboardData(text: code.value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _text(
            context,
            '\u9a8c\u8bc1\u7801\u5df2\u590d\u5236',
            'Code copied.',
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required BuildContext context,
    required String value,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 44,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _text(context, '\u6682\u65e0 2FA', 'No 2FA Items'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialCard(
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
          tooltip: _text(context, '\u7f16\u8f91', 'Edit'),
          onPressed: () => _openEditor(context, initial: credential),
          icon: const Icon(Icons.edit_outlined),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(90),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    const SizedBox(height: 4),
                    Text(
                      linkedAccounts.isEmpty
                          ? _text(
                              context,
                              '\u672a\u5173\u8054\u8d26\u53f7',
                              'No linked account',
                            )
                          : linkedAccounts
                                .map((account) => account.name)
                                .join(' / '),
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
                tooltip: _text(context, '\u7f16\u8f91', 'Edit'),
                onPressed: () => _openEditor(context, initial: credential),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: _text(context, '\u5220\u9664', 'Delete'),
                onPressed: () => _deleteCredential(context, credential),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
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
                tooltip: _text(
                  context,
                  '\u590d\u5236\u9a8c\u8bc1\u7801',
                  'Copy code',
                ),
                onPressed: () => _copyCode(context, code),
                icon: const Icon(Icons.content_copy_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: code.secondsRemaining / code.period,
            minHeight: 5,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialPanel(
    BuildContext context,
    EnhancedAppProvider provider,
    List<TotpCredential> credentials,
  ) {
    if (credentials.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: credentials.map((credential) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCredentialCard(context, provider, credential),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EnhancedAppProvider>();
    final credentials = provider.totpCredentials;
    final linkedCount = credentials.fold<int>(
      0,
      (sum, credential) => sum + credential.linkedAccountIds.length,
    );

    return AdaptivePage(
      desktopMaxWidth: 1200,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 96),
        children: [
          AdaptiveSection(
            maxWidth: AppSectionWidths.panel,
            child: AppPageHeader(
              icon: Icons.verified_user_outlined,
              title: _text(context, '2FA', '2FA'),
              subtitle: _text(
                context,
                '\u72ec\u7acb\u7ba1\u7406\u52a8\u6001\u9a8c\u8bc1\u7801\uff0c\u518d\u5173\u8054\u5230\u8d26\u53f7\u3002',
                'Manage authenticator codes independently, then link accounts.',
              ),
              trailing: FilledButton.icon(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add),
                label: Text(_text(context, '\u65b0\u589e', 'Add')),
              ),
              metrics: [
                _buildMetricChip(
                  context: context,
                  value: '${credentials.length}',
                  label: _text(context, '\u9879', 'Items'),
                ),
                _buildMetricChip(
                  context: context,
                  value: '$linkedCount',
                  label: _text(context, '\u5173\u8054', 'Links'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AdaptiveSection(
            maxWidth: AppSectionWidths.panel,
            child: _buildCredentialPanel(context, provider, credentials),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
