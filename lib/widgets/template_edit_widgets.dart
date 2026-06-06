import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_design_tokens.dart';
import '../models/account_template.dart';
import '../utils/field_presets.dart';

/// Maps [AccountFieldType] to a human-readable label.
String fieldTypeLabel(AccountFieldType type) {
  switch (type) {
    case AccountFieldType.text:
      return '文本';
    case AccountFieldType.password:
      return '密码';
    case AccountFieldType.number:
      return '数字';
    case AccountFieldType.email:
      return '邮箱';
    case AccountFieldType.phone:
      return '电话';
    case AccountFieldType.url:
      return '网址';
    case AccountFieldType.time:
      return '时间';
    case AccountFieldType.custom:
      return '自定义';
    case AccountFieldType.accountLink:
      return '关联账户';
    case AccountFieldType.templateRef:
      return '模板关联';
    case AccountFieldType.subForm:
      return '嵌套子表单';
    case AccountFieldType.unknown:
      return '未知';
    case AccountFieldType.longText:
      return '多行文本';
    case AccountFieldType.list:
      return '列表';
  }
}

/// Maps [AccountFieldType] to a representative icon.
IconData fieldTypeIcon(AccountFieldType type) {
  switch (type) {
    case AccountFieldType.text:
      return Icons.notes_outlined;
    case AccountFieldType.password:
      return Icons.password_outlined;
    case AccountFieldType.number:
      return Icons.pin_outlined;
    case AccountFieldType.email:
      return Icons.email_outlined;
    case AccountFieldType.phone:
      return Icons.phone_outlined;
    case AccountFieldType.url:
      return Icons.link_outlined;
    case AccountFieldType.time:
      return Icons.schedule_outlined;
    case AccountFieldType.custom:
      return Icons.extension_outlined;
    case AccountFieldType.accountLink:
      return Icons.link_outlined;
    case AccountFieldType.templateRef:
      return Icons.account_tree_outlined;
    case AccountFieldType.subForm:
      return Icons.dynamic_feed_outlined;
    case AccountFieldType.unknown:
      return Icons.help_outline_outlined;
    case AccountFieldType.longText:
      return Icons.notes_outlined;
    case AccountFieldType.list:
      return Icons.list_outlined;
  }
}

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
        borderRadius: BorderRadius.circular(AppRadii.panel),
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
  /// Map of templateId → template title for the target-template picker
  /// shown when [AccountFieldType.templateRef] is selected.
  final Map<String, String> availableTemplates;

  const FieldEditorDialog({
    super.key,
    required this.initial,
    required this.originallyPersisted,
    required this.fieldTypeLabelBuilder,
    this.availableTemplates = const {},
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
  late bool _isReference;
  late TimeFieldFormat _timeFormat;
  String? _targetTemplateId;
  String? _subTemplateId;
  int? _maxSubItems;

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
    _isReference = initial?.attributes.isReference ?? false;
    _timeFormat = initial?.attributes.timeFormat ?? TimeFieldFormat.full;
    _targetTemplateId = initial?.attributes.targetTemplateId;
    _subTemplateId = initial?.attributes.subTemplateId;
    _maxSubItems = initial?.attributes.maxSubItems;
  }

  void _submit() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入字段名称。')));
      return;
    }

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
          isPrimary: _isReference ? false : _isPrimary,
          isRequired: _isRequired,
          isSecret: _isReference ? false : _isSecret,
          isEditable: _isReference ? true : _isEditable,
          isSearchable: _isReference ? false : _isSearchable,
          isCopyable: _isReference ? false : _isCopyable,
          isReference: _isReference,
          timeFormat: _timeFormat,
          hint: _hintCtrl.text.trim().isEmpty ? null : _hintCtrl.text.trim(),
          targetTemplateId: _type == AccountFieldType.templateRef
              ? _targetTemplateId
              : null,
          subTemplateId: _type == AccountFieldType.subForm
              ? _subTemplateId
              : null,
          maxSubItems: _type == AccountFieldType.subForm
              ? _maxSubItems
              : null,
        ),
      ),
    );
  }

  void _setFieldType(AccountFieldType value) {
    setState(() {
      _type = value;
      if (value == AccountFieldType.accountLink ||
          value == AccountFieldType.templateRef ||
          value == AccountFieldType.subForm) {
        _isReference = true;
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
              if (_type == AccountFieldType.templateRef) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _targetTemplateId,
                  decoration: const InputDecoration(
                    labelText: '目标模板',
                    helperText: '关联账户时将只显示使用此模板的账户',
                  ),
                  items: widget.availableTemplates.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _targetTemplateId = value);
                  },
                ),
              ],
              if (_type == AccountFieldType.subForm) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _subTemplateId,
                  decoration: const InputDecoration(
                    labelText: '子表单模板',
                    helperText: '子项将使用此模板的字段结构',
                  ),
                  items: widget.availableTemplates.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _subTemplateId = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '最大子项数',
                    helperText: _maxSubItems == null || _maxSubItems == 0
                        ? '留空表示不限制'
                        : '当前限制：$_maxSubItems',
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    setState(
                      () => _maxSubItems = (parsed != null && parsed > 0)
                          ? parsed
                          : null,
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _hintCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '提示文本'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '字段说明'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isReference,
                contentPadding: EdgeInsets.zero,
                title: const Text('关联字段'),
                subtitle: const Text('不保存数据，仅作为关联入口'),
                onChanged: (value) => setState(() => _isReference = value),
              ),
              SwitchListTile(
                value: _isRequired,
                contentPadding: EdgeInsets.zero,
                title: const Text('必填'),
                onChanged: (value) => setState(() => _isRequired = value),
              ),
              if (!_isReference) ...[
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

/// A dialog for previewing and selecting fields from a [FieldPreset]
/// before inserting them into a template.
class FieldPresetPreviewDialog extends StatefulWidget {
  final FieldPreset preset;

  const FieldPresetPreviewDialog({super.key, required this.preset});

  @override
  State<FieldPresetPreviewDialog> createState() =>
      _FieldPresetPreviewDialogState();
}

class _FieldPresetPreviewDialogState extends State<FieldPresetPreviewDialog> {
  late final Set<int> _selectedIndices;

  String _text(String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  @override
  void initState() {
    super.initState();
    _selectedIndices = {
      for (var i = 0; i < widget.preset.fields.length; i++) i,
    };
  }

  void _toggleAll(bool select) {
    setState(() {
      if (select) {
        _selectedIndices.addAll(
          List.generate(widget.preset.fields.length, (i) => i),
        );
      } else {
        _selectedIndices.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSelected = _selectedIndices.length == widget.preset.fields.length;

    return AlertDialog(
      title: Row(
        children: [
          Icon(widget.preset.icon, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _text(
                '插入「${widget.preset.name}」字段组',
                'Insert "${widget.preset.name}" fields',
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => _toggleAll(!allSelected),
              icon: Icon(
                allSelected
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: 18,
              ),
              label: Text(
                allSelected
                    ? _text('取消全选', 'Deselect all')
                    : _text('全选', 'Select all'),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.preset.fields.length; i++)
                      CheckboxListTile(
                        value: _selectedIndices.contains(i),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedIndices.add(i);
                            } else {
                              _selectedIndices.remove(i);
                            }
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary: Icon(
                          fieldTypeIcon(
                            widget.preset.fields[i].attributes.type,
                          ),
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(widget.preset.fields[i].label),
                        subtitle: Text(
                          fieldTypeLabel(
                            widget.preset.fields[i].attributes.type,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(
          onPressed: _selectedIndices.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedIndices.toList()..sort()),
          child: Text(
            _text(
              '插入 ${_selectedIndices.length} 个字段',
              'Insert ${_selectedIndices.length} fields',
            ),
          ),
        ),
      ],
    );
  }
}
