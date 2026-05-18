import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/smoke_test_helpers.dart';

/// PC 桌面端核心冒烟测试
///
/// 运行前请确保 SECRETROY_TEST_DIR 环境变量已设置，以避免污染真实用户数据。
/// 脚本参考: tool/run_integration_tests.ps1
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'PC smoke: create vault, add account, search, navigate settings',
    (tester) async {
      await configureSmokeSurface(tester);
      await launchAndUnlockSmokeApp(tester);

      await createWebsiteAccount(
        tester,
        name: 'AutoTest-Google',
        email: 'autotest@example.com',
        website: 'https://accounts.google.com',
        username: 'autotest@example.com',
        password: 'AutoTest-Password-123!',
      );

      await tapVisibleText(tester, '搜索');
      await tester.enterText(
        find.byWidgetPredicate((widget) => widget is SearchBar),
        'AutoTest',
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data?.contains('AutoTest-Google') ?? false),
        ),
        findsAtLeastNWidgets(1),
      );

      await tapVisibleText(tester, '设置');
      await pumpUntilFound(tester, find.text('设置中心'));
      expect(find.text('个性化与外观'), findsOneWidget);
      expect(find.text('安全设置'), findsOneWidget);
    },
  );
}
