import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';

import '../providers/enhanced_app_provider.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/app_page_header.dart';
import 'appearance_settings_view.dart';
import 'password_tools_view.dart';
import 'security_settings_view.dart';
import 'settings/vault_health_view.dart';
import 'sync_settings_view.dart';
import 'templates/template_list_view.dart';
import 'release_note_view.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  String _text(BuildContext context, String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  Widget _buildHeroCard(BuildContext context) {
    return AppPageHeader(
      icon: Icons.settings_outlined,
      title: _text(context, '\u8bbe\u7f6e\u4e2d\u5fc3', 'Settings Center'),
      subtitle: _text(
        context,
        '\u4e2a\u6027\u5316\u3001\u5b89\u5168\u3001\u5bc6\u7801\u5de5\u5177\u3001\u540c\u6b65\u4e0e\u6a21\u677f\u7ba1\u7406',
        'Visuals, security, password tools, sync, and templates',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final customTemplateCount = context
        .watch<EnhancedAppProvider>()
        .customTemplates
        .length;

    return AdaptivePage(
      desktopMaxWidth: 1200,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
        children: [
          AdaptiveSection(
            maxWidth: AppSectionWidths.hero,
            child: _buildHeroCard(context),
          ),
          const SizedBox(height: 16),
          AdaptiveSection(
            maxWidth: AppSectionWidths.panel,
            child: Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: _text(context, '个性化与外观', 'Appearance'),
                    subtitle: _text(
                      context,
                      '设置主题颜色、暗黑模式及视觉风格',
                      'Theme colors, dark mode, and visual style',
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AppearanceSettingsView(),
                        ),
                      );
                    },
                  ),
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    thickness: 0.5,
                  ),
                  _SettingsTile(
                    icon: Icons.security_outlined,
                    title: l10n.securitySettingsTitle,
                    subtitle: l10n.securitySettingsSubtitle,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SecuritySettingsView(),
                        ),
                      );
                    },
                  ),
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    thickness: 0.5,
                  ),
                  _SettingsTile(
                    icon: Icons.health_and_safety_outlined,
                    title: _text(context, 'Vault 体检', 'Vault Health'),
                    subtitle: _text(
                      context,
                      '检查保险库安全状态和账号风险',
                      'Check vault security status and account risks',
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const VaultHealthView(),
                        ),
                      );
                    },
                  ),
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    thickness: 0.5,
                  ),
                  _SettingsTile(
                    icon: Icons.sync_outlined,
                    title: l10n.dataSyncTitle,
                    subtitle: l10n.dataSyncSubtitle,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SyncSettingsView(),
                        ),
                      );
                    },
                  ),
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    thickness: 0.5,
                  ),
                  _SettingsTile(
                    icon: Icons.password_outlined,
                    title: _text(context, '密码工具', 'Password Tools'),
                    subtitle: _text(
                      context,
                      '生成高强度密码',
                      'Generate strong passwords',
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PasswordToolsView(),
                        ),
                      );
                    },
                  ),
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    thickness: 0.5,
                  ),
                  _SettingsTile(
                    icon: Icons.view_list_outlined,
                    title: l10n.templatesTitle,
                    subtitle: customTemplateCount == 0
                        ? '管理自定义模板和字段'
                        : '已创建 $customTemplateCount 个自定义模板',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const TemplateListView(),
                        ),
                      );
                    },
                  ),
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    thickness: 0.5,
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title: l10n.aboutSecretRoy,
                    subtitle:
                        '${l10n.versionNumber} · ${_text(context, '同步与安全增强更新', 'Enhanced Sync & Security')}',
                    showChevron: false,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ReleaseNoteView(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showChevron;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withAlpha(100),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: showChevron
          ? Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : null,
      onTap: onTap,
    );
  }
}
