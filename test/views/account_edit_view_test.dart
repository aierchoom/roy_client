import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/providers/enhanced_app_provider.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:secret_roy/views/accounts/account_edit_view.dart';

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

Future<void> _pumpAccountEditView(
  WidgetTester tester,
  Widget child, {
  EnhancedAppProvider? provider,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2000));
  final p = provider ?? _createTestProvider();
  // EditMetadataRow directly reads ServiceManager.instance.
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
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
}

void main() {
  group('AccountEditView', () {
    testWidgets('renders create form without crash', (tester) async {
      await _pumpAccountEditView(tester, const AccountEditView());
      expect(find.byType(AccountEditView), findsOneWidget);
    });

    testWidgets('renders edit form with initial account', (tester) async {
      final account = AccountItem(
        id: 'acc_1',
        name: 'Test Account',
        email: '',
        templateId: 'tpl_default',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
        syncStatus: SyncStatus.synchronized,
      );
      await _pumpAccountEditView(tester, AccountEditView(initial: account));
      expect(find.byType(AccountEditView), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Test Account'), findsOneWidget);
    });

    testWidgets('renders name TextField with initial value', (tester) async {
      final account = AccountItem(
        id: 'acc_1',
        name: 'Test Account',
        email: 'test@example.com',
        templateId: 'tpl_default',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
        syncStatus: SyncStatus.synchronized,
      );
      await _pumpAccountEditView(tester, AccountEditView(initial: account));
      expect(find.widgetWithText(TextField, 'Test Account'), findsOneWidget);
    });
  });
}
