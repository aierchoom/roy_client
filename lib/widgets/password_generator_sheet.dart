import 'package:flutter/material.dart';

import '../l10n/app_text_extension.dart';
import '../services/service_manager.dart';
import '../services/sensitive_clipboard_service.dart';

class PasswordGeneratorResult {
  final String password;
  final PasswordGeneratorOptions options;

  const PasswordGeneratorResult({
    required this.password,
    required this.options,
  });
}

class PasswordGeneratorOptions {
  final int length;
  final bool includeUppercase;
  final bool includeLowercase;
  final bool includeNumbers;
  final bool includeSpecial;

  const PasswordGeneratorOptions({
    required this.length,
    required this.includeUppercase,
    required this.includeLowercase,
    required this.includeNumbers,
    required this.includeSpecial,
  });

  factory PasswordGeneratorOptions.defaults({int length = 20}) {
    return PasswordGeneratorOptions(
      length: length,
      includeUppercase: true,
      includeLowercase: true,
      includeNumbers: true,
      includeSpecial: true,
    );
  }
}

Future<PasswordGeneratorResult?> showPasswordGeneratorSheet(
  BuildContext context, {
  PasswordGeneratorOptions? initialOptions,
  String? title,
  String? subtitle,
  String? applyLabel,
  bool showApplyAction = true,
  int minLength = 8,
  int maxLength = 32,
}) {
  final normalizedMin = minLength.clamp(4, 64).toInt();
  final normalizedMax = maxLength.clamp(normalizedMin, 64).toInt();
  final baseOptions =
      initialOptions ??
      PasswordGeneratorOptions.defaults(
        length: normalizedMin > 20 ? normalizedMin : 20,
      );

  return showModalBottomSheet<PasswordGeneratorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) {
      return PasswordGeneratorSheet(
        initialOptions: baseOptions,
        title: title,
        subtitle: subtitle,
        applyLabel: applyLabel,
        showApplyAction: showApplyAction,
        minLength: normalizedMin,
        maxLength: normalizedMax,
      );
    },
  );
}

class PasswordGeneratorSheet extends StatefulWidget {
  final PasswordGeneratorOptions initialOptions;
  final String? title;
  final String? subtitle;
  final String? applyLabel;
  final bool showApplyAction;
  final int minLength;
  final int maxLength;

  const PasswordGeneratorSheet({
    super.key,
    required this.initialOptions,
    required this.minLength,
    required this.maxLength,
    this.title,
    this.subtitle,
    this.applyLabel,
    this.showApplyAction = true,
  });

  @override
  State<PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<PasswordGeneratorSheet> {
  late int _length;
  late bool _includeUppercase;
  late bool _includeLowercase;
  late bool _includeNumbers;
  late bool _includeSpecial;
  late String _password;

  @override
  void initState() {
    super.initState();
    _length = widget.initialOptions.length
        .clamp(widget.minLength, widget.maxLength)
        .toInt();
    _includeUppercase = widget.initialOptions.includeUppercase;
    _includeLowercase = widget.initialOptions.includeLowercase;
    _includeNumbers = widget.initialOptions.includeNumbers;
    _includeSpecial = widget.initialOptions.includeSpecial;

    if (!_hasEnabledGroup) {
      _includeLowercase = true;
    }

    _password = _generatePassword();
  }

  bool get _hasEnabledGroup =>
      _includeUppercase ||
      _includeLowercase ||
      _includeNumbers ||
      _includeSpecial;

  int get _enabledGroupCount {
    var count = 0;
    if (_includeUppercase) count++;
    if (_includeLowercase) count++;
    if (_includeNumbers) count++;
    if (_includeSpecial) count++;
    return count;
  }

  PasswordGeneratorOptions get _currentOptions => PasswordGeneratorOptions(
    length: _length,
    includeUppercase: _includeUppercase,
    includeLowercase: _includeLowercase,
    includeNumbers: _includeNumbers,
    includeSpecial: _includeSpecial,
  );

  int get _strengthScore => ServiceManager.calculatePasswordStrength(_password);

  String get _strengthLabel {
    final score = _strengthScore;
    if (Localizations.localeOf(context).languageCode == 'zh') {
      if (score >= ServiceManager.passwordStrengthThresholdVeryStrong) {
        return '非常强';
      }
      if (score >= ServiceManager.passwordStrengthThresholdStrong) {
        return '强';
      }
      if (score >= ServiceManager.passwordStrengthThresholdMedium) {
        return '中等';
      }
      if (score >= ServiceManager.passwordStrengthThresholdWeak) {
        return '弱';
      }
      return '很弱';
    }
    return ServiceManager.getPasswordStrengthLevel(score);
  }

  Color _strengthColor(ThemeData theme) {
    final score = _strengthScore;
    if (score >= ServiceManager.passwordStrengthThresholdVeryStrong) {
      return Colors.green.shade700;
    }
    if (score >= ServiceManager.passwordStrengthThresholdStrong) {
      return Colors.teal.shade700;
    }
    if (score >= ServiceManager.passwordStrengthThresholdMedium) {
      return Colors.orange.shade700;
    }
    if (score >= ServiceManager.passwordStrengthThresholdWeak) {
      return Colors.deepOrange.shade700;
    }
    return theme.colorScheme.error;
  }

  void _regenerate() {
    setState(() {
      _password = _generatePassword();
    });
  }

  void _toggleOption(bool currentValue, void Function(bool nextValue) apply) {
    final nextEnabledCount = currentValue
        ? _enabledGroupCount - 1
        : _enabledGroupCount + 1;
    if (nextEnabledCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.text(
              '至少保留一种字符类型',
              'Keep at least one character type enabled',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      apply(!currentValue);
      if (_length < _enabledGroupCount) {
        _length = _enabledGroupCount;
      }
      _password = _generatePassword();
    });
  }

  String _generatePassword() {
    return ServiceManager.generatePassword(
      length: _length,
      includeUppercase: _includeUppercase,
      includeLowercase: _includeLowercase,
      includeNumbers: _includeNumbers,
      includeSpecial: _includeSpecial,
    );
  }

  Future<void> _copyPassword() async {
    await SensitiveClipboardService.copy(
      text: _password,
      level: ClipboardRiskLevel.high,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.text('密码已复制', 'Password copied'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strengthColor = _strengthColor(theme);
    final minSliderLength = widget.minLength > _enabledGroupCount
        ? widget.minLength
        : _enabledGroupCount;
    final canAdjustLength = widget.maxLength > minSliderLength;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ??
                  context.text('密码生成器', 'Password Generator'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle ??
                  context.text(
                    '像 1Password 一样自定义长度和字符类型，然后一键应用。',
                    'Tune length and character types, then apply the result in one tap.',
                  ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          _password,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: _regenerate,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(context.text('重来', 'Refresh')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.text('强度', 'Strength'),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withAlpha(170),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _strengthLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withAlpha(200),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$_strengthScore / 100',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: strengthColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _strengthScore / 100,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surface.withAlpha(120),
                      valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.text('长度', 'Length'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$_length',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (canAdjustLength)
                      Slider(
                        value: _length.toDouble(),
                        min: minSliderLength.toDouble(),
                        max: widget.maxLength.toDouble(),
                        divisions: widget.maxLength - minSliderLength,
                        label: '$_length',
                        onChanged: (value) {
                          setState(() {
                            _length = value.round();
                            _password = _generatePassword();
                          });
                        },
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          context.text(
                            '当前字段长度固定为 $_length 位。',
                            'This field is fixed at $_length characters.',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      context.text(
                        '建议至少 16 位，且包含多个字符类型。',
                        'A length of 16+ with mixed character types is recommended.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    _OptionTile(
                      title: context.text('大写字母', 'Uppercase'),
                      subtitle: 'A-Z',
                      value: _includeUppercase,
                      onChanged: (_) => _toggleOption(
                        _includeUppercase,
                        (nextValue) => _includeUppercase = nextValue,
                      ),
                    ),
                    _OptionTile(
                      title: context.text('小写字母', 'Lowercase'),
                      subtitle: 'a-z',
                      value: _includeLowercase,
                      onChanged: (_) => _toggleOption(
                        _includeLowercase,
                        (nextValue) => _includeLowercase = nextValue,
                      ),
                    ),
                    _OptionTile(
                      title: context.text('数字', 'Numbers'),
                      subtitle: '0-9',
                      value: _includeNumbers,
                      onChanged: (_) => _toggleOption(
                        _includeNumbers,
                        (nextValue) => _includeNumbers = nextValue,
                      ),
                    ),
                    _OptionTile(
                      title: context.text('符号', 'Symbols'),
                      subtitle: '!@#\$%',
                      value: _includeSpecial,
                      onChanged: (_) => _toggleOption(
                        _includeSpecial,
                        (nextValue) => _includeSpecial = nextValue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyPassword,
                    icon: const Icon(Icons.content_copy_outlined),
                    label: Text(context.text('复制', 'Copy')),
                  ),
                ),
                if (widget.showApplyAction) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(
                          PasswordGeneratorResult(
                            password: _password,
                            options: _currentOptions,
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        widget.applyLabel ??
                            context.text('使用密码', 'Use Password'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
