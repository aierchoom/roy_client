import 'package:flutter/material.dart';

import '../services/service_manager.dart';
import '../utils/relative_time_formatter.dart';

class EditMetadataRow extends StatelessWidget {
  final int? editedAt;
  final String? editedBy;

  const EditMetadataRow({
    super.key,
    this.editedAt,
    this.editedBy,
  });

  @override
  Widget build(BuildContext context) {
    if (editedAt == null && editedBy == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final timeText = RelativeTimeFormatter.format(context, editedAt);
    final deviceId = editedBy;
    final currentDeviceId = ServiceManager.instance.identityService.deviceId;
    final alias = ServiceManager.instance.deviceAliasService.resolve(
      context,
      deviceId,
      currentDeviceId: currentDeviceId,
    );

    final parts = <String>[];
    if (timeText.isNotEmpty) parts.add(timeText);
    if (alias.isNotEmpty) parts.add(alias);
    if (parts.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onLongPress: () {
        final absolute = RelativeTimeFormatter.formatAbsolute(context, editedAt);
        final fullDevice = deviceId ?? '';
        final message = <String>[];
        if (absolute.isNotEmpty) message.add(absolute);
        if (fullDevice.isNotEmpty) message.add(fullDevice);
        if (message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message.join('\n')),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: Row(
        children: [
          Icon(
            Icons.history,
            size: 13,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
          ),
          const SizedBox(width: 5),
          Text(
            parts.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
