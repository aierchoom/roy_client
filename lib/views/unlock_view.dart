import 'package:flutter/material.dart';

import '../l10n/app_text_extension.dart';
import '../services/biometric_auth_service.dart';
import '../services/service_manager.dart';
import '../widgets/adaptive_page.dart';
import '../theme/app_design_tokens.dart';
import '../theme/app_layout.dart';

class UnlockView extends StatefulWidget {
  const UnlockView({super.key});

  @override
  State<UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends State<UnlockView> {
  final _passwordController = TextEditingController();
  final _serviceManager = ServiceManager.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  BiometricAuthStatus _biometricStatus = BiometricAuthStatus.notSupported;
  String _biometricName = 'Biometrics';
  bool _isFirstRun = false;
  bool _checkingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkAppLaunchStatus();
    _checkBiometricStatus();
  }

  Future<void> _checkAppLaunchStatus() async {
    final noPasswordMode = await _serviceManager.isNoPasswordMode();
    if (noPasswordMode) {
      if (mounted) {
        await _unlockWithNoPassword();
      }
      return;
    }

    final hasDatabase = await _serviceManager.storageService
        .isDatabaseInitialized();
    final hasIdentity = await _serviceManager.checkIdentityExists();

    if (!mounted) return;

    setState(() {
      // Only a clean device can create a fresh vault identity implicitly.
      // If a database exists but identity keys are missing, unlock must fail
      // through ServiceManager instead of silently rebasing old data.
      _isFirstRun = !hasDatabase && !hasIdentity;
      _checkingStatus = false;
    });
  }

  Future<void> _checkBiometricStatus() async {
    final status = await _serviceManager.getBiometricStatus();
    final name = await _serviceManager.getBiometricName();

    if (!mounted) return;
    setState(() {
      _biometricStatus = status;
      _biometricName = name;
    });

    if (status == BiometricAuthStatus.enabled && mounted) {
      await _unlockWithBiometric();
    }
  }

  Future<void> _unlockWithNoPassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_isFirstRun) {
      // 首次运行或身份丢失时创建新保险库，先彻底清理旧数据库文件以防冲突
      await _serviceManager.storageService.deleteDatabaseFile();
    }

    await _serviceManager.enableNoPasswordMode();

    if (!mounted) return;
    if (_serviceManager.state == ServiceManagerState.unlocked) return;

    setState(() {
      _isLoading = false;
      _checkingStatus = false;
      _errorMessage =
          _serviceManager.errorMessage ??
          context.text(
            '\u89e3\u9501\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
            'Unlock failed. Please try again.',
          );
    });
  }

  Future<void> _unlockWithPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_isFirstRun) {
      // 首次运行或身份丢失时创建新保险库，先彻底清理旧数据库文件以防冲突
      await _serviceManager.storageService.deleteDatabaseFile();
    }

    final result = await _serviceManager.unlockWithPassword(password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case UnlockResult.success:
        return;
      case UnlockResult.invalidPassword:
        setState(
          () => _errorMessage = context.text(
            '\u4e3b\u5bc6\u7801\u4e0d\u6b63\u786e\u3002',
            'Incorrect master password.',
          ),
        );
        return;
      case UnlockResult.biometricNotEnabled:
      case UnlockResult.biometricFailed:
      case UnlockResult.alreadyInProgress:
      case UnlockResult.error:
        setState(
          () => _errorMessage =
              _serviceManager.errorMessage ??
              context.text(
                '\u89e3\u9501\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
                'Unlock failed. Please try again.',
              ),
        );
        return;
    }
  }

  Future<void> _unlockWithBiometric() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _serviceManager.unlockWithBiometric();

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case UnlockResult.success:
        return;
      case UnlockResult.biometricFailed:
        setState(
          () => _errorMessage = context.text(
            '\u751f\u7269\u8bc6\u522b\u9a8c\u8bc1\u5931\u8d25\u3002',
            'Biometric verification failed.',
          ),
        );
        return;
      case UnlockResult.invalidPassword:
      case UnlockResult.biometricNotEnabled:
      case UnlockResult.alreadyInProgress:
      case UnlockResult.error:
        setState(
          () => _errorMessage = context.text(
            '\u89e3\u9501\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
            'Unlock failed. Please try again.',
          ),
        );
        return;
    }
  }

  Future<void> _resetApp() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.text('\u6e05\u7a7a\u672c\u673a\u5e93', 'Clear Local Vault'),
        ),
        content: Text(
          context.text(
            '\u8fd9\u4f1a\u4ece\u5f53\u524d\u8bbe\u5907\u4e0a\u5220\u9664\u6240\u6709\u672c\u5730\u8d26\u6237\u548c\u8bbe\u7f6e\u3002',
            'This removes all local accounts and settings from this device.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.text('\u53d6\u6d88', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.text('\u6e05\u7a7a', 'Clear')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    await _serviceManager.resetApplication();

    if (!mounted) return;
    setState(() {
      _isFirstRun = true;
      _isLoading = false;
      _errorMessage = null;
      _passwordController.clear();
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          context.text(
            '\u672c\u5730\u6570\u636e\u5df2\u6e05\u7a7a\u3002',
            'Local data cleared successfully.',
          ),
        ),
      ),
    );
  }

  Widget _buildBrandPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primaryContainer, colorScheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: colorScheme.surface.withAlpha(AppAlphas.surfaceOverlay),
              borderRadius: BorderRadius.circular(AppRadii.panel),
            ),
            child: Icon(
              Icons.lock_outline,
              size: 42,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'SecretRoy',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.text(
              '\u4e00\u4e2a\u540c\u65f6\u7167\u987e\u624b\u673a\u4e0e\u684c\u9762\u7aef\u4f53\u9a8c\u7684\u5b89\u5168\u5e93\u3002',
              'A secure vault experience designed for both mobile and desktop.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimaryContainer.withAlpha(180),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroBadge(
                label: context.text(
                  '\u4e3b\u5bc6\u7801\u4fdd\u62a4',
                  'Master password protected',
                ),
                onColor: colorScheme.onPrimaryContainer,
              ),
              _HeroBadge(
                label: context.text(
                  '\u652f\u6301\u751f\u7269\u8bc6\u522b',
                  'Biometric support',
                ),
                onColor: colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isFirstRun
                  ? context.text('\u521b\u5efa\u4fdd\u9669\u5e93', 'Create Vault')
                  : context.text('\u89e3\u9501\u4fdd\u9669\u5e93', 'Unlock Vault'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _isFirstRun
                  ? context.text(
                      '\u7b2c\u4e00\u6b21\u4f7f\u7528\u65f6\uff0c\u8bf7\u5148\u8bbe\u7f6e\u4e3b\u5bc6\u7801\u6216\u9009\u62e9\u8df3\u8fc7\u3002',
                      'Set a master password for your first launch, or choose to skip it.',
                    )
                  : context.text(
                      '\u4f7f\u7528\u4e3b\u5bc6\u7801\u6216\u751f\u7269\u8bc6\u522b\u8fdb\u5165 SecretRoy\u3002',
                      'Use your master password or biometrics to enter SecretRoy.',
                    ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              enabled: !_isLoading,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _unlockWithPassword(),
              decoration: InputDecoration(
                labelText: _isFirstRun
                    ? context.text(
                        '\u521b\u5efa\u4e3b\u5bc6\u7801',
                        'Create Master Password',
                      )
                    : context.text('\u4e3b\u5bc6\u7801', 'Master Password'),
                hintText: _isFirstRun
                    ? context.text(
                        '\u4e3a\u9996\u6b21\u4f7f\u7528\u8bbe\u7f6e\u4e00\u4e2a\u4e3b\u5bc6\u7801',
                        'Set a master password for the first run',
                      )
                    : context.text(
                        '\u8f93\u5165\u4f60\u7684\u4e3b\u5bc6\u7801',
                        'Enter your master password',
                      ),
                prefixIcon: const Icon(Icons.password_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _unlockWithPassword,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isFirstRun
                            ? Icons.add_moderator_outlined
                            : Icons.lock_open_outlined,
                      ),
                label: Text(
                  _isLoading
                      ? context.text('\u5904\u7406\u4e2d...', 'Working...')
                      : (_isFirstRun
                            ? context.text(
                                '\u521b\u5efa\u4fdd\u9669\u5e93',
                                'Create Vault',
                              )
                            : context.text('\u89e3\u9501', 'Unlock')),
                ),
              ),
            ),
            if (_isFirstRun) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _unlockWithNoPassword,
                  icon: const Icon(Icons.no_encryption_outlined),
                  label: Text(
                    context.text(
                      '\u8df3\u8fc7\u4e3b\u5bc6\u7801',
                      'Skip Master Password',
                    ),
                  ),
                ),
              ),
            ],
            if (_biometricStatus == BiometricAuthStatus.enabled &&
                !_isFirstRun) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _unlockWithBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(
                    context.text(
                      '\u4f7f\u7528 $_biometricName',
                      'Use $_biometricName',
                    ),
                  ),
                ),
              ),
            ],
            if (!_isFirstRun) ...[
              const SizedBox(height: AppSpacing.xl),
              TextButton(
                onPressed: _isLoading ? null : _resetApp,
                child: Text(
                  context.text(
                    '\u5fd8\u8bb0\u5bc6\u7801\uff1f\u91cd\u7f6e\u672c\u673a\u8bbe\u5907',
                    'Forgot password? Reset this device',
                  ),
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppLayout.isExpanded(context);

    return Scaffold(
      body: SafeArea(
        child: _checkingStatus
            ? const Center(child: CircularProgressIndicator())
            : AdaptivePage(
                desktopMaxWidth: 1220,
                tabletMaxWidth: 760,
                child: Center(
                  child: isDesktop
                      ? Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 20),
                                child: _buildBrandPanel(context),
                              ),
                            ),
                            SizedBox(
                              width: 460,
                              child: SingleChildScrollView(
                                child: _buildAuthCard(context),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xxl,
                          ),
                          child: Column(
                            children: [
                              _buildBrandPanel(context),
                              const SizedBox(height: 18),
                              _buildAuthCard(context),
                            ],
                          ),
                        ),
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}

class _HeroBadge extends StatelessWidget {
  final String label;
  final Color onColor;

  const _HeroBadge({required this.label, required this.onColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: onColor.withAlpha(AppAlphas.tint),
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: onColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
