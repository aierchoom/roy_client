# 质量收敛：模板工具依赖与静态门禁

**Status**: Completed
**Date**: 2026-05-07
**Scope**: 当前工作区质量门禁、模板图标工具依赖整理、home/search 与 sync queue 静态问题清理
**Baseline**: 2026-05-06 smoke 自动化覆盖复核后，工作区存在多处未提交功能改动

---

## Goal

对当前 `roy_client` 工作区进行一次质量收敛，优先让稳定质量门禁回到绿色，并记录仍未闭合的测试工具链风险。

---

## Scope

本轮聚焦以下本地改动：

- `lib/models/account_template.dart`
- `lib/utils/template_icons.dart`
- `lib/views/home/home_search_view.dart`
- `lib/views/sync/local_sync_queue_view.dart`
- `docs/reports/execution/README.md`

同时清理了误生成的未跟踪 `null` 文件；该文件内容是一次命令失败输出，不属于项目源码或文档。

---

## Changes

### 1. 拆除模板图标工具循环依赖

`account_template.dart` 原本导入 `template_icons.dart`，而 `template_icons.dart` 又导入 `account_template.dart` 获取 `TemplateCategory`、`AccountField` 等类型，形成模型层和工具层的循环依赖。

本轮将以下领域相关逻辑放回 `account_template.dart`：

- `templateCategoryIcon`
- `inferTemplateCategory`

`template_icons.dart` 保留纯图标与 badge 工具：

- `kTemplateIconOptions`
- `templateIconFromStorageValue`
- `templateIconStorageValue`
- `templateBadgeText`
- `iconForBuiltinTemplate`

### 2. 清理 Home Search 旧同步队列残留

`home_search_view.dart` 已改为通过 `_LocalSyncAlertBanner` 跳转到 `LocalSyncQueueView`，旧的内联同步队列面板、row 组件和直接 push/discard 逻辑已不再使用。

本轮清理了残留未使用 import：

- `../../models/local_sync_change.dart`
- `../../sync/sync_service.dart`

### 3. 清理 Local Sync Queue 静态问题

`local_sync_queue_view.dart` 清理：

- 未使用的 `Theme.of(context)` 局部变量
- 未使用的 `theme` 局部变量
- `separatorBuilder` 中触发 `unnecessary_underscores` 的参数命名

### 4. 清理误生成文件

删除未跟踪文件 `null`。其内容为 shell/PowerShell 命令失败输出，不属于有效项目文件。

---

## Validation

```powershell
& 'F:\FlutterSDK\flutter\bin\flutter.bat' analyze
```

结果：

```text
No issues found! (ran in 2.2s)
```

```powershell
& 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\models\account_item_test.dart --reporter expanded
```

结果：

```text
00:00 +2: All tests passed!
```

```powershell
.\tool\run_integration_tests.cmd
```

结果：

| 测试文件 | 状态 | 用时 |
|---|---:|---:|
| `smoke_full_workflows_test.dart` | PASS | 00:47.161 |
| `smoke_happy_path_test.dart` | PASS | 00:32.039 |

汇总：

```text
Total: 2  |  Pass: 2  |  Fail: 0
All tests passed.
```

---

## Risk Notes

- `flutter test test\models\account_template_test.dart --reporter expanded` 仍会在当前本机环境超时，未进入用例输出。拆除循环依赖降低了结构风险，但没有完全闭合该测试挂起问题。
- 裸 `dart` 命令在本机环境中曾出现挂起，因此本轮没有使用 `dart format` 完成机械格式化；改动通过 `flutter analyze` 校验。
- `run_integration_tests.cmd` 通过后仍打印 `Nuget.exe not found, trying to download or use cached version.`，未影响测试结果，但 Windows 构建依赖缓存仍建议后续整理。
- 当前工作区仍有大量既有未提交功能改动，本轮只做质量收敛，不对未审阅业务改动做回退或大范围重构。

---

## Follow-ups

- 单独定位 `account_template_test.dart` 在本机测试发现/编译阶段超时的问题。
- 恢复稳定的 `dart format` 或明确项目内推荐格式化入口。
- 将 `LocalSyncQueueView` 的自动化覆盖补到 smoke 或 widget test 中，验证 home search 待同步入口到审阅页的跳转。
- 后续提交前再次运行 `flutter analyze` 与 `tool/run_integration_tests.cmd`。
