import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/totp_service.dart';
import 'package:secret_roy/providers/enhanced_app_provider.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:secret_roy/views/accounts/account_list_view.dart';

import '../fakes/fake_identity_service.dart';
import '../fakes/fake_sync_service.dart';
import '../fakes/fake_auto_lock_service.dart';
import '../fakes/fake_biometric_auth_service.dart';
import '../sync/sync_server_test_harness.dart';

EnhancedAppProvider _createTestProvider() {
  final storage = FakeSecureStorageService();
  final manager = ServiceManager.testable(
    secureStorageService: storage,
    identityService: FakeIdentityService(),
    syncService: FakeSyncService(),
    autoLockService: FakeAutoLockService(),
    biometricService: FakeBiometricAuthService(),
    initialState: ServiceManagerState.unlocked,
  );
  return EnhancedAppProvider(storage, manager);
}

Future<void> _pumpAccountListView(
  WidgetTester tester,
  Widget child, {
  EnhancedAppProvider? provider,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2000));
  final p = provider ?? _createTestProvider();
  ServiceManager.setInstanceForTesting(p.serviceManager);
  addTearDown(ServiceManager.resetInstance);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: ChangeNotifierProvider<EnhancedAppProvider>.value(
        value: p,
        child: child,
      ),
    ),
  );
  // AccountListView uses Timer.periodic, so pumpAndSettle would hang.
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('AccountListView', () {
    testWidgets('renders empty state', (tester) async {
      await _pumpAccountListView(tester, const AccountListView());
      expect(find.byType(AccountListView), findsOneWidget);
    });

    testWidgets('renders list with accounts', (tester) async {
      final storage = FakeSecureStorageService();
      final account = AccountItem(
        id: 'acc_1',
        name: 'My Account',
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
      final manager = ServiceManager.testable(
        secureStorageService: storage,
        identityService: FakeIdentityService(),
        syncService: FakeSyncService(),
        autoLockService: FakeAutoLockService(),
        biometricService: FakeBiometricAuthService(),
        initialState: ServiceManagerState.unlocked,
      );
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpAccountListView(tester, const AccountListView(), provider: provider);
      expect(find.textContaining('My Account'), findsOneWidget);
    });

    testWidgets('filters by category tabs', (tester) async {
      final storage = FakeSecureStorageService();
      final account = AccountItem(
        id: 'acc_1',
        name: 'My Account',
        email: '',
        templateId: 'builtin_generic_info',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
        syncStatus: SyncStatus.synchronized,
      );
      final totp = TotpCredential(
        id: 'totp_1',
        label: 'My TOTP',
        config: const TotpConfig(
          issuer: 'Example',
          account: 'user@example.com',
          secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
          algorithm: TotpAlgorithm.sha1,
          digits: 6,
          period: 30,
        ),
        linkedAccountIds: const [],
        createdAt: DateTime.now().millisecondsSinceEpoch,
        labelHlc: Hlc.zero('local'),
        configHlc: Hlc.zero('local'),
        linksHlc: Hlc.zero('local'),
        syncStatus: SyncStatus.synchronized,
      );
      storage.accounts[account.id] = account;
      storage.totpCredentials[totp.id] = totp;

      final manager = ServiceManager.testable(
        secureStorageService: storage,
        identityService: FakeIdentityService(),
        syncService: FakeSyncService(),
        autoLockService: FakeAutoLockService(),
        biometricService: FakeBiometricAuthService(),
        initialState: ServiceManagerState.unlocked,
      );
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpAccountListView(tester, const AccountListView(), provider: provider);

      // Account visible under "All" tab.
      expect(find.textContaining('My Account'), findsOneWidget);

      // Switch to "2FA" tab.
      await tester.tap(find.text('2FA'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('My Account'), findsNothing);
      expect(find.textContaining('My TOTP'), findsOneWidget);

      // Switch back to "All" tab.
      await tester.tap(find.text('全部'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('My Account'), findsOneWidget);
    });

    testWidgets('shows delete confirmation and removes account on confirm', (tester) async {
      final storage = FakeSecureStorageService();
      final account = AccountItem(
        id: 'acc_1',
        name: 'My Account',
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

      final manager = ServiceManager.testable(
        secureStorageService: storage,
        identityService: FakeIdentityService(),
        syncService: FakeSyncService(),
        autoLockService: FakeAutoLockService(),
        biometricService: FakeBiometricAuthService(),
        initialState: ServiceManagerState.unlocked,
      );
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpAccountListView(tester, const AccountListView(), provider: provider);

      expect(find.textContaining('My Account'), findsOneWidget);

      // Long-press account tile to open context menu.
      await tester.longPress(find.textContaining('My Account'));
      await tester.pump(const Duration(milliseconds: 400));

      // Tap delete in bottom sheet.
      await tester.tap(find.widgetWithText(ListTile, '删除'));
      await tester.pump(const Duration(milliseconds: 400));

      // Confirm dialog should appear.
      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap delete in confirmation dialog.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, '删除'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // Account should no longer be visible.
      expect(find.textContaining('My Account'), findsNothing);
    });

    testWidgets('shows empty state for category with no items', (tester) async {
      final storage = FakeSecureStorageService();
      final account = AccountItem(
        id: 'acc_1',
        name: 'My Account',
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

      final manager = ServiceManager.testable(
        secureStorageService: storage,
        identityService: FakeIdentityService(),
        syncService: FakeSyncService(),
        autoLockService: FakeAutoLockService(),
        biometricService: FakeBiometricAuthService(),
        initialState: ServiceManagerState.unlocked,
      );
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpAccountListView(tester, const AccountListView(), provider: provider);

      // Switch to "2FA" tab where there are no TOTP credentials.
      await tester.tap(find.text('2FA'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('My Account'), findsNothing);
      expect(find.text('暂无 2FA'), findsOneWidget);
    });
  });
}
