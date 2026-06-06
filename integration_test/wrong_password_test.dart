import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:secret_roy/views/unlock_view.dart';

import 'support/smoke_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('regression: wrong password then correct password', (tester) async {
    // Cleanup: dispose widget tree first, then destroy the service manager.
    // addTearDown callbacks run in reverse registration order, so the pump
    // registered second runs first, disposing the tree before destroy.
    addTearDown(() async {
      await ServiceManager.destroyForTesting();
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    await configureSmokeSurface(tester);

    // 先创建/解锁保险库，确保进入 returning-user 状态
    await launchAndUnlockSmokeApp(tester);

    // 禁用无密码模式
    await ServiceManager.instance.disableNoPasswordMode();

    // 锁定保险库
    await ServiceManager.instance.lock();

    // 显式渲染 UnlockView（不依赖 MaterialApp home 自动切换）
    // 注意：lock() 后不能先 pumpAndSettle，否则旧 HomeView 重建时其中的
    // FutureBuilder 会尝试访问已关闭的数据库，导致异常。
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        home: const UnlockView(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final passwordField = find.byType(TextField);
    await pumpUntilFound(tester, passwordField);

    // Enter wrong password and tap unlock.
    await tester.tap(passwordField);
    await tester.pumpAndSettle();
    await tester.enterText(passwordField, 'wrong-password');
    await tester.pumpAndSettle();

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
    await tester.tap(passwordField);
    await tester.pumpAndSettle();
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

    // 解锁成功后验证状态
    expect(ServiceManager.instance.state, ServiceManagerState.unlocked);
  });
}
