import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/smoke_test_helpers.dart';

/// PC desktop broader smoke coverage.
///
/// This stays deliberately shallow: each major workspace area gets one real
/// interaction path so regressions surface early without turning smoke into
/// a slow exhaustive suite.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PC smoke: full workspace workflows', (tester) async {
    await configureSmokeSurface(tester);
    await launchAndUnlockSmokeApp(tester);

    const originalAccountName = 'AutoTest-Full-GitHub';
    const editedAccountName = 'AutoTest-Full-GitHub-Edited';
    const accountEmail = 'full-smoke@example.com';
    const totpLabel = 'AutoTest 2FA';
    const templateName = 'AutoTest 模板';

    await createWebsiteAccount(
      tester,
      name: originalAccountName,
      email: accountEmail,
      website: 'https://github.com',
      username: accountEmail,
      password: 'Full-Smoke-Password-123!',
    );

    // Edit the account from its preview screen.
    await tester.tap(find.text(originalAccountName).first);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('预览账户'));
    expect(find.text('预览账户'), findsOneWidget);

    await tester.tap(find.byTooltip('编辑账户'));
    await tester.pumpAndSettle();
    await enterTextByLabel(tester, '账户名称', editedAccountName);
    await tester.tap(find.byTooltip('保存账户'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text(editedAccountName), findsAtLeastNWidgets(1));

    // Create a TOTP item and link it to the edited account.
    await tapVisibleText(tester, '2FA');
    await tapVisibleText(tester, '新增');
    await enterTextByLabel(tester, '名称', totpLabel);
    await enterTextByLabel(
      tester,
      '密钥 / otpauth URI',
      'otpauth://totp/SecretRoy:$accountEmail?secret=JBSWY3DPEHPK3PXP&issuer=SecretRoy',
    );
    await tapVisibleText(tester, editedAccountName);
    await tester.tap(find.byTooltip('保存').first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text(totpLabel), findsAtLeastNWidgets(1));
    expect(find.text(editedAccountName), findsAtLeastNWidgets(1));

    // Password tools: open generator, keep a generated result.
    await tapVisibleText(tester, '设置');
    await pumpUntilFound(tester, find.text('设置中心'));
    await tapVisibleText(tester, '密码工具');
    await pumpUntilFound(tester, find.text('密码工具'));
    await tapVisibleText(tester, '打开生成器');
    await pumpUntilFound(tester, find.text('密码生成器'));
    await tapVisibleText(tester, '保留结果');
    await pumpUntilFound(tester, find.text('最近一次结果'));
    expect(find.text('最近一次结果'), findsOneWidget);

    await tapBack(tester);
    await pumpUntilFound(tester, find.text('设置中心'));

    // Vault health should calculate against the unlocked test vault.
    await tapVisibleText(tester, 'Vault 体检');
    await pumpUntilFound(tester, find.text('Vault 体检'));
    await pumpUntilFound(tester, find.textContaining('体检时间'));
    expect(find.textContaining('体检时间'), findsOneWidget);

    await tapBack(tester);
    await pumpUntilFound(tester, find.text('设置中心'));

    // Template manager: create a minimal custom template with one field.
    await tapVisibleText(tester, '模板管理');
    await pumpUntilFound(tester, find.text('模板中心'));
    await tester.tap(find.byTooltip('新建模板'));
    await tester.pumpAndSettle();

    await enterTextByLabel(tester, '标题', templateName);
    await enterTextByLabel(tester, '副标题', 'PC smoke custom template');
    await tester.tap(find.byTooltip('添加字段'));
    await tester.pumpAndSettle();
    await enterTextByLabel(tester, '字段名称', 'Smoke Field');
    await enterTextByLabel(tester, '字段标识', 'smoke_field');
    await tapVisibleText(tester, '保存字段');
    await pumpUntilFound(tester, find.text('Smoke Field'));
    expect(find.text('Smoke Field'), findsAtLeastNWidgets(1));

    await tester.tap(find.byTooltip('保存模板'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await pumpUntilFound(tester, find.text(templateName));
    expect(find.text(templateName), findsAtLeastNWidgets(1));
  });
}
