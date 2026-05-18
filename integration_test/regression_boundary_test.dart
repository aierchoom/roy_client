import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:secret_roy/services/service_manager.dart';

import 'support/smoke_test_helpers.dart';

/// QA 回归边界覆盖测试。
///
/// 覆盖手工回归中最高频、最高风险的操作路径：
/// 1. 账户删除确认流程
/// 2. 搜索过滤与清除
/// 3. 分类 tab 切换
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await ServiceManager.destroyForTesting();
  });

  tearDown(() async {
    await ServiceManager.destroyForTesting();
  });

  testWidgets('regression: delete account with confirmation', (tester) async {
    await configureSmokeSurface(tester);
    await launchAndUnlockSmokeApp(tester);

    const accountName = 'RegTest-Delete-Me';

    // Create an account.
    await createWebsiteAccount(
      tester,
      name: accountName,
      email: 'delete@example.com',
      website: 'https://delete.example.com',
      username: 'delete',
      password: 'Delete-Password-123!',
    );

    // Long-press the account tile to open context menu.
    final accountFinder = textContaining(accountName).first;
    await pumpUntilFound(tester, accountFinder);
    expect(accountFinder, findsAtLeastNWidgets(1));
    await tester.longPress(accountFinder);
    await tester.pumpAndSettle();

    // Tap delete in the bottom sheet.
    final sheetDelete = find.widgetWithText(ListTile, '删除');
    await pumpUntilFound(tester, sheetDelete);
    await tester.tap(sheetDelete);
    await tester.pumpAndSettle();

    // Confirm deletion in the AlertDialog.
    final dialogDelete = find.widgetWithText(TextButton, '删除');
    await pumpUntilFound(tester, dialogDelete);
    expect(dialogDelete, findsOneWidget);
    await tester.tap(dialogDelete);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify the account no longer appears.
    expect(find.text(accountName), findsNothing);
  });

  testWidgets('regression: search filtering and clear', (tester) async {
    await configureSmokeSurface(tester);
    await launchAndUnlockSmokeApp(tester);

    const accountName = 'RegTest-Search-Target';

    // Create a target account.
    await createWebsiteAccount(
      tester,
      name: accountName,
      email: 'search@example.com',
      website: 'https://search.example.com',
      username: 'search',
      password: 'Search-Password-123!',
    );

    // Activate search.
    await tapVisibleText(tester, '搜索');
    await tester.pumpAndSettle();

    // Enter a query that matches the target.
    final searchField = find.byWidgetPredicate((w) => w is SearchBar);
    await pumpUntilFound(tester, searchField);
    await tester.enterText(searchField, 'Search-Target');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(textContaining(accountName), findsAtLeastNWidgets(1));

    // Enter a query that matches nothing.
    await tester.enterText(searchField, 'NoSuchAccountXYZ');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text(accountName), findsNothing);

    // Clear search and verify target reappears.
    await tester.tap(find.byTooltip('清除'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(textContaining(accountName), findsAtLeastNWidgets(1));
  });

  testWidgets('regression: category tab switching', (tester) async {
    await configureSmokeSurface(tester);
    await launchAndUnlockSmokeApp(tester);

    // Default view should show the "全部" tab.
    expect(find.text('全部'), findsAtLeastNWidgets(1));

    // Switch to "2FA" tab.
    await tapVisibleText(tester, '2FA');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Switch back to "全部".
    await tapVisibleText(tester, '全部');
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
