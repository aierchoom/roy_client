# 上下文暂存

## 当前目标
修复 CI 集成测试失败，确保 `regression_boundary_test.dart` 和 `theme_and_layout_test.dart` 在模拟 Android compact 布局（390×844）下全部通过。

## 已完成
- **Layout overflow 修复**（mobile compact 375×812）：
  - `AppPageHeader`: `ClipRect` + `TextOverflow.ellipsis`
  - `MetricChip`: `Flexible` + `maxLines: 1`
  - `AccountListView` filter/template row: `ClipRect` + `FittedBox(scaleDown)` + `Flexible`
  - `AccountListView` group header: `ClipRect`
  - `AccountListTile`: `ClipRect` + `Expanded` + `Flexible`
- **集成测试文本期望更新**：`'保险库'` 替代 `'账户中心'`（`launchAndUnlockSmokeApp` + `theme_and_layout_test`）
- **`theme_and_layout_test.dart`**：添加 `addTearDown(() => tester.binding.setSurfaceSize(null))`
- **单元测试**：全部 677 个通过（1 skipped）
- **按钮查找修复**：`FilledButton.icon` 的 factory 创建 `_FilledButtonWithIcon`（private class），`find.byType(FilledButton)` 因严格 `runtimeType ==` 匹配而失效，改用 `find.byWidgetPredicate((w) => w is FilledButton)`
- **`configureSmokeSurface`**：
  - 设置移动端尺寸 390×844（替代原 1440×1400 桌面尺寸）
  - 添加 `tester.view.resetViewInsets()` 清除键盘残留，防止 `AppNavBar` 因 `bottomInset > 0` 被隐藏
- **wrong-password test 逻辑修复**：
  - 原逻辑错误：`resetApplication()` 后进入 first-run 状态，任何密码都会直接创建新保险库，永远不会显示 `主密码不正确。`
  - 新逻辑：先 `launchAndUnlockSmokeApp()` 创建保险库 → `ServiceManager.instance.lock()` 锁定 → `app.main()` 重新启动进入 returning-user 状态 → 测试错误密码
- **`notifications` 表缺失防御性修复**：
  - 在 `SecureStorageService` 中添加 `_ensureNotificationsTable()` 方法
  - `loadNotifications`、`saveNotification`、`markNotificationRead`、`markAllNotificationsRead`、`deleteNotification`、`getUnreadNotificationCount` 捕获 `no such table: notifications` 时自动建表
- **`theme_and_layout_test.dart` layout test 统一表面配置**：使用 `configureSmokeSurface(tester)` 替代单独 `setSurfaceSize(375, 812)`

## 当前进度
- 所有代码修改已完成
- 单元测试全部通过（677 passed, 1 skipped）
- **集成测试尚未验证**（见下方环境限制）

## 关键文件
| 文件 | 状态 |
|---|---|
| `lib/widgets/app_page_header.dart` | 已修复 overflow |
| `lib/widgets/inbox/inbox_hero_metrics.dart` | 已修复 overflow |
| `lib/views/accounts/account_list_view.dart` | 已修复 overflow |
| `lib/widgets/account_list_tile.dart` | 已修复 overflow |
| `lib/services/secure_storage_service.dart` | 已添加 `_ensureNotificationsTable` 防御性建表 |
| `integration_test/support/smoke_test_helpers.dart` | 已修改 `configureSmokeSurface`（390×844 + `resetViewInsets`） |
| `integration_test/regression_boundary_test.dart` | 已修改 wrong-password test 逻辑 + 按钮查找 |
| `integration_test/theme_and_layout_test.dart` | 文本期望已更新 + layout test 统一配置 |

## 环境限制
- 当前工作环境的 Windows Flutter 桌面构建工具链在 `flutter clean` 后损坏，CMake 无法识别 C++ 编译器
- Web 设备不支持集成测试
- 因此集成测试无法在本地验证，需推送到 CI 环境或修复本地 Windows 构建环境后验证

## 未解决问题
- Windows `NotificationService` init 警告：`Invalid argument(s): Windows settings must be set when targeting Windows platform.`（非致命，不影响测试）

## 风险与注意事项
- `ServiceManager` 是单例，测试间状态会残留。`launchAndUnlockSmokeApp` 通过 `app.main()` 重新启动应用，但单例状态保留。
- `configureSmokeSurface` 现在统一设置 390×844，所有集成测试都进入 compact 布局。如果某些测试依赖桌面布局的特定 UI（如 `AppNavRail` 的文本可见性），可能需要调整。
- `FilledButton.icon` 的 private class 问题：在任何平台下都需要使用 `is FilledButton` 而非 `byType(FilledButton)`。
