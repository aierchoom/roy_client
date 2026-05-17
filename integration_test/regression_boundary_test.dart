import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:secret_roy/main.dart' as app;
import 'package:secret_roy/services/service_manager.dart';

import 'support/smoke_test_helpers.dart';

/// QA 回归边界覆盖测试。
///
/// 覆盖手工回归中最高频、最高风险的操作路径：
/// 1. 账户删除确认流程
/// 2. 搜索过滤与清除
/// 3. 分类 tab 切换
/// 4. 错误密码解锁 → 正确密码解锁
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
    final accountFinder = find.text(accountName).first;
    await pumpUntilFound(tester, accountFinder);
    expect(accountFinder, findsAtLeastNWidgets(1));
    await tester.longPress(accountFinder);
    await tester.pumpAndSettle();

    // Tap delete in the bottom sheet.
    await tapVisibleText(tester, '删除');
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
    expect(find.text(accountName), findsAtLeastNWidgets(1));

    // Enter a query that matches nothing.
    await tester.enterText(searchField, 'NoSuchAccountXYZ');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text(accountName), findsNothing);

    // Clear search and verify target reappears.
    await tester.tap(find.byTooltip('清除'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text(accountName), findsAtLeastNWidgets(1));
  });

  testWidgets('regression: category tab switching', (tester) async {
    await configureSmokeSurface(tester);
    await launchAndUnlockSmokeApp(tester);

    // Default view should show the "全部" tab.
    expect(find.text('全部'), findsAtLeastNWidgets(1));

    // Switch to "账户" tab.
    await tapVisibleText(tester, '账户');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Switch to "安全笔记" tab.
    await tapVisibleText(tester, '安全笔记');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Switch to "2FA" tab.
    await tapVisibleText(tester, '2FA');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Switch back to "全部".
    await tapVisibleText(tester, '全部');
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('regression: wrong password then correct password', (tester) async {
    await configureSmokeSurface(tester);

    // 先创建/解锁保险库，确保进入 returning-user 状态（否则 first-run 下任何密码都会直接创建）
    await launchAndUnlockSmokeApp(tester);

    // 锁定保险库：替换单例为一个 locked 状态的新实例，避免 lock() 在 Windows 上的文件系统竞态
    final lockedManager = ServiceManager.testable(initialState: ServiceManagerState.locked);
    ServiceManager.setInstanceForTesting(lockedManager);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 重新启动应用，应显示 UnlockView（按钮为「解锁」）
    app.main();
    await tester.pumpAndSettle();

    // Wait for the password field.
    final passwordField = find.byType(TextField);
    await pumpUntilFound(tester, passwordField);

    // Enter wrong password and tap unlock.
    await tester.enterText(passwordField, 'wrong-password');
    await tester.pumpAndSettle();

    // FilledButton.icon 的 factory 实际创建的是 private class _FilledButtonWithIcon，
    // find.byType(FilledButton) 因严格 runtimeType 匹配而失效，改用 is 检查。
    final submitButton = find.ancestor(
      of: find.text('解锁'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    await pumpUntilFound(tester, submitButton);
    expect(submitButton, findsOneWidget);
    await tester.tap(submitButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Expect error message.
    expect(find.text('主密码不正确。'), findsOneWidget);

    // Enter correct password and tap submit again.
    await tester.enterText(passwordField, '123ckets');
    await tester.pumpAndSettle();

    final submitButton2 = find.ancestor(
      of: find.text('解锁'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    await pumpUntilFound(tester, submitButton2);
    expect(submitButton2, findsOneWidget);
    await tester.tap(submitButton2);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Should reach the home screen.
    await pumpUntilFound(tester, find.text('保险库'));
    expect(find.text('保险库'), findsOneWidget);
  });
}
