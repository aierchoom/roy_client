import 'package:flutter/material.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:secret_roy/sync/lan_sync_coordinator.dart';
import 'package:secret_roy/sync/lan_sync_session.dart';
import 'package:secret_roy/theme/theme.dart';

/// Host 端 LAN 同步冲突处理 Sheet。
///
/// 当 [coordinator] 进入 [LanSyncPhase.resolving] 时，通过
/// [LanSyncConflictOverlay] 自动弹出。用户确认后调用 [onConfirm]，
/// 取消后调用 [onCancel]。
class LanSyncConflictSheet extends StatelessWidget {
  final LanSyncCoordinator coordinator;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const LanSyncConflictSheet({
    super.key,
    required this.coordinator,
    this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final preview = coordinator.currentConflictPreview ?? [];
    final conflictCount = preview.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '数据冲突 ($conflictCount)',
                    style: AppTextStyles.headlineSmall(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '以下字段在两端同时被修改，已按时间戳自动保留最新值：',
              style: AppTextStyles.bodyMedium(context)?.copyWith(
                color: AppTextStyles.bodyMedium(context)?.color?.withAlpha(180),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: preview.length,
                itemBuilder: (context, index) {
                  final item = preview[index];
                  final accountId = item['account_id'] as String? ?? '?';
                  final fieldKey = item['field_key'] as String? ?? '?';
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.merge_type, size: 20),
                    title: Text(
                      '$accountId · $fieldKey',
                      style: AppTextStyles.bodySmall(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onCancel?.call();
                    },
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm?.call();
                    },
                    child: const Text('确认'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 监听 LAN 同步状态并自动弹出冲突 Sheet 的 Overlay Widget。
///
/// 应放置在页面顶层（如 [HomeView] 或 [Scaffold]  body 中），
/// 通过 [ServiceManager] 获取 [LanSyncCoordinator]。
class LanSyncConflictOverlay extends StatefulWidget {
  const LanSyncConflictOverlay({super.key});

  @override
  State<LanSyncConflictOverlay> createState() => _LanSyncConflictOverlayState();
}

class _LanSyncConflictOverlayState extends State<LanSyncConflictOverlay> {
  bool _sheetShown = false;

  @override
  Widget build(BuildContext context) {
    final serviceManager = ServiceManager.instance;
    final coordinator = serviceManager.lanSyncCoordinator;

    // Use a post-frame callback to show sheet outside of build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowSheet(coordinator);
    });

    return const SizedBox.shrink();
  }

  void _maybeShowSheet(LanSyncCoordinator coordinator) {
    if (!mounted) return;

    final phase = coordinator.currentSession?.phase;
    final isResolving = phase == LanSyncPhase.resolving;

    if (isResolving && !_sheetShown) {
      _sheetShown = true;
      _showConflictSheet(coordinator);
    } else if (!isResolving && _sheetShown) {
      _sheetShown = false;
    }
  }

  void _showConflictSheet(LanSyncCoordinator coordinator) {
    final sessionId = coordinator.currentSession?.sessionId;
    if (sessionId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => LanSyncConflictSheet(
        coordinator: coordinator,
        onConfirm: () async {
          await coordinator.hostCommit(sessionId);
          if (mounted) setState(() => _sheetShown = false);
        },
        onCancel: () async {
          await coordinator.abort();
          if (mounted) setState(() => _sheetShown = false);
        },
      ),
    );
  }
}
