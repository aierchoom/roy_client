# Smoke 自动化执行与覆盖差距复核

**Status**: Automated smoke passed; full QA regression not completed
**Date**: 2026-05-06
**Scope**: Windows 桌面端现有 `integration_test/*.dart` 自动化 smoke；对照 QA 93 条回归矩阵复核覆盖差距
**Baseline**: 当前工作区未提交变更状态下的 `roy_client`

---

## Goal

阅读并执行 `roy_client` 的现有 smoke 自动测试，同时对照 `docs/qa/qa-regression-test-plan.md` 与 `docs/qa/qa-test-run-checklist.md` 复核“全量”的真实含义，避免把“现有自动化脚本全量通过”误写成“产品级 QA 全量回归通过”。

---

## Scope

本次已完成的自动化 smoke 范围来自 `tool/run_integration_tests.ps1` 自动发现的全部集成测试文件：

| 测试文件 | 覆盖路径 |
|---|---|
| `integration_test/smoke_full_workflows_test.dart` | 创建 Vault、创建网站账号、编辑账号、创建并关联 2FA、密码生成器保留结果、Vault 体检、模板创建 |
| `integration_test/smoke_happy_path_test.dart` | 创建 Vault、添加账号、搜索验证、进入设置页并校验主要设置分区 |

辅助能力来自 `integration_test/support/smoke_test_helpers.dart`：

- 固定测试窗口尺寸为 `1440 x 1400`
- 启动应用并创建/解锁测试 Vault
- 通过中文 UI 文案和 tooltip 定位主要控件
- 通过 `SECRETROY_TEST_DIR` 使用独立临时数据目录，避免污染真实用户数据

QA 回归矩阵总范围来自 `docs/qa/qa-test-run-checklist.md`：

| 范围 | 数量 |
|---|---:|
| QA 回归用例总数 | 93 |
| 文档标注已自动化 | 3 |
| 本次实际执行的 integration smoke 文件 | 2 |
| 本次人工/多设备/硬件用例执行数 | 0 |

---

## Execution

执行命令：

```powershell
.\tool\run_integration_tests.cmd
```

额外质量门禁探测：

```powershell
& 'F:\FlutterSDK\flutter\bin\flutter.bat' analyze
& 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\models\account_item_test.dart --reporter expanded
```

执行环境与脚本行为：

- 平台：Windows desktop target
- Runner：Flutter integration test
- 测试发现：`integration_test/*.dart`
- 每个测试文件单独创建临时目录：`%TEMP%\secret_roy_integration_test_*`
- 环境变量：`SECRETROY_TEST_DIR` 指向临时目录；`SECRETROY_TEST_DISABLE_NO_PASSWORD=1`
- 脚本结束后清理每个临时测试数据目录

---

## Validation

### 已完成并通过

测试结果汇总：

| 测试文件 | 状态 | 用时 |
|---|---:|---:|
| `smoke_full_workflows_test.dart` | PASS | 00:48.462 |
| `smoke_happy_path_test.dart` | PASS | 00:31.590 |

总计：

- Total: 2
- Pass: 2
- Fail: 0
- 脚本总耗时：约 80.5 秒

静态分析：

| 命令 | 状态 | 结果 |
|---|---:|---|
| `flutter analyze` | PASS | `No issues found!` |

单文件测试探针：

| 命令 | 状态 | 结果 |
|---|---:|---|
| `flutter test test\models\account_item_test.dart --reporter expanded` | PASS | 2 tests passed |

关键输出摘录：

```text
Found 2 test scripts:
  - smoke_full_workflows_test.dart
  - smoke_happy_path_test.dart

[PASS] smoke_full_workflows_test.dart (48.462)
[PASS] smoke_happy_path_test.dart (31.590)

Total: 2  |  Pass: 2  |  Fail: 0
All tests passed.
```

---

### 扩展验证未完成

用户指出“测试不够全量”后，尝试扩展执行单元/组件测试：

| 命令 | 状态 | 观察 |
|---|---:|---|
| `tool\flutter_test.ps1` | TIMEOUT | 15 分钟超时；遗留 Dart 测试进程和工具生成的 `pubspec_overrides.yaml`，已清理 |
| `tool\flutter_test.ps1 test\models --reporter compact` | TIMEOUT | 5 分钟超时；遗留 Dart 测试进程和工具生成的 `pubspec_overrides.yaml`，已清理 |
| `flutter test test\models --reporter expanded` | TIMEOUT | 5 分钟超时；测试发现/调度阶段无可用输出 |
| `flutter test test\models\hlc_test.dart --list-tests` | TIMEOUT | 2 分钟超时；说明卡点早于实际用例执行 |
| `flutter test test\models\hlc_test.dart --verbose` | TIMEOUT | 1 分钟超时；shell 超时前无可用输出，残留 Dart 进程已清理 |

当前判断：

- `flutter analyze` 正常
- Windows desktop integration smoke 正常
- 单个已知模型测试文件 `account_item_test.dart` 正常
- 但扩展到多文件或某些单文件时，Flutter/Dart test discovery/编译阶段在本机挂起
- 因此本轮不能宣称单元/组件测试全量通过

---

## Coverage Notes

本次 integration smoke 覆盖了桌面端一部分关键端到端用户路径：

- 首次进入应用后创建测试 Vault
- 新建网站账号并验证列表可见
- 搜索账号
- 账号预览和编辑保存
- 新建 TOTP/2FA 条目并关联账号
- 打开密码工具并保留生成结果
- 打开 Vault 体检并等待体检时间生成
- 新建自定义模板和字段
- 进入设置中心并校验主要设置项

但对照 93 条 QA 回归矩阵，仍未覆盖或未执行的主要范围包括：

- 多设备同步 Push/Pull、冲突收件箱、LAN/远程配对
- 生物识别、自动锁定、系统剪贴板定时清理
- 账号删除/撤销删除、复制密码、敏感字段遮罩
- 模板编辑/删除保护、时间字段格式、关联字段
- TOTP 扫码、粘贴二维码图片、动态码刷新、删除
- 导入/导出加密快照、恢复码导入预览与覆盖确认
- 外观设置切换、性能与稳定性快速检查

当前 `integration_test/README.md` 的“当前覆盖范围”仍只列出 `smoke_happy_path_test.dart`，已落后于实际测试文件数量；实际自动化 smoke 已包含 `smoke_full_workflows_test.dart`。

---

## Risk Notes

- **不能称为产品级全量测试**：本次只完整执行了现有 integration smoke 文件；QA 矩阵中的 93 条用例没有全量执行。
- **覆盖仍是浅层 smoke**：`smoke_full_workflows_test.dart` 覆盖面较宽，但每个模块只验证一条可用路径，不替代模块级单元测试、异常路径测试或人工场景。
- **单元/组件测试扩展验证受阻**：本地 Flutter/Dart test discovery/编译阶段出现挂起，已清理残留进程和临时 override，但需要后续单独定位工具链卡点。
- **仍未覆盖硬件/多设备场景**：生物识别、摄像头扫码、LAN 配对、多设备同步和冲突解决仍需人工或独立环境验证。
- **测试依赖中文 UI 文案与 tooltip**：产品文案、tooltip 或布局调整会直接影响 finder 稳定性。
- **构建日志提示 NuGet 获取信息**：测试通过后日志末尾出现 `Nuget.exe not found, trying to download or use cached version.`，未影响本次结果，但建议后续确认 Windows 构建依赖缓存是否稳定。

---

## Follow-ups

- 更新 `integration_test/README.md` 的覆盖范围表，补充 `smoke_full_workflows_test.dart`
- 定位 `flutter test` 多文件/部分单文件在本机挂起的问题，优先收集可实时输出的日志或使用更小粒度批处理
- 更新 `docs/qa/qa-test-run-checklist.md` 的自动化覆盖标注，把 `smoke_full_workflows_test.dart` 覆盖到的路径明确映射到用例 ID
- 为账号删除/撤销删除、模板编辑/删除、导出加密快照补充自动化 smoke
- 将 smoke 测试结果输出到机器可读日志或 Markdown，减少人工整理成本
- 在 CI 或本地 QA 流程中固定 Windows 构建依赖缓存，降低 NuGet 环境噪音
