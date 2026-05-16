import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/app_notification.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/providers/enhanced_app_provider.dart';
import 'package:secret_roy/providers/notification_provider.dart';
import 'package:secret_roy/services/notification_service.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:secret_roy/views/home/home_view.dart';
import 'package:secret_roy/views/home/layouts/home_view_desktop.dart';
import 'package:secret_roy/theme/app_design_tokens.dart';
import 'package:secret_roy/views/home/layouts/home_view_mobile.dart';
import 'package:secret_roy/widgets/app_nav_bar.dart';
import 'package:secret_roy/widgets/app_nav_rail.dart';

import '../fakes/fake_auto_lock_service.dart';
import '../fakes/fake_biometric_auth_service.dart';
import '../fakes/fake_identity_service.dart';
import '../fakes/fake_sync_service.dart';
import '../sync/sync_server_test_harness.dart';

class _FakeSecureStorageService2 extends FakeSecureStorageService {
  @override
  Future<List<AccountTemplate>> loadAllTemplates({bool includeDeleted = false}) async {
    return [];
  }

  @override
  Future<String> getDatabaseFilePath() async => '/tmp/test_vault.db';
}

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super(FakeSecureStorageService());

  @override
  Future<void> init() async {}

  @override
  Future<List<AppNotification>> generatePasswordExpiryNotifications({
    required List<AccountItem> accounts,
    required List<AccountTemplate> templates,
    int expiryDays = 90,
  }) async => [];

  @override
  Future<List<AppNotification>> generateWeakPasswordNotifications({
    required List<AccountItem> accounts,
    required List<AccountTemplate> templates,
    int strengthThreshold = 40,
  }) async => [];

  @override
  Future<void> scheduleDailyCheck({int hour = 9, int minute = 0}) async {}

  @override
  Future<void> cancelAllScheduled() async {}
}

EnhancedAppProvider _createTestProvider({FakeSecureStorageService? storage}) {
  final s = storage ?? _FakeSecureStorageService2();
  final manager = ServiceManager.testable(
    secureStorageService: s,
    identityService: FakeIdentityService(),
    syncService: FakeSyncService(),
    autoLockService: FakeAutoLockService(),
    biometricService: FakeBiometricAuthService(),
    initialState: ServiceManagerState.unlocked,
  );
  return EnhancedAppProvider(s, manager);
}

Future<void> _pumpHomeView(
  WidgetTester tester, {
  EnhancedAppProvider? appProvider,
  NotificationProvider? notificationProvider,
  Size surfaceSize = const Size(1200, 800),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final ap = appProvider ?? _createTestProvider();
  final np = notificationProvider ?? NotificationProvider(ap.serviceManager.storageService, _FakeNotificationService());
  ServiceManager.setInstanceForTesting(ap.serviceManager);
  addTearDown(ServiceManager.resetInstance);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        extensions: [AppVisualTokens.fromBrightness(Brightness.light)],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<EnhancedAppProvider>.value(value: ap),
          ChangeNotifierProvider<NotificationProvider>.value(value: np),
        ],
        child: const HomeView(),
      ),
    ),
  );
  // AccountListView uses Timer.periodic, so pumpAndSettle would hang.
  // Pump long enough for NotificationCenterView's health report future to complete.
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('HomeView', () {
    group('mobile layout (compact)', () {
      testWidgets('renders HomeViewMobile with bottom nav bar', (tester) async {
        await _pumpHomeView(tester, surfaceSize: const Size(390, 1200));
        expect(find.byType(HomeViewMobile), findsOneWidget);
        expect(find.byType(HomeViewDesktop), findsNothing);
        expect(find.byType(AppNavBar), findsOneWidget);
        expect(find.byType(AppNavRail), findsNothing);
      });

      testWidgets('nav bar contains all four destinations', (tester) async {
        await _pumpHomeView(tester, surfaceSize: const Size(390, 1200));
        expect(find.text('账户'), findsOneWidget);
        expect(find.text('搜索'), findsOneWidget);
        expect(find.text('通知'), findsOneWidget);
        expect(find.text('设置'), findsOneWidget);
      });

      testWidgets('tapping nav destinations switches tabs', (tester) async {
        await _pumpHomeView(tester, surfaceSize: const Size(390, 1200));

        // Default tab is accounts (empty state).
        expect(find.text('暂无条目'), findsOneWidget);

        // Tap Search.
        await tester.tap(find.text('搜索'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('搜索账户...'), findsOneWidget);

        // Tap Notifications.
        await tester.tap(find.text('通知'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('通知中心'), findsOneWidget);

        // Tap Settings.
        await tester.tap(find.text('设置'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('设置中心'), findsOneWidget);

        // Tap back to Accounts.
        await tester.tap(find.text('账户'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('暂无条目'), findsOneWidget);
      });

      testWidgets('double-tapping account tab toggles templates', (tester) async {
        await _pumpHomeView(tester, surfaceSize: const Size(390, 1200));
        expect(find.text('账户'), findsOneWidget);

        // First tap on accounts stays on accounts.
        await tester.tap(find.text('账户'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('账户'), findsOneWidget);

        // Second tap on accounts toggles to templates.
        await tester.tap(find.text('账户'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('模板'), findsOneWidget);

        // Third tap toggles back to accounts.
        await tester.tap(find.text('模板'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('账户'), findsOneWidget);
      });
    });

    group('desktop layout (expanded)', () {
      testWidgets('renders HomeViewDesktop with side nav rail', (tester) async {
        await _pumpHomeView(tester, surfaceSize: const Size(1400, 900));
        expect(find.byType(HomeViewDesktop), findsOneWidget);
        expect(find.byType(HomeViewMobile), findsNothing);
        expect(find.byType(AppNavRail), findsOneWidget);
        expect(find.byType(AppNavBar), findsNothing);
      });

      testWidgets('nav rail contains all four destinations', (tester) async {
        await _pumpHomeView(tester, surfaceSize: const Size(1400, 900));
        expect(find.text('账户'), findsOneWidget);
        expect(find.text('搜索'), findsOneWidget);
        expect(find.text('通知'), findsOneWidget);
        expect(find.text('设置'), findsOneWidget);
      });

      testWidgets('tapping nav rail destinations switches tabs', (tester) async {
        await _pumpHomeView(tester, surfaceSize: const Size(1400, 900));

        // Default tab is accounts.
        expect(find.text('暂无条目'), findsOneWidget);

        // Tap Search.
        await tester.tap(find.text('搜索'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('搜索账户...'), findsOneWidget);

        // Tap Notifications.
        await tester.tap(find.text('通知'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('通知中心'), findsOneWidget);

        // Tap Settings.
        await tester.tap(find.text('设置'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('设置中心'), findsOneWidget);
      });

      testWidgets('renders SecretRoy header in nav rail', (tester) async {
        await _pumpHomeView(tester, surfaceSize: const Size(1400, 900));
        expect(find.text('SecretRoy'), findsOneWidget);
        expect(find.text('安全库工作区'), findsOneWidget);
      });
    });

    group('empty state', () {
      testWidgets('shows empty state when no accounts exist', (tester) async {
        await _pumpHomeView(tester);
        expect(find.text('暂无条目'), findsOneWidget);
        expect(find.text('保险库中还没有任何内容，点击右下角按钮开始添加。'), findsOneWidget);
      });
    });

    group('with data', () {
      testWidgets('shows account in list after loading', (tester) async {
        final storage = FakeSecureStorageService();
        final account = AccountItem(
          id: 'acc_1',
          name: 'Test Account',
          email: 'test@example.com',
          templateId: 'builtin_generic_info',
          data: const {},
          createdAt: DateTime.now().millisecondsSinceEpoch,
          nameHlc: Hlc.zero('local'),
          emailHlc: Hlc.zero('local'),
          dataHlc: const {},
          syncStatus: SyncStatus.synchronized,
        );
        storage.accounts[account.id] = account;

        final provider = _createTestProvider(storage: storage);
        await _pumpHomeView(tester, appProvider: provider, surfaceSize: const Size(1400, 900));

        expect(find.textContaining('Test Account'), findsOneWidget);
      });

      testWidgets('search tab shows search bar and results panel', (tester) async {
        final storage = FakeSecureStorageService();
        final account = AccountItem(
          id: 'acc_1',
          name: 'Searchable Account',
          email: '',
          templateId: 'builtin_generic_info',
          data: const {},
          createdAt: DateTime.now().millisecondsSinceEpoch,
          nameHlc: Hlc.zero('local'),
          emailHlc: Hlc.zero('local'),
          dataHlc: const {},
          syncStatus: SyncStatus.synchronized,
        );
        storage.accounts[account.id] = account;

        final provider = _createTestProvider(storage: storage);
        await _pumpHomeView(tester, appProvider: provider, surfaceSize: const Size(1400, 900));

        await tester.tap(find.text('搜索'));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('搜索账户...'), findsOneWidget);
        expect(find.text('最近使用'), findsOneWidget);
        expect(find.textContaining('Searchable Account'), findsOneWidget);
      });

      testWidgets('notification tab renders health checks when no explicit notifications', (tester) async {
        await _pumpHomeView(tester, surfaceSize: const Size(1400, 900));
        await tester.tap(find.text('通知'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('通知中心'), findsOneWidget);
        expect(find.text('Vault 体检'), findsOneWidget);
      });
    });

    group('search button presence', () {
      testWidgets('search destination is present on mobile', (tester) async {
        await _pumpHomeView(tester, surfaceSize: const Size(400, 800));
        expect(find.text('搜索'), findsOneWidget);
      });

      testWidgets('search destination is present on desktop', (tester) async {
        await _pumpHomeView(tester, surfaceSize: const Size(1400, 900));
        expect(find.text('搜索'), findsOneWidget);
      });
    });
  });
}
