import 'package:flutter/material.dart';

import '../../theme/app_design_tokens.dart';
import '../../widgets/app_page_header.dart';

/// Data holder for a single metric chip.
class MetricData {
  final String value;
  final String label;
  final Color color;

  const MetricData({
    required this.value,
    required this.label,
    required this.color,
  });
}

/// Hero section with an icon, title, subtitle and a row of metric chips.
class InboxHeroMetrics extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<MetricData> metrics;
  final Widget? trailing;

  const InboxHeroMetrics({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.metrics = const [],
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(
      icon: icon,
      title: title,
      subtitle: subtitle,
      metrics: metrics
          .map((m) => _MetricChip(value: m.value, label: m.label, color: m.color))
          .toList(),
      trailing: trailing,
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MetricChip({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(AppAlphas.tint),
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: color,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withAlpha(190),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
