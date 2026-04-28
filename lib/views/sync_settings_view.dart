// ignore_for_file: use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/enhanced_app_provider.dart';
import '../services/identity_service.dart';
import '../services/lan_pairing_service.dart';
import '../services/service_manager.dart';
import '../services/vault_pairing_service.dart';
import '../sync/sync_service.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/sync_settings_dialogs.dart';

class SyncSettingsView extends StatefulWidget {
  const SyncSettingsView({super.key});

  @override
  State<SyncSettingsView> createState() => _SyncSettingsViewState();
}

class _SyncSettingsViewState extends State<SyncSettingsView> {
  final _serviceManager = ServiceManager.instance;

  bool _isLoading = false;
  bool _isSavingSyncServer = false;
  String _syncServerUrl = ServiceManager.defaultSyncServerUrl;
  bool _isPairingBusy = false;
  PairingSessionInfo? _hostPairingSession;
  PairingPendingRequest? _hostPendingRequest;
  PairingJoinResult? _joinPairingResult;
  bool _joinPairingForceOverwrite = false;
  bool _isLanPairingBusy = false;

  bool get _isMobileClient =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool _isLoopbackUrl(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  String _mobileLoopbackHint() {
    return _text(
      '手机端不能使用 127.0.0.1 或 localhost，请改成电脑在同一局域网下的 IP，例如 http://192.168.1.100:8080',
      'Phones cannot use 127.0.0.1 or localhost here. Use your computer\'s LAN IP instead, for example http://192.168.1.100:8080',
    );
  }

  String _text(String zh, String en) {
    if (!mounted) return en;
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  String _syncStateLabel(SyncState state) {
    return switch (state) {
      SyncState.offline => _text('离线', 'Offline'),
      SyncState.syncing => _text('同步中', 'Syncing'),
      SyncState.conflictRecovery => _text('恢复中', 'Recovering'),
      SyncState.synced => _text('已就绪', 'Ready'),
      SyncState.error => _text('需要处理', 'Needs attention'),
    };
  }

  bool _isServerPersistenceIssue(String? message) {
    if (message == null) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('vault file is unreadable') ||
        normalized.contains('failed to persist vault') ||
        normalized.contains('storage is temporarily unavailable');
  }

  ({Color background, Color foreground, IconData icon}) _syncStatusTone(
    BuildContext context,
    SyncState state,
    String? message,
  ) {
    final theme = Theme.of(context);
    if (state == SyncState.error) {
      return (
        background: theme.colorScheme.errorContainer,
        foreground: theme.colorScheme.onErrorContainer,
        icon: _isServerPersistenceIssue(message)
            ? Icons.storage_outlined
            : Icons.error_outline,
      );
    }
    if (state == SyncState.conflictRecovery) {
      return (
        background: theme.colorScheme.tertiaryContainer,
        foreground: theme.colorScheme.onTertiaryContainer,
        icon: Icons.settings_backup_restore_outlined,
      );
    }
    if (state == SyncState.syncing) {
      return (
        background: theme.colorScheme.primaryContainer,
        foreground: theme.colorScheme.onPrimaryContainer,
        icon: Icons.sync,
      );
    }
    if (state == SyncState.offline) {
      return (
        background: theme.colorScheme.surfaceContainerHighest,
        foreground: theme.colorScheme.onSurfaceVariant,
        icon: Icons.cloud_off_outlined,
      );
    }
    return (
      background: theme.colorScheme.secondaryContainer,
      foreground: theme.colorScheme.onSecondaryContainer,
      icon: Icons.cloud_done_outlined,
    );
  }

  String? _syncStatusDescription(
    SyncState state,
    String? message, {
    required bool hasDirtyData,
  }) {
    if (state == SyncState.error) {
      if (_isServerPersistenceIssue(message)) {
        return _text(
          '服务器可连接，但同步存储层当前不稳定，请稍后重试或检查服务器数据文件。',
          'The server is reachable, but its sync storage layer is unhealthy. Retry later or inspect the server vault files.',
        );
      }
      return message;
    }
    return switch (state) {
      SyncState.offline => _text(
        '当前未与同步服务器建立连接。',
        'The client is currently not connected to the sync server.',
      ),
      SyncState.syncing => _text(
        '正在与远程 vault 交换更新。',
        'Changes are currently being exchanged with the remote vault.',
      ),
      SyncState.conflictRecovery => _text(
        '正在处理上一次中断或冲突后的恢复流程。',
        'The client is replaying recovery steps after an interrupted or conflicting sync cycle.',
      ),
      SyncState.synced =>
        message ??
            (hasDirtyData
                ? _text(
                    '本地变更已排队，等待下一次同步上传。',
                    'Local changes are queued and waiting for the next upload.',
                  )
                : _text(
                    '同步状态正常，可随时发起新的同步。',
                    'Sync is healthy and ready for the next exchange.',
                  )),
      SyncState.error => null,
    };
  }

  String? _syncActionTitle(
    SyncState state,
    String? message, {
    required bool hasDirtyData,
  }) {
    if (state == SyncState.error) {
      if (_isServerPersistenceIssue(message)) {
        return _text('建议动作', 'Recommended action');
      }
      if (message != null &&
          (message.contains('server address') ||
              message.contains('LAN IP') ||
              message.contains('loopback'))) {
        return _text('先修正地址', 'Fix the server address first');
      }
      return _text('建议动作', 'Recommended action');
    }
    if (state == SyncState.offline) {
      return _text('下一步', 'Next step');
    }
    if (state == SyncState.conflictRecovery) {
      return _text('当前策略', 'Current strategy');
    }
    if (state == SyncState.synced && hasDirtyData) {
      return _text('推荐操作', 'Recommended action');
    }
    return null;
  }

  String? _syncActionDetail(
    SyncState state,
    String? message, {
    required bool hasDirtyData,
  }) {
    if (state == SyncState.error) {
      if (_isServerPersistenceIssue(message)) {
        return _text(
          '先检查服务端 vault JSON/备份文件是否可读，然后再重试。',
          'Inspect the server vault JSON and backup files first, then retry sync.',
        );
      }
      if (message != null &&
          (message.contains('server address') ||
              message.contains('LAN IP') ||
              message.contains('loopback'))) {
        return _text(
          '打开 Server 设置，改成可达的 URL，手机请使用桌面机 LAN IP。',
          'Open Server settings and switch to a reachable URL. On phones, use the desktop machine LAN IP.',
        );
      }
      return _text(
        '修复提示后再重试 Sync Now，如果重复出现再查看日志。',
        'Retry Sync Now after addressing the issue. If it repeats, inspect the client and server logs.',
      );
    }
    if (state == SyncState.offline) {
      return _text(
        '确认服务器地址、网络可达性，然后手动重试一次同步。',
        'Verify the server address and network reachability, then retry one manual sync.',
      );
    }
    if (state == SyncState.conflictRecovery) {
      return _text(
        '系统会先尝试自动收敛，若仍有冲突，再去冲突收件箱审阅。',
        'Let the automatic recovery finish first. If conflicts remain, review them in the conflict inbox.',
      );
    }
    if (state == SyncState.synced && hasDirtyData) {
      return _text(
        '本地已有待上传更改，可以现在重试同步或等待下一次自动触发。',
        'There are local changes waiting to upload. Retry sync now or wait for the next automatic run.',
      );
    }
    return null;
  }

  bool _showsInlineServerEditAction(SyncState state, String? message) {
    return state == SyncState.error &&
        message != null &&
        (message.contains('server address') ||
            message.contains('LAN IP') ||
            message.contains('loopback'));
  }

  String _primarySyncActionLabel(
    SyncState state, {
    required bool hasDirtyData,
  }) {
    if (state == SyncState.error || state == SyncState.offline) {
      return _text('再试同步', 'Retry Sync');
    }
    if (state == SyncState.synced && hasDirtyData) {
      return _text('立即上传', 'Upload Now');
    }
    return _text('立即同步', 'Sync Now');
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final syncServerUrl =
        await _serviceManager.getSyncServerUrl() ??
        ServiceManager.defaultSyncServerUrl;

    if (!mounted) return;
    setState(() {
      _syncServerUrl = syncServerUrl;
      _isLoading = false;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: theme.colorScheme.error,
      ),
    );
  }

  Future<void> _runSync(
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
    EnhancedAppProvider provider,
  ) async {
    final progressRoute = DialogRoute<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_text('正在同步数据...', 'Syncing data...')),
          ],
        ),
      ),
    );
    navigator.push(progressRoute);

    try {
      final result = await _serviceManager.syncNow();
      if (!mounted) return;

      if (result.success) {
        final hasConflicts = result.conflictCount > 0;
        final defaultMessage = hasConflicts
            ? _text(
                '发现 ${result.conflictCount} 个同步冲突，请到冲突收件箱决定是否覆盖',
                '${result.conflictCount} sync conflict(s) detected. Review the conflict inbox before overwriting.',
              )
            : switch ((result.pulled, result.pushed)) {
                (true, _) => _text('已拉取远程更新', 'Pulled remote updates'),
                (_, true) => _text('已上传本地更改', 'Pushed local updates'),
                _ => _text('数据已是最新', 'Already up to date'),
              };
        final message = result.notice ?? defaultMessage;

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              hasConflicts || result.notice != null
                  ? message
                  : _text(
                      '$message（本地版本: ${result.version}）',
                      '$message (version: ${result.version})',
                    ),
            ),
            backgroundColor: hasConflicts ? Colors.orange : Colors.green,
          ),
        );

        if (result.pulled || hasConflicts) {
          await provider.refresh();
        }
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _text('同步失败：${result.error}', 'Sync failed: ${result.error}'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_text('发生未预期的同步错误：$e', 'Unexpected sync error: $e')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      final routeNavigator = progressRoute.navigator;
      if (progressRoute.isActive && routeNavigator != null) {
        routeNavigator.removeRoute(progressRoute);
      }

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _showSyncConfigDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SyncServerDialog(
        initialValue: _syncServerUrl,
        title: _text('同步服务器', 'Sync Server'),
        labelText: _text('服务器 URL', 'Server URL'),
        hintText: _text('http://example.com:8080', 'http://example.com:8080'),
        cancelLabel: _text('取消', 'Cancel'),
        saveLabel: _text('保存', 'Save'),
      ),
    );

    if (!mounted || result == null) return;
    await _saveSyncServerUrl(result);
  }

  Future<void> _saveSyncServerUrl(String rawUrl) async {
    final messenger = ScaffoldMessenger.of(context);
    final normalizedUrl = _normalizeSyncServerUrl(rawUrl);
    if (normalizedUrl.isEmpty) {
      _showError(_text('请先输入有效的服务器地址。', 'Enter a valid server address first.'));
      return;
    }

    if (_isMobileClient && _isLoopbackUrl(normalizedUrl)) {
      _showError(_mobileLoopbackHint());
      return;
    }

    setState(() => _isSavingSyncServer = true);
    try {
      await _serviceManager.setSyncServerUrl(normalizedUrl);
      if (!mounted) return;
      setState(() => _syncServerUrl = normalizedUrl);
      messenger.showSnackBar(
        SnackBar(content: Text(_text('同步服务器已保存', 'Sync server saved'))),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(_text('保存服务器失败：$e', 'Failed to save server: $e'));
    } finally {
      if (mounted) {
        setState(() => _isSavingSyncServer = false);
      }
    }
  }

  String _normalizeSyncServerUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) return '';

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return url;
  }

  bool _hasLocalVaultData() {
    final provider = context.read<EnhancedAppProvider>();
    return provider.allAccounts.isNotEmpty ||
        provider.customTemplates.isNotEmpty ||
        _serviceManager.syncVersion > 0 ||
        _serviceManager.hasDirtyData;
  }

  Future<bool> _confirmOverwriteLocalData() async {
    if (!_hasLocalVaultData()) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(
            _text('覆盖本地数据？', 'Overwrite Local Data?'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            _text(
              '当前设备已存在本地数据。继续加入将覆盖并清空当前设备上的所有本地数据。你确定要继续吗？',
              'This device already has local data. Joining will overwrite and clear all local data on this device. Are you sure you want to continue?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_text('取消', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_text('强制覆盖', 'Overwrite')),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _startLanPairingHost() async {
    if (_isLanPairingBusy) return;
    if (!await _confirmTrustedLanPairing()) return;

    setState(() => _isLanPairingBusy = true);
    try {
      final session = await _serviceManager.startLanVaultPairingHost();
      if (!mounted) return;

      await _showGeneratedCodeDialog(
        _text('面对面链接码', 'Face-to-Face Link Code'),
        _text(
          '仅在这个窗口打开期间有效。请让另一台设备现在输入这 8 位临时码：',
          'This code expires when this window closes. Enter it on the other device now:',
        ),
        session.pairingCode,
        showCopyNotice: false,
      );
    } on LanPairingServiceException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError(
        _text('启动面对面链接失败: $e', 'Failed to start face-to-face linking: $e'),
      );
    } finally {
      await _serviceManager.stopLanVaultPairingHost();
      if (mounted) {
        setState(() {
          _isLanPairingBusy = false;
        });
      }
    }
  }

  Future<void> _showJoinLanPairingDialog() async {
    if (!await _confirmTrustedLanPairing()) return;
    final forceOverwrite = _hasLocalVaultData();
    if (forceOverwrite && !await _confirmOverwriteLocalData()) return;

    final pairingCode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => LanPairingCodeDialog(
        title: _text('输入面对面链接码', 'Enter Face-to-Face Code'),
        subtitle: _text(
          '输入可信设备当前弹窗中显示的 8 位临时码。窗口关闭后不能再领取密钥包。',
          'Enter the 8-character temporary code shown on your trusted device. The key bundle is unavailable after that window closes.',
        ),
        confirmLabel: _text('链接并导入', 'Link & Import'),
        cancelLabel: _text('取消', 'Cancel'),
        codeLabel: _text('8 位临时码', '8-Character Temporary Code'),
      ),
    );

    if (!mounted || pairingCode == null) {
      return;
    }

    final provider = context.read<EnhancedAppProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isLanPairingBusy = true);
    try {
      await _serviceManager.joinLanVaultPairingWithCode(
        pairingCode,
        forceOverwrite: forceOverwrite,
      );
      await provider.refresh();
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _text(
              '面对面链接完成。若本次未携带全量数据，可执行一次同步拉取远程数据。',
              'Face-to-face link complete. Run Sync Now if this import did not include all data.',
            ),
          ),
        ),
      );
    } on LanPairingServiceException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } on IdentityTransferCodeException catch (e) {
      if (!mounted) return;
      _showError(
        _text(
          '导入的链接包无效: ${e.message}',
          'Imported bundle is invalid: ${e.message}',
        ),
      );
    } on VaultImportPreconditionException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } on VaultImportException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError(_text('面对面链接失败: $e', 'Failed to link face-to-face: $e'));
    } finally {
      if (mounted) {
        setState(() => _isLanPairingBusy = false);
      }
    }
  }

  Future<bool> _confirmTrustedLanPairing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(
            _text('仅在可信局域网使用', 'Use only on a trusted LAN'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            _text(
              '面对面链接会临时在本机局域网监听。请只在家庭、办公室或手机热点等可信网络中使用；公共 Wi-Fi 不建议使用。',
              'Face-to-face linking temporarily listens on your local network. Use it only on trusted home, office, or hotspot networks; avoid public Wi-Fi.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_text('取消', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_text('继续', 'Continue')),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _createVaultPairingSession() async {
    if (_isPairingBusy) return;
    setState(() => _isPairingBusy = true);

    try {
      final session = await _serviceManager.createVaultPairingSession();
      await Clipboard.setData(ClipboardData(text: session.pairingCode));
      if (!mounted) return;

      setState(() {
        _hostPairingSession = session;
        _hostPendingRequest = null;
      });

      await _showGeneratedCodeDialog(
        _text('远程配对码', 'Remote Pairing Code'),
        _text(
          '请在另一台设备上输入此配对码。新设备提交请求后，还需要本机手动批准。',
          'Enter this code on the other device. The request still needs manual approval on this device.',
        ),
        session.pairingCode,
      );
    } on VaultPairingServiceException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to create pairing code: $e');
    } finally {
      if (mounted) {
        setState(() => _isPairingBusy = false);
      }
    }
  }

  Future<void> _refreshHostPairingSession() async {
    final session = _hostPairingSession;
    if (session == null || _isPairingBusy) return;

    setState(() => _isPairingBusy = true);
    try {
      final status = await _serviceManager.getVaultPairingSessionStatus(
        session.sessionId,
      );
      if (!mounted) return;

      setState(() {
        _hostPendingRequest = status.status == 'pending_approval'
            ? status.pendingRequest
            : null;
      });
      if (status.status == 'approved') {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _text(
                '已批准远程配对。新设备现在可以领取加密密钥包。',
                'Pairing approved. The new device can now import vault keys.',
              ),
            ),
          ),
        );
      }
    } on VaultPairingServiceException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to refresh pairing session: $e');
    } finally {
      if (mounted) {
        setState(() => _isPairingBusy = false);
      }
    }
  }

  Future<void> _approvePendingPairingRequest() async {
    final session = _hostPairingSession;
    final pendingRequest = _hostPendingRequest;
    if (session == null || pendingRequest == null || _isPairingBusy) {
      return;
    }

    setState(() => _isPairingBusy = true);
    try {
      await _serviceManager.approveVaultPairingRequest(
        sessionId: session.sessionId,
        requestId: pendingRequest.requestId,
      );
      if (!mounted) return;

      setState(() => _hostPendingRequest = null);
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _text(
              '已允许设备加入。新设备现在可以完成导入。',
              'Device approved. New device can finish import now.',
            ),
          ),
        ),
      );
    } on VaultPairingServiceException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to approve pairing request: $e');
    } finally {
      if (mounted) {
        setState(() => _isPairingBusy = false);
      }
    }
  }

  Future<void> _showJoinPairingCodeDialog() async {
    final forceOverwrite = _hasLocalVaultData();
    if (forceOverwrite && !await _confirmOverwriteLocalData()) return;

    final pairingCode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => VaultLinkCodeDialog(
        title: _text('加入远程配对', 'Join Remote Pairing'),
        subtitle: _text(
          '输入已有可信设备显示的远程配对码。提交后需要对方设备批准，服务器只负责中转。',
          'Enter the pairing code shown on your trusted existing device.',
        ),
        confirmLabel: _text('请求配对', 'Request Pairing'),
        cancelLabel: _text('取消', 'Cancel'),
        fieldLabel: _text('远程配对码', 'Remote Pairing Code'),
      ),
    );

    if (!mounted || pairingCode == null) return;

    setState(() => _isPairingBusy = true);
    try {
      final joinResult = await _serviceManager.joinVaultPairingSession(
        pairingCode,
      );
      if (!mounted) return;

      setState(() {
        _joinPairingResult = joinResult;
        _joinPairingForceOverwrite = forceOverwrite;
      });
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _text(
              '配对请求已发送。请在可信设备上检查并批准。',
              'Pairing request sent. Ask the trusted device to approve it.',
            ),
          ),
        ),
      );
    } on VaultPairingServiceException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to join pairing session: $e');
    } finally {
      if (mounted) {
        setState(() => _isPairingBusy = false);
      }
    }
  }

  Future<void> _checkPairingBundleAndImport() async {
    final joinResult = _joinPairingResult;
    if (joinResult == null || _isPairingBusy) return;

    setState(() => _isPairingBusy = true);
    try {
      final bundleResult = await _serviceManager
          .fetchAndImportVaultPairingBundle(
            sessionId: joinResult.sessionId,
            requestId: joinResult.requestId,
            forceOverwrite: _joinPairingForceOverwrite,
          );
      if (!mounted) return;

      if (bundleResult.status == 'approved') {
        setState(() {
          _joinPairingResult = null;
          _joinPairingForceOverwrite = false;
        });
        final provider = context.read<EnhancedAppProvider>();
        final messenger = ScaffoldMessenger.of(context);
        await provider.refresh();
        if (!mounted) return;

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _text(
                '远程配对完成。若本次未携带全量数据，可执行一次同步拉取远程数据。',
                'Vault pairing completed. Run Sync Now to pull existing data.',
              ),
            ),
          ),
        );
        return;
      }

      if (bundleResult.status == 'pending_approval') {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _text(
                '仍在等待可信设备批准。',
                'Still waiting for approval on the trusted device.',
              ),
            ),
          ),
        );
        return;
      }

      if (bundleResult.status == 'rejected' ||
          bundleResult.status == 'expired') {
        setState(() {
          _joinPairingResult = null;
          _joinPairingForceOverwrite = false;
        });
      }
      _showError('Pairing status: ${bundleResult.status}');
    } on VaultPairingServiceException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } on IdentityTransferCodeException catch (e) {
      if (!mounted) return;
      _showError(
        _text(
          '导入的远程配对包无效: ${e.message}',
          'Imported bundle is invalid: ${e.message}',
        ),
      );
    } on VaultImportPreconditionException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } on VaultImportException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError(_text('获取远程配对结果失败: $e', 'Failed to fetch pairing bundle: $e'));
    } finally {
      if (mounted) {
        setState(() => _isPairingBusy = false);
      }
    }
  }

  Future<void> _exportSecureVaultLinkCode() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final bool? includeData = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_text('导出离线恢复码', 'Export Offline Recovery Code')),
          content: Text(
            _text(
              '离线恢复码用于没有面对面链接或远程配对条件时手动恢复密钥。\n\n包含全量数据后可在纯离线场景恢复快照，但密文会更长；仅包含身份密钥时，新设备后续仍需要同步服务器拉取数据。',
              'Offline recovery codes are for manual key recovery when face-to-face or remote pairing is unavailable.\n\nIncluding all data enables offline snapshot recovery but makes the ciphertext much longer; identity-only recovery still needs a sync server later.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_text('仅恢复密钥', 'Keys Only')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_text('密钥 + 数据快照', 'Keys + Data Snapshot')),
            ),
          ],
        ),
      );

      if (includeData == null) return;

      final password = await _showPasswordInputDialog(
        title: _text('设置恢复密码', 'Set Recovery Password'),
        subtitle: _text(
          '恢复码会使用此密码加密。请单独保存密码，不要和恢复码放在同一处。',
          'This password encrypts the recovery code. Store it separately from the code.',
        ),
      );
      if (password == null) return;

      final code = await _serviceManager.exportSecureVaultLinkCode(
        password,
        includeData: includeData,
      );
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _text('离线恢复码已复制到剪贴板', 'Offline recovery code copied to clipboard'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(_text('导出失败: $e', 'Export failed: $e'));
    }
  }

  Future<void> _importSecureVaultLinkCode() async {
    final forceOverwrite = _hasLocalVaultData();
    if (forceOverwrite && !await _confirmOverwriteLocalData()) return;

    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => VaultLinkCodeDialog(
        title: _text('导入离线恢复码', 'Import Offline Recovery Code'),
        subtitle: _text(
          '粘贴此前导出的离线恢复码。恢复会切换本设备的保险库密钥，可能覆盖本地数据。',
          'Paste a previously exported offline recovery code. Importing switches this device to that vault key and may overwrite local data.',
        ),
        confirmLabel: _text('下一步', 'Next'),
        cancelLabel: _text('取消', 'Cancel'),
        fieldLabel: _text('离线恢复码', 'Offline Recovery Code'),
        minLines: 4,
        maxLines: 12,
      ),
    );

    if (!mounted || code == null || code.isEmpty) return;

    final password = await _showPasswordInputDialog(
      title: _text('输入恢复密码', 'Enter Recovery Password'),
      subtitle: _text(
        '请输入导出恢复码时设置的密码。',
        'Enter the password set when the recovery code was exported.',
      ),
    );
    if (password == null) return;

    try {
      setState(() => _isPairingBusy = true);
      await _serviceManager.importSecureVaultLinkCode(
        code,
        password,
        forceOverwrite: forceOverwrite,
      );
      if (!mounted) return;

      final provider = context.read<EnhancedAppProvider>();
      final messenger = ScaffoldMessenger.of(context);

      await provider.refresh();
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _text('离线恢复码导入成功', 'Recovery code imported successfully'),
          ),
        ),
      );
    } on IdentityTransferCodeException catch (e) {
      if (!mounted) return;
      _showError(_text('导入失败: ${e.message}', 'Import failed: ${e.message}'));
    } on VaultImportPreconditionException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } on VaultImportException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError(_text('导入失败: $e', 'Import failed: $e'));
    } finally {
      if (mounted) {
        setState(() => _isPairingBusy = false);
      }
    }
  }

  Future<String?> _showPasswordInputDialog({
    required String title,
    required String subtitle,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subtitle),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _text('密码', 'Password'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_text('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(_text('确定', 'OK')),
          ),
        ],
      ),
    );
  }

  Future<void> _showGeneratedCodeDialog(
    String title,
    String subtitle,
    String code, {
    bool showCopyNotice = true,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(subtitle),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  code,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (showCopyNotice) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _text(
                        '配对码已自动复制到剪贴板',
                        'Pairing code copied to clipboard.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 12),
                Text(
                  _text(
                    '保持此窗口打开，完成后密钥包会自动销毁。',
                    'Keep this window open. The key bundle is destroyed after use.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_text('确定', 'OK')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSyncContent(BuildContext context) {
    final theme = Theme.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<EnhancedAppProvider>();
    final hasDirtyData = _serviceManager.hasDirtyData;
    final syncState = _serviceManager.syncState;
    final syncError = _serviceManager.syncErrorMessage;
    final syncNote = _serviceManager.syncStatusNote;
    final syncMessage = syncNote ?? syncError;
    final statusTone = _syncStatusTone(context, syncState, syncMessage);
    final statusDescription = _syncStatusDescription(
      syncState,
      syncMessage,
      hasDirtyData: hasDirtyData,
    );
    final actionTitle = _syncActionTitle(
      syncState,
      syncMessage,
      hasDirtyData: hasDirtyData,
    );
    final actionDetail = _syncActionDetail(
      syncState,
      syncMessage,
      hasDirtyData: hasDirtyData,
    );
    final showsInlineServerEditAction = _showsInlineServerEditAction(
      syncState,
      syncMessage,
    );
    final primaryActionLabel = _primarySyncActionLabel(
      syncState,
      hasDirtyData: hasDirtyData,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text('服务器地址', 'Server Address'),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                _syncServerUrl,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SyncInfoChip(
                    label: _text(
                      '版本 V${_serviceManager.syncVersion}',
                      'Version V${_serviceManager.syncVersion}',
                    ),
                  ),
                  SyncInfoChip(
                    label: hasDirtyData
                        ? _text('有未同步更改', 'Unsynced changes')
                        : _text('已与服务器对齐', 'Ready to sync'),
                  ),
                  SyncInfoChip(label: _syncStateLabel(syncState)),
                ],
              ),
              if (statusDescription != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusTone.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        statusTone.icon,
                        size: 18,
                        color: statusTone.foreground,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusDescription,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusTone.foreground,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (actionTitle != null && actionDetail != null) ...[
                const SizedBox(height: 12),
                Text(
                  actionTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  actionDetail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (showsInlineServerEditAction)
                      OutlinedButton.icon(
                        onPressed: _isSavingSyncServer
                            ? null
                            : _showSyncConfigDialog,
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(_text('修改 Server', 'Edit Server')),
                      ),
                    if (!showsInlineServerEditAction &&
                        !_serviceManager.syncService.isSyncing)
                      FilledButton.icon(
                        onPressed: () =>
                            _runSync(navigator, messenger, provider),
                        icon: const Icon(Icons.refresh),
                        label: Text(primaryActionLabel),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSavingSyncServer ? null : _showSyncConfigDialog,
                icon: _isSavingSyncServer
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.settings_ethernet_outlined),
                label: Text(_text('服务器', 'Server')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _serviceManager.syncService.isSyncing
                    ? null
                    : () => _runSync(navigator, messenger, provider),
                icon: const Icon(Icons.sync_outlined),
                label: Text(primaryActionLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.tertiaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withAlpha(210),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.sync_outlined,
              size: 28,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text('分布式同步中心', 'Distributed Sync Center'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _text(
                    '端到端加密的本地优先架构，确保数据在多设备间安全同步。',
                    'Local-first architecture with end-to-end encrypted synchronization.',
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(80),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncListenable = Listenable.merge([
      _serviceManager,
      _serviceManager.syncService,
    ]);

    return AnimatedBuilder(
      animation: syncListenable,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(_text('数据同步', 'Sync Data'))),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : AdaptivePage(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    children: [
                      _buildHeroCard(context),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        context: context,
                        title: _text('同步控制', 'Sync Controls'),
                        subtitle: _text(
                          '管理同步服务器地址并执行即时数据同步。',
                          'Manage the server URL and trigger immediate synchronization.',
                        ),
                        child: _buildSyncContent(context),
                      ),
                      const SizedBox(height: 16),
                      _buildVaultLinkSection(context),
                      const SizedBox(height: 16),
                      _buildDiagnosticSection(context),
                      const SizedBox(height: 16),
                      _buildTechnicalInsights(context),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildDiagnosticSection(BuildContext context) {
    final identity = _serviceManager.identityService;
    final lastSync = _serviceManager.syncService.lastSyncTime;
    final lastSyncStr = lastSync == null
        ? _text('从未同步', 'Never')
        : '${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}:${lastSync.second.toString().padLeft(2, '0')}';

    return _buildSectionCard(
      context: context,
      title: _text('诊断与标识', 'Diagnostics & Identity'),
      subtitle: _text(
        '当前设备的同步元数据与网络标识。',
        'Sync metadata and network identity for this device.',
      ),
      child: Column(
        children: [
          _buildInfoRow(
            context,
            Icons.fingerprint,
            _text('节点 ID (Node ID)', 'Node ID'),
            identity.deviceId,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            context,
            Icons.hub_outlined,
            _text('保险库 ID (Vault ID)', 'Vault ID'),
            identity.vaultId,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            context,
            Icons.update_outlined,
            _text('上次同步时间', 'Last Sync'),
            lastSyncStr,
          ),
        ],
      ),
    );
  }

  Widget _buildVaultLinkSection(BuildContext context) {
    final theme = Theme.of(context);
    final hostSession = _hostPairingSession;
    final hostPendingRequest = _hostPendingRequest;
    final joinResult = _joinPairingResult;
    return _buildSectionCard(
      context: context,
      title: _text('密钥恢复与设备链接', 'Key Recovery & Device Linking'),
      subtitle: _text(
        '按场景选择入口，避免误用恢复能力覆盖本机保险库。',
        'Choose the route by scenario to avoid accidentally overwriting this device vault.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecoveryRouteGuide(context),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(70),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _text(
                '日常加新设备优先使用面对面链接或远程配对；离线恢复码只用于无法配对时的应急恢复；内部兼容码不作为普通用户入口。',
                'Use face-to-face linking or remote pairing for normal device setup. Offline recovery codes are for emergency recovery, and internal compatibility codes are not a normal user entry.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildActionHeader(
            context,
            Icons.wifi_find_outlined,
            _text('面对面链接：8 位临时码', 'Face-to-Face Link: 8-Character Code'),
            _text(
              '两台设备在同一可信局域网内，且仅在配对码窗口打开期间可领取密钥包。',
              'The key bundle can be claimed only while the 8-character code window is open.',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _isLanPairingBusy ? null : _startLanPairingHost,
                  icon: _isLanPairingBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_outlined, size: 18),
                  label: Text(_text('显示临时码', 'Show Code')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLanPairingBusy
                      ? null
                      : _showJoinLanPairingDialog,
                  icon: const Icon(Icons.pin_outlined, size: 18),
                  label: Text(_text('输入临时码', 'Enter Code')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _text(
              '关闭配对码窗口、领取成功或超时后，本机都会立即销毁本次密钥包。',
              'Closing the code window, a successful claim, or timeout destroys this key bundle.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: theme.colorScheme.outlineVariant.withAlpha(140)),
          const SizedBox(height: 8),
          _buildActionHeader(
            context,
            Icons.admin_panel_settings_outlined,
            _text('远程配对：可信设备批准', 'Remote Pairing: Trusted Approval'),
            _text(
              '两台设备不在同一局域网时使用。服务器只中转请求和密文，已有设备必须手动批准。',
              'Use when devices are not on the same LAN. The server relays requests and ciphertext, and an existing device must approve.',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _isPairingBusy ? null : _createVaultPairingSession,
                  icon: _isPairingBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_link_outlined, size: 18),
                  label: Text(_text('创建', 'Create')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isPairingBusy ? null : _showJoinPairingCodeDialog,
                  icon: const Icon(Icons.link_outlined, size: 18),
                  label: Text(_text('加入', 'Join')),
                ),
              ),
            ],
          ),
          if (hostSession != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(95),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text('主机端会话', 'Host Session'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    '${_text('配对码', 'Pairing Code')}: ${hostSession.pairingCode}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_text('会话 ID', 'Session')}: ${hostSession.sessionId}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${_text('过期时间', 'Expires')}: ${hostSession.expiresAt.toLocal()}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isPairingBusy
                          ? null
                          : _refreshHostPairingSession,
                      icon: const Icon(Icons.refresh_outlined, size: 18),
                      label: Text(_text('检查设备接入请求', 'Check Requests')),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hostPendingRequest != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withAlpha(120),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text('待处理请求', 'Pending Request'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_text('请求节点 ID', 'Requester Node')}: ${hostPendingRequest.requesterDeviceId}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isPairingBusy
                          ? null
                          : _approvePendingPairingRequest,
                      icon: const Icon(Icons.verified_user_outlined, size: 18),
                      label: Text(_text('允许设备加入', 'Approve Device')),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (joinResult != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withAlpha(110),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text('加入请求处理中', 'Join Request In Progress'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_text('会话 ID', 'Session')}: ${joinResult.sessionId}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '${_text('请求 ID', 'Request')}: ${joinResult.requestId}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isPairingBusy
                          ? null
                          : _checkPairingBundleAndImport,
                      icon: const Icon(
                        Icons.download_for_offline_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _text('检查授权结果并导入', 'Check Approval & Import'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: theme.colorScheme.outlineVariant.withAlpha(140)),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.vpn_key_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              _text('离线恢复码', 'Offline Recovery Code'),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              _text(
                '手动导出和导入加密恢复码。仅在无法使用面对面链接或远程配对时使用。',
                'Manually export and import encrypted recovery codes. Use only when pairing is unavailable.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _text(
                    '恢复码会携带保险库密钥材料。请设置恢复密码，并将恢复码和密码分开保存。',
                    'Recovery codes carry vault key material. Set a recovery password and store the code separately from the password.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _exportSecureVaultLinkCode,
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: Text(_text('导出恢复码', 'Export recovery code')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _importSecureVaultLinkCode,
                      icon: const Icon(Icons.paste_outlined, size: 18),
                      label: Text(_text('导入恢复码', 'Import recovery code')),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.integration_instructions_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              _text('内部兼容码说明', 'Internal Compatibility Code'),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              _text(
                '用于旧链路和内部密钥包承载，不作为普通恢复入口展示。',
                'Used by internal bundle transport; not exposed as a normal recovery entry.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            children: [
              Text(
                _text(
                  '内部兼容码是 sroy-link 格式，当前仍被面对面链接和远程配对的密钥包流程承载使用。普通用户请使用上面的三个入口，不要手动保存或粘贴内部兼容码。',
                  'The internal compatibility code uses the sroy-link format and is still carried inside face-to-face and remote pairing bundles. Use the three entries above instead of manually saving or pasting this internal code.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalInsights(BuildContext context) {
    return _buildSectionCard(
      context: context,
      title: _text('技术架构说明', 'Technical Insights'),
      subtitle: _text(
        'SecretRoy 如何保障您的数据安全与一致性。',
        'How SecretRoy ensures your data security and consistency.',
      ),
      child: Column(
        children: [
          _buildInsightItem(
            context,
            Icons.security,
            _text('零知识加密 (Zero-Knowledge)', 'Zero-Knowledge Encryption'),
            _text(
              '所有数据在离开设备前均经由“保险库主密钥 (Vault Master Key)”进行加密。',
              'All data is encrypted by your "Vault Master Key" before leaving the device.',
            ),
          ),
          const SizedBox(height: 16),
          _buildInsightItem(
            context,
            Icons.merge_type,
            _text('CRDT 无冲突合并', 'CRDT Conflict-Free'),
            _text(
              '使用 HLC 混合逻辑时钟，确保多设备并发修改时能够自动确定性合并。',
              'Uses Hybrid Logical Clocks (HLC) to ensure deterministic merging of concurrent edits.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryRouteGuide(BuildContext context) {
    return Column(
      children: [
        _buildRouteGuideItem(
          context,
          Icons.wifi_tethering_outlined,
          _text('面对面链接', 'Face-to-face linking'),
          _text(
            '同一可信局域网内使用 8 位临时码，窗口关闭即停止领取。',
            'Use an 8-character temporary code on a trusted LAN; closing the window stops claims.',
          ),
        ),
        const SizedBox(height: 8),
        _buildRouteGuideItem(
          context,
          Icons.admin_panel_settings_outlined,
          _text('远程配对', 'Remote pairing'),
          _text(
            '通过服务器中转配对请求，必须由已有设备批准。',
            'Relay pairing requests through the server; an existing device must approve.',
          ),
        ),
        const SizedBox(height: 8),
        _buildRouteGuideItem(
          context,
          Icons.vpn_key_outlined,
          _text('离线恢复码', 'Offline recovery code'),
          _text(
            '手动保存的加密恢复码，用于无法配对时恢复密钥或数据快照。',
            'A manually saved encrypted recovery code for key or snapshot recovery when pairing is unavailable.',
          ),
        ),
        const SizedBox(height: 8),
        _buildRouteGuideItem(
          context,
          Icons.integration_instructions_outlined,
          _text('内部兼容码', 'Internal compatibility code'),
          _text(
            'sroy-link 仅作为内部承载格式，不作为普通用户入口。',
            'sroy-link is an internal transport format, not a normal user entry.',
          ),
        ),
      ],
    );
  }

  Widget _buildRouteGuideItem(
    BuildContext context,
    IconData icon,
    String title,
    String desc,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionHeader(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightItem(
    BuildContext context,
    IconData icon,
    String title,
    String desc,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
