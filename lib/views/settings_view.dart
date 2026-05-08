import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';

import '../l10n/app_text_extension.dart';
import '../providers/enhanced_app_provider.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/app_page_header.dart';
import '../widgets/app_settings_group.dart';
import '../widgets/app_settings_tile.dart';
import 'appearance_settings_view.dart';
import 'password_tools_view.dart';
import 'security_settings_view.dart';
import 'settings/vault_health_view.dart';
import 'sync_settings_view.dart';
import 'templates/template_list_view.dart';
import 'release_note_view.dart';
import '../theme/app_design_tokens.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  Widget _buildHeroCard(BuildContext context) {
    return AppPageHeader(
      icon: Icons.settings_outlined,
      title: context.text( '\u8bbe\u7f6e\u4e2d\u5fc3', 'Settings Center'),
      subtitle: context.text('\u4e2a\u6027\u5316\u3001\u5b89\u5168\u3001\u5bc6\u7801\u5de5\u5177\u3001\u540c\u6b65\u4e0e\u6a21\u677f\u7ba1\u7406',
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
          const SizedBox(height: AppSpacing.lg),
          AdaptiveSection(
            maxWidth: AppSectionWidths.panel,
            child: AppSettingsGroup(
              children: [
                AppSettingsTile(
                  icon: Icons.palette_outlined,
                  title: context.text( '个性化与外观', 'Appearance'),
                  subtitle: context.text('设置主题颜色、暗黑模式及视觉风格',
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
                AppSettingsTile(
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
                AppSettingsTile(
                  icon: Icons.health_and_safety_outlined,
                  title: context.text( 'Vault 体检', 'Vault Health'),
                  subtitle: context.text('检查保险库安全状态和账号风险',
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
                AppSettingsTile(
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
                AppSettingsTile(
                  icon: Icons.password_outlined,
                  title: context.text( '密码工具', 'Password Tools'),
                  subtitle: context.text('生成高强度密码',
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
                AppSettingsTile(
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
                AppSettingsTile(
                  icon: Icons.info_outline,
                  title: l10n.aboutSecretRoy,
                  subtitle:
                      '${l10n.versionNumber} · ${context.text( '同步与安全增强更新', 'Enhanced Sync & Security')}',
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
        ],
      ),
    );
  }
}
