import 'package:flutter/material.dart';

/// Animated circular selection indicator with checkmark.
class SelectionIndicator extends StatelessWidget {
  final bool selected;
  final double size;
  final Duration duration;

  const SelectionIndicator({
    super.key,
    required this.selected,
    this.size = 22,
    this.duration = const Duration(milliseconds: 160),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: duration,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? theme.colorScheme.primary : Colors.transparent,
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
              size: size * 0.64,
              color: theme.colorScheme.onPrimary,
            )
          : null,
    );
  }
}
