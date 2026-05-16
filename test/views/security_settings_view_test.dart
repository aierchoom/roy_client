import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:secret_roy/views/security_settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_auto_lock_service.dart';
import '../fakes/fake_biometric_auth_service.dart';
import '../fakes/fake_identity_service.dart';
import '../fakes/fake_sync_service.dart';
import '../sync/sync_server_test_harness.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  group('SecuritySettingsView', () {
    Future<void> pumpView(WidgetTester tester) async {
      final manager = ServiceManager.testable(
        secureStorageService: FakeSecureStorageService(),
        identityService: FakeIdentityService(),
        syncService: FakeSyncService(),
        autoLockService: FakeAutoLockService(),
        biometricService: FakeBiometricAuthService(),
        initialState: ServiceManagerState.unlocked,
      );
      ServiceManager.setInstanceForTesting(manager);
      addTearDown(ServiceManager.resetInstance);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const SecuritySettingsView(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('renders without crashing', (tester) async {
      await pumpView(tester);
      await tester.pumpAndSettle();

      expect(find.byType(SecuritySettingsView), findsOneWidget);
      expect(find.textContaining('安全'), findsWidgets);
    });

    testWidgets('shows auto lock section', (tester) async {
      await pumpView(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('自动锁定'), findsWidgets);
    });

    testWidgets('shows biometric section', (tester) async {
      await pumpView(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('生物识别'), findsWidgets);
    });
  });
}
