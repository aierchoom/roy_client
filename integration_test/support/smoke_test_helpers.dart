import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/main.dart' as app;

Future<void> configureSmokeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Finder textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

Finder textFieldContainingLabel(String labelPart) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        (widget.decoration?.labelText?.contains(labelPart) ?? false),
  );
}

Future<void> enterTextByLabel(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = textFieldByLabel(label);
  await pumpUntilFound(tester, field, timeout: const Duration(seconds: 3));
  if (field.evaluate().isEmpty) {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      for (var i = 0; i < 20 && field.evaluate().isEmpty; i++) {
        await tester.drag(scrollables.last, const Offset(0, -420));
        await tester.pumpAndSettle();
      }
    }
  }
  await pumpUntilFound(tester, field);
  expect(field, findsOneWidget);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> launchAndUnlockSmokeApp(
  WidgetTester tester, {
  String password = '123ckets',
}) async {
  app.main();
  await tester.pumpAndSettle();

  final passwordField = textFieldContainingLabel('密码');
  await pumpUntilFound(tester, passwordField);
  expect(passwordField, findsOneWidget);

  await tester.enterText(passwordField, password);
  await tester.pumpAndSettle();

  final createText = find.text('创建保险库');
  final unlockText = find.text('解锁');
  final buttonDeadline = DateTime.now().add(const Duration(seconds: 5));
  while (createText.evaluate().isEmpty &&
      unlockText.evaluate().isEmpty &&
      DateTime.now().isBefore(buttonDeadline)) {
    await tester.pump(const Duration(milliseconds: 300));
  }

  if (createText.evaluate().isNotEmpty) {
    await tester.tap(createText.last);
  } else if (unlockText.evaluate().isNotEmpty) {
    await tester.tap(unlockText);
  } else {
    throw StateError('未找到创建保险库或解锁按钮');
  }

  await pumpUntilFound(tester, find.text('账户中心'));
  expect(find.text('账户中心'), findsOneWidget);
}

Future<void> createWebsiteAccount(
  WidgetTester tester, {
  required String name,
  required String email,
  required String website,
  required String username,
  required String password,
}) async {
  await tester.tap(find.byTooltip('新建账户'));
  await tester.pumpAndSettle();

  final accountNameField = textFieldByLabel('账户名称');
  await pumpUntilFound(tester, accountNameField);
  expect(accountNameField, findsOneWidget);

  await tester.enterText(accountNameField, name);
  await tester.pumpAndSettle();

  await tester.enterText(textFieldContainingLabel('邮箱'), email);
  await tester.pumpAndSettle();

  await enterTextByLabel(tester, '网站', website);
  await enterTextByLabel(tester, '账号', username);
  await enterTextByLabel(tester, '密码', password);

  await tester.tap(find.byTooltip('保存账户'));
  await tester.pumpAndSettle(const Duration(seconds: 2));

  expect(find.text(name), findsAtLeastNWidgets(1));
}

Future<void> tapVisibleText(
  WidgetTester tester,
  String text, {
  bool last = false,
}) async {
  final finder = find.text(text);
  await pumpUntilFound(tester, finder);
  expect(finder, findsAtLeastNWidgets(1));
  await tester.tap(last ? finder.last : finder.first);
  await tester.pumpAndSettle();
}

Future<void> tapBack(WidgetTester tester) async {
  final back = find.byTooltip('返回');
  await pumpUntilFound(tester, back, timeout: const Duration(seconds: 3));
  expect(back, findsAtLeastNWidgets(1));
  await tester.tap(back.first);
  await tester.pumpAndSettle();
}
