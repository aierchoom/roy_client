import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/providers/enhanced_app_provider.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:secret_roy/sync/crdt_merge_engine.dart';
import 'package:secret_roy/views/conflict_inbox_view.dart';

import '../fakes/fake_auto_lock_service.dart';
import '../fakes/fake_biometric_auth_service.dart';
import '../fakes/fake_identity_service.dart';
import '../fakes/fake_sync_service.dart';
import '../sync/sync_server_test_harness.dart';

void main() {
  group('ConflictInboxView', () {
    Future<void> pumpView(WidgetTester tester, {EnhancedAppProvider? provider}) async {
      final p = provider ?? EnhancedAppProvider(
        FakeSecureStorageService(),
        ServiceManager.testable(
          secureStorageService: FakeSecureStorageService(),
          identityService: FakeIdentityService(),
          syncService: FakeSyncService(),
          autoLockService: FakeAutoLockService(),
          biometricService: FakeBiometricAuthService(),
          initialState: ServiceManagerState.unlocked,
        ),
      );
      ServiceManager.setInstanceForTesting(p.serviceManager);
      addTearDown(ServiceManager.resetInstance);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: ChangeNotifierProvider<EnhancedAppProvider>.value(
            value: p,
            child: const ConflictInboxView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('renders empty state when no conflicts', (tester) async {
      await pumpView(tester);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.byType(ConflictInboxView), findsOneWidget);
      expect(find.textContaining('没有冲突记录'), findsOneWidget);
    });

    testWidgets('renders conflict groups', (tester) async {
      final storage = FakeSecureStorageService();
      final account = AccountItem(
        id: 'acc_1',
        name: 'GitHub',
        email: 'user@example.com',
        templateId: 'builtin_website',
        data: const {'password': 'old'},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
        syncStatus: SyncStatus.pendingPush,
      );
      storage.accounts['acc_1'] = account;
      storage.conflictLogs['acc_1'] = [
        ConflictLog(
          accountId: 'acc_1',
          fieldKey: 'password',
          fieldValue: 'old',
          hlc: Hlc.zero('local'),
          savedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

      final manager = ServiceManager.testable(
        secureStorageService: storage,
        identityService: FakeIdentityService(),
        syncService: FakeSyncService(),
        autoLockService: FakeAutoLockService(),
        biometricService: FakeBiometricAuthService(),
        initialState: ServiceManagerState.unlocked,
      );
      final provider = EnhancedAppProvider(storage, manager);

      await pumpView(tester, provider: provider);
      await tester.pumpAndSettle();

      expect(find.text('GitHub'), findsOneWidget);
    });
  });
}
