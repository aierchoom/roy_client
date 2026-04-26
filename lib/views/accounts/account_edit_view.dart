import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/account_item.dart';
import '../../models/account_template.dart';
import '../../models/hlc.dart';
import '../../providers/enhanced_app_provider.dart';
import '../../services/service_manager.dart';
import '../../widgets/adaptive_page.dart';
import '../../widgets/green_add_button.dart';
import '../../widgets/password_generator_sheet.dart';

class AccountEditView extends StatefulWidget {
  final AccountItem? initial;

  const AccountEditView({super.key, this.initial});

  @override
  State<AccountEditView> createState() => _AccountEditViewState();
}

class _AccountEditViewState extends State<AccountEditView> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _pickedTag;
  String? _activeTemplateId;
  late bool _isEditing;

  final Map<String, TextEditingController> _fieldCtrls = {};
  final Map<String, bool> _fieldVisibility = {};
  final Map<String, String> _draftData = {};
  final Map<String, String> _removedLegacyData = {};
  AccountTemplate? _currentTemplate;

  String _text(String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  bool _isTimeField(AccountField field) {
    return field.attributes.type == AccountFieldType.time;
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
                      child: Text(_text('\u53d6\u6d88', 'Cancel')),
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
                      child: Text(_text('\u786e\u5b9a', 'Confirm')),
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
        cancelText: _text('\u53d6\u6d88', 'Cancel'),
        confirmText: _text('\u786e\u5b9a', 'Confirm'),
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
      helpText: _text('\u9009\u62e9\u65e5\u671f', 'Select date'),
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
      cancelText: _text('\u53d6\u6d88', 'Cancel'),
      confirmText: _text('\u786e\u5b9a', 'Confirm'),
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
    _isEditing = widget.initial == null;
    _draftData.addAll(widget.initial?.data ?? const <String, String>{});
    if (widget.initial != null) {
      _nameCtrl.text = widget.initial!.name;
      _emailCtrl.text = widget.initial!.email;
      _pickedTag = widget.initial!.templateId;
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

  bool get _hasMissingTemplate =>
      _pickedTag != null && _currentTemplate == null;

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
        _text('\u5f53\u524d\u6a21\u677f', 'Current template');
    final nextTemplateName =
        nextTemplate?.title ?? _text('\u65b0\u6a21\u677f', 'New template');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text('\u5207\u6362\u6a21\u677f', 'Change Template')),
        content: Text(
          _text(
            '\u4f60\u6b63\u5728\u5c06\u8d26\u6237\u4ece\u201c$currentTemplateName\u201d\u5207\u6362\u5230\u201c$nextTemplateName\u201d\u3002\n\n\u7cfb\u7edf\u4f1a\u4fdd\u7559\u539f\u6709\u5b57\u6bb5\u503c\uff0c\u4f46\u4e0d\u4f1a\u81ea\u52a8\u8fc1\u79fb\u6210\u65b0\u6a21\u677f\u5b57\u6bb5\uff0c\u8bf7\u5728\u4fdd\u5b58\u524d\u786e\u8ba4\u9700\u8981\u7684\u65b0\u5b57\u6bb5\u5185\u5bb9\u3002',
            'You are changing this account from "$currentTemplateName" to "$nextTemplateName".\n\nExisting field values will be preserved, but they will not be auto-mapped to the new template. Please review the new template fields before saving.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_text('\u53d6\u6d88', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_text('\u7ee7\u7eed', 'Continue')),
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
            '\u5220\u9664\u5386\u53f2\u5b57\u6bb5',
            'Remove Historical Field',
          ),
        ),
        content: Text(
          _text(
            '\u786e\u8ba4\u5c06\u201c${_formatKeyLabel(key)}\u201d\u6807\u8bb0\u4e3a\u5220\u9664\u5417\uff1f\n\n\u8fd9\u4e2a\u53d8\u66f4\u4f1a\u5728\u4fdd\u5b58\u8d26\u6237\u540e\u751f\u6548\uff0c\u53ef\u4ee5\u5728\u4fdd\u5b58\u524d\u968f\u65f6\u6062\u590d\u3002',
            'Mark "${_formatKeyLabel(key)}" for removal?\n\nThis change will take effect when you save the account, and you can restore it any time before saving.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_text('\u53d6\u6d88', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_text('\u6807\u8bb0\u5220\u9664', 'Mark for Removal')),
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

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              '\u8bf7\u586b\u5199\u8d26\u6237\u540d\u79f0',
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
              '\u5f53\u524d\u6a21\u677f\u4e0d\u53ef\u7528\uff0c\u8bf7\u5148\u6062\u590d\u6216\u9009\u62e9\u53ef\u7528\u6a21\u677f\u540e\u518d\u4fdd\u5b58\u3002',
              'The selected template is unavailable. Restore it or choose an available template before saving.',
            ),
          ),
        ),
      );
      return;
    }

    if (_currentTemplate != null) {
      for (final field in _currentTemplate!.fields) {
        if (field.attributes.isRequired &&
            (_fieldCtrls[field.fieldKey]?.text.isEmpty ?? true)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _text(
                  '\u8bf7\u586b\u5199\u5fc5\u586b\u5b57\u6bb5\uff1a${field.label}',
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
    for (final key in _removedLegacyData.keys) {
      if (_visibleFieldKeys.contains(key)) continue;
      data.remove(key);
    }

    final item = AccountItem(
      id:
          widget.initial?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: _emailCtrl.text.trim(),
      templateId: _pickedTag ?? '',
      data: data,
      createdAt:
          widget.initial?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      nameHlc: widget.initial?.nameHlc ?? Hlc.zero('local'),
      emailHlc: widget.initial?.emailHlc ?? Hlc.zero('local'),
      dataHlc: widget.initial?.dataHlc ?? {},
      serverVersion: widget.initial?.serverVersion ?? 0,
      syncStatus: widget.initial?.syncStatus ?? SyncStatus.pendingPush,
      isDeleted: widget.initial?.isDeleted ?? false,
      deleteHlc: widget.initial?.deleteHlc,
    );

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
              '$label \u6682\u65e0\u53ef\u590d\u5236\u5185\u5bb9',
              'No content available to copy for $label',
            ),
          ),
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: trimmed));
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(_text('\u5df2\u590d\u5236 $label', 'Copied $label')),
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
          tooltip: _text('\u9009\u62e9\u65f6\u95f4', 'Pick date and time'),
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
              ? _text('\u9690\u85cf\u5bc6\u7801', 'Hide password')
              : _text('\u663e\u793a\u5bc6\u7801', 'Show password'),
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
            '\u590d\u5236\u5b57\u6bb5\u5185\u5bb9',
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

  List<BoxShadow> _softCardShadows(ThemeData theme, {double depth = 1}) {
    if (theme.brightness != Brightness.light) {
      return const [];
    }

    return [
      BoxShadow(
        color: theme.colorScheme.shadow.withAlpha(
          (10 * depth).round().clamp(0, 255),
        ),
        blurRadius: 28 * depth,
        offset: Offset(0, 16 * depth),
      ),
      BoxShadow(
        color: theme.colorScheme.primary.withAlpha(
          (6 * depth).round().clamp(0, 255),
        ),
        blurRadius: 12 * depth,
        offset: Offset(0, 6 * depth),
      ),
    ];
  }

  Color _softSurface(ThemeData theme, {Color? tint, int tintAlpha = 18}) {
    final base = theme.colorScheme.surface;
    if (tint == null) {
      return base;
    }
    if (theme.brightness != Brightness.light) {
      return theme.colorScheme.surfaceContainerHigh;
    }
    return Color.alphaBlend(tint.withAlpha(tintAlpha), base);
  }

  Widget _buildToneChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? tint,
  }) {
    final theme = Theme.of(context);
    final accent = tint ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _softSurface(theme, tint: accent, tintAlpha: 16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withAlpha(48)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
    final heroBase = _softSurface(
      theme,
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: heroEdge),
        boxShadow: _softCardShadows(theme, depth: 1.15),
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
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _softCardShadows(theme, depth: 0.45),
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
                              '\u672a\u547d\u540d\u8d26\u6237',
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
                            '\u8bf7\u9009\u62e9\u6a21\u677f',
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
              _buildToneChip(
                context,
                icon: _isEditing
                    ? Icons.edit_note_outlined
                    : Icons.visibility_outlined,
                label: _isEditing
                    ? _text('正在编辑', 'Editing')
                    : _text('只读预览', 'Preview'),
                tint: theme.colorScheme.onPrimaryContainer,
              ),
              if (selectedTemplate != null)
                _buildToneChip(
                  context,
                  icon: Icons.layers_outlined,
                  label:
                      '${selectedTemplate.fields.length} ${_text('个字段', 'fields')}',
                  tint: theme.colorScheme.onPrimaryContainer,
                ),
              if (_emailCtrl.text.trim().isNotEmpty)
                _buildToneChip(
                  context,
                  icon: Icons.alternate_email_rounded,
                  label: _emailCtrl.text.trim(),
                  tint: theme.colorScheme.onPrimaryContainer,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: heroBase.withAlpha(230),
              borderRadius: BorderRadius.circular(18),
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
                    borderRadius: BorderRadius.circular(16),
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
        : _softSurface(theme, tint: theme.colorScheme.primary, tintAlpha: 18);

    return Container(
      decoration: BoxDecoration(
        color: _softSurface(
          theme,
          tint: theme.colorScheme.primary,
          tintAlpha: 8,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(88),
        ),
        boxShadow: _softCardShadows(theme, depth: 0.82),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('\u57fa\u672c\u4fe1\u606f', 'Basic Information'),
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
                            '\u8d26\u6237\u540d\u79f0',
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
                            '\u7ed1\u5b9a\u90ae\u7bb1/\u5907\u6ce8',
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
                            '\u8d26\u6237\u540d\u79f0',
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
                            '\u7ed1\u5b9a\u90ae\u7bb1/\u5907\u6ce8',
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
                labelText: _text('\u9009\u62e9\u6a21\u677f', 'Select Template'),
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              hint: Text(
                _text('\u8bf7\u9009\u62e9\u6a21\u677f', 'Choose a template'),
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
                  borderRadius: BorderRadius.circular(18),
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
                          '\u5f53\u524d\u6a21\u677f\u7f3a\u5931\uff0c\u8d26\u6237\u5df2\u8fdb\u5165\u4fdd\u62a4\u72b6\u6001\u3002\u4f60\u53ef\u4ee5\u67e5\u770b\u5df2\u4fdd\u5b58\u7684\u5b57\u6bb5\uff0c\u4f46\u9700\u8981\u5148\u6062\u590d\u6216\u5207\u6362\u5230\u53ef\u7528\u6a21\u677f\u540e\u624d\u80fd\u4fdd\u5b58\u3002',
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
                  borderRadius: BorderRadius.circular(18),
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
                        borderRadius: BorderRadius.circular(16),
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
                              _buildToneChip(
                                context,
                                icon: Icons.view_stream_outlined,
                                label:
                                    '${selectedTemplate.fields.length} ${_text('个字段', 'fields')}',
                              ),
                              _buildToneChip(
                                context,
                                icon: Icons.star_border_rounded,
                                label:
                                    '${selectedTemplate.fields.where((field) => field.attributes.isRequired).length} ${_text('个必填', 'required')}',
                              ),
                              _buildToneChip(
                                context,
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
    final theme = Theme.of(context);
    final controller = _fieldCtrls[field.fieldKey];
    final accent = _fieldAccentColor(theme, field);
    final previewSurface = _softSurface(theme, tint: accent, tintAlpha: 10);

    return Container(
      decoration: BoxDecoration(
        color: _softSurface(theme, tint: accent, tintAlpha: 5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withAlpha(38)),
        boxShadow: _softCardShadows(theme, depth: 0.7),
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
                    color: _softSurface(theme, tint: accent, tintAlpha: 18),
                    borderRadius: BorderRadius.circular(15),
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
                _buildToneChip(
                  context,
                  icon: Icons.label_outline_rounded,
                  label: field.attributes.type.name,
                  tint: accent,
                ),
                if (field.attributes.isRequired)
                  _buildToneChip(
                    context,
                    icon: Icons.star_outline_rounded,
                    label: _text('必填', 'Required'),
                    tint: accent,
                  ),
                if (field.attributes.isSecret)
                  _buildToneChip(
                    context,
                    icon: Icons.visibility_off_outlined,
                    label: _text('保密', 'Secret'),
                    tint: accent,
                  ),
                if (!field.attributes.isEditable)
                  _buildToneChip(
                    context,
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
                borderRadius: BorderRadius.circular(18),
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
                    onTap:
                        _isTimeField(field) &&
                            field.attributes.timeFormat !=
                                TimeFieldFormat.monthYear &&
                            _isEditing &&
                            field.attributes.isEditable
                        ? () => _pickDateTimeField(field, controller!)
                        : null,
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

  Widget _buildTopSection(BuildContext context) {
    final overview = _buildOverviewCard(context);
    final basicInfo = _buildBasicInfoCard(context);

    return Column(children: [overview, const SizedBox(height: 24), basicInfo]);
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
        color: _softSurface(
          theme,
          tint: theme.colorScheme.secondary,
          tintAlpha: 10,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(88),
        ),
        boxShadow: _softCardShadows(theme, depth: 0.62),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('\u8d26\u6237\u5b57\u6bb5', 'Account Fields'),
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
                  _buildToneChip(
                    context,
                    icon: Icons.layers_outlined,
                    label: '${template.title} · $fieldCount',
                  ),
                  _buildToneChip(
                    context,
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
        ? _text('\u6a21\u677f\u5df2\u7f3a\u5931', 'Template Missing')
        : _text(
            '\u8bf7\u5148\u9009\u62e9\u6a21\u677f',
            'Choose a Template First',
          );
    final description = _hasMissingTemplate
        ? _text(
            '\u8be5\u8d26\u6237\u539f\u6765\u7ed1\u5b9a\u7684\u6a21\u677f\u5df2\u4e0d\u53ef\u7528\u3002\u4e3a\u4e86\u907f\u514d\u539f\u59cb\u6570\u636e\u88ab\u8986\u76d6\uff0c\u7cfb\u7edf\u6682\u65f6\u7981\u6b62\u76f4\u63a5\u4fdd\u5b58\u3002',
            'The template linked to this account is no longer available. Saving is temporarily disabled so the original data is not overwritten.',
          )
        : _text(
            '\u6a21\u677f\u4f1a\u51b3\u5b9a\u8d26\u6237\u9700\u8981\u5f55\u5165\u54ea\u4e9b\u4fe1\u606f\uff0c\u9009\u62e9\u540e\u4e0b\u65b9\u4f1a\u81ea\u52a8\u5c55\u5f00\u5b57\u6bb5\u3002',
            'Templates decide which pieces of information belong to this account.',
          );

    return Container(
      decoration: BoxDecoration(
        color: _softSurface(
          theme,
          tint: theme.colorScheme.secondary,
          tintAlpha: 12,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(90),
        ),
        boxShadow: _softCardShadows(theme, depth: 0.55),
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
                borderRadius: BorderRadius.circular(18),
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
              _text('\u5386\u53f2\u5b57\u6bb5', 'Historical Fields'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                '\u8fd9\u4e9b\u662f\u5f53\u524d\u6a21\u677f\u6ca1\u6709\u5b9a\u4e49\uff0c\u4f46\u8d26\u6237\u4ecd\u7136\u4fdd\u7559\u7684\u5b57\u6bb5\u3002\u4f60\u53ef\u4ee5\u7ee7\u7eed\u4fdd\u7559\u5b83\u4eec\uff0c\u6216\u5728\u4fdd\u5b58\u524d\u660e\u786e\u6807\u8bb0\u5220\u9664\u3002',
                'These fields still belong to the account even though the current template does not define them. You can keep them, or explicitly mark them for removal before saving.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            ...legacyEntries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                      90,
                    ),
                    borderRadius: BorderRadius.circular(12),
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
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: _text(
                              '\u590d\u5236\u5b57\u6bb5\u5185\u5bb9',
                              'Copy field value',
                            ),
                            onPressed: () => _copyValue(
                              _formatKeyLabel(entry.key),
                              entry.value,
                            ),
                            icon: const Icon(Icons.content_copy_outlined),
                          ),
                          if (_isEditing)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: _text(
                                '\u6807\u8bb0\u5220\u9664',
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
                        entry.value,
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
                _text('\u5f85\u5220\u9664\u5b57\u6bb5', 'Pending Removal'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _text(
                  '\u8fd9\u4e9b\u5b57\u6bb5\u4f1a\u5728\u4fdd\u5b58\u540e\u4ece\u8d26\u6237\u4e2d\u79fb\u9664\uff0c\u5728\u4fdd\u5b58\u4e4b\u524d\u4ecd\u53ef\u6062\u590d\u3002',
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
                      borderRadius: BorderRadius.circular(12),
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
                          label: Text(_text('\u6062\u590d', 'Restore')),
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
    final currentTemplate = _currentTemplate;
    final legacyData = _legacyData;
    final isDesktop = AppBreakpoints.isDesktop(context);
    final fabBottomOffset = isDesktop ? 24.0 : 20.0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? _text('\u65b0\u5efa\u8d26\u6237', 'Add Account')
              : _isEditing
              ? _text('\u7f16\u8f91\u8d26\u6237', 'Edit Account')
              : _text('\u9884\u89c8\u8d26\u6237', 'Preview Account'),
        ),
        actions: [
          if (widget.initial != null)
            IconButton(
              tooltip: _text(
                '\u5386\u53f2\u7248\u672c\u4e0e\u51b2\u7a81',
                'History & Conflicts',
              ),
              icon: const Icon(Icons.history_outlined),
              onPressed: _showConflictHistory,
            ),
          IconButton(
            tooltip: _text(
              '\u590d\u5236\u5168\u90e8\u4fe1\u606f',
              'Copy all information',
            ),
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () => _copyValue(
              _text('\u5168\u90e8\u4fe1\u606f', 'All Information'),
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
              _softSurface(
                theme,
                tint: theme.colorScheme.primary,
                tintAlpha: 16,
              ),
              theme.scaffoldBackgroundColor,
              _softSurface(
                theme,
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
              ? _text('\u4fdd\u5b58\u8d26\u6237', 'Save Account')
              : _text('\u7f16\u8f91\u8d26\u6237', 'Edit Account'),
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
              '\u6ca1\u6709\u5386\u53f2\u6216\u51b2\u7a81\u8bb0\u5f55',
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
                  '\u5386\u53f2\u51b2\u7a81\u8bb0\u5f55 (Conflict Logs)',
                  'History & Conflicts',
                ),
                style: sheetTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _text(
                  '\u70b9\u51fb\u6062\u590d\u4ee5\u5c06\u65e7\u6570\u636e\u586b\u5165\u7f16\u8f91\u6846\uff0c\u4fdd\u5b58\u5373\u53ef\u8986\u76d6\u4e91\u7aef\u3002',
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: FilledButton.tonal(
                        child: Text(_text('\u6062\u590d', 'Restore')),
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
                                  '\u5df2\u586b\u5165\u8868\u5355\uff0c\u8bf7\u70b9\u51fb\u4fdd\u5b58\u4ee5\u751f\u6548',
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

class MonthYearInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) return newValue;

    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 4) text = text.substring(0, 4);

    var formatted = '';
    for (var i = 0; i < text.length; i++) {
      if (i == 2) formatted += '/';
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
