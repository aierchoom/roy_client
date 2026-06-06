import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/providers/enhanced_app_provider.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:secret_roy/views/templates/template_edit_view.dart';
import 'package:secret_roy/views/templates/template_list_view.dart';

import '../fakes/fake_auto_lock_service.dart';
import '../fakes/fake_biometric_auth_service.dart';
import '../fakes/fake_identity_service.dart';
import '../fakes/fake_sync_service.dart';
import '../sync/sync_server_test_harness.dart';

EnhancedAppProvider _createTestProvider({FakeSecureStorageService? storage}) {
  final s = storage ?? FakeSecureStorageService();
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

Future<void> _pumpTemplateListView(
  WidgetTester tester,
  Widget child, {
  EnhancedAppProvider? provider,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2000));
  final p = provider ?? _createTestProvider();
  ServiceManager.setInstanceForTesting(p.serviceManager);
  addTearDown(ServiceManager.resetInstance);
  await tester.pumpWidget(
    ChangeNotifierProvider<EnhancedAppProvider>.value(
      value: p,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AccountItem _makeAccount({
  required String id,
  required String name,
  required String templateId,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return AccountItem(
    id: id,
    name: name,
    email: '',
    templateId: templateId,
    data: const {},
    createdAt: now,
    nameHlc: Hlc.zero('test'),
    emailHlc: Hlc.zero('test'),
    dataHlc: const {},
    syncStatus: SyncStatus.synchronized,
  );
}

AccountTemplate _makeTemplate({
  required String id,
  required String title,
  bool isCustom = true,
  List<AccountField> fields = const [],
}) {
  return AccountTemplate(
    templateId: id,
    title: title,
    subTitle: '',
    category: TemplateCategory.custom,
    fields: fields,
    isCustom: isCustom,
  );
}

void _mockClipboard() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') return null;
        if (call.method == 'Clipboard.getData') return null;
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TemplateListView', () {
    testWidgets('renders empty custom section and builtin templates', (
      tester,
    ) async {
      await _pumpTemplateListView(tester, const TemplateListView());
      expect(find.text('还没有自定义模板'), findsOneWidget);
      expect(find.text('自定义模板'), findsOneWidget);
      expect(find.text('内置模板'), findsAtLeastNWidgets(1));
      expect(find.text('模板管理'), findsOneWidget);
    });

    testWidgets('renders hero card stats correctly', (tester) async {
      final storage = FakeSecureStorageService();
      storage.templates['custom_1'] = _makeTemplate(
        id: 'custom_1',
        title: 'C1',
      );
      storage.accounts['acc_1'] = _makeAccount(
        id: 'acc_1',
        name: 'A1',
        templateId: 'custom_1',
      );
      final provider = _createTestProvider(storage: storage);
      await _pumpTemplateListView(
        tester,
        const TemplateListView(),
        provider: provider,
      );

      // basicAccountTemplates has 9 items + 1 custom = 10 total
      expect(find.textContaining('10 个模板'), findsOneWidget);
      expect(find.textContaining('1 个自定义'), findsOneWidget);
      expect(find.textContaining('1 个在用'), findsOneWidget);
    });

    testWidgets('renders custom template card with actions', (tester) async {
      final storage = FakeSecureStorageService();
      storage.templates['custom_1'] = _makeTemplate(
        id: 'custom_1',
        title: 'My Custom',
        fields: [
          const AccountField(
            fieldKey: 'f1',
            label: 'Username',
            attributes: AccountFieldAttributes(type: AccountFieldType.text),
          ),
        ],
      );
      final provider = _createTestProvider(storage: storage);
      await _pumpTemplateListView(
        tester,
        const TemplateListView(),
        provider: provider,
      );

      expect(find.text('MC'), findsOneWidget);
      expect(find.textContaining('My Custom'), findsOneWidget);
    });

    testWidgets('renders builtin template card without actions', (
      tester,
    ) async {
      await _pumpTemplateListView(tester, const TemplateListView());
      expect(find.text('内置模板'), findsAtLeastNWidgets(1));
    });

    testWidgets('navigates to TemplateEditView when add button tapped', (
      tester,
    ) async {
      await _pumpTemplateListView(tester, const TemplateListView());
      await tester.tap(find.text('新建模板'));
      await tester.pumpAndSettle();
      expect(find.byType(TemplateEditView), findsOneWidget);
    });

    testWidgets('navigates to TemplateEditView when custom card tapped', (
      tester,
    ) async {
      final storage = FakeSecureStorageService();
      storage.templates['custom_1'] = _makeTemplate(
        id: 'custom_1',
        title: 'C1',
      );
      final provider = _createTestProvider(storage: storage);
      await _pumpTemplateListView(
        tester,
        const TemplateListView(),
        provider: provider,
      );

      await tester.tap(find.text('C1'));
      await tester.pumpAndSettle();
      expect(find.byType(TemplateEditView), findsOneWidget);
    });

    testWidgets('deletes custom template after confirmation', (tester) async {
      final storage = FakeSecureStorageService();
      storage.templates['custom_1'] = _makeTemplate(
        id: 'custom_1',
        title: 'C1',
      );
      final provider = _createTestProvider(storage: storage);
      await _pumpTemplateListView(
        tester,
        const TemplateListView(),
        provider: provider,
      );

      // Badge text for 'C1' is 'C1' itself.
      expect(find.text('C1'), findsOneWidget);

      await tester.tap(find.byTooltip('删除模板'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('删除模板'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(find.text('C1'), findsNothing);
    });

    testWidgets('shows snackbar when deleting template in use', (tester) async {
      final storage = FakeSecureStorageService();
      storage.templates['custom_1'] = _makeTemplate(
        id: 'custom_1',
        title: 'C1',
      );
      storage.accounts['acc_1'] = _makeAccount(
        id: 'acc_1',
        name: 'A1',
        templateId: 'custom_1',
      );
      final provider = _createTestProvider(storage: storage);
      await _pumpTemplateListView(
        tester,
        const TemplateListView(),
        provider: provider,
      );

      await tester.tap(find.byTooltip('删除模板'));
      await tester.pumpAndSettle();

      expect(find.textContaining('仍被 1 个账户使用'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('imports templates successfully', (tester) async {
      final provider = _createTestProvider();
      await _pumpTemplateListView(
        tester,
        const TemplateListView(),
        provider: provider,
      );

      await tester.tap(find.text('导入模板'));
      await tester.pumpAndSettle();

      final json = encodeTemplateExport([
        _makeTemplate(id: 'imp_1', title: 'Imported'),
      ]);

      await tester.enterText(find.byType(TextField), json);
      await tester.pump();

      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();

      expect(find.textContaining('成功导入 1 个模板'), findsOneWidget);
      expect(find.textContaining('Imported'), findsOneWidget);
    });

    testWidgets('shows snackbar on invalid import JSON', (tester) async {
      final provider = _createTestProvider();
      await _pumpTemplateListView(
        tester,
        const TemplateListView(),
        provider: provider,
      );

      await tester.tap(find.text('导入模板'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'not json');
      await tester.pump();

      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();

      expect(find.textContaining('导入失败'), findsOneWidget);
    });

    testWidgets('batch export dialog disables export when nothing selected', (
      tester,
    ) async {
      final storage = FakeSecureStorageService();
      storage.templates['custom_1'] = _makeTemplate(
        id: 'custom_1',
        title: 'C1',
      );
      final provider = _createTestProvider(storage: storage);
      await _pumpTemplateListView(
        tester,
        const TemplateListView(),
        provider: provider,
      );

      await tester.tap(find.text('导出模板'));
      await tester.pumpAndSettle();

      expect(find.text('批量导出模板'), findsOneWidget);

      // Uncheck the only template.
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      final exportButton = find.widgetWithText(FilledButton, '导出');
      expect(tester.widget<FilledButton>(exportButton).enabled, false);

      // Cancel dialog.
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });

    testWidgets('batch export dialog exports selected templates', (
      tester,
    ) async {
      final storage = FakeSecureStorageService();
      storage.templates['custom_1'] = _makeTemplate(
        id: 'custom_1',
        title: 'C1',
      );
      final provider = _createTestProvider(storage: storage);
      await _pumpTemplateListView(
        tester,
        const TemplateListView(),
        provider: provider,
      );

      _mockClipboard();
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.tap(find.text('导出模板'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '导出'));
      await tester.pumpAndSettle();

      expect(find.textContaining('已复制到剪贴板'), findsOneWidget);
    });
  });
}
