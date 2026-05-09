import 'package:flutter/material.dart';

import '../l10n/app_text_extension.dart';
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

  String _durationLabel(AutoLockDuration duration) {
    switch (duration) {
      case AutoLockDuration.immediately:
        return context.text('立即', 'Immediately');
      case AutoLockDuration.fiveSeconds:
        return context.text('5 秒', '5 seconds');
      case AutoLockDuration.thirtySeconds:
        return context.text('30 秒', '30 seconds');
      case AutoLockDuration.oneMinute:
        return context.text('1 分钟', '1 minute');
      case AutoLockDuration.fiveMinutes:
        return context.text('5 分钟', '5 minutes');
      case AutoLockDuration.tenMinutes:
        return context.text('10 分钟', '10 minutes');
      case AutoLockDuration.never:
        return context.text('从不', 'Never');
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
            context.text(
              '已关闭 $_biometricName 解锁',
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
              context.text(
                '$_biometricName 已启用',
                '$_biometricName enabled',
              ),
            ),
          ),
        );
        return;
      case BiometricSetupResult.notSupported:
        _showError(
          context.text(
            '当前设备不支持 $_biometricName。',
            'This device does not support $_biometricName.',
          ),
        );
        return;
      case BiometricSetupResult.notEnrolled:
        _showError(
          context.text(
            '请先在系统设置中录入 $_biometricName。',
            'Set up $_biometricName in system settings first.',
          ),
        );
        return;
      case BiometricSetupResult.cancelled:
        return;
      case BiometricSetupResult.invalidPassword:
        _showError(
          context.text(
            '主密码不正确，无法启用 $_biometricName。',
            'Incorrect master password. Could not enable $_biometricName.',
          ),
        );
        return;
      case BiometricSetupResult.lockedOut:
        _showError(
          context.text(
            '生物识别已被临时锁定，请稍后再试。',
            'Biometrics are temporarily locked. Try again later.',
          ),
        );
        return;
      case BiometricSetupResult.passcodeNotSet:
        _showError(
          context.text(
            '请先为设备设置锁屏密码。',
            'Set a device passcode before enabling biometrics.',
          ),
        );
        return;
      case BiometricSetupResult.noPasswordMode:
        _showError(
          context.text(
            '无密码模式下无法启用生物识别。请先设置主密码。',
            'Biometrics cannot be enabled in no-password mode. Please set a master password first.',
          ),
        );
        return;
      case BiometricSetupResult.error:
        _showError(
          context.text(
            '启用 $_biometricName 失败。',
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
        title: Text(context.text('验证身份', 'Verify Identity')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.text(
                '请输入主密码以启用 $_biometricName 解锁。',
                'Enter your master password to enable $_biometricName unlock.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.text('主密码', 'Master Password'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.text('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(context.text('确认', 'Confirm')),
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
              color: theme.colorScheme.surface.withAlpha(
                AppAlphas.surfaceOverlay,
              ),
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
                  context.text('安全设置', 'Security Settings'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.text(
                    '统一管理自动锁定与生物识别。',
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
                  color: theme.colorScheme.primaryContainer.withAlpha(
                    AppAlphas.strong,
                  ),
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
        context.text(
          '当前设备不支持生物识别。',
          'Biometrics are not supported on this device.',
        ),
      );
    }

    if (_biometricStatus == BiometricAuthStatus.notEnrolled) {
      return Text(
        context.text(
          '请先在系统设置里开启 $_biometricName。',
          'Set up $_biometricName in the operating system first.',
        ),
      );
    }

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.fingerprint),
      title: Text(
        context.text(
          '使用 $_biometricName 解锁',
          'Use $_biometricName to unlock',
        ),
      ),
      subtitle: Text(
        context.text(
          '使用生物识别更快访问保险库',
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
                ? context.text('启用主密码', 'Enable Master Password')
                : context.text('修改主密码', 'Change Master Password'),
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
                      labelText: context.text('当前主密码', 'Current Master Password'),
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
                    labelText: context.text('新主密码', 'New Master Password'),
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
                    labelText: context.text('确认新主密码', 'Confirm New Password'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.text('取消', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.text('两次输入的密码不一致', 'Passwords do not match'),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(context.text('确认', 'Confirm')),
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
                context.text('主密码更新成功', 'Master password updated successfully'),
              ),
            ),
          );
        } else {
          _showError(
            context.text(
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
          ? context.text('启用主密码保护', 'Enable Password Protection')
          : context.text('修改主密码', 'Change Master Password'),
      subtitle: _isNoPasswordMode
          ? context.text('为您的数据设置一个强密码', 'Set a strong password for your data')
          : context.text(
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
        title: Text(context.text('安全设置', 'Security Settings')),
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
                    title: context.text(
                      '主密码管理',
                      'Master Password',
                    ),
                    subtitle: _isNoPasswordMode
                        ? context.text(
                            '您当前已跳过主密码，建议启用以保护数据安全。',
                            'You currently have no master password. Enable one for better security.',
                          )
                        : context.text(
                            '修改您的保险库主密码。',
                            'Change your vault master password.',
                          ),
                    child: _buildPasswordManagementTile(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSectionCard(
                    context: context,
                    title: context.text('自动锁定', 'Auto Lock'),
                    subtitle: context.text(
                      '设置应用退到后台后多久自动锁定。',
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
                            subtitle: context.text(
                              '在达到时间后要求重新解锁',
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
                    title: context.text('生物识别', 'Biometrics'),
                    subtitle: context.text(
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
        border: Border.all(
          color: theme.colorScheme.error.withAlpha(AppAlphas.medium),
        ),
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
                context.text('危险区域', 'Danger Zone'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.text(
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
              label: Text(context.text('销毁保险库并重置', 'Destroy Vault & Reset')),
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
        title: Text(context.text('彻底销毁确认', 'Destruction Confirmation')),
        content: Text(
          context.text(
            '这将删除本地所有加密数据库、身份密钥和配置信息。完成后应用将强制重启。确认继续吗？',
            'This will delete all local encrypted databases, identity keys, and configurations. The app will restart afterwards. Continue?',
          ),
        ),
        actions: [
          TextButton(
            child: Text(context.text('取消', 'Cancel')),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.text('确认销毁', 'Confirm Destruction')),
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
            context.text('数据已销毁，请手动重启应用。', 'Data destroyed. Please restart the app.'),
          ),
        ),
      );

      // Navigate to splash or exit
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }
}
