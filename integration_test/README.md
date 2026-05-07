# SecretRoy PC 自动化测试（Windows 桌面端）

> 目标：让非技术 QA 也能一键跑测试，开发人员维护测试用例，人工只补充硬件/多设备场景。

---

## 快速开始

1. 确保已安装 Flutter SDK 并执行过 `flutter pub get`。
2. 在 PowerShell 中执行：

```powershell
.\tool\run_integration_tests.cmd
```

脚本会自动：
- 生成临时测试数据目录（不会碰你的真实保险库）
- 依次运行 `integration_test/*.dart`
- 输出每个用例的通过/失败状态
- 最后清理临时数据

---

## 测试数据隔离原理

通过环境变量 `SECRETROY_TEST_DIR` 重定向数据存储路径。
`SecureStorageService` 在初始化时会检查该变量，若存在则使用指定目录而非用户 Documents 文件夹。

---

## 当前覆盖范围

| 测试脚本 | 覆盖内容 |
|---|---|
| `smoke_happy_path_test.dart` | 首次运行创建 Vault → 添加账号 → 搜索验证 → 切换设置页 |

---

## 如何新增测试

1. 在 `integration_test/` 下新建 `.dart` 文件，命名建议前缀 `smoke_` 或 `regression_`。
2. 模板：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:secret_roy/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('描述你要测试的场景', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // 用 finder 定位 UI 元素，用 tester.tap / enterText 交互
    // 常用 finder：
    //   find.text('文本')              按文本查找
    //   find.byTooltip('tooltip')         按 tooltip 查找
    //   find.byType(TextField)            按类型查找
    //   find.byWidgetPredicate(...)       自定义过滤器
  });
}
```

3. 中文界面默认 locale 是 `zh`，所以 finder 优先用中文文案。
4. 测试脚本执行时会在同一个 App 进程中运行，若需要独立状态请单独写一个 `.dart` 文件。

---

## 建议补充的自动化场景

以下场景在 PC 端完全可自动化，建议逐步补充：

- [ ] 账号编辑、删除、撤销删除
- [ ] 模板创建、编辑、删除
- [ ] Vault Health 打分验证
- [ ] 密码生成器 + 强度评估
- [ ] 外观设置（深色/浅色/主题色）
- [ ] 导出加密快照（可用模拟路径）

## 仍需人工的场景

这些场景因涉及硬件或多设备，自动化成本过高，建议保留人工 checklist：

- 生物识别解锁（需要 Windows Hello 传感器或模拟器）
- 手机扫码导入 TOTP（需要摄像头）
- 多设备同步 / 冲突解决（需要两台设备 + 服务端）
- LAN 配对（需要多台机器同局域网）
- 剪贴板定时清理验证（系统级别，难以稳定自动化）
