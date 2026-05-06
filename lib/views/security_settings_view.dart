import 'package:flutter/material.dart';

import '../services/auto_lock_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/service_manager.dart';
import '../widgets/adaptive_page.dart';
import '../theme/app_design_tokens.dart';

class SecuritySettingsView extends StatefulWidget {
  const SecuritySettingsView({super.key});

  @override
  State<SecuritySettingsView> createState() => _SecuritySettingsViewState();
}

class _SecuritySettingsViewState extends State<SecuritySettingsView> {
  final _serviceManager = ServiceManager.instance;

  bool _isLoading = false;
  BiometricAuthStatus _biometricStatus = BiometricAuthStatus.notSupported;
  String _biometricName = 'Biometrics';
  AutoLockDuration _autoLockDuration = AutoLockDuration.oneMinute;
  bool _isNoPasswordMode = false;

  String _text(String zh, String en) {
    if (!mounted) return en;
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  String _durationLabel(AutoLockDuration duration) {
    switch (duration) {
      case AutoLockDuration.immediately:
        return _text('\u7acb\u5373', 'Immediately');
      case AutoLockDuration.fiveSeconds:
        return _text('5 \u79d2', '5 seconds');
      case AutoLockDuration.thirtySeconds:
        return _text('30 \u79d2', '30 seconds');
      case AutoLockDuration.oneMinute:
        return _text('1 \u5206\u949f', '1 minute');
      case AutoLockDuration.fiveMinutes:
        return _text('5 \u5206\u949f', '5 minutes');
      case AutoLockDuration.tenMinutes:
        return _text('10 \u5206\u949f', '10 minutes');
      case AutoLockDuration.never:
        return _text('\u4ece\u4e0d', 'Never');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final biometricStatus = await _serviceManager.getBiometricStatus();
    final biometricName = await _serviceManager.getBiometricName();

    final noPasswordMode = await _serviceManager.isNoPasswordMode();

    if (!mounted) return;
    setState(() {
      _biometricStatus = biometricStatus;
      _biometricName = biometricName;
      _autoLockDuration = _serviceManager.autoLockDuration;
      _isNoPasswordMode = noPasswordMode;
      _isLoading = false;
    });
  }

  Future<void> _toggleBiometric(bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!enabled) {
      await _serviceManager.disableBiometric();
      if (!mounted) return;
      setState(() => _biometricStatus = BiometricAuthStatus.available);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _text(
              '\u5df2\u5173\u95ed $_biometricName \u89e3\u9501',
              '$_biometricName unlock disabled',
            ),
          ),
        ),
      );
      return;
    }

    final password = await _showPasswordDialog();
    if (password == null || password.isEmpty) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    final result = await _serviceManager.enableBiometric(password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case BiometricSetupResult.success:
        setState(() => _biometricStatus = BiometricAuthStatus.enabled);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _text(
                '$_biometricName \u5df2\u542f\u7528',
                '$_biometricName enabled',
              ),
            ),
          ),
        );
        return;
      case BiometricSetupResult.notSupported:
        _showError(
          _text(
            '\u5f53\u524d\u8bbe\u5907\u4e0d\u652f\u6301 $_biometricName\u3002',
            'This device does not support $_biometricName.',
          ),
        );
        return;
      case BiometricSetupResult.notEnrolled:
        _showError(
          _text(
            '\u8bf7\u5148\u5728\u7cfb\u7edf\u8bbe\u7f6e\u4e2d\u5f55\u5165 $_biometricName\u3002',
            'Set up $_biometricName in system settings first.',
          ),
        );
        return;
      case BiometricSetupResult.cancelled:
        return;
      case BiometricSetupResult.invalidPassword:
        _showError(
          _text(
            '\u4e3b\u5bc6\u7801\u4e0d\u6b63\u786e\uff0c\u65e0\u6cd5\u542f\u7528 $_biometricName\u3002',
            'Incorrect master password. Could not enable $_biometricName.',
          ),
        );
        return;
      case BiometricSetupResult.lockedOut:
        _showError(
          _text(
            '\u751f\u7269\u8bc6\u522b\u5df2\u88ab\u4e34\u65f6\u9501\u5b9a\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
            'Biometrics are temporarily locked. Try again later.',
          ),
        );
        return;
      case BiometricSetupResult.passcodeNotSet:
        _showError(
          _text(
            '\u8bf7\u5148\u4e3a\u8bbe\u5907\u8bbe\u7f6e\u9501\u5c4f\u5bc6\u7801\u3002',
            'Set a device passcode before enabling biometrics.',
          ),
        );
        return;
      case BiometricSetupResult.noPasswordMode:
        _showError(
          _text(
            '\u65e0\u5bc6\u7801\u6a21\u5f0f\u4e0b\u65e0\u6cd5\u542f\u7528\u751f\u7269\u8bc6\u522b\u3002\u8bf7\u5148\u8bbe\u7f6e\u4e3b\u5bc6\u7801\u3002',
            'Biometrics cannot be enabled in no-password mode. Please set a master password first.',
          ),
        );
        return;
      case BiometricSetupResult.error:
        _showError(
          _text(
            '\u542f\u7528 $_biometricName \u5931\u8d25\u3002',
            'Failed to enable $_biometricName.',
          ),
        );
        return;
    }
  }

  Future<void> _setAutoLockDuration(AutoLockDuration duration) async {
    await _serviceManager.setAutoLockDuration(duration);
    if (!mounted) return;
    setState(() => _autoLockDuration = duration);
  }

  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text('\u9a8c\u8bc1\u8eab\u4efd', 'Verify Identity')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _text(
                '\u8bf7\u8f93\u5165\u4e3b\u5bc6\u7801\u4ee5\u542f\u7528 $_biometricName \u89e3\u9501\u3002',
                'Enter your master password to enable $_biometricName unlock.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _text('\u4e3b\u5bc6\u7801', 'Master Password'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_text('\u53d6\u6d88', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(_text('\u786e\u8ba4', 'Confirm')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
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
              color: theme.colorScheme.surface.withAlpha(AppAlphas.surfaceOverlay),
              borderRadius: BorderRadius.circular(AppRadii.panel),
            ),
            child: Icon(
              Icons.shield_outlined,
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
                  _text('\u5b89\u5168\u8bbe\u7f6e', 'Security Settings'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _text(
                    '\u7edf\u4e00\u7ba1\u7406\u81ea\u52a8\u9501\u5b9a\u4e0e\u751f\u7269\u8bc6\u522b\u3002',
                    'Manage auto lock and biometrics in one place.',
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

  Widget _buildOptionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(AppAlphas.strong),
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.check,
                        size: 14,
                        color: theme.colorScheme.onPrimary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricContent(BuildContext context) {
    if (_biometricStatus == BiometricAuthStatus.notSupported) {
      return Text(
        _text(
          '\u5f53\u524d\u8bbe\u5907\u4e0d\u652f\u6301\u751f\u7269\u8bc6\u522b\u3002',
          'Biometrics are not supported on this device.',
        ),
      );
    }

    if (_biometricStatus == BiometricAuthStatus.notEnrolled) {
      return Text(
        _text(
          '\u8bf7\u5148\u5728\u7cfb\u7edf\u8bbe\u7f6e\u91cc\u5f00\u542f $_biometricName\u3002',
          'Set up $_biometricName in the operating system first.',
        ),
      );
    }

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.fingerprint),
      title: Text(
        _text(
          '\u4f7f\u7528 $_biometricName \u89e3\u9501',
          'Use $_biometricName to unlock',
        ),
      ),
      subtitle: Text(
        _text(
          '\u4f7f\u7528\u751f\u7269\u8bc6\u522b\u66f4\u5feb\u8bbf\u95ee\u4fdd\u9669\u5e93',
          'Use biometrics for faster access',
        ),
      ),
      value: _biometricStatus == BiometricAuthStatus.enabled,
      onChanged: _toggleBiometric,
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            _isNoPasswordMode
                ? _text('启用主密码', 'Enable Master Password')
                : _text('修改主密码', 'Change Master Password'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isNoPasswordMode)
                  TextField(
                    controller: oldPasswordController,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      labelText: _text('当前主密码', 'Current Master Password'),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureOld = !obscureOld),
                      ),
                    ),
                  ),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: _text('新主密码', 'New Master Password'),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _text('确认新主密码', 'Confirm New Password'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_text('取消', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _text('两次输入的密码不一致', 'Passwords do not match'),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(_text('确认', 'Confirm')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      final success = await _serviceManager.changeMasterPassword(
        _isNoPasswordMode ? '' : oldPasswordController.text,
        newPasswordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          final noPassword = await _serviceManager.isNoPasswordMode();
          if (!mounted) return;
          final messenger = ScaffoldMessenger.of(context);
          setState(() => _isNoPasswordMode = noPassword);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                _text('主密码更新成功', 'Master password updated successfully'),
              ),
            ),
          );
        } else {
          _showError(
            _text(
              '更新失败，请检查当前密码是否正确',
              'Update failed. Please check your current password.',
            ),
          );
        }
      }
    }

    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Widget _buildPasswordManagementTile(BuildContext context) {
    return _buildOptionTile(
      context: context,
      title: _isNoPasswordMode
          ? _text('启用主密码保护', 'Enable Password Protection')
          : _text('修改主密码', 'Change Master Password'),
      subtitle: _isNoPasswordMode
          ? _text('为您的数据设置一个强密码', 'Set a strong password for your data')
          : _text(
              '定期更换密码以提高安全性',
              'Change password periodically for better security',
            ),
      icon: Icons.password_outlined,
      selected: false,
      onTap: _showChangePasswordDialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_text('\u5b89\u5168\u8bbe\u7f6e', 'Security Settings')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AdaptivePage(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  _buildHeroCard(context),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSectionCard(
                    context: context,
                    title: _text(
                      '\u4e3b\u5bc6\u7801\u7ba1\u7406',
                      'Master Password',
                    ),
                    subtitle: _isNoPasswordMode
                        ? _text(
                            '\u60a8\u5f53\u524d\u5df2\u8df3\u8fc7\u4e3b\u5bc6\u7801\uff0c\u5efa\u8bae\u542f\u7528\u4ee5\u4fdd\u62a4\u6570\u636e\u5b89\u5168\u3002',
                            'You currently have no master password. Enable one for better security.',
                          )
                        : _text(
                            '\u4fee\u6539\u60a8\u7684\u4fdd\u9669\u5e93\u4e3b\u5bc6\u7801\u3002',
                            'Change your vault master password.',
                          ),
                    child: _buildPasswordManagementTile(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSectionCard(
                    context: context,
                    title: _text('\u81ea\u52a8\u9501\u5b9a', 'Auto Lock'),
                    subtitle: _text(
                      '\u8bbe\u7f6e\u5e94\u7528\u9000\u5230\u540e\u53f0\u540e\u591a\u4e45\u81ea\u52a8\u9501\u5b9a\u3002',
                      'Choose how quickly the vault locks after the app leaves the foreground.',
                    ),
                    child: Column(
                      children: [
                        for (
                          var i = 0;
                          i < AutoLockDuration.values.length;
                          i++
                        ) ...[
                          _buildOptionTile(
                            context: context,
                            title: _durationLabel(AutoLockDuration.values[i]),
                            subtitle: _text(
                              '\u5728\u8fbe\u5230\u65f6\u95f4\u540e\u8981\u6c42\u91cd\u65b0\u89e3\u9501',
                              'Require unlocking again after this delay',
                            ),
                            icon: Icons.timer_outlined,
                            selected:
                                _autoLockDuration == AutoLockDuration.values[i],
                            onTap: () => _setAutoLockDuration(
                              AutoLockDuration.values[i],
                            ),
                          ),
                          if (i != AutoLockDuration.values.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSectionCard(
                    context: context,
                    title: _text('生物识别', 'Biometrics'),
                    subtitle: _text(
                      '在设备支持的情况下，使用指纹或面容快速解锁。',
                      'Use fingerprint or face unlock when the device supports it.',
                    ),
                    child: _buildBiometricContent(context),
                  ),
                  const SizedBox(height: 32),
                  _buildDangerZone(context),
                ],
              ),
            ),
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withAlpha(AppAlphas.low),
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: theme.colorScheme.error.withAlpha(AppAlphas.medium)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                _text('危险区域', 'Danger Zone'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _text(
              '删除当前保险库的所有数据并重置应用。此操作不可撤销，请确保您已有备份。',
              'Permanently delete all data in this vault and reset the app. This action cannot be undone.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer.withAlpha(200),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                ),
              ),
              onPressed: _showFactoryResetDialog,
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(_text('销毁保险库并重置', 'Destroy Vault & Reset')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFactoryResetDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_text('彻底销毁确认', 'Destruction Confirmation')),
        content: Text(
          _text(
            '这将删除本地所有加密数据库、身份密钥和配置信息。完成后应用将强制重启。确认继续吗？',
            'This will delete all local encrypted databases, identity keys, and configurations. The app will restart afterwards. Continue?',
          ),
        ),
        actions: [
          TextButton(
            child: Text(_text('取消', 'Cancel')),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_text('确认销毁', 'Confirm Destruction')),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);

      await _serviceManager.resetApplication();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          content: Text(
            _text('数据已销毁，请手动重启应用。', 'Data destroyed. Please restart the app.'),
          ),
        ),
      );

      // Navigate to splash or exit
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }
}
