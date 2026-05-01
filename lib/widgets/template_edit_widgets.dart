import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/account_template.dart';

/// A metric display widget for template editor.
class EditorMetric extends StatelessWidget {
  final String label;
  final String value;

  const EditorMetric({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimaryContainer.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withAlpha(210),
            ),
          ),
        ],
      ),
    );
  }
}

/// Result data class for field editor dialog.
class FieldEditorResult {
  final String label;
  final String rawKey;
  final String? description;
  final AccountFieldAttributes attributes;

  const FieldEditorResult({
    required this.label,
    required this.rawKey,
    required this.description,
    required this.attributes,
  });
}

/// A dialog for editing account template fields.
class FieldEditorDialog extends StatefulWidget {
  final AccountField? initial;
  final bool originallyPersisted;
  final String Function(AccountFieldType) fieldTypeLabelBuilder;

  const FieldEditorDialog({
    super.key,
    required this.initial,
    required this.originallyPersisted,
    required this.fieldTypeLabelBuilder,
  });

  @override
  State<FieldEditorDialog> createState() => _FieldEditorDialogState();
}

class _FieldEditorDialogState extends State<FieldEditorDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _hintCtrl;
  late final TextEditingController _descriptionCtrl;

  late AccountFieldType _type;
  late bool _isRequired;
  late bool _isSecret;
  late bool _isEditable;
  late bool _isSearchable;
  late bool _isCopyable;
  late bool _isPrimary;
  late TimeFieldFormat _timeFormat;

  String _text(String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _labelCtrl = TextEditingController(text: initial?.label ?? '');
    _keyCtrl = TextEditingController(text: initial?.fieldKey ?? '');
    _hintCtrl = TextEditingController(text: initial?.attributes.hint ?? '');
    _descriptionCtrl = TextEditingController(text: initial?.description ?? '');

    _type = initial?.attributes.type ?? AccountFieldType.text;
    _isRequired = initial?.attributes.isRequired ?? false;
    _isSecret = initial?.attributes.isSecret ?? false;
    _isEditable = initial?.attributes.isEditable ?? true;
    _isSearchable = initial?.attributes.isSearchable ?? false;
    _isCopyable = initial?.attributes.isCopyable ?? true;
    _isPrimary = initial?.attributes.isPrimary ?? false;
    _timeFormat = initial?.attributes.timeFormat ?? TimeFieldFormat.full;
  }

  void _submit() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入字段名称。')));
      return;
    }

    final isTotp = _type == AccountFieldType.totp;
    Navigator.pop(
      context,
      FieldEditorResult(
        label: label,
        rawKey: widget.originallyPersisted
            ? (widget.initial?.fieldKey ?? '')
            : _keyCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        attributes: AccountFieldAttributes(
          type: _type,
          isPrimary: isTotp ? false : _isPrimary,
          isRequired: _isRequired,
          isSecret: isTotp ? false : _isSecret,
          isEditable: isTotp ? true : _isEditable,
          isSearchable: isTotp ? false : _isSearchable,
          isCopyable: isTotp ? false : _isCopyable,
          timeFormat: _timeFormat,
          hint: isTotp
              ? (_hintCtrl.text.trim().isEmpty
                    ? '\u9009\u62e9\u6216\u65b0\u5efa 2FA'
                    : _hintCtrl.text.trim())
              : (_hintCtrl.text.trim().isEmpty ? null : _hintCtrl.text.trim()),
        ),
      ),
    );
  }

  void _setFieldType(AccountFieldType value) {
    setState(() {
      _type = value;
      if (value == AccountFieldType.totp) {
        if (!widget.originallyPersisted && _labelCtrl.text.trim().isEmpty) {
          _labelCtrl.text = '2FA';
        }
        if (!widget.originallyPersisted && _keyCtrl.text.trim().isEmpty) {
          _keyCtrl.text = 'totp';
        }
        if (_hintCtrl.text.trim().isEmpty) {
          _hintCtrl.text = '\u9009\u62e9\u6216\u65b0\u5efa 2FA';
        }
        if (_descriptionCtrl.text.trim().isEmpty) {
          _descriptionCtrl.text =
              '\u5173\u8054\u72ec\u7acb 2FA \u51ed\u636e\uff0c\u4e0d\u5728\u8d26\u6237\u5b57\u6bb5\u91cc\u4fdd\u5b58\u5bc6\u94a5\u3002';
        }
        _isSecret = false;
        _isSearchable = false;
        _isCopyable = false;
        _isPrimary = false;
      }
    });
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _keyCtrl.dispose();
    _hintCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '新增字段' : '编辑字段'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _labelCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '字段名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keyCtrl,
                enabled: !widget.originallyPersisted,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: '字段标识',
                  helperText: widget.originallyPersisted
                      ? '已有字段标识已锁定，避免影响已保存的账户数据。'
                      : '用于保存数据，建议使用英文字母、数字和下划线。',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountFieldType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: '字段类型'),
                items: AccountFieldType.values
                    .map(
                      (fieldType) => DropdownMenuItem(
                        value: fieldType,
                        child: Text(widget.fieldTypeLabelBuilder(fieldType)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _setFieldType(value);
                },
              ),
              if (_type == AccountFieldType.time) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<TimeFieldFormat>(
                  initialValue: _timeFormat,
                  decoration: const InputDecoration(labelText: '时间格式'),
                  items: [
                    DropdownMenuItem(
                      value: TimeFieldFormat.full,
                      child: Text(_text('全格式', 'Full (YYYY-MM-DD HH:mm)')),
                    ),
                    DropdownMenuItem(
                      value: TimeFieldFormat.date,
                      child: Text(_text('仅日期', 'Date only (YYYY-MM-DD)')),
                    ),
                    DropdownMenuItem(
                      value: TimeFieldFormat.monthYear,
                      child: Text(_text('月/年', 'Month/Year (MM/YY)')),
                    ),
                    DropdownMenuItem(
                      value: TimeFieldFormat.time,
                      child: Text(_text('仅时间', 'Time only (HH:mm)')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _timeFormat = value);
                  },
                ),
              ],
              if (_type == AccountFieldType.totp) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withAlpha(90),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '2FA 字段只作为账号页的快捷关联入口；验证码密钥仍保存在独立 2FA 模块中。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _hintCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '提示文本'),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '字段说明'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isRequired,
                contentPadding: EdgeInsets.zero,
                title: const Text('必填'),
                onChanged: (value) => setState(() => _isRequired = value),
              ),
              if (_type != AccountFieldType.totp) ...[
                SwitchListTile(
                  value: _isSecret,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('保密字段'),
                  onChanged: (value) => setState(() => _isSecret = value),
                ),
                SwitchListTile(
                  value: _isEditable,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('允许编辑'),
                  onChanged: (value) => setState(() => _isEditable = value),
                ),
                SwitchListTile(
                  value: _isSearchable,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('可搜索'),
                  onChanged: (value) => setState(() => _isSearchable = value),
                ),
                SwitchListTile(
                  value: _isCopyable,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('允许复制'),
                  onChanged: (value) => setState(() => _isCopyable = value),
                ),
                SwitchListTile(
                  value: _isPrimary,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('主字段'),
                  onChanged: (value) => setState(() => _isPrimary = value),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存字段')),
      ],
    );
  }
}
