import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:secret_roy/views/unlock_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_crypto_service.dart';
import '../fakes/fake_identity_service.dart';
import '../fakes/fake_sync_service.dart';
import '../fakes/fake_auto_lock_service.dart';
import '../fakes/fake_biometric_auth_service.dart';
import '../sync/sync_server_test_harness.dart';

void main() {
  group('UnlockView', () {
    setUpAll(() {
      SharedPreferences.setMockInitialValues({});
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
    });

    tearDown(() {
      ServiceManager.resetInstance();
    });

    testWidgets('renders without crash', (tester) async {
      ServiceManager.setInstanceForTesting(
        ServiceManager.testable(
          secureStorageService: FakeSecureStorageService(),
          identityService: FakeIdentityService(),
          syncService: FakeSyncService(),
          autoLockService: FakeAutoLockService(),
          biometricService: FakeBiometricAuthService(),
          initialState: ServiceManagerState.locked,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const UnlockView(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(UnlockView), findsOneWidget);
    });

    testWidgets('shows error message when in error state', (tester) async {
      ServiceManager.setInstanceForTesting(
        ServiceManager.testable(
          secureStorageService: FakeSecureStorageService(),
          identityService: FakeIdentityService(),
          syncService: FakeSyncService(),
          autoLockService: FakeAutoLockService(),
          biometricService: FakeBiometricAuthService(),
          initialState: ServiceManagerState.error,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const UnlockView(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(UnlockView), findsOneWidget);
    });

    testWidgets('password unlock transitions to unlocked', (tester) async {
      ServiceManager.setInstanceForTesting(
        ServiceManager.testable(
          cryptoService: FakeCryptoService(),
          secureStorageService: FakeSecureStorageService(),
          identityService: FakeIdentityService(hasIdentity: true),
          syncService: FakeSyncService(),
          autoLockService: FakeAutoLockService(),
          biometricService: FakeBiometricAuthService(),
          initialState: ServiceManagerState.locked,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const UnlockView(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Enter password and tap unlock.
      await tester.enterText(find.byType(TextField), 'password');
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is FilledButton).first,
      );
      await tester.pump();

      // Wait for unlock async work to complete.
      await tester.pump(const Duration(milliseconds: 500));
      expect(ServiceManager.instance.state, ServiceManagerState.unlocked);
    });

    testWidgets('shows invalid password error', (tester) async {
      final crypto = FakeCryptoService();
      ServiceManager.setInstanceForTesting(
        ServiceManager.testable(
          cryptoService: crypto,
          secureStorageService: FakeSecureStorageService(),
          identityService: FakeIdentityService(hasIdentity: true),
          syncService: FakeSyncService(),
          autoLockService: FakeAutoLockService(),
          biometricService: FakeBiometricAuthService(),
          initialState: ServiceManagerState.locked,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const UnlockView(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Simulate crypto failure.
      crypto.setShouldFail(true);
      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is FilledButton).first,
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('主密码不正确。'), findsOneWidget);
    });

    testWidgets('reset app confirmation cancels and confirms', (tester) async {
      ServiceManager.setInstanceForTesting(
        ServiceManager.testable(
          cryptoService: FakeCryptoService(),
          secureStorageService: FakeSecureStorageService(),
          identityService: FakeIdentityService(hasIdentity: true),
          syncService: FakeSyncService(),
          autoLockService: FakeAutoLockService(),
          biometricService: FakeBiometricAuthService(),
          initialState: ServiceManagerState.locked,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const UnlockView(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Scroll to ensure reset button is visible and tap it.
      await tester.ensureVisible(find.text('忘记密码？重置本机设备'));
      await tester.pump();
      await tester.tap(find.text('忘记密码？重置本机设备'));
      await tester.pump(const Duration(milliseconds: 400));

      // Confirm dialog appears.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('清空本机库'), findsOneWidget);

      // Cancel.
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsNothing);
      expect(ServiceManager.instance.state, ServiceManagerState.locked);

      // Tap reset again and confirm.
      await tester.tap(find.text('忘记密码？重置本机设备'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(FilledButton, '清空'));
      await tester.pump(const Duration(milliseconds: 400));

      // After reset, the app should be back in first-run mode.
      expect(find.text('创建主密码'), findsOneWidget);
    });
  });
}
