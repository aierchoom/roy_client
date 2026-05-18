import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:secret_roy/main.dart' as app;
import 'package:secret_roy/services/service_manager.dart';

import 'support/smoke_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await ServiceManager.destroyForTesting();
  });

  testWidgets('regression: wrong password then correct password', (tester) async {
    await configureSmokeSurface(tester);

    // 先创建/解锁保险库，确保进入 returning-user 状态
    await launchAndUnlockSmokeApp(tester);

    // 禁用无密码模式，防止 UnlockView 自动解锁跳过密码输入
    await ServiceManager.instance.disableNoPasswordMode();

    // 正常锁定保险库
    await ServiceManager.instance.lock();
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
