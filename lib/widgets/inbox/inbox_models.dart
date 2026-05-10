import 'package:flutter/material.dart';

/// Severity level used to drive color/icon theming for inbox items.
enum InboxSeverity { critical, warning, info, success }

/// Action descriptor for an inbox item. Supports both single-target
/// deep-links and multi-target list navigation.
class InboxAction {
  final String? targetId;
  final List<String> targetIds;
  final VoidCallback? onTap;

  const InboxAction({
    this.targetId,
    this.targetIds = const [],
    this.onTap,
  });
}

/// Unified interface for any item that can appear in an inbox.
abstract class InboxItem {
  String get id;
  String get categoryKey;
  InboxSeverity get severity;
  String get title;
  String get subtitle;
  InboxAction? get action;
  bool get isUnread;
}
