import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:secret_roy/views/home/home_view.dart';
import 'package:secret_roy/views/unlock_view.dart';

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

    // 禁用无密码模式
    await ServiceManager.instance.disableNoPasswordMode();

    // 锁定保险库
    await ServiceManager.instance.lock();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 显式渲染 UnlockView（不依赖 MaterialApp home 自动切换）
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
    await tester.pumpAndSettle();

    final passwordField = find.byType(TextField);
    await pumpUntilFound(tester, passwordField);

    // Enter wrong password and tap unlock.
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

    // 解锁成功后显式切换到 HomeView 验证
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
        home: const HomeView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('保险库'), findsOneWidget);
  });
}
