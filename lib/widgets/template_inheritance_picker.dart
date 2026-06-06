import 'package:flutter/material.dart';

import '../models/account_template.dart';
import '../utils/template_reference_validator.dart';

/// A dialog for selecting parent templates (Feature 2: template inheritance).
///
/// Shows all available templates, excluding those that would create
/// inheritance cycles. Supports multi-select with chips.
class TemplateInheritancePicker extends StatefulWidget {
  final List<AccountTemplate> availableTemplates;
  final String selfTemplateId;
  final List<String> currentlySelected;
  /// Map of templateId → parentTemplateIds for all templates.
  final Map<String, List<String>> parentGraph;

  const TemplateInheritancePicker({
    super.key,
    required this.availableTemplates,
    required this.selfTemplateId,
    this.currentlySelected = const [],
    this.parentGraph = const {},
  });

  @override
  State<TemplateInheritancePicker> createState() =>
      _TemplateInheritancePickerState();
}

class _TemplateInheritancePickerState extends State<TemplateInheritancePicker> {
  late List<String> _selected;
  late Set<String> _cycleCandidates;

  String _text(String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.currentlySelected);
    _cycleCandidates = TemplateReferenceValidator.findInheritanceCycleCandidates(
      selfId: widget.selfTemplateId,
      parentGraph: widget.parentGraph,
    );
  }

  void _toggle(String templateId) {
    setState(() {
      if (_selected.contains(templateId)) {
        _selected.remove(templateId);
      } else {
        _selected.add(templateId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: Text(_text('选择父模板', 'Select Parent Templates')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selected.isNotEmpty) ...[
              Text(
                _text('已选择 ${_selected.length} 个', '${_selected.length} selected'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selected.map((id) {
                  final t = widget.availableTemplates.firstWhere(
                    (x) => x.templateId == id,
                    orElse: () => widget.availableTemplates.first,
                  );
                  return Chip(
                    label: Text(t.title),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _toggle(id),
                    backgroundColor: colors.primary.withAlpha(30),
                    side: BorderSide(color: colors.primary.withAlpha(80)),
                  );
                }).toList(),
              ),
              const Divider(height: 24),
            ],
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.availableTemplates.length,
                itemBuilder: (context, index) {
                  final t = widget.availableTemplates[index];
                  if (t.templateId == widget.selfTemplateId) {
                    return const SizedBox.shrink();
                  }
                  final isBlocked =
                      _cycleCandidates.contains(t.templateId);
                  final isSelected = _selected.contains(t.templateId);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: isBlocked
                        ? null
                        : (_) => _toggle(t.templateId),
                    title: Text(t.title),
                    subtitle: isBlocked
                        ? Text(
                            _text(
                              '添加此模板会造成循环引用',
                              'Adding would create a cycle',
                            ),
                            style: TextStyle(color: colors.error, fontSize: 12),
                          )
                        : Text(
                            '${t.fields.length} ${_text('个字段', 'fields')}',
                          ),
                    secondary: Icon(
                      isBlocked
                          ? Icons.block_outlined
                          : (isSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank),
                      color: isBlocked ? colors.error : colors.primary,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_text('取消', 'Cancel')),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, List<String>.from(_selected)),
          child: Text(_text('确定', 'Confirm')),
        ),
      ],
    );
  }
}
