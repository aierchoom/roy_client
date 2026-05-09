import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_text_extension.dart';
import '../providers/theme_provider.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/app_hero_card.dart';
import '../widgets/app_option_tile.dart';
import '../widgets/section_card.dart';

class AppearanceSettingsView extends StatelessWidget {
  const AppearanceSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<AppThemeProvider>();

    final colorPresets = AppBrandColors.presets;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.text( '个性化与外观', 'Appearance'),
        ),
      ),
      body: AdaptivePage(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            AppHeroCard(
              icon: Icons.palette_outlined,
              title: context.text('视觉个性化',
                'Visual Customization',
              ),
              subtitle: context.text('统一设置主题模式、配色与深色细节，让整套界面保持舒适且有识别度。',
                'Shape theme mode, accent color, and dark-mode details in one place.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: context.text( '主题模式', 'Theme Mode'),
              subtitle: context.text('选择跟随系统、固定浅色或固定深色。',
                'Choose system, fixed light mode, or fixed dark mode.',
              ),
              child: Column(
                children: [
                  AppOptionTile(
                    title: context.text('跟随系统',
                      'Follow System',
                    ),
                    subtitle: context.text('跟随设备当前的浅色/深色设定',
                      'Matches the current device setting',
                    ),
                    icon: Icons.brightness_auto_outlined,
                    selected: themeProvider.themeMode == ThemeMode.system,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                  ),
                  const Divider(height: 1),
                  AppOptionTile(
                    title: context.text('浅色模式',
                      'Light Mode',
                    ),
                    subtitle: context.text('使用更明亮、干净的界面显示',
                      'Uses a brighter and cleaner interface',
                    ),
                    icon: Icons.light_mode_outlined,
                    selected: themeProvider.themeMode == ThemeMode.light,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                  ),
                  const Divider(height: 1),
                  AppOptionTile(
                    title: context.text('深色模式',
                      'Dark Mode',
                    ),
                    subtitle: context.text('更适合夜间使用和低光环境',
                      'Better for night use and low-light environments',
                    ),
                    icon: Icons.dark_mode_outlined,
                    selected: themeProvider.themeMode == ThemeMode.dark,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (themeProvider.themeMode != ThemeMode.light)
              SectionCard(
                title: context.text('深色模式优化',
                  'Dark Mode Enhancement',
                ),
                subtitle: context.text('对深色模式做更进一步的显示细节调整。',
                  'Fine-tune how the dark interface behaves.',
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    context.text('极致黑 (OLED)',
                      'True Black (OLED)',
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    context.text('在深色模式下使用更纯的黑色背景，适合 OLED 屏幕。',
                      'Uses a deeper black background, especially suited to OLED displays.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: themeProvider.trueBlack,
                  onChanged: themeProvider.setTrueBlack,
                ),
              ),
            if (themeProvider.themeMode != ThemeMode.light)
              const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: context.text( '主题颜色', 'Accent Color'),
              subtitle: context.text('选一个主色，让按钮、导航和状态标识更有整体感。',
                'Choose the primary color for buttons, navigation, and highlights.',
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: colorPresets.map((color) {
                    final isSelected =
                        themeProvider.colorSeed.toARGB32() == color.toARGB32();
                    return _ColorPresetButton(
                      color: color,
                      selected: isSelected,
                      onTap: () => themeProvider.setColorSeed(color),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPresetButton extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorPresetButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? theme.colorScheme.onSurface : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withAlpha(AppAlphas.strong),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: selected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}
