import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../theme/app_design_tokens.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/account_item.dart';
import '../../models/account_template.dart';
import '../../models/hlc.dart';
import '../../models/totp_credential.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../services/service_manager.dart';
import '../../services/sensitive_clipboard_service.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/green_add_button.dart';
import '../../widgets/password_generator_sheet.dart';
import '../../widgets/account_edit_widgets.dart';
import '../../widgets/edit_metadata_row.dart';
import 'account_edit_utils.dart';
import 'totp_credential_edit_view.dart';

class AccountEditView extends StatefulWidget {
  final AccountItem? initial;
  final String? initialTemplateId;

  const AccountEditView({super.key, this.initial, this.initialTemplateId});

  @override
  State<AccountEditView> createState() => _AccountEditViewState();
}

class _AccountEditViewState extends State<AccountEditView> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _pickedTag;
  String? _activeTemplateId;
  late bool _isEditing;
  late final String _accountId;

  final Map<String, TextEditingController> _fieldCtrls = {};
  final Map<String, bool> _fieldVisibility = {};
  final Map<String, bool> _fieldMarkdownPreview = {};
  final Map<String, String> _draftData = {};
  final Map<String, String> _removedLegacyData = {};
  final Set<String> _pendingNewAccountTotpLinkIds = {};
  final List<TotpCredential> _pendingTotpCredentials = [];
  AccountTemplate? _currentTemplate;

  String _text(String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  bool _isTimeField(AccountField field) {
    return field.attributes.type == AccountFieldType.time;
  }

  bool _isTotpField(AccountField field) {
    return field.attributes.type == AccountFieldType.custom &&
        field.attributes.isReference;
  }

  bool _isAccountLinkField(AccountField field) {
    return field.attributes.type == AccountFieldType.accountLink;
  }

  DateTime? _tryParseDateTime(String raw, TimeFieldFormat format) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (format == TimeFieldFormat.monthYear) {
      if (trimmed.length == 5 && trimmed.contains('/')) {
        final parts = trimmed.split('/');
        final month = int.tryParse(parts[0]);
        final year = int.tryParse(parts[1]);
        if (month != null && year != null) {
          // YY logic: > 50 -> 19xx, <= 50 -> 20xx
          final fullYear = year > 50 ? 1900 + year : 2000 + year;
          return DateTime(fullYear, month);
        }
      }
      return null;
    }

    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    final normalized = trimmed.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  String _formatDateTime(DateTime value, TimeFieldFormat format) {
    switch (format) {
      case TimeFieldFormat.monthYear:
        return DateFormat('MM/yy').format(value);
      case TimeFieldFormat.date:
        return DateFormat('yyyy-MM-dd').format(value);
      case TimeFieldFormat.time:
        return DateFormat('HH:mm').format(value);
      case TimeFieldFormat.full:
        return DateFormat('yyyy-MM-dd HH:mm').format(value);
    }
  }

  Future<void> _pickDateTimeField(
    AccountField field,
    TextEditingController controller,
  ) async {
    final format = field.attributes.timeFormat;
    final parsed = _tryParseDateTime(controller.text, format);
    final now = DateTime.now();
    final initial = parsed ?? now;

    if (format == TimeFieldFormat.monthYear) {
      DateTime selectedDate = initial;
      await showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            height: 300,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(_text('取消', 'Cancel')),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          controller.text = _formatDateTime(
                            selectedDate,
                            format,
                          );
                        });
                        Navigator.pop(context);
                      },
                      child: Text(_text('确定', 'Confirm')),
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.monthYear,
                    initialDateTime: initial,
                    onDateTimeChanged: (date) => selectedDate = date,
                  ),
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    if (format == TimeFieldFormat.time) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
        cancelText: _text('取消', 'Cancel'),
        confirmText: _text('确定', 'Confirm'),
      );
      if (pickedTime != null && mounted) {
        final result = DateTime(
          now.year,
          now.month,
          now.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          controller.text = _formatDateTime(result, format);
        });
      }
      return;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: _text('选择日期', 'Select date'),
    );
    if (pickedDate == null || !mounted) return;

    if (format == TimeFieldFormat.date) {
      setState(() {
        controller.text = _formatDateTime(pickedDate, format);
      });
      return;
    }

    // Full Date + Time
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      cancelText: _text('取消', 'Cancel'),
      confirmText: _text('确定', 'Confirm'),
    );
    if (pickedTime == null || !mounted) return;

    final pickedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      controller.text = _formatDateTime(pickedDateTime, format);
    });
  }

  @override
  void initState() {
    super.initState();
    _accountId =
        widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    _isEditing = widget.initial == null;
    _draftData.addAll(
      (widget.initial?.data ?? const <String, dynamic>{}).map(
        (k, v) => MapEntry(k, v?.toString() ?? ''),
      ),
    );
    if (widget.initial != null) {
      _nameCtrl.text = widget.initial!.name;
      _emailCtrl.text = widget.initial!.email;
      _pickedTag = widget.initial!.templateId;
    } else if ((widget.initialTemplateId ?? '').trim().isNotEmpty) {
      _pickedTag = widget.initialTemplateId;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pickedTag == null) {
      final templates = context.read<EnhancedAppProvider>().allTemplates;
      if (templates.isNotEmpty) {
        _pickedTag = templates.first.templateId;
      }
    }
    _buildFieldsForTemplate(_pickedTag);
  }

  void _buildFieldsForTemplate(String? templateId) {
    if (templateId == null) return;
    if (_activeTemplateId == templateId && _fieldCtrls.isNotEmpty) return;

    _persistVisibleFieldDrafts();

    final provider = context.read<EnhancedAppProvider>();
    final template = provider.getTemplate(templateId);
    if (template == null) {
      _currentTemplate = null;
      _activeTemplateId = templateId;
      for (final controller in _fieldCtrls.values) {
        controller.dispose();
      }
      _fieldCtrls.clear();
      _fieldVisibility.clear();
      return;
    }

    _currentTemplate = template;
    _activeTemplateId = templateId;

    for (final controller in _fieldCtrls.values) {
      controller.dispose();
    }
    _fieldCtrls.clear();
    _fieldVisibility.clear();

    for (final field in template.fields) {
      if (_isTotpField(field)) {
        _draftData.remove(field.fieldKey);
        continue;
      }
      if (_isAccountLinkField(field)) {
        continue;
      }
      final controller = TextEditingController();
      controller.text = _draftData[field.fieldKey] ?? '';
      _fieldCtrls[field.fieldKey] = controller;
      if (field.attributes.isSecret) {
        _fieldVisibility[field.fieldKey] = false;
      }
    }
  }

  void _persistVisibleFieldDrafts() {
    _fieldCtrls.forEach((key, controller) {
      _draftData[key] = controller.text;
    });
  }

  Set<String> get _visibleFieldKeys =>
      _currentTemplate?.fields.map((field) => field.fieldKey).toSet() ??
      <String>{};

  Set<String> get _nonDataFieldKeys =>
      _currentTemplate?.fields
          .where(_isTotpField)
          .map((field) => field.fieldKey)
          .toSet() ??
      <String>{};

  bool get _hasMissingTemplate =>
      _pickedTag != null && _currentTemplate == null;

  void _syncTemplateSelectionFromProvider(List<AccountTemplate> templates) {
    if (templates.isEmpty) return;

    String? nextTemplateId;
    if (_pickedTag == null) {
      if (widget.initial != null) return;
      final initialTemplateId = widget.initialTemplateId;
      nextTemplateId =
          initialTemplateId != null &&
              templates.any(
                (template) => template.templateId == initialTemplateId,
              )
          ? initialTemplateId
          : templates.first.templateId;
    } else if (_currentTemplate == null &&
        templates.any((template) => template.templateId == _pickedTag)) {
      nextTemplateId = _pickedTag;
    }

    if (nextTemplateId == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentTemplate?.templateId == nextTemplateId) return;
      setState(() {
        _pickedTag = nextTemplateId;
        _buildFieldsForTemplate(nextTemplateId);
      });
    });
  }

  Map<String, String> get _legacyData {
    final legacy = <String, String>{};
    for (final entry in _draftData.entries) {
      if (_visibleFieldKeys.contains(entry.key)) continue;
      if (_removedLegacyData.containsKey(entry.key)) continue;
      if (entry.value.trim().isEmpty) continue;
      legacy[entry.key] = entry.value;
    }
    return legacy;
  }

  Map<String, String> get _removedLegacyEntries {
    final removed = <String, String>{};
    for (final entry in _removedLegacyData.entries) {
      if (_visibleFieldKeys.contains(entry.key)) continue;
      removed[entry.key] = entry.value;
    }
    return removed;
  }

  String _formatKeyLabel(String key) {
    final parts = key
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return key;
    return parts
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }

  Future<bool> _confirmTemplateChange(String newTemplateId) async {
    if (widget.initial == null || newTemplateId == _pickedTag) {
      return true;
    }

    final provider = context.read<EnhancedAppProvider>();
    final nextTemplate = provider.getTemplate(newTemplateId);
    final currentTemplateName =
        _currentTemplate?.title ??
        _text('当前模板', 'Current template');
    final nextTemplateName =
        nextTemplate?.title ?? _text('新模板', 'New template');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text('切换模板', 'Change Template')),
        content: Text(
          _text(
            '你正在将账户从“$currentTemplateName”切换到“$nextTemplateName”。\n\n系统会保留原有字段值，但不会自动迁移成新模板字段，请在保存前确认需要的新字段内容。',
            'You are changing this account from "$currentTemplateName" to "$nextTemplateName".\n\nExisting field values will be preserved, but they will not be auto-mapped to the new template. Please review the new template fields before saving.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_text('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_text('继续', 'Continue')),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _confirmRemoveLegacyField(String key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _text(
            '删除历史字段',
            'Remove Historical Field',
          ),
        ),
        content: Text(
          _text(
            '确认将“${_formatKeyLabel(key)}”标记为删除吗？\n\n这个变更会在保存账户后生效，可以在保存前随时恢复。',
            'Mark "${_formatKeyLabel(key)}" for removal?\n\nThis change will take effect when you save the account, and you can restore it any time before saving.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_text('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_text('标记删除', 'Mark for Removal')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final previousValue = _draftData[key];
    if (previousValue == null) return;

    setState(() {
      _removedLegacyData[key] = previousValue;
    });
  }

  void _restoreLegacyField(String key) {
    setState(() {
      _removedLegacyData.remove(key);
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final provider = context.read<EnhancedAppProvider>();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              '请填写账户名称',
              'Please enter a name',
            ),
          ),
        ),
      );
      return;
    }

    if (_hasMissingTemplate || _pickedTag == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              '当前模板不可用，请先恢复或选择可用模板后再保存。',
              'The selected template is unavailable. Restore it or choose an available template before saving.',
            ),
          ),
        ),
      );
      return;
    }

    if (_currentTemplate != null) {
      for (final field in _currentTemplate!.fields) {
        if (_isTotpField(field)) {
          if (field.attributes.isRequired &&
              !_hasSelectedTotpCredential(provider)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _text(
                    '请关联必填字段：${field.label}',
                    'Required link missing: ${field.label}',
                  ),
                ),
              ),
            );
            return;
          }
          continue;
        }
        if (_isAccountLinkField(field)) {
          if (field.attributes.isRequired &&
              (_draftData[field.fieldKey]?.isEmpty ?? true)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _text(
                    '请选择必填字段：${field.label}',
                    'Required link missing: ${field.label}',
                  ),
                ),
              ),
            );
            return;
          }
          continue;
        }
        if (field.attributes.isRequired &&
            (_fieldCtrls[field.fieldKey]?.text.isEmpty ?? true)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _text(
                  '请填写必填字段：${field.label}',
                  'Required field missing: ${field.label}',
                ),
              ),
            ),
          );
          return;
        }
      }
    }

    _persistVisibleFieldDrafts();

    final data = Map<String, String>.from(_draftData);
    for (final key in _nonDataFieldKeys) {
      data.remove(key);
    }
    for (final key in _removedLegacyData.keys) {
      if (_visibleFieldKeys.contains(key)) continue;
      data.remove(key);
    }

    final item = AccountItem(
      id: _accountId,
      name: name,
      email: _emailCtrl.text.trim(),
      templateId: _pickedTag ?? '',
      data: data,
      createdAt:
          widget.initial?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      modifiedAt: widget.initial?.modifiedAt ?? 0,
      lastEditedBy: widget.initial?.lastEditedBy,
      lastEditedAt: widget.initial?.lastEditedAt,
      nameHlc: widget.initial?.nameHlc ?? Hlc.zero('local'),
      emailHlc: widget.initial?.emailHlc ?? Hlc.zero('local'),
      dataHlc: widget.initial?.dataHlc ?? {},
      serverVersion: widget.initial?.serverVersion ?? 0,
      syncStatus: widget.initial?.syncStatus ?? SyncStatus.pendingPush,
      isDeleted: widget.initial?.isDeleted ?? false,
      deleteHlc: widget.initial?.deleteHlc,
    );

    if (widget.initial == null) {
      await _flushPendingTotpChanges(provider);
      if (!mounted) return;
    }

    Navigator.of(context).pop(item);
  }

  Future<void> _copyValue(String label, String value) async {
    final trimmed = value.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (trimmed.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _text(
              '$label 暂无可复制内容',
              'No content available to copy for $label',
            ),
          ),
        ),
      );
      return;
    }

    await SensitiveClipboardService.copy(
      text: trimmed,
      level: ClipboardRiskLevel.high,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(_text('已复制 $label', 'Copied $label')),
      ),
    );
  }

  String _buildCopyAllText() {
    final lines = <String>[];

    if (_currentTemplate != null) {
      for (final field in _currentTemplate!.fields) {
        final value = _fieldCtrls[field.fieldKey]?.text.trim() ?? '';
        if (value.isEmpty) continue;
        lines.add('${field.label}: $value');
      }
    }

    for (final entry in _legacyData.entries) {
      lines.add('${_formatKeyLabel(entry.key)}: ${entry.value}');
    }

    return lines.where((line) => !line.endsWith(': ')).join('\n');
  }

  bool _isPasswordField(AccountField field) {
    return field.attributes.type == AccountFieldType.password;
  }

  PasswordGeneratorOptions _passwordOptionsForField(AccountField field) {
    final rawMinLength = field.attributes.minLength ?? 12;
    final rawMaxLength = field.attributes.maxLength ?? 32;
    final fieldKey = field.fieldKey.toLowerCase();
    final isShortCodeField =
        (field.attributes.maxLength != null &&
            field.attributes.maxLength! <= 6) ||
        fieldKey.contains('pin') ||
        fieldKey.contains('cvv');
    final minLength = rawMinLength < 4 ? 4 : rawMinLength;
    final maxLength = rawMaxLength < minLength ? minLength : rawMaxLength;
    final defaultLength = isShortCodeField
        ? maxLength.clamp(minLength, 6).toInt()
        : 20.clamp(minLength, maxLength).toInt();

    return PasswordGeneratorOptions(
      length: defaultLength,
      includeUppercase: !isShortCodeField,
      includeLowercase: !isShortCodeField,
      includeNumbers: true,
      includeSpecial: !isShortCodeField && maxLength >= 8,
    );
  }

  Future<void> _generatePasswordForField(
    AccountField field,
    TextEditingController controller,
  ) async {
    final minLength = (field.attributes.minLength ?? 8).clamp(4, 64).toInt();
    final maxLength = (field.attributes.maxLength ?? 32)
        .clamp(minLength, 64)
        .toInt();
    final result = await showPasswordGeneratorSheet(
      context,
      initialOptions: _passwordOptionsForField(field),
      title: _text(
        '为 ${field.label} 生成密码',
        'Generate Password for ${field.label}',
      ),
      subtitle: _text(
        '生成后会直接回填到当前字段。',
        'The generated value will be filled into this field immediately.',
      ),
      applyLabel: _text('填入字段', 'Fill Field'),
      minLength: minLength,
      maxLength: maxLength,
    );

    if (result == null || !mounted) return;

    setState(() {
      controller.text = result.password;
    });
  }

  Widget? _buildFieldSuffixActions(
    AccountField field,
    TextEditingController? controller,
  ) {
    if (controller == null) return null;

    final actions = <Widget>[];
    if (_isTimeField(field)) {
      actions.add(
        IconButton(
          tooltip: _text('选择时间', 'Pick date and time'),
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: !_isEditing || !field.attributes.isEditable
              ? null
              : () => _pickDateTimeField(field, controller),
          icon: const Icon(Icons.schedule_outlined),
        ),
      );
    }

    if (_isPasswordField(field) && _isEditing) {
      actions.add(
        IconButton(
          tooltip: _text('生成随机密码', 'Generate random password'),
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: !field.attributes.isEditable
              ? null
              : () => _generatePasswordForField(field, controller),
          icon: const Icon(Icons.auto_awesome_outlined),
        ),
      );
    }

    if (field.attributes.isSecret) {
      final isVisible = _fieldVisibility[field.fieldKey] == true;
      actions.add(
        IconButton(
          tooltip: isVisible
              ? _text('隐藏密码', 'Hide password')
              : _text('显示密码', 'Show password'),
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: () => setState(() {
            _fieldVisibility[field.fieldKey] = !isVisible;
          }),
          icon: Icon(
            isVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      );
    }

    if (!_isEditing) {
      actions.add(
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          tooltip: _text(
            '复制字段内容',
            'Copy field value',
          ),
          onPressed: () => _copyValue(field.label, controller.text),
          icon: const Icon(Icons.content_copy_outlined),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: actions,
    );
  }

  Color _fieldAccentColor(ThemeData theme, AccountField field) {
    if (field.attributes.isSecret) {
      return theme.colorScheme.tertiary;
    }
    if (_isTimeField(field)) {
      return theme.colorScheme.secondary;
    }
    if (field.attributes.isRequired) {
      return theme.colorScheme.primary;
    }
    return theme.colorScheme.secondary;
  }

  Widget _buildOverviewCard(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTemplate = _currentTemplate;
    final heroBase = AppSurfaces.soft(
      theme.colorScheme,
      tint: theme.colorScheme.primary,
      tintAlpha: 28,
    );
    final heroEdge = theme.colorScheme.primary.withAlpha(42);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              theme.colorScheme.primary.withAlpha(24),
              theme.colorScheme.primaryContainer,
            ),
            Color.alphaBlend(
              theme.colorScheme.tertiary.withAlpha(18),
              theme.colorScheme.tertiaryContainer,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: heroEdge),
        boxShadow: AppShadows.card(theme, depth: 1.15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'account-icon-${widget.initial?.id}',
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withAlpha(232),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: AppShadows.card(theme, depth: 0.45),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    selectedTemplate?.badgeText ?? 'TM',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameCtrl.text.trim().isEmpty
                          ? _text(
                              '未命名账户',
                              'Untitled Account',
                            )
                          : _nameCtrl.text.trim(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedTemplate?.title ??
                          _text(
                            '请选择模板',
                            'Choose a template',
                          ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withAlpha(
                          210,
                        ),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ToneChip(
                icon: _isEditing
                    ? Icons.edit_note_outlined
                    : Icons.visibility_outlined,
                label: _isEditing
                    ? _text('正在编辑', 'Editing')
                    : _text('只读预览', 'Preview'),
                tint: theme.colorScheme.onPrimaryContainer,
              ),
              if (selectedTemplate != null)
                ToneChip(
                  icon: Icons.layers_outlined,
                  label:
                      '${selectedTemplate.fields.length} ${_text('个字段', 'fields')}',
                  tint: theme.colorScheme.onPrimaryContainer,
                ),
              if (_emailCtrl.text.trim().isNotEmpty)
                ToneChip(
                  icon: Icons.alternate_email_rounded,
                  label: _emailCtrl.text.trim(),
                  tint: theme.colorScheme.onPrimaryContainer,
                ),
            ],
          ),
          if (widget.initial != null) ...[
            const SizedBox(height: 10),
            EditMetadataRow(
              editedAt: widget.initial!.lastEditedAt ?? widget.initial!.modifiedAt,
              editedBy: widget.initial!.lastEditedBy,
            ),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: heroBase.withAlpha(230),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: heroEdge.withAlpha(90)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text('字段状态', 'Field Status'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedTemplate == null
                            ? _text(
                                '先选模板，下面的录入区会自动展开。',
                                'Choose a template to unlock the form below.',
                              )
                            : _text(
                                '当前模板字段会在下面按组呈现，浅色模式下已经强化了层次和预览感。',
                                'The active template fields are staged below with stronger hierarchy and preview treatment.',
                              ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withAlpha(
                            210,
                          ),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withAlpha(214),
                    borderRadius: BorderRadius.circular(AppRadii.panel),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final templates = context.watch<EnhancedAppProvider>().allTemplates;
    final selectedTemplateId =
        templates.any((template) => template.templateId == _pickedTag)
        ? _pickedTag
        : null;
    final selectedTemplate = selectedTemplateId == null
        ? null
        : templates
              .where((template) => template.templateId == selectedTemplateId)
              .first;
    final showMissingTemplateWarning = _hasMissingTemplate;
    final selectedTemplateAccent = selectedTemplate == null
        ? theme.colorScheme.primary
        : AppSurfaces.soft(
            theme.colorScheme,
            tint: theme.colorScheme.primary,
            tintAlpha: 18,
          );

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.soft(
          theme.colorScheme,
          tint: theme.colorScheme.primary,
          tintAlpha: 8,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(88),
        ),
        boxShadow: AppShadows.card(theme, depth: 0.82),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('基本信息', 'Basic Information'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                '先确定账户名称、备注和模板，让下面的字段区在浅色模式下也有清晰的层次与重点。',
                'Set the account identity first so the field area below feels intentional and easier to scan.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;
                if (!isWide) {
                  return Column(
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                        readOnly: !_isEditing,
                        decoration: InputDecoration(
                          labelText: _text(
                            '账户名称',
                            'Account Name',
                          ),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailCtrl,
                        onChanged: (_) => setState(() {}),
                        readOnly: !_isEditing,
                        decoration: InputDecoration(
                          labelText: _text(
                            '绑定邮箱/备注',
                            'Email / Note',
                          ),
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                        readOnly: !_isEditing,
                        decoration: InputDecoration(
                          labelText: _text(
                            '账户名称',
                            'Account Name',
                          ),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        onChanged: (_) => setState(() {}),
                        readOnly: !_isEditing,
                        decoration: InputDecoration(
                          labelText: _text(
                            '绑定邮箱/备注',
                            'Email / Note',
                          ),
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('template-$selectedTemplateId-${templates.length}'),
              initialValue: selectedTemplateId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _text('选择模板', 'Select Template'),
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              hint: Text(
                _text('请选择模板', 'Choose a template'),
              ),
              items: [
                for (final template in templates)
                  DropdownMenuItem(
                    value: template.templateId,
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(template.title)),
                      ],
                    ),
                  ),
              ],
              onChanged: !_isEditing
                  ? null
                  : (value) async {
                      if (value == null) return;
                      final canChange = await _confirmTemplateChange(value);
                      if (!canChange || !mounted) return;
                      setState(() {
                        _pickedTag = value;
                        _buildFieldsForTemplate(value);
                      });
                    },
            ),
            if (showMissingTemplateWarning) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withAlpha(92),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(
                    color: theme.colorScheme.error.withAlpha(72),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _text(
                          '当前模板缺失，账户已进入保护状态。你可以查看已保存的字段，但需要先恢复或切换到可用模板后才能保存。',
                          'The selected template is missing, so this account is protected until a valid template is restored or selected.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (selectedTemplate != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selectedTemplateAccent,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(
                    color: theme.colorScheme.primary.withAlpha(44),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withAlpha(232),
                        borderRadius: BorderRadius.circular(AppRadii.panel),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        selectedTemplate.badgeText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedTemplate.title,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (selectedTemplate.subTitle.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              selectedTemplate.subTitle.trim(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ToneChip(
                                icon: Icons.view_stream_outlined,
                                label:
                                    '${selectedTemplate.fields.length} ${_text('个字段', 'fields')}',
                              ),
                              ToneChip(
                                icon: Icons.star_border_rounded,
                                label:
                                    '${selectedTemplate.fields.where((field) => field.attributes.isRequired).length} ${_text('个必填', 'required')}',
                              ),
                              ToneChip(
                                icon: Icons.visibility_off_outlined,
                                label:
                                    '${selectedTemplate.fields.where((field) => field.attributes.isSecret).length} ${_text('个保密', 'secret')}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(BuildContext context, AccountField field) {
    if (_isTotpField(field)) {
      return _buildTotpLinkSection(context, field);
    }
    if (_isAccountLinkField(field)) {
      return _buildAccountLinkSection(context, field);
    }
    if (field.attributes.type == AccountFieldType.longText) {
      return _buildLongTextFieldCard(context, field);
    }
    if (field.attributes.type == AccountFieldType.list) {
      return _buildListFieldCard(context, field);
    }

    final theme = Theme.of(context);
    final controller = _fieldCtrls[field.fieldKey];
    final accent = _fieldAccentColor(theme, field);
    final previewSurface = AppSurfaces.soft(
      theme.colorScheme,
      tint: accent,
      tintAlpha: 10,
    );
    final canPickInlineTime =
        controller != null &&
        _isTimeField(field) &&
        field.attributes.timeFormat != TimeFieldFormat.monthYear &&
        _isEditing &&
        field.attributes.isEditable;

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.soft(theme.colorScheme, tint: accent, tintAlpha: 5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: accent.withAlpha(38)),
        boxShadow: AppShadows.card(theme, depth: 0.7),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppSurfaces.soft(
                      theme.colorScheme,
                      tint: accent,
                      tintAlpha: 18,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: Icon(
                    field.attributes.isSecret
                        ? Icons.key_outlined
                        : _isTimeField(field)
                        ? Icons.schedule_outlined
                        : Icons.notes_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        field.fieldKey,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if ((field.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          field.description!.trim(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ToneChip(
                  icon: Icons.label_outline_rounded,
                  label: field.attributes.type.name,
                  tint: accent,
                ),
                if (field.attributes.isRequired)
                  ToneChip(
                    icon: Icons.star_outline_rounded,
                    label: _text('必填', 'Required'),
                    tint: accent,
                  ),
                if (field.attributes.isSecret)
                  ToneChip(
                    icon: Icons.visibility_off_outlined,
                    label: _text('保密', 'Secret'),
                    tint: accent,
                  ),
                if (!field.attributes.isEditable)
                  ToneChip(
                    icon: Icons.lock_outline_rounded,
                    label: _text('只读', 'Read only'),
                    tint: accent,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: previewSurface,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: accent.withAlpha(34)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _text('字段预览', 'Field Preview'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _isEditing
                            ? _text('可编辑', 'Editable')
                            : _text('只读模式', 'Read only'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if ((field.attributes.hint ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      field.attributes.hint!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    obscureText:
                        field.attributes.isSecret &&
                        !(_fieldVisibility[field.fieldKey] ?? false),
                    readOnly:
                        (_isTimeField(field) &&
                            field.attributes.timeFormat !=
                                TimeFieldFormat.monthYear) ||
                        !_isEditing ||
                        !field.attributes.isEditable,
                    keyboardType:
                        field.attributes.timeFormat == TimeFieldFormat.monthYear
                        ? TextInputType.number
                        : null,
                    inputFormatters:
                        field.attributes.timeFormat == TimeFieldFormat.monthYear
                        ? [MonthYearInputFormatter()]
                        : null,
                    onTap: canPickInlineTime
                        ? () => _pickDateTimeField(field, controller)
                        : null,
                    onChanged: null,
                    decoration: InputDecoration(
                      labelText: field.label,
                      hintText: field.attributes.hint,
                      prefixIcon: Icon(
                        field.attributes.isSecret
                            ? Icons.password_outlined
                            : _isTimeField(field)
                            ? Icons.schedule_outlined
                            : Icons.text_fields_outlined,
                      ),
                      suffixIcon: _buildFieldSuffixActions(field, controller),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 72,
                        minHeight: 40,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLongTextFieldCard(BuildContext context, AccountField field) {
    final theme = Theme.of(context);
    final controller = _fieldCtrls[field.fieldKey];
    final accent = _fieldAccentColor(theme, field);
    final isSecret = field.attributes.isSecret;
    final isVisible = !isSecret || (_fieldVisibility[field.fieldKey] ?? false);
    final isPreview = _fieldMarkdownPreview[field.fieldKey] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.soft(theme.colorScheme, tint: accent, tintAlpha: 5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: accent.withAlpha(38)),
        boxShadow: AppShadows.card(theme, depth: 0.7),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppSurfaces.soft(
                      theme.colorScheme,
                      tint: accent,
                      tintAlpha: 18,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: Icon(
                    isSecret ? Icons.key_outlined : Icons.notes_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        field.fieldKey,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Markdown preview toggle
                if (isVisible)
                  IconButton(
                    onPressed: () => setState(
                      () => _fieldMarkdownPreview[field.fieldKey] = !isPreview,
                    ),
                    icon: Icon(
                      isPreview ? Icons.edit_outlined : Icons.visibility_outlined,
                      size: 20,
                    ),
                    tooltip: isPreview
                        ? _text('编辑', 'Edit')
                        : _text('预览', 'Preview'),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (isSecret && !isVisible)
              InkWell(
                onTap: () =>
                    setState(() => _fieldVisibility[field.fieldKey] = true),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppSurfaces.soft(
                      theme.colorScheme,
                      tint: accent,
                      tintAlpha: 5,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: accent.withAlpha(34)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.visibility_off_outlined,
                        color: accent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _text(
                          '点击展开编辑内容',
                          'Tap to reveal and edit',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (isPreview)
              MarkdownBody(
                data: controller?.text ?? '',
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyMedium,
                  code: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              )
            else
              TextField(
                controller: controller,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                readOnly: !_isEditing || !field.attributes.isEditable,
                decoration: InputDecoration(
                  labelText: field.label,
                  hintText: field.attributes.hint,
                  prefixIcon: const Icon(Icons.notes_outlined),
                  suffixIcon: isSecret
                      ? IconButton(
                          icon: const Icon(Icons.visibility_off_outlined),
                          onPressed: () => setState(
                            () => _fieldVisibility[field.fieldKey] = false,
                          ),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListFieldCard(BuildContext context, AccountField field) {
    final theme = Theme.of(context);
    final controller = _fieldCtrls[field.fieldKey];
    final accent = _fieldAccentColor(theme, field);
    final isMnemonic = field.fieldKey == 'mnemonic_words';

    if (controller == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.soft(theme.colorScheme, tint: accent, tintAlpha: 5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: accent.withAlpha(38)),
        boxShadow: AppShadows.card(theme, depth: 0.7),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppSurfaces.soft(
                      theme.colorScheme,
                      tint: accent,
                      tintAlpha: 18,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: Icon(
                    isMnemonic ? Icons.vpn_key_outlined : Icons.list_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        field.fieldKey,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ListFieldEditor(
              controller: controller,
              isMnemonic: isMnemonic,
              isSecret: field.attributes.isSecret,
              readOnly: !_isEditing || !field.attributes.isEditable,
              hint: field.attributes.hint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    final overview = _buildOverviewCard(context);
    final basicInfo = _buildBasicInfoCard(context);

    return Column(children: [overview, const SizedBox(height: 24), basicInfo]);
  }

  Future<void> _setTotpCredentialLink(
    EnhancedAppProvider provider,
    TotpCredential credential,
    String accountId,
    bool selected,
  ) async {
    if (widget.initial == null) {
      final pendingIndex = _pendingTotpCredentials.indexWhere(
        (item) => item.id == credential.id,
      );
      setState(() {
        if (pendingIndex == -1) {
          if (selected) {
            _pendingNewAccountTotpLinkIds.add(credential.id);
          } else {
            _pendingNewAccountTotpLinkIds.remove(credential.id);
          }
          return;
        }

        final links = _pendingTotpCredentials[pendingIndex].linkedAccountIds
            .toList();
        if (selected) {
          if (!links.contains(accountId)) links.add(accountId);
        } else {
          links.remove(accountId);
        }
        _pendingTotpCredentials[pendingIndex] =
            _pendingTotpCredentials[pendingIndex].copyWith(
              linkedAccountIds: links,
            );
      });
      return;
    }

    final links = credential.linkedAccountIds.toList();
    if (selected) {
      if (!links.contains(accountId)) links.add(accountId);
    } else {
      links.remove(accountId);
    }
    await provider.updateTotpCredential(
      credential.copyWith(linkedAccountIds: links),
    );
  }

  bool _isTotpCredentialSelected(TotpCredential credential, String accountId) {
    return credential.isLinkedToAccount(accountId) ||
        (widget.initial == null &&
            _pendingNewAccountTotpLinkIds.contains(credential.id));
  }

  List<TotpCredential> _visibleTotpCredentials(EnhancedAppProvider provider) {
    return [..._pendingTotpCredentials, ...provider.totpCredentials];
  }

  bool _hasSelectedTotpCredential(EnhancedAppProvider provider) {
    return _visibleTotpCredentials(
      provider,
    ).any((credential) => _isTotpCredentialSelected(credential, _accountId));
  }

  Future<void> _createTotpCredentialForAccount(
    EnhancedAppProvider provider,
  ) async {
    final credential = await Navigator.push<TotpCredential>(
      context,
      MaterialPageRoute(
        builder: (_) => TotpCredentialEditView(initialAccountId: _accountId),
      ),
    );
    if (credential == null || !mounted) return;

    if (widget.initial == null) {
      setState(() {
        _pendingTotpCredentials.insert(0, credential);
      });
      return;
    }

    await provider.addTotpCredential(credential);
  }

  Future<void> _flushPendingTotpChanges(EnhancedAppProvider provider) async {
    for (final credential in provider.totpCredentials) {
      if (!_pendingNewAccountTotpLinkIds.contains(credential.id)) continue;
      final links = credential.linkedAccountIds.toList();
      if (!links.contains(_accountId)) {
        links.add(_accountId);
        await provider.updateTotpCredential(
          credential.copyWith(linkedAccountIds: links),
        );
      }
    }

    for (final credential in _pendingTotpCredentials) {
      await provider.addTotpCredential(credential);
    }
  }

  Widget _buildTotpLinkSection(BuildContext context, AccountField field) {
    final provider = context.watch<EnhancedAppProvider>();
    final theme = Theme.of(context);
    final accountId = _accountId;
    final credentials = _visibleTotpCredentials(provider);
    final linkedCount = credentials
        .where((credential) => _isTotpCredentialSelected(credential, accountId))
        .length;

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.soft(
          theme.colorScheme,
          tint: theme.colorScheme.primary,
          tintAlpha: 10,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(88),
        ),
        boxShadow: AppShadows.card(theme, depth: 0.55),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    field.label.trim().isEmpty
                        ? _text('2FA 关联', '2FA Links')
                        : field.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ToneChip(
                  icon: Icons.link_outlined,
                  label: _text(
                    '$linkedCount 个已关联',
                    '$linkedCount linked',
                  ),
                  tint: theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              field.description?.trim().isNotEmpty == true
                  ? field.description!.trim()
                  : _text(
                      '2FA 是独立功能，这里只选择哪些动态验证码和该账户关联。',
                      '2FA lives independently. This section only links authenticator entries to this account.',
                    ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            if (credentials.isEmpty)
              Text(
                _text(
                  '暂无 2FA 项，可以直接在这里新建。',
                  'No 2FA items yet. You can create one here.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...credentials.map((credential) {
                final selected = _isTotpCredentialSelected(
                  credential,
                  accountId,
                );
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(credential.displayLabel),
                  subtitle: Text(
                    '${credential.config.issuer ?? '-'} / ${credential.config.account ?? '-'}',
                  ),
                  onChanged: !_isEditing
                      ? null
                      : (value) => _setTotpCredentialLink(
                          provider,
                          credential,
                          accountId,
                          value == true,
                        ),
                );
              }),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: !_isEditing
                    ? null
                    : () => _createTotpCredentialForAccount(provider),
                icon: const Icon(Icons.add_link_outlined),
                label: Text(_text('新建 2FA', 'Add 2FA')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountLinkSection(BuildContext context, AccountField field) {
    final theme = Theme.of(context);
    final provider = context.watch<EnhancedAppProvider>();
    final linkedId = _draftData[field.fieldKey];
    final linkedAccount = linkedId != null && linkedId.isNotEmpty
        ? provider.getAccount(linkedId)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.soft(
          theme.colorScheme,
          tint: theme.colorScheme.primary,
          tintAlpha: 10,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(88),
        ),
        boxShadow: AppShadows.card(theme, depth: 0.55),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    field.label.trim().isEmpty
                        ? _text('关联账户', 'Linked Account')
                        : field.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (linkedAccount != null)
                  ToneChip(
                    icon: Icons.check_circle_outlined,
                    label: _text('已关联', 'Linked'),
                    tint: theme.colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              field.description?.trim().isNotEmpty == true
                  ? field.description!.trim()
                  : _text(
                      '用于关联其他账户记录。',
                      'Used to link to another account entry.',
                    ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            if (linkedAccount != null)
              _buildLinkedAccountCard(context, linkedAccount, field)
            else
              Text(
                _text(
                  '尚未关联任何账户。',
                  'No account linked yet.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 10),
            if (_isEditing)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showAccountPicker(context, field),
                    icon: Icon(
                      linkedAccount != null
                          ? Icons.swap_horiz_outlined
                          : Icons.add_link_outlined,
                    ),
                    label: Text(
                      linkedAccount != null
                          ? _text('更换关联', 'Change Link')
                          : _text('选择账户', 'Select Account'),
                    ),
                  ),
                  if (linkedAccount != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _draftData.remove(field.fieldKey);
                        });
                      },
                      icon: const Icon(Icons.link_off_outlined),
                      label: Text(_text('清除关联', 'Clear')),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedAccountCard(
    BuildContext context,
    AccountItem account,
    AccountField field,
  ) {
    final theme = Theme.of(context);
    final provider = context.read<EnhancedAppProvider>();
    final template = provider.getTemplate(account.templateId);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AccountEditView(initial: account),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadii.panel),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.account_circle_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (template != null)
                      Text(
                        template.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAccountPicker(
    BuildContext context,
    AccountField field,
  ) async {
    final provider = context.read<EnhancedAppProvider>();
    final accounts = provider.allAccounts
        .where((a) => a.id != _accountId)
        .toList(growable: false);

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => _AccountPickerDialog(
        accounts: accounts,
        currentSelection: _draftData[field.fieldKey],
        resolveTemplate: provider.getTemplate,
        localeText: _text,
      ),
    );

    if (selected == null) return;
    if (!mounted) return;

    setState(() {
      if (selected.isEmpty) {
        _draftData.remove(field.fieldKey);
      } else {
        _draftData[field.fieldKey] = selected;
      }
    });
  }

  Widget _buildFieldSectionHeader(
    BuildContext context,
    AccountTemplate? template,
  ) {
    final theme = Theme.of(context);
    final fieldCount = template?.fields.length ?? 0;
    final secretCount =
        template?.fields.where((field) => field.attributes.isSecret).length ??
        0;

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.soft(
          theme.colorScheme,
          tint: theme.colorScheme.secondary,
          tintAlpha: 10,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(88),
        ),
        boxShadow: AppShadows.card(theme, depth: 0.62),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('账户字段', 'Account Fields'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              template == null
                  ? _text(
                      '模板确定后，这里会展开对应的字段组，方便在浅色模式下快速浏览与编辑。',
                      'Template fields will appear here once a template is selected.',
                    )
                  : _text(
                      '字段卡片现在带预览层和强调信息，浏览时更像成品而不是表单堆叠。',
                      'These cards now stage content with clearer preview layers and emphasis.',
                    ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (template != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ToneChip(
                    icon: Icons.layers_outlined,
                    label: '${template.title} · $fieldCount',
                  ),
                  ToneChip(
                    icon: Icons.visibility_off_outlined,
                    label: '$secretCount ${_text('个保密字段', 'secret')}',
                    tint: theme.colorScheme.tertiary,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFieldSection(
    BuildContext context,
    AccountTemplate currentTemplate,
  ) {
    return Column(
      children: [
        for (var i = 0; i < currentTemplate.fields.length; i++) ...[
          _buildFieldCard(context, currentTemplate.fields[i]),
          if (i != currentTemplate.fields.length - 1)
            const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildEmptyFieldState(BuildContext context) {
    final theme = Theme.of(context);
    final title = _hasMissingTemplate
        ? _text('模板已缺失', 'Template Missing')
        : _text(
            '请先选择模板',
            'Choose a Template First',
          );
    final description = _hasMissingTemplate
        ? _text(
            '该账户原来绑定的模板已不可用。为了避免原始数据被覆盖，系统暂时禁止直接保存。',
            'The template linked to this account is no longer available. Saving is temporarily disabled so the original data is not overwritten.',
          )
        : _text(
            '模板会决定账户需要录入哪些信息，选择后下方会自动展开字段。',
            'Templates decide which pieces of information belong to this account.',
          );

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.soft(
          theme.colorScheme,
          tint: theme.colorScheme.secondary,
          tintAlpha: 12,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(90),
        ),
        boxShadow: AppShadows.card(theme, depth: 0.55),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withAlpha(236),
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.rule_folder_outlined,
                size: 28,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegacyFieldsCard(BuildContext context) {
    final theme = Theme.of(context);
    final legacyEntries = _legacyData.entries.toList();
    final removedEntries = _removedLegacyEntries.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('历史字段', 'Historical Fields'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                '这些是当前模板没有定义，但账户仍然保留的字段。你可以继续保留它们，或在保存前明确标记删除。',
                'These fields still belong to the account even though the current template does not define them. You can keep them, or explicitly mark them for removal before saving.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            ...legacyEntries.map((entry) {
              final meta = widget.initial?.fieldMeta[entry.key];
              final label = meta?.label ?? _formatKeyLabel(entry.key);
              final isSecret = meta?.type == AccountFieldType.password.name;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                      90,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withAlpha(120),
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
                                  label,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (meta != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withAlpha(AppAlphas.tint),
                                          borderRadius: BorderRadius.circular(AppRadii.chip),
                                        ),
                                        child: Text(
                                          meta.type,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: _text(
                              '复制字段内容',
                              'Copy field value',
                            ),
                            onPressed: () => _copyValue(label, entry.value),
                            icon: const Icon(Icons.content_copy_outlined),
                          ),
                          if (_isEditing)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: _text(
                                '标记删除',
                                'Mark for removal',
                              ),
                              onPressed: () =>
                                  _confirmRemoveLegacyField(entry.key),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        isSecret ? '••••••••' : entry.value,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (_isEditing && removedEntries.isNotEmpty) ...[
              const SizedBox(height: 8),
              Divider(color: theme.colorScheme.outlineVariant.withAlpha(120)),
              const SizedBox(height: 12),
              Text(
                _text('待删除字段', 'Pending Removal'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _text(
                  '这些字段会在保存后从账户中移除，在保存之前仍可恢复。',
                  'These fields will be removed from the account after you save. You can still restore them before saving.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ...removedEntries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withAlpha(60),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(
                        color: theme.colorScheme.error.withAlpha(70),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatKeyLabel(entry.key),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.key,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _restoreLegacyField(entry.key),
                          icon: const Icon(Icons.undo_outlined),
                          label: Text(_text('恢复', 'Restore')),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = context.watch<EnhancedAppProvider>().allTemplates;
    _syncTemplateSelectionFromProvider(templates);
    final currentTemplate = _currentTemplate;
    final legacyData = _legacyData;
    final isDesktop = AppBreakpoints.isDesktop(context);
    final fabBottomOffset = isDesktop ? 24.0 : 20.0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? _text('新建账户', 'Add Account')
              : _isEditing
              ? _text('编辑账户', 'Edit Account')
              : _text('预览账户', 'Preview Account'),
        ),
        actions: [
          if (widget.initial != null)
            IconButton(
              tooltip: _text(
                '历史版本与冲突',
                'History & Conflicts',
              ),
              icon: const Icon(Icons.history_outlined),
              onPressed: _showConflictHistory,
            ),
          IconButton(
            tooltip: _text(
              '复制全部信息',
              'Copy all information',
            ),
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () => _copyValue(
              _text('全部信息', 'All Information'),
              _buildCopyAllText(),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppSurfaces.soft(
                theme.colorScheme,
                tint: theme.colorScheme.primary,
                tintAlpha: 16,
              ),
              theme.scaffoldBackgroundColor,
              AppSurfaces.soft(
                theme.colorScheme,
                tint: theme.colorScheme.tertiary,
                tintAlpha: 8,
              ),
            ],
            stops: const [0, 0.24, 1],
          ),
        ),
        child: AdaptivePage(
          desktopMaxWidth: 1320,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 120),
            children: [
              _buildTopSection(context),
              const SizedBox(height: 24),
              _buildFieldSectionHeader(context, currentTemplate),
              const SizedBox(height: 12),
              if (currentTemplate == null)
                _buildEmptyFieldState(context)
              else
                _buildFieldSection(context, currentTemplate),
              if (legacyData.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildLegacyFieldsCard(context),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: SafeArea(
        minimum: EdgeInsets.only(right: 4, bottom: fabBottomOffset),
        child: GreenAddButton(
          heroTag: widget.initial == null
              ? 'save-account-fab-new'
              : _isEditing
              ? 'save-account-fab-edit'
              : 'edit-account-fab-preview',
          tooltip: _isEditing
              ? _text('保存账户', 'Save Account')
              : _text('编辑账户', 'Edit Account'),
          icon: _isEditing ? Icons.check : Icons.edit_outlined,
          onPressed: _isEditing
              ? (_hasMissingTemplate ? null : _save)
              : () => setState(() {
                  _isEditing = true;
                }),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    for (final controller in _fieldCtrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _showConflictHistory() async {
    final accountId = widget.initial!.id;
    final logs = await ServiceManager.instance.storageService.getConflictLogs(
      accountId,
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final sheetTheme = Theme.of(context);

    if (logs.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _text(
              '没有历史或冲突记录',
              'No history or conflicts found',
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetTheme.scaffoldBackgroundColor,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.only(
            top: 20,
            left: 16,
            right: 16,
            bottom: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(
                  '历史冲突记录 (Conflict Logs)',
                  'History & Conflicts',
                ),
                style: sheetTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _text(
                  '点击恢复以将旧数据填入编辑框，保存即可覆盖云端。',
                  'Tap Restore to load old data into the form. Saving it will overwrite the cloud.',
                ),
                style: sheetTheme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (ctx, idx) {
                    final log = logs[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _formatKeyLabel(log.fieldKey.replaceFirst('data.', '')),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.fieldValue,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateFormat('yy-MM-dd HH:mm').format(
                              DateTime.fromMillisecondsSinceEpoch(log.savedAt),
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      trailing: FilledButton.tonal(
                        child: Text(_text('恢复', 'Restore')),
                        onPressed: () {
                          if (log.fieldKey == 'name') {
                            _nameCtrl.text = log.fieldValue;
                          } else if (log.fieldKey == 'email') {
                            _emailCtrl.text = log.fieldValue;
                          } else if (log.fieldKey.startsWith('data.')) {
                            final key = log.fieldKey.replaceFirst('data.', '');
                            if (_fieldCtrls.containsKey(key)) {
                              _fieldCtrls[key]!.text = log.fieldValue;
                            }
                            _draftData[key] = log.fieldValue;
                          }
                          setState(() {
                            _isEditing = true;
                          });
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                _text(
                                  '已填入表单，请点击保存以生效',
                                  'Draft loaded. Hit save to commit.',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// List Field Editor — used by AccountFieldType.list
// ---------------------------------------------------------------------------

class _ListFieldEditor extends StatefulWidget {
  final TextEditingController controller;
  final bool isMnemonic;
  final bool isSecret;
  final bool readOnly;
  final String? hint;

  const _ListFieldEditor({
    required this.controller,
    this.isMnemonic = false,
    this.isSecret = false,
    this.readOnly = false,
    this.hint,
  });

  @override
  State<_ListFieldEditor> createState() => _ListFieldEditorState();
}

class _ListFieldEditorState extends State<_ListFieldEditor> {
  late List<String> _items;
  bool _mnemonicObscured = true;
  Timer? _autoHideTimer;

  static const _validMnemonicLengths = {12, 15, 18, 21, 24};

  @override
  void initState() {
    super.initState();
    _items = _parseItems(widget.controller.text);
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ListFieldEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _items = _parseItems(widget.controller.text);
    }
  }

  List<String> _parseItems(String text) {
    if (text.trim().isEmpty) return [];
    return text.split('\n').where((s) => s.isNotEmpty).toList();
  }

  void _updateController() {
    final newText = _items.join('\n');
    if (widget.controller.text != newText) {
      widget.controller.text = newText;
    }
  }

  void _addItem() {
    setState(() => _items.add(''));
    _updateController();
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
    _updateController();
  }

  void _updateItem(int index, String value) {
    if (index >= 0 && index < _items.length) {
      _items[index] = value;
      _updateController();
    }
  }

  void _handlePaste(String pasted) {
    final words = pasted.trim().split(RegExp(r'[\s,;，；]+'));
    final filtered = words.where((w) => w.isNotEmpty).toList();
    if (filtered.isEmpty) return;
    setState(() => _items = filtered);
    _updateController();
  }

  Future<void> _copyAllItems() async {
    if (_items.isEmpty) return;
    final separator = widget.isMnemonic ? ' ' : '\n';
    await SensitiveClipboardService.copy(
      text: _items.join(separator),
      level: ClipboardRiskLevel.high,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 220,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_rounded, size: 16),
            const SizedBox(width: 8),
            Text(context.text('已复制全部', 'Copied all')),
          ],
        ),
      ),
    );
  }

  void _revealWithAutoHide() {
    setState(() => _mnemonicObscured = false);
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _mnemonicObscured = true);
    });
  }

  bool get _isMnemonicValid =>
      _items.isNotEmpty && _validMnemonicLengths.contains(_items.length);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isMnemonic) {
      return _buildMnemonicEditor(theme);
    }
    return _buildGenericListEditor(theme);
  }

  Widget _buildMnemonicEditor(ThemeData theme) {
    final accent = theme.colorScheme.primary;
    final errorColor = theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.readOnly)
          TextField(
            decoration: InputDecoration(
              hintText:
                  widget.hint ??
                  '粘贴助记词，支持空格/换行/逗号分隔',
              prefixIcon: const Icon(Icons.paste_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
            ),
            onSubmitted: _handlePaste,
          ),
        if (!widget.readOnly) const SizedBox(height: 12),
        if (_items.isEmpty)
          Text(
            '还未输入助记词',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          // Word count + validation badge
          Row(
            children: [
              Text(
                '${_items.length} 个单词',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              if (_isMnemonicValid)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Text(
                    '有效',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: errorColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Text(
                    '应为 ${_validMnemonicLengths.toList().join('/')} 个',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              if (_items.isNotEmpty)
                IconButton(
                  onPressed: _copyAllItems,
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              // Reveal/obscure toggle
              IconButton(
                onPressed: () {
                  if (_mnemonicObscured) {
                    _revealWithAutoHide();
                  } else {
                    _autoHideTimer?.cancel();
                    setState(() => _mnemonicObscured = true);
                  }
                },
                icon: Icon(
                  _mnemonicObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _items.asMap().entries.map((entry) {
              final index = entry.key;
              final value = entry.value;
              return SizedBox(
                width: 90,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withAlpha(AppAlphas.medium),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${index + 1}.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _mnemonicObscured && !widget.readOnly
                            ? GestureDetector(
                                onTap: _revealWithAutoHide,
                                child: Text(
                                  '••••',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: accent,
                                  ),
                                ),
                              )
                            : TextField(
                                controller: TextEditingController(text: value),
                                onChanged: (v) => _updateItem(index, v),
                                readOnly: widget.readOnly,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (!widget.readOnly && _items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _items.length < 24 ? _addItem : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加单词'),
                ),
                TextButton.icon(
                  onPressed: _items.isNotEmpty
                      ? () => _removeItem(_items.length - 1)
                      : null,
                  icon: const Icon(Icons.remove, size: 18),
                  label: const Text('删除末尾'),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildGenericListEditor(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_items.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: _copyAllItems,
              icon: const Icon(Icons.copy_outlined, size: 18),
              tooltip: context.text('复制全部', 'Copy all'),
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ..._items.asMap().entries.map((entry) {
          final index = entry.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: entry.value),
                    onChanged: (v) => _updateItem(index, v),
                    readOnly: widget.readOnly,
                    obscureText: widget.isSecret && _mnemonicObscured,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: '${index + 1}',
                      prefixIcon: const Icon(Icons.short_text_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.control),
                      ),
                    ),
                  ),
                ),
                if (!widget.readOnly)
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: theme.colorScheme.error.withAlpha(AppAlphas.emphasis),
                    ),
                    onPressed: () => _removeItem(index),
                  ),
              ],
            ),
          );
        }),
        if (widget.isSecret && _items.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              if (_mnemonicObscured) {
                _revealWithAutoHide();
              } else {
                _autoHideTimer?.cancel();
                setState(() => _mnemonicObscured = true);
              }
            },
            icon: Icon(
              _mnemonicObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 18,
            ),
            label: Text(
              _mnemonicObscured
                  ? context.text('显示', 'Reveal')
                  : context.text('隐藏', 'Hide'),
            ),
          ),
        if (!widget.readOnly)
          TextButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            label: const Text('添加项'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Account Picker Dialog — used by AccountFieldType.accountLink
// ---------------------------------------------------------------------------

class _AccountPickerDialog extends StatefulWidget {
  final List<AccountItem> accounts;
  final String? currentSelection;
  final AccountTemplate? Function(String templateId) resolveTemplate;
  final String Function(String zh, String en) localeText;

  const _AccountPickerDialog({
    required this.accounts,
    required this.currentSelection,
    required this.resolveTemplate,
    required this.localeText,
  });

  @override
  State<_AccountPickerDialog> createState() => _AccountPickerDialogState();
}

class _AccountPickerDialogState extends State<_AccountPickerDialog> {
  String _query = '';

  List<AccountItem> get _filtered {
    if (_query.isEmpty) return widget.accounts;
    final normalized = _query.toLowerCase();
    return widget.accounts.where((a) {
      return a.name.toLowerCase().contains(normalized) ||
          a.email.toLowerCase().contains(normalized);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;

    return AlertDialog(
      title: Text(
        widget.localeText(
          '选择关联账户',
          'Select Linked Account',
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.localeText(
                    '搜索账户...',
                    'Search accounts...',
                  ),
                  prefixIcon: const Icon(Icons.search_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.localeText(
                          '未找到账户',
                          'No accounts found',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final account = filtered[index];
                        final template = widget.resolveTemplate(
                          account.templateId,
                        );
                        final isSelected =
                            widget.currentSelection == account.id;

                        return ListTile(
                          leading: Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: template != null
                              ? Text(
                                  template.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, account.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.currentSelection != null &&
            widget.currentSelection!.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(
              widget.localeText('清除关联', 'Clear Link'),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.localeText('取消', 'Cancel')),
        ),
      ],
    );
  }
}
