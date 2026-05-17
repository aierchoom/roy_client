import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/smoke_test_helpers.dart';

/// 主题与布局集成测试。
///
/// 覆盖：
/// 1. 暗色主题切换验证
/// 2. 移动端布局（小尺寸 surface）基本渲染验证
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('theme: switch to dark mode and verify', (tester) async {
    await configureSmokeSurface(tester);
    await launchAndUnlockSmokeApp(tester);

    // Navigate to Settings.
    await tapVisibleText(tester, '设置');
    await pumpUntilFound(tester, find.text('设置中心'));

    // Navigate to Appearance Settings.
    await tapVisibleText(tester, '个性化与外观');
    await pumpUntilFound(tester, find.text('视觉个性化'));

    // Verify default theme mode options are present.
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);

    // Tap "Dark Mode".
    await tapVisibleText(tester, '深色模式');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify dark-mode-specific option appears (True Black / OLED).
    expect(find.text('极致黑 (OLED)'), findsOneWidget);

    // Verify the UI remains functional by navigating back.
    await tapBack(tester);
    await pumpUntilFound(tester, find.text('设置中心'));

    // Return to home and verify basic rendering still works.
    await tapVisibleText(tester, '账户');
    await pumpUntilFound(tester, find.text('保险库'));
    expect(find.text('保险库'), findsAtLeastNWidgets(1));
  });

  testWidgets('layout: mobile compact surface renders correctly', (tester) async {
    await configureSmokeSurface(tester);
    // 覆盖为 compact 手机尺寸，验证移动端布局
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.binding.handleMetricsChanged();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();

    await launchAndUnlockSmokeApp(tester);

    // Verify core home elements render on small surface.
    await pumpUntilFound(tester, find.text('保险库'));
    expect(find.text('保险库'), findsAtLeastNWidgets(1));

    // Verify category filter bar renders.
    expect(find.text('全部'), findsAtLeastNWidgets(1));
    expect(find.text('2FA'), findsAtLeastNWidgets(1));

    // Verify bottom navigation or action area renders.
    expect(find.byTooltip('新建'), findsAtLeastNWidgets(1));

    // Verify settings navigation works on compact layout.
    await tapVisibleText(tester, '设置');
    await pumpUntilFound(tester, find.text('设置中心'));
    expect(find.text('设置中心'), findsOneWidget);
  });
}
