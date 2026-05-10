import 'package:flutter/material.dart';

import '../../l10n/app_text_extension.dart';

/// A generic category filter bar using ChoiceChips.
///
/// [T] is the enum or value type used to identify each category.
class InboxFilterBar<T> extends StatelessWidget {
  /// Each tuple is: (value, chineseLabel, englishLabel).
  final List<(T, String, String)> categories;
  final T selected;
  final ValueChanged<T> onSelected;

  const InboxFilterBar({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      children: categories.map((cat) {
        final isSelected = selected == cat.$1;
        return ChoiceChip(
          label: Text(context.text(cat.$2, cat.$3)),
          selected: isSelected,
          onSelected: (_) => onSelected(cat.$1),
          selectedColor: theme.colorScheme.primaryContainer,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }
}
