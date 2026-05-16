import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/providers/enhanced_app_provider.dart';
import 'package:secret_roy/providers/notification_provider.dart';
import 'package:secret_roy/providers/theme_provider.dart';
import 'package:secret_roy/services/notification_service.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:secret_roy/views/appearance_settings_view.dart';
import 'package:secret_roy/views/password_tools_view.dart';
import 'package:secret_roy/views/release_note_view.dart';
import 'package:secret_roy/views/security_settings_view.dart';
import 'package:secret_roy/views/settings/notification_settings_view.dart';
import 'package:secret_roy/views/settings_view.dart';
import 'package:secret_roy/views/sync_settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_service_manager.dart';
import '../sync/sync_server_test_harness.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  group('SettingsView', () {
    Future<void> _pumpSubject(WidgetTester tester) async {
      final manager = createFakeServiceManager();
      ServiceManager.setInstanceForTesting(manager);
      addTearDown(ServiceManager.resetInstance);

      final fakeStorage = FakeSecureStorageService();
      final prefs = await SharedPreferences.getInstance();
      final themeProvider = AppThemeProvider(prefs);
      final notificationProvider = NotificationProvider(
        fakeStorage,
        NotificationService(fakeStorage),
      );
      final appProvider = EnhancedAppProvider(fakeStorage, manager);

      addTearDown(() {
        themeProvider.dispose();
        notificationProvider.dispose();
        appProvider.dispose();
      });

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: notificationProvider),
            ChangeNotifierProvider.value(value: appProvider),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: const SettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders without crashing', (tester) async {
      await _pumpSubject(tester);
      expect(find.byType(SettingsView), findsOneWidget);
      expect(find.textContaining('设置中心'), findsOneWidget);
    });

    testWidgets('shows all setting tiles', (tester) async {
      await _pumpSubject(tester);
      expect(find.text('个性化与外观'), findsOneWidget);
      expect(find.text('安全设置'), findsOneWidget);
      expect(find.text('数据同步'), findsOneWidget);
      expect(find.text('通知设置'), findsOneWidget);
      expect(find.text('密码工具'), findsOneWidget);
      expect(find.textContaining('关于 SecretRoy'), findsOneWidget);
    });

    testWidgets(
      'tapping appearance navigates to AppearanceSettingsView with theme options',
      (tester) async {
        await _pumpSubject(tester);
        await tester.tap(find.text('个性化与外观'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(AppearanceSettingsView), findsOneWidget);
        expect(find.text('跟随系统'), findsOneWidget);
        expect(find.text('浅色模式'), findsOneWidget);
        expect(find.text('深色模式'), findsOneWidget);

        await tester.tap(find.text('深色模式'));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(AppearanceSettingsView));
        final themeProvider = Provider.of<AppThemeProvider>(
          context,
          listen: false,
        );
        expect(themeProvider.themeMode, ThemeMode.dark);
      },
    );

    testWidgets(
      'tapping security navigates to SecuritySettingsView with password change entry',
      (tester) async {
        await _pumpSubject(tester);
        await tester.tap(find.text('安全设置'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(SecuritySettingsView), findsOneWidget);
        expect(find.textContaining('主密码管理'), findsOneWidget);
        expect(find.text('修改主密码'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping sync navigates to SyncSettingsView with server config',
      (tester) async {
        await _pumpSubject(tester);
        await tester.tap(find.text('数据同步'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(SyncSettingsView), findsOneWidget);
        expect(find.text('服务器地址'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping notification navigates to NotificationSettingsView',
      (tester) async {
        await _pumpSubject(tester);
        await tester.tap(find.text('通知设置'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(NotificationSettingsView), findsOneWidget);
      },
    );

    testWidgets(
      'tapping password tools navigates to PasswordToolsView',
      (tester) async {
        await _pumpSubject(tester);
        await tester.tap(find.text('密码工具'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(PasswordToolsView), findsOneWidget);
      },
    );

    testWidgets(
      'tapping about navigates to ReleaseNoteView',
      (tester) async {
        await _pumpSubject(tester);
        await tester.tap(find.textContaining('关于 SecretRoy'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(ReleaseNoteView), findsOneWidget);
      },
    );
  });
}
