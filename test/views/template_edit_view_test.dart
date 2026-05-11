import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/views/templates/template_edit_view.dart';
import 'package:secret_roy/widgets/green_add_button.dart';

Future<void> _pumpTemplateEditView(
  WidgetTester tester,
  Widget child,
) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2000));
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TemplateEditView', () {
    testWidgets('renders create form without crash', (tester) async {
      await _pumpTemplateEditView(tester, const TemplateEditView());

      expect(find.byType(TemplateEditView), findsOneWidget);
      expect(find.byType(TextField), findsAtLeastNWidgets(2));
    });

    testWidgets('shows snackbar when title is empty', (tester) async {
      await _pumpTemplateEditView(tester, const TemplateEditView());

      // Tap save FAB (the one with check icon).
      await tester.tap(find.widgetWithIcon(GreenAddButton, Icons.check));
      await tester.pump();

      expect(find.text('请输入模板标题'), findsOneWidget);
    });

    testWidgets('shows snackbar when no fields are added', (tester) async {
      await _pumpTemplateEditView(tester, const TemplateEditView());

      // Enter title.
      await tester.enterText(find.byType(TextField).first, 'Test Template');
      await tester.pump();

      // Tap save FAB.
      await tester.tap(find.widgetWithIcon(GreenAddButton, Icons.check));
      await tester.pump();

      expect(find.text('请至少添加一个字段。'), findsOneWidget);
    });

    testWidgets('adds field and saves template successfully', (tester) async {
      AccountTemplate? result;

      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await Navigator.push<AccountTemplate>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TemplateEditView(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open TemplateEditView.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter title.
      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, 'My Template');
      await tester.pump();

      // Scroll down to reveal the add-field button inside ListView.
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      // Tap add-field button (the small GreenAddButton with add icon).
      final addButton = find.byWidgetPredicate(
        (w) => w is GreenAddButton && w.small,
      );
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // FieldEditorDialog should appear.
      expect(find.byType(AlertDialog), findsOneWidget);

      // Enter field label.
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '字段名称',
        ),
        'Username',
      );
      await tester.pump();

      // Save field.
      await tester.tap(find.widgetWithText(FilledButton, '保存字段'));
      await tester.pumpAndSettle();

      // Dialog should close; scroll to bring field list into viewport.
      expect(find.text('新增字段'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.textContaining('Username'), findsAtLeastNWidgets(1));

      // Tap save FAB.
      await tester.tap(find.widgetWithIcon(GreenAddButton, Icons.check));
      await tester.pumpAndSettle();

      // Should pop with a template.
      expect(result, isNotNull);
      expect(result!.title, 'My Template');
      expect(result!.fields.length, 1);
      expect(result!.fields.first.label, 'Username');
    });

    testWidgets('pre-populates fields in edit mode', (tester) async {
      final template = AccountTemplate(
        templateId: 'tpl_1',
        title: 'Existing',
        subTitle: 'Sub',
        iconCodePoint: null,
        category: TemplateCategory.login,
        fields: [
          AccountField(
            fieldKey: 'username',
            label: 'Username',
            attributes: const AccountFieldAttributes(
              type: AccountFieldType.text,
            ),
          ),
        ],
        isCustom: true,
        serverVersion: 1,
        syncStatus: SyncStatus.synchronized,
      );

      await _pumpTemplateEditView(tester, TemplateEditView(initial: template));

      expect(find.widgetWithText(TextField, 'Existing'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
    });

    testWidgets('cancel returns null', (tester) async {
      AccountTemplate? result = const AccountTemplate(
        templateId: 'dummy',
        title: '',
        subTitle: '',
        category: TemplateCategory.custom,
        fields: [],
        isCustom: true,
        serverVersion: 0,
        syncStatus: SyncStatus.pendingPush,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await Navigator.push<AccountTemplate>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TemplateEditView(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap back button to pop without saving.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}
