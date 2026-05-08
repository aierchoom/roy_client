import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/account_item.dart';
import '../../models/hlc.dart';
import '../../models/totp_credential.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../services/totp_import_service.dart';
import '../../services/totp_qr_image_import_service.dart';
import '../../services/totp_service.dart';
import '../../services/sensitive_clipboard_service.dart';
import 'totp_qr_scanner_view.dart';
import '../../theme/app_design_tokens.dart';

class TotpCredentialEditView extends StatefulWidget {
  final TotpCredential? initial;
  final String? initialAccountId;

  const TotpCredentialEditView({
    super.key,
    this.initial,
    this.initialAccountId,
  });

  @override
  State<TotpCredentialEditView> createState() => _TotpCredentialEditViewState();
}

class _TotpCredentialEditViewState extends State<TotpCredentialEditView> {
  final _labelCtrl = TextEditingController();
  final _configCtrl = TextEditingController();
  final Set<String> _linkedAccountIds = {};
  Timer? _timer;

  bool get _supportsQrScan =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _labelCtrl.text = initial.label;
      _configCtrl.text = jsonEncode(initial.config.toJson());
      _linkedAccountIds.addAll(initial.linkedAccountIds);
    }
    final initialAccountId = widget.initialAccountId;
    if (initialAccountId != null && initialAccountId.trim().isNotEmpty) {
      _linkedAccountIds.add(initialAccountId);
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _fillFromRaw(String raw) async {
    try {
      final normalized = TotpImportService.normalizeImportValue(raw);
      setState(() => _configCtrl.text = normalized);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_totpErrorMessage(error))));
    }
  }

  Future<void> _scanQr() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TotpQrScannerView(
          title: context.text('扫描 2FA 二维码', 'Scan 2FA QR Code'),
          helpText: context.text('将二维码放入取景框', 'Place the QR code in the frame.'),
          invalidMessage: context.text(
            '这不是可用的 2FA 二维码',
            'This is not a usable 2FA QR code.',
          ),
          torchTooltip: context.text('闪光灯', 'Torch'),
          switchCameraTooltip: context.text('切换摄像头', 'Switch camera'),
        ),
      ),
    );
    if (raw == null || raw.trim().isEmpty || !mounted) return;
    await _fillFromRaw(raw);
  }

  Future<void> _pasteQr() async {
    try {
      final normalized = await _readPastedQr();
      if (!mounted) return;
      setState(() => _configCtrl.text = normalized);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_totpErrorMessage(error))));
    }
  }

  Future<String> _readPastedQr() async {
    try {
      return await TotpQrImageImportService.normalizeClipboardQrImage();
    } catch (imageError) {
      if (imageError is TotpException &&
          imageError.message !=
              TotpQrImageImportService.noClipboardImageMessage) {
        rethrow;
      }
    }

    final text = (await Clipboard.getData('text/plain'))?.text ?? '';
    return TotpImportService.normalizeImportValue(text);
  }

  String _totpErrorMessage(Object error) {
    if (error is TotpException) {
      if (error.message == 'No TOTP QR content was found.') {
        return context.text(
          '没有找到可用的 2FA 二维码内容',
          'No usable 2FA QR content was found.',
        );
      }
      if (error.message == TotpQrImageImportService.noClipboardImageMessage) {
        return context.text('剪贴板里没有二维码图片', 'There is no QR image on the clipboard.');
      }
      if (error.message == TotpQrImageImportService.imageDecodeFailedMessage) {
        return context.text('二维码图片无法读取', 'The QR image could not be read.');
      }
      if (error.message == TotpQrImageImportService.noQrCodeFoundMessage) {
        return context.text('图片里没有二维码', 'No QR code was found in the image.');
      }
      return error.message;
    }
    return error.toString();
  }

  Future<void> _copyCode(TotpCode code) async {
    await SensitiveClipboardService.copy(
      text: code.value,
      level: ClipboardRiskLevel.high,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.text('验证码已复制', 'Code copied.'))));
  }

  void _save() {
    TotpConfig config;
    try {
      final normalized = TotpImportService.normalizeImportValue(
        _configCtrl.text,
      );
      config = TotpService.parseConfig(normalized);
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_totpErrorMessage(error))));
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final initial = widget.initial;
    final credential = TotpCredential(
      id: initial?.id ?? now.toString(),
      label: _labelCtrl.text.trim(),
      config: config,
      linkedAccountIds: _linkedAccountIds.toList(),
      createdAt: initial?.createdAt ?? now,
      labelHlc: initial?.labelHlc ?? Hlc.zero('local'),
      configHlc: initial?.configHlc ?? Hlc.zero('local'),
      linksHlc: initial?.linksHlc ?? Hlc.zero('local'),
      serverVersion: initial?.serverVersion ?? 0,
      syncStatus: initial?.syncStatus ?? SyncStatus.pendingPush,
      isDeleted: initial?.isDeleted ?? false,
      deleteHlc: initial?.deleteHlc,
    );

    Navigator.pop(context, credential);
  }

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    final raw = _configCtrl.text.trim();
    if (raw.isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      final config = TotpService.parseConfig(raw);
      final code = const TotpService().generate(config);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withAlpha(70),
          borderRadius: BorderRadius.circular(AppRadii.panel),
          border: Border.all(color: theme.colorScheme.primary.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  onPressed: () => _copyCode(code),
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
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${TotpService.algorithmName(config.algorithm)} · ${config.digits} digits · ${config.period}s',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    } catch (error) {
      return Text(
        _totpErrorMessage(error),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }
  }

  Widget _buildAccountSelector(
    BuildContext context,
    List<AccountItem> accounts,
  ) {
    final theme = Theme.of(context);
    if (accounts.isEmpty) {
      return Text(
        context.text('暂无可关联账号', 'No accounts available to link.'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      children: accounts.map((account) {
        return CheckboxListTile(
          value: _linkedAccountIds.contains(account.id),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(account.name),
          subtitle: account.email.trim().isEmpty ? null : Text(account.email),
          onChanged: (value) {
            setState(() {
              if (value == true) {
                _linkedAccountIds.add(account.id);
              } else {
                _linkedAccountIds.remove(account.id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<EnhancedAppProvider>().allAccounts;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? context.text('新建 2FA', 'Add 2FA')
              : context.text('编辑 2FA', 'Edit 2FA'),
        ),
        actions: [
          IconButton(
            tooltip: context.text('保存', 'Save'),
            onPressed: _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: [
          TextField(
            controller: _labelCtrl,
            decoration: InputDecoration(
              labelText: context.text('名称', 'Label'),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _configCtrl,
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.visiblePassword,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.text('密钥 / otpauth URI', 'Secret / otpauth URI'),
              prefixIcon: const Icon(Icons.key_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_supportsQrScan)
                OutlinedButton.icon(
                  onPressed: _scanQr,
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: Text(context.text('扫码', 'Scan')),
                ),
              OutlinedButton.icon(
                onPressed: _pasteQr,
                icon: const Icon(Icons.paste_outlined),
                label: Text(context.text('粘贴二维码', 'Paste QR')),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildPreview(context),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            context.text('关联账号', 'Linked Accounts'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildAccountSelector(context, accounts),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: Text(context.text('保存', 'Save')),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _labelCtrl.dispose();
    _configCtrl.dispose();
    super.dispose();
  }
}
