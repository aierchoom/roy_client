import 'package:flutter/material.dart';

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

  String _text(String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

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
        return '\u975e\u5e38\u5f3a';
      }
      if (score >= ServiceManager.passwordStrengthThresholdStrong) {
        return '\u5f3a';
      }
      if (score >= ServiceManager.passwordStrengthThresholdMedium) {
        return '\u4e2d\u7b49';
      }
      if (score >= ServiceManager.passwordStrengthThresholdWeak) {
        return '\u5f31';
      }
      return '\u5f88\u5f31';
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
            _text(
              '\u81f3\u5c11\u4fdd\u7559\u4e00\u79cd\u5b57\u7b26\u7c7b\u578b',
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
          _text('\u5bc6\u7801\u5df2\u590d\u5236', 'Password copied'),
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
                  _text('\u5bc6\u7801\u751f\u6210\u5668', 'Password Generator'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle ??
                  _text(
                    '\u50cf 1Password \u4e00\u6837\u81ea\u5b9a\u4e49\u957f\u5ea6\u548c\u5b57\u7b26\u7c7b\u578b\uff0c\u7136\u540e\u4e00\u952e\u5e94\u7528\u3002',
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
                        label: Text(_text('\u91cd\u6765', 'Refresh')),
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
                              _text('\u5f3a\u5ea6', 'Strength'),
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
                          _text('\u957f\u5ea6', 'Length'),
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
                          _text(
                            '\u5f53\u524d\u5b57\u6bb5\u957f\u5ea6\u56fa\u5b9a\u4e3a $_length \u4f4d\u3002',
                            'This field is fixed at $_length characters.',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      _text(
                        '\u5efa\u8bae\u81f3\u5c11 16 \u4f4d\uff0c\u4e14\u5305\u542b\u591a\u4e2a\u5b57\u7b26\u7c7b\u578b\u3002',
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
                      title: _text('\u5927\u5199\u5b57\u6bcd', 'Uppercase'),
                      subtitle: 'A-Z',
                      value: _includeUppercase,
                      onChanged: (_) => _toggleOption(
                        _includeUppercase,
                        (nextValue) => _includeUppercase = nextValue,
                      ),
                    ),
                    _OptionTile(
                      title: _text('\u5c0f\u5199\u5b57\u6bcd', 'Lowercase'),
                      subtitle: 'a-z',
                      value: _includeLowercase,
                      onChanged: (_) => _toggleOption(
                        _includeLowercase,
                        (nextValue) => _includeLowercase = nextValue,
                      ),
                    ),
                    _OptionTile(
                      title: _text('\u6570\u5b57', 'Numbers'),
                      subtitle: '0-9',
                      value: _includeNumbers,
                      onChanged: (_) => _toggleOption(
                        _includeNumbers,
                        (nextValue) => _includeNumbers = nextValue,
                      ),
                    ),
                    _OptionTile(
                      title: _text('\u7b26\u53f7', 'Symbols'),
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
                    label: Text(_text('\u590d\u5236', 'Copy')),
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
                            _text('\u4f7f\u7528\u5bc6\u7801', 'Use Password'),
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
