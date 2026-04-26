import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'providers/enhanced_app_provider.dart';
import 'providers/theme_provider.dart';
import 'services/service_manager.dart';
import 'views/home/home_view.dart';
import 'views/password_tools_view.dart';
import 'views/security_settings_view.dart';
import 'views/sync_settings_view.dart';
import 'views/unlock_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await ServiceManager.instance.initialize();

  runApp(SecretRoyApp(prefs: prefs));
}

class SecretRoyApp extends StatefulWidget {
  final SharedPreferences prefs;

  const SecretRoyApp({super.key, required this.prefs});

  @override
  State<SecretRoyApp> createState() => _SecretRoyAppState();
}

class _SecretRoyAppState extends State<SecretRoyApp> {
  final _serviceManager = ServiceManager.instance;

  @override
  void initState() {
    super.initState();
    _serviceManager.setupLifecycleObserver();
  }

  @override
  void dispose() {
    _serviceManager.disposeLifecycleObserver();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _serviceManager),
        ChangeNotifierProvider(
          create: (_) => EnhancedAppProvider(ServiceManager.instance.storageService, ServiceManager.instance),
        ),
        ChangeNotifierProvider(create: (_) => AppThemeProvider(widget.prefs)),
      ],
      child: Consumer2<ServiceManager, AppThemeProvider>(
        builder: (context, serviceManager, themeProvider, _) {
          return MaterialApp(
            title: 'SecretRoy',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh'), Locale('en')],
            locale: const Locale('zh'),
            theme: _buildLightTheme(themeProvider.colorSeed),
            darkTheme: _buildDarkTheme(themeProvider.colorSeed, themeProvider.trueBlack),
            themeMode: themeProvider.themeMode,
            home: serviceManager.state == ServiceManagerState.unlocked ? const HomeView() : const UnlockView(),
            routes: {
              '/unlock': (context) => const UnlockView(),
              '/home': (context) => const HomeView(),
              '/password-tools': (context) => const PasswordToolsView(),
              '/security': (context) => const SecuritySettingsView(),
              '/sync': (context) => const SyncSettingsView(),
            },
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme(Color seed) {
    final colorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: GoogleFonts.notoSansScTextTheme(ThemeData.light().textTheme).copyWith(
        titleLarge: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
      ),
      scaffoldBackgroundColor: Color.alphaBlend(colorScheme.primary.withAlpha(18), colorScheme.surfaceContainerLow),
      canvasColor: Color.alphaBlend(colorScheme.primary.withAlpha(18), colorScheme.surfaceContainerLow),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: GoogleFonts.notoSansSc(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardColor: colorScheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.notoSansSc(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
        contentTextStyle: GoogleFonts.notoSansSc(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: GoogleFonts.notoSansSc(color: colorScheme.onInverseSurface, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant.withAlpha(120), thickness: 0.8, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withAlpha(100),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        labelStyle: GoogleFonts.notoSansSc(fontWeight: FontWeight.w500),
        floatingLabelStyle: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600, color: colorScheme.primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: GoogleFonts.notoSansSc(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.notoSansSc(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        selectedLabelTextStyle: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  ThemeData _buildDarkTheme(Color seed, bool trueBlack) {
    // Boost saturation for blue seeds to avoid 'muddy' dark modes
    Color activeSeed = seed;
    final hsv = HSVColor.fromColor(seed);
    if (hsv.saturation < 0.4 && hsv.hue > 180 && hsv.hue < 260) {
      activeSeed = hsv.withSaturation(0.5).toColor();
    }
    final colorScheme = ColorScheme.fromSeed(seedColor: activeSeed, brightness: Brightness.dark);

    final bgColor = trueBlack ? Colors.black : Color.alphaBlend(colorScheme.primary.withAlpha(18), colorScheme.surfaceContainerLow);
    final cardColor = trueBlack ? const Color(0xFF0D1012) : colorScheme.surface;
    final inputColor = trueBlack ? const Color(0xFF0A0C0E) : colorScheme.surfaceContainerHighest;

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: GoogleFonts.notoSansScTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
      ),
      scaffoldBackgroundColor: bgColor,
      canvasColor: bgColor,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: GoogleFonts.notoSansSc(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.notoSansSc(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
        contentTextStyle: GoogleFonts.notoSansSc(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        modalBackgroundColor: cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: GoogleFonts.notoSansSc(color: colorScheme.onInverseSurface, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant.withAlpha(110), thickness: 0.8, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        labelStyle: GoogleFonts.notoSansSc(fontWeight: FontWeight.w500),
        floatingLabelStyle: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600, color: colorScheme.primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: GoogleFonts.notoSansSc(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        selectedLabelTextStyle: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
