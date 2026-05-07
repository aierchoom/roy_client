import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/app_hero_card.dart';
import '../widgets/app_option_tile.dart';
import '../widgets/section_card.dart';

class AppearanceSettingsView extends StatelessWidget {
  const AppearanceSettingsView({super.key});

  String _text(BuildContext context, String zh, String en) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<AppThemeProvider>();

    final colorPresets = AppBrandColors.presets;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _text(context, '\u4e2a\u6027\u5316\u4e0e\u5916\u89c2', 'Appearance'),
        ),
      ),
      body: AdaptivePage(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            AppHeroCard(
              icon: Icons.palette_outlined,
              title: _text(
                context,
                '\u89c6\u89c9\u4e2a\u6027\u5316',
                'Visual Customization',
              ),
              subtitle: _text(
                context,
                '\u7edf\u4e00\u8bbe\u7f6e\u4e3b\u9898\u6a21\u5f0f\u3001\u914d\u8272\u4e0e\u6df1\u8272\u7ec6\u8282\uff0c\u8ba9\u6574\u5957\u754c\u9762\u4fdd\u6301\u8212\u9002\u4e14\u6709\u8bc6\u522b\u5ea6\u3002',
                'Shape theme mode, accent color, and dark-mode details in one place.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: _text(context, '\u4e3b\u9898\u6a21\u5f0f', 'Theme Mode'),
              subtitle: _text(
                context,
                '\u9009\u62e9\u8ddf\u968f\u7cfb\u7edf\u3001\u56fa\u5b9a\u6d45\u8272\u6216\u56fa\u5b9a\u6df1\u8272\u3002',
                'Choose system, fixed light mode, or fixed dark mode.',
              ),
              child: Column(
                children: [
                  AppOptionTile(
                    title: _text(
                      context,
                      '\u8ddf\u968f\u7cfb\u7edf',
                      'Follow System',
                    ),
                    subtitle: _text(
                      context,
                      '\u8ddf\u968f\u8bbe\u5907\u5f53\u524d\u7684\u6d45\u8272/\u6df1\u8272\u8bbe\u5b9a',
                      'Matches the current device setting',
                    ),
                    icon: Icons.brightness_auto_outlined,
                    selected: themeProvider.themeMode == ThemeMode.system,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                  ),
                  const Divider(height: 1),
                  AppOptionTile(
                    title: _text(
                      context,
                      '\u6d45\u8272\u6a21\u5f0f',
                      'Light Mode',
                    ),
                    subtitle: _text(
                      context,
                      '\u4f7f\u7528\u66f4\u660e\u4eae\u3001\u5e72\u51c0\u7684\u754c\u9762\u663e\u793a',
                      'Uses a brighter and cleaner interface',
                    ),
                    icon: Icons.light_mode_outlined,
                    selected: themeProvider.themeMode == ThemeMode.light,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                  ),
                  const Divider(height: 1),
                  AppOptionTile(
                    title: _text(
                      context,
                      '\u6df1\u8272\u6a21\u5f0f',
                      'Dark Mode',
                    ),
                    subtitle: _text(
                      context,
                      '\u66f4\u9002\u5408\u591c\u95f4\u4f7f\u7528\u548c\u4f4e\u5149\u73af\u5883',
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
                title: _text(
                  context,
                  '\u6df1\u8272\u6a21\u5f0f\u4f18\u5316',
                  'Dark Mode Enhancement',
                ),
                subtitle: _text(
                  context,
                  '\u5bf9\u6df1\u8272\u6a21\u5f0f\u505a\u66f4\u8fdb\u4e00\u6b65\u7684\u663e\u793a\u7ec6\u8282\u8c03\u6574\u3002',
                  'Fine-tune how the dark interface behaves.',
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    _text(
                      context,
                      '\u6781\u81f4\u9ed1 (OLED)',
                      'True Black (OLED)',
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _text(
                      context,
                      '\u5728\u6df1\u8272\u6a21\u5f0f\u4e0b\u4f7f\u7528\u66f4\u7eaf\u7684\u9ed1\u8272\u80cc\u666f\uff0c\u9002\u5408 OLED \u5c4f\u5e55\u3002',
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
              title: _text(context, '\u4e3b\u9898\u989c\u8272', 'Accent Color'),
              subtitle: _text(
                context,
                '\u9009\u4e00\u4e2a\u4e3b\u8272\uff0c\u8ba9\u6309\u94ae\u3001\u5bfc\u822a\u548c\u72b6\u6001\u6807\u8bc6\u66f4\u6709\u6574\u4f53\u611f\u3002',
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
