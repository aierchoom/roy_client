import 'package:flutter/material.dart';

List<TextSpan> highlightNumbers(
  String text,
  Color highlightColor, {
  TextStyle? baseStyle,
}) {
  final spans = <TextSpan>[];
  final regex = RegExp(r'(\d+)');
  var lastEnd = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(
        text: text.substring(lastEnd, match.start),
        style: baseStyle,
      ));
    }
    spans.add(TextSpan(
      text: match.group(0),
      style: baseStyle?.copyWith(
        color: highlightColor,
        fontWeight: FontWeight.w900,
      ),
    ));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastEnd),
      style: baseStyle,
    ));
  }
  return spans;
}
