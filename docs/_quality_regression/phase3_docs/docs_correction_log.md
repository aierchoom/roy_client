# 文档一致性修正日志

**修正日期**: 2026-05-16
**依据**: `docs/_quality_regression/phase1_reports/08_docs_audit.md`

---

## 修正文件清单

| 序号 | 文件 | 修正类型 | 严重程度 |
|------|------|----------|----------|
| 1 | `docs/wiki/testing-guide.md` | 数据更新 + 结构补全 | P0 - 严重过期 |
| 2 | `docs/guides/technical-documentation.md` | 顶部警告 + 目录/服务列表修正 | P0 - 多处错误 |
| 3 | `docs/wiki/development-setup.md` | 单点修正 | P2 - 轻度过期 |
| 4 | `docs/wiki/api-reference.md` | 类名修正 + 缺失标注 | P0 - 引用错误 |
| 5 | `docs/architecture/01-system-architecture.md` | 目录结构补全 + 容器图更新 | P1 - 基线未更新 |

---

## 详细修正记录

### 1. `docs/wiki/testing-guide.md`

**修改位置 1**: 文档标题下方更新日期标注
- **修改原因**: 整篇文档统计基线严重过期
- **原内容**: 未标注数据过期
- **更新为**: 添加 `<!-- 2026-05-16 修正：下方统计数据已过期，以本节最新数据为准 -->`

**修改位置 2**: "测试概览"表格
- **修改原因**: 测试文件数、用例数、Widget 测试数量均严重低于实际值
- **原内容**: 测试文件数 24 / 用例数 120+ / Widget 测试 1
- **更新为**: 测试文件数 74 / 用例数 540 / Widget 测试 18 个文件（约 109 个 testWidgets）

**修改位置 3**: 目录结构树
- **修改原因**: 完全遗漏 `providers/`、`system/`、`theme/`、`utils/`、`views/`，且 `widgets/`、`sync/` 严重不全
- **原内容**: 仅列出 models(5)、services(10)、sync(9)、widgets(1)，合计约 24 个文件
- **更新为**: 补全全部 10 个测试子目录，合计 74 个测试文件（含 integration_test）
  - 新增 `providers/` 3 个文件
  - 新增 `system/` 7 个文件
  - 新增 `theme/` 2 个文件
  - 新增 `utils/` 1 个文件
  - 新增 `views/` 9 个文件
  - `widgets/` 从 1 扩展为 9 个文件
  - `sync/` 从 9 扩展为 15 个文件（新增 6 个 LAN sync 测试）
  - 新增 `integration_test/` 3 个文件

**修改位置 4**: 运行测试命令
- **修改原因**: `dart test` 命令不适用于本工程（Flutter 工程需用 `flutter test`）
- **原内容**: `dart test test/sync/lan_pairing_service_test.dart`
- **更新为**: Windows 本地测试特殊命令 `.\tool\flutter_test.ps1`

**修改位置 5**: "覆盖缺口"段落
- **修改原因**: "Widget 测试仅覆盖 account_list_tile" 已过期
- **原内容**: Widget 测试仅覆盖 account_list_tile
- **更新为**: 划线删除旧描述，补充 views+widgets 共 18 个测试文件但仍需更多端到端测试

**修改位置 6**: 新增 TODO 标注
- **修改原因**: 原文档遗漏大量 Widget/View 测试说明
- **新增内容**: TODO 待补充 `test/views/` 和 `test/widgets/` 其余文件说明

---

### 2. `docs/guides/technical-documentation.md`

**修改位置 1**: 文档顶部添加全局警告
- **修改原因**: 本文档服务列表、目录结构、解锁流程多处已过期，过期程度太高
- **新增内容**: `⚠️ 本文档部分信息已过期，建议参考 [技术基线总览]`

**修改位置 2**: `lib/` 目录结构
- **修改原因**: 遗漏 `core/`、`system/`（仅列 4 个文件，实际 10 个）、`theme/`、`utils/`；models、providers、services、sync 均严重不全
- **原内容**: models(3)、providers(2)、services(8)、sync(3)、system(4)
- **更新为**: 补全全部一级目录及子文件
  - 新增 `core/` 2 个文件
  - `models/` 从 3 扩展为 8 个文件
  - `providers/` 补充 `notification_provider.dart`
  - `services/` 从 8 扩展为 18 个文件
  - `sync/` 从 3 扩展为 12 个文件（含 LAN sync 子系统）
  - `system/` 从 4 扩展为 10 个文件
  - 新增 `theme/` 4 个文件
  - 新增 `utils/` 4 个文件

**修改位置 3**: ServiceManager 内部持有服务列表
- **修改原因**: 遗漏 10+ 个服务/协调器
- **原内容**: 仅列 10 个服务
- **更新为**: 补充 `VaultUnlockCoordinator`、`VaultDataRepository`、`SyncCoordinator`、`VaultImportExportCoordinator`、`VaultPairingCoordinator`、`NotificationService`、`SensitiveClipboardService`、`DeviceAliasService`、`TotpImportService`、`TotpQrImageImportService`、`VaultHealthCalculator`

**修改位置 4**: 解锁流程伪代码
- **修改原因**: `SecureStorageService.initialize` 和 `SyncService.initialize` 已委托给 Coordinator
- **原内容**: `SecureStorageService.initialize(deviceId)` → `SyncService.initialize()`
- **更新为**: `VaultUnlockCoordinator.initializeStorage(deviceId)` → `SyncCoordinator.initialize()`

**修改位置 5**: SecureStorageService 数据表
- **修改原因**: 遗漏 TOTP 和通知相关表
- **原内容**: accounts / templates / conflict_logs / settings
- **更新为**: 补充 `totp_credentials`、`app_notifications`

---

### 3. `docs/wiki/development-setup.md`

**修改位置**: VS Code 推荐设置
- **修改原因**: `dart.lineLength` 与实际项目配置不符（`.vscode/settings.json` 为 120）
- **原内容**: `"dart.lineLength": 100`
- **更新为**: `"dart.lineLength": 120`

---

### 4. `docs/wiki/api-reference.md`

**修改位置 1**: SecureStorageService API 签名
- **修改原因**: 类名引用错误，`ConflictLog` 实际为 `TemplateConflictLog`
- **原内容**: `saveConflictLogs(List<ConflictLog> logs)`、`getConflictLogs(String accountId)` 返回 `List<ConflictLog>`
- **更新为**: `saveConflictLogs(List<TemplateConflictLog> logs)`、`getConflictLogs(String accountId)` 返回 `List<TemplateConflictLog>`

**修改位置 2**: 新增缺失服务章节（DeviceAliasService、NotificationService、TotpImportService、TotpQrImageImportService、VaultHealthCalculator）
- **修改原因**: 审计报告确认这些服务在代码中存在但 API 参考未覆盖
- **新增内容**: 5 个 TODO 待补充标注（遵循"不强行编写"原则）

**修改位置 3**: 章节编号顺延
- **修改原因**: 插入 5 个新章节后原 AccountItem / AccountTemplate 编号需顺延
- **AccountItem**: 从 ## 9 改为 ## 13
- **AccountTemplate**: 从 ## 10 改为 ## 14

---

### 5. `docs/architecture/01-system-architecture.md`

**修改位置 1**: `lib/` 核心结构描述
- **修改原因**: 完全遗漏 `core/`、`system/`、`theme/`、`utils/` 四个一级目录
- **原内容**: `main.dart / l10n / models / providers / services / sync / views / widgets`
- **更新为**: 补充 `core/`、`system/`、`theme/`、`utils/`，并在各目录下补充职责说明

**修改位置 2**: Container Diagram (Mermaid)
- **修改原因**: 图中无 `system/` 协调器层、LAN Sync 组件、Theme 层
- **原内容**: SM 直接指向 SS/SY/SEC
- **更新为**: SM 新增指向 `CO["Coordinators (system/)"]` 和 `TH["Theme"]`，SY 明确标注为 `SyncService + LAN Sync`

---

## 未修正/标注为 TODO 的内容

| 文档 | 未修正内容 | 原因 |
|------|-----------|------|
| `docs/wiki/testing-guide.md` | 大量 Widget/View 测试文件的详细说明 | 遵循"不强行编写"原则，仅标注 TODO |
| `docs/wiki/api-reference.md` | DeviceAliasService 等 5 个新服务的 API 摘要 | 遵循"不强行编写"原则，仅标注 TODO |
| `docs/guides/technical-documentation.md` | 解锁流程后续细节、UI 层视图列表、数据流等 | 过期程度太高，建议整体重写，仅修正最明确的事实性错误 |
| `docs/architecture/01-system-architecture.md` | Container Diagram 中各 Coordinator 的详细交互 | 超出"明确过期事实"范围 |

---

## 修正原则执行情况

1. ✅ 只修正**明确过期**的事实性错误（测试数量、文件路径、类名、方法名）
2. ✅ 不新增大段内容，只修正错误信息
3. ✅ 在修正处标注 `<!-- 2026-05-16 修正：原内容XXX，更新为YYY -->`
4. ✅ 文档缺失重要章节时添加"TODO 待补充"提示，不强行编写
5. ✅ `technical-documentation.md` 因过期程度太高在顶部添加警告并建议参考技术基线总览
