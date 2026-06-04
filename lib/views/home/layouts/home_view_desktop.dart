import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_text_extension.dart';
import '../../../providers/enhanced_app_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../theme/app_design_tokens.dart';
import '../../../widgets/app_nav_rail.dart';

class HomeViewDesktop extends StatelessWidget {
  final int selectedIndex;
  final bool accountShowTemplates;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> pages;

  const HomeViewDesktop({
    super.key,
    required this.selectedIndex,
    required this.accountShowTemplates,
    required this.onDestinationSelected,
    required this.pages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncBadgeCount = context
        .watch<EnhancedAppProvider>()
        .localSyncChanges
        .length;
    final conflictBadgeCount = context
        .watch<EnhancedAppProvider>()
        .conflictCount;
    final notificationBadgeCount = context
        .watch<NotificationProvider>()
        .unreadCount;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppNavRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                destinations: [
                  AppNavDestination(
                    icon: accountShowTemplates
                        ? Icons.dashboard_customize_outlined
                        : Icons.inventory_2_outlined,
                    selectedIcon: accountShowTemplates
                        ? Icons.dashboard_customize
                        : Icons.inventory_2,
                    label: accountShowTemplates
                        ? context.text('模板', 'Templates')
                        : context.text('账户', 'Accounts'),
                    description: accountShowTemplates
                        ? context.text('管理账户模板', 'Manage account templates')
                        : context.text('查看全部账户', 'Browse your vault'),
                    badgeLabel: selectedIndex == 0
                        ? (accountShowTemplates ? '账户' : '模板')
                        : null,
                  ),
                  AppNavDestination(
                    icon: Icons.search_outlined,
                    selectedIcon: Icons.search,
                    label: context.text('搜索', 'Search'),
                    description: context.text('快速定位账户', 'Search and jump fast'),
                  ),
                  AppNavDestination(
                    icon: Icons.edit_note_outlined,
                    selectedIcon: Icons.edit_note,
                    label: context.text('随手记', 'Notes'),
                    description: context.text(
                      '轻量 Markdown 速记',
                      'Light Markdown notes',
                    ),
                  ),
                  AppNavDestination(
                    icon: Icons.notifications_outlined,
                    selectedIcon: Icons.notifications,
                    label: context.text('通知', 'Alerts'),
                    description: context.text(
                      '密码安全提醒与通知',
                      'Password security reminders',
                    ),
                    badgeCount:
                        notificationBadgeCount +
                        syncBadgeCount +
                        conflictBadgeCount,
                  ),
                  AppNavDestination(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: context.text('设置', 'Settings'),
                    description: context.text(
                      '主题、安全与模板',
                      'Theme, security, templates',
                    ),
                  ),
                ],
                header: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(14),
                    borderRadius: BorderRadius.circular(AppRadii.panel),
                    border: Border.all(
                      color: theme.colorScheme.primary.withAlpha(34),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppRadii.button),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.lock_outline,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SecretRoy',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.text('安全库工作区', 'Secure workspace'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                footer: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                      82,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.panel),
                  ),
                  child: Text(
                    context.text(
                      '导航保持稳定，高频工具入口不再强调悬浮装饰。',
                      'Navigation stays stable, with less decorative chrome around frequent tools.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                  child: IndexedStack(index: selectedIndex, children: pages),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
