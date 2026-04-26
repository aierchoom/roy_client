import 'package:flutter/material.dart';

const Color kGreenAddButtonColor = Color(0xFF1FA463);

class GreenAddButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;
  final Object? heroTag;
  final bool small;
  final IconData icon;

  const GreenAddButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.heroTag,
    this.small = false,
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    if (small) {
      return FloatingActionButton.small(
        heroTag: heroTag,
        onPressed: onPressed,
        tooltip: tooltip,
        backgroundColor: kGreenAddButtonColor,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: Icon(icon),
      );
    }

    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: kGreenAddButtonColor,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      child: Icon(icon),
    );
  }
}
