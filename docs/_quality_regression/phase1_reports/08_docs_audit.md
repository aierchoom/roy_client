[stage] runner_started
[stage] agent_built
[stage] context_restored
[stage] context_ready
[stage] run_soul_start
[tool] Shell
[tool] Shell
[tool_result] success
[tool] Shell
[tool_result] success
[tool_result] success
[tool] ReadFile
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool_result] success
[tool] ReadFile
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool_result] success
[tool] Shell
[tool] Grep
[tool_result] success
[tool] Grep
[tool_result] success
[tool] Grep
[tool_result] success
[tool] Grep
[tool_result] success
[tool] Shell
[tool_result] success
[tool_result] success
[tool] Shell
[tool] Shell
[tool_result] success
[tool] Shell
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool_result] success
# SecretRoy 文档一致性报告

**扫描范围**：`docs/` 目录全部 87 个文件 vs. `lib/`、`test/` 实际代码状态  
**扫描日期**：2026-05-16  
**评估结论**：核心安全与产品文档较新且准确，但 **测试指南严重过期**、**架构文档缺少新模块**、**多处类名/路径引用错误**。

---

## 一、文档目录总览

| 子目录 | 文件数 | 内容性质 |
|---|---|---|
| `architecture/` | 9 | 系统架构、运行时、风险路线图、企业改进计划 |
| `beginner/` | 4 | 新人入门：Flutter 基础、架构、App 流程、示例特性 |
| `features/` | 9 | 账户模板、本地出站同步审阅、2FA/TOTP 功能文档 |
| `guides/` | 2 | 技术文档撰写指南、Flutter+Node 新手教程 |
| `plans/` | 4 | LAN 同步、安全笔记集成、样式优化等历史计划 |
| `product/` | 7 | 产品特性基准、迭代任务、业务规格、UI 质量收敛 |
| `qa/` | 3 | 回归测试计划、测试运行清单、自动化测试指南 |
| `reports/execution/` | 30+ | 2026-04-28 至 2026-05-07 的逐日执行报告 |
| `security/` | 4 | 安全功能、本地数据库加密、Beta 风险清单、密钥同步 |
| `sync/` | 6 | 同步协议、保险库链接设计、恢复路线、状态图 |
| `wiki/` | 8 | 开发者速查：API 参考、架构概览、数据模型、测试指南、环境搭建 |
| 根目录 | 2 | `README.md`、`todo.md` |

---

## 二、过期信息清单（文档存在但代码已变更）

### P0 - 严重过期 / 引用错误

| 文档 | 具体问题 | 证据 |
|---|---|---|
| **`docs/wiki/testing-guide.md`** | **测试文件数写作 24，实际约 72 个 Dart 文件**（去除 fakes/harness 后约 66 个测试文件）。测试用例数写作 120+，实际仅 `test()` 调用即 **424 个**，`testWidgets()` **109 个**，合计 **533+**。Widget 测试写作 1 个，实际 **14 个 widget 测试文件**（`test/widgets/` 9 个 + `test/views/` 10 个）。目录结构完全遗漏 `providers/`、`system/`、`theme/`、`utils/`、`views/`。 | 最后更新 2026-05-01，但最近三次 commit 分别新增 +73、+48、+32 个用例，文档未跟进。 |
| **`docs/wiki/data-models.md`** | 附录 A 声称 `Vault` 模型位于 `lib/models/vault.dart`，**该文件不存在**。模型关系中 `Vault` 作为顶层容器描述，但代码中无独立 `Vault` 类，仅有 `AccountItem`、`AccountTemplate` 等。 | `find lib/models -type f` 确认无 `vault.dart`。 |
| **`docs/sync/sync-protocol.md`** | 伪代码中引用 **`ConflictLogService.save(...)`**，代码中**不存在该类**。引用的 `ConflictLog` 类名与实际模型 `TemplateConflictLog` 不符。 | `grep -r "class ConflictLogService" lib/` 无结果。 |
| **`docs/wiki/api-reference.md`** | `SecureStorageService` API 签名中使用 **`ConflictLog`**，实际应为 **`TemplateConflictLog`**。 | `lib/services/secure_storage_service.dart` 中使用 `TemplateConflictLog`。 |
| **`docs/product/application-characteristics.md`** | 全局功能地图中 `冲突收件箱` 一行引用 **`ConflictLog`**，应为 **`TemplateConflictLog`**。 | `lib/models/template_conflict_log.dart` 确认类名。 |

### P1 - 明显过期 / 基线未更新

| 文档 | 具体问题 | 证据 |
|---|---|---|
| **`docs/todo.md`** | 多处引用过时的测试基线："Stage 1 ✅ ... `flutter test` 120 passed / 1 skipped"、"`flutter test` 127 passed / 1 skipped"、"`flutter test` 123 passed / 1 skipped"。当前实际基线已达 **533+ 用例**。 | 该文档最后更新 2026-05-07，但 05-06 的 `application-characteristics.md` 已记录 187 passed，05-07 后又新增约 80 个用例。 |
| **`docs/product/application-characteristics.md`** | 历史基线段落（T8、T0-T7、T11、Vault Health）分别记录 78 passed、76 passed、187 passed，**均未更新到当前实际值**。 | 最近 commit 53c05fe 已新增 +32 cases。 |
| **`docs/architecture/01-system-architecture.md`** | `lib/` 核心结构描述为 `main.dart / l10n / models / providers / services / sync / views / widgets`，**完全遗漏 `system/`、`theme/`、`utils/`、`core/` 四个一级目录**。Container Diagram 中无 `system/` 模块、LAN Sync 组件、Theme 层。 | 最后更新 2026-04-20，`lib/system/` 已于此后大幅扩展。 |
| **`docs/architecture/02-runtime-and-sync.md`** | 同步架构序列图中引用 `CrdtMergeEngine` 返回 `conflict logs`，但未说明实际模型是 `TemplateConflictLog`。安全运行时评估提到 `SyncService` 的 `encrypted_signed_payload` "仍不是标准 AEAD/E2EE 终局方案"，但 **T3 已于 2026-04-30 完成升级**，该描述已过时。 | `docs/product/iteration-tasks.md` T3 完成记录确认已升级为 `sroy-sync:` AES-256-GCM + HKDF。 |

### P2 - 轻度过期 / 信息不全

| 文档 | 具体问题 | 证据 |
|---|---|---|
| **`docs/qa/testing-automation-guide.md`** | 分层图中 Widget Tests 写作 "20+ tests" 在 `test/views/*`，实际 views+widgets 合计 **23 个测试文件、100+ 用例**。E2E Smoke 写作 "(2 tests)"，`integration_test/` 实际有 **3 个文件**（`smoke_happy_path`、`smoke_full_workflows`、`regression_boundary`）。 | 目录 listing 确认。 |
| **`docs/wiki/development-setup.md`** | VS Code 推荐设置中 `dart.lineLength` 写作 **100**，项目实际使用 **120**（`.vscode/settings.json` 及 `AGENTS.md` 均确认）。 | `cat .vscode/settings.json` 确认 `dart.lineLength: 120`。 |
| **`docs/security/key-sync-implementation.md`** | 回归覆盖一节缺少大量新增测试：`test/system/vault_pairing_coordinator_test.dart`、`test/sync/lan_sync_*_test.dart`（6 个文件）、`test/services/vault_health_calculator_test.dart`（29 项）。 | `find test -name "*lan_sync*" -o -name "*vault_pairing*"` 确认存在。 |

---

## 三、文档缺失清单（代码存在但文档缺失）

### 一级模块缺失（architecture/wiki 中几乎未提及）

| 代码模块 | 实际内容 | 应补充的文档位置 |
|---|---|---|
| **`lib/system/`** | 含 `VaultDumpCoordinator`、`VaultImportExportCoordinator`、`VaultPairingCoordinator`、`VaultUnlockCoordinator`、`VaultDataRepository`、`SyncCoordinator`、`SyncServerUrlStore` 等 7+ 个核心协调器。 | `docs/architecture/01-system-architecture.md` 应新增 `system/` 分层说明。 |
| **`lib/theme/`** | `app_design_tokens.dart`、`app_layout.dart`、`app_text_styles.dart` 构成的 Token-based Design System。 | `docs/architecture/` 或 `docs/wiki/` 应补充设计系统文档。 |
| **`lib/core/`** | `AppLogger`、`CryptoRandom` 等基础工具。 | 架构文档缺少核心工具层描述。 |
| **`lib/utils/`** | `field_presets.dart`、`template_icons.dart`、`relative_time_formatter.dart`、`text_highlight.dart`。 | `docs/wiki/data-models.md` 或新增 utils 说明。 |

### 新服务/视图缺失（api-reference / architecture-overview 未覆盖）

| 代码存在 | 说明 |
|---|---|
| `lib/services/device_alias_service.dart` | 设备别名服务，未在 API 参考中列出。 |
| `lib/services/notification_service.dart` | 通知服务，未在 API 参考中列出。 |
| `lib/services/totp_import_service.dart` | TOTP URI/文本导入，未在 API 参考中列出。 |
| `lib/services/totp_qr_image_import_service.dart` | 二维码图片导入，未在 API 参考中列出。 |
| `lib/services/vault_health_calculator.dart` | Vault Health 计算服务（29 项测试），api-reference 未提及。 |
| `lib/views/settings/notification_settings_view.dart` | 通知设置页，architecture-overview 未列出。 |
| `lib/views/settings/vault_health_view.dart` | 体检面板页，architecture-overview 未列出。 |
| `lib/views/accounts/totp_credential_edit_view.dart` | TOTP 编辑页，architecture-overview 未列出。 |
| `lib/views/accounts/totp_qr_scanner_view.dart` | QR 扫码页，architecture-overview 未列出。 |
| `lib/views/sync/local_sync_queue_view.dart` | 本地同步队列页，architecture-overview 未列出。 |
| `lib/sync/lan_sync_client.dart` | LAN 同步客户端，sync-protocol.md 未提及。 |
| `lib/sync/lan_sync_coordinator.dart` | LAN 同步协调器，sync-protocol.md 未提及。 |
| `lib/sync/lan_sync_host_handler.dart` | LAN 同步主机处理器，sync-protocol.md 未提及。 |
| `lib/sync/lan_sync_session.dart` | LAN 同步会话，sync-protocol.md 未提及。 |
| `lib/sync/totp_credential_merge_engine.dart` | TOTP 凭据合并引擎，sync-protocol.md 未提及。 |

### 测试文档缺失

| 测试目录 | 文件数 | 现状 |
|---|---|---|
| `test/providers/` | 3 | testing-guide.md 完全未提及 |
| `test/system/` | 7 | testing-guide.md 完全未提及 |
| `test/theme/` | 2 | testing-guide.md 完全未提及 |
| `test/utils/` | 1 | testing-guide.md 完全未提及 |
| `test/views/` | 10 | testing-guide.md 完全未提及 |
| `test/sync/lan_sync_*_test.dart` | 6 | testing-guide.md 未提及 LAN sync 测试 |

---

## 四、`docs/todo.md` 任务状态核查

| 任务 | 文档状态 | 实际状态 | 结论 |
|---|---|---|---|
| P0 - T15 生物识别加密 | ✅ Completed 2026-05-01 | `biometric_auth_service.dart` 已使用 AES-256-GCM 信封 | **已完成，描述准确** |
| P0 - T16 服务端认证 | ✅ Completed 2026-05-01 | `X-Vault-Token` 已落地 | **已完成，描述准确** |
| P1 - Stage 1 (T9/T12) | ✅ 已完成 | 同步状态机 10 状态、敏感剪贴板策略已收敛 | **已完成，描述准确** |
| P1 - Stage 3 (T13) | 文档标记为 Stage 3 待做 | `vault_health_calculator.dart`、`vault_health_view.dart`、29 项测试已落地 | **T13 实际已完成，但 todo.md 未明确勾选** |
| P1 - Stage 3 (T14) | 文档标记为待做 | `VaultImportExportCoordinator`、导入预览、回滚测试已落地 | **T14 实际已完成，但 todo.md 未明确勾选** |
| P2 - Stage 4 (T17) | 部分勾选 | `SyncService` 已拆分、Design Tokens 已落地，但 account_edit_view / sync_settings_view 拆分未勾选 | **状态一致，部分完成** |
| P2 - Stage 4 (T18) | 未勾选 | QR 导出/恢复码模板未实现 | **状态一致** |
| T10 服务端持久化 | 未关闭 | `roy_server` 原子写入、校验已落地，但幂等/错误分类文档中仍标记为未完成 | **需确认是否已实际完成** |

**注意**：`todo.md` 的测试基线（120 passed 等）已严重过时，但任务勾选状态基本准确。T13/T14 在 `iteration-tasks.md` 中有详细完成记录，建议 `todo.md` 同步勾选并更新基线。

---

## 五、优先修正建议

### 立即执行（P0）

1. **重写 `docs/wiki/testing-guide.md`**
   - 测试文件数：24 → **~66**
   - 测试用例数：120+ → **533+**
   - Widget 测试：1 → **23 个文件（109 个 testWidgets）**
   - 补全遗漏目录：`providers/`、`system/`、`theme/`、`utils/`、`views/`、`sync/lan_sync_*`

2. **统一修正 `ConflictLog` → `TemplateConflictLog`**
   - 影响文件：`docs/wiki/api-reference.md`、`docs/wiki/data-models.md`、`docs/sync/sync-protocol.md`、`docs/product/application-characteristics.md`

3. **删除/修正 `lib/models/vault.dart` 引用**
   - `docs/wiki/data-models.md` 附录 A 中 `Vault` 条目应删除或指向实际代码位置（`Vault` 概念目前分散在 `IdentityService` / `SecureStorageService` 中，无独立模型文件）。

### 尽快执行（P1）

4. **更新 `docs/architecture/01-system-architecture.md`**
   - 补充 `lib/` 实际结构：`core/`、`system/`、`theme/`、`utils/`
   - Container Diagram 增加 `system/` 协调器、`LanPairingService`、`ThemeProvider`

5. **更新所有测试基线**
   - `docs/todo.md`、`docs/product/application-characteristics.md`、`docs/product/iteration-tasks.md` 中历史基线统一更新为当前实际值（约 533+ passed, 1 skipped）。

6. **更新 `docs/sync/sync-protocol.md`**
   - `ConflictLogService` 伪代码改为 `TemplateConflictLog` 或 `SecureStorageService.saveConflictLogs`
   - 补充 T3 AEAD 升级后的正式契约描述（当前文档底部虽有补充，但正文伪代码仍是旧语义）

### 中期补充（P2）

7. **为 `lib/system/` 编写架构说明**
   - `system/` 是当前 ServiceManager 拆分后的核心扩展点，建议在 `docs/architecture/` 新增 `07-system-modules.md`，说明各 Coordinator 职责边界。

8. **补充 LAN Sync 协议文档**
   - `lib/sync/lan_sync_*.dart` 已形成完整的局域网同步子系统，建议在 `docs/sync/` 新增 `lan-sync-protocol.md`。

9. **更新 `docs/wiki/api-reference.md`**
   - 新增 `DeviceAliasService`、`NotificationService`、`TotpImportService`、`TotpQrImageImportService`、`VaultHealthCalculator` 的 API 摘要。

### 长期维护机制（P3）

10. **建立文档维护检查清单**
    - 每次新增测试文件 → 同步更新 `testing-guide.md`
    - 每次新增 `lib/` 一级目录 → 同步更新 `architecture/01-system-architecture.md`
    - 每次新增模型类 → 同步更新 `data-models.md` 和 `api-reference.md`
    - 建议在 `docs/product/application-characteristics.md` 的"功能迭代准入检查表"中增加第 13 条："是否同步更新了 `testing-guide.md` 和 `architecture-overview.md`？"[stage] run_soul_finished

[summary]
# SecretRoy 文档一致性报告

**扫描范围**：`docs/` 目录全部 87 个文件 vs. `lib/`、`test/` 实际代码状态  
**扫描日期**：2026-05-16  
**评估结论**：核心安全与产品文档较新且准确，但 **测试指南严重过期**、**架构文档缺少新模块**、**多处类名/路径引用错误**。

---

## 一、文档目录总览

| 子目录 | 文件数 | 内容性质 |
|---|---|---|
| `architecture/` | 9 | 系统架构、运行时、风险路线图、企业改进计划 |
| `beginner/` | 4 | 新人入门：Flutter 基础、架构、App 流程、示例特性 |
| `features/` | 9 | 账户模板、本地出站同步审阅、2FA/TOTP 功能文档 |
| `guides/` | 2 | 技术文档撰写指南、Flutter+Node 新手教程 |
| `plans/` | 4 | LAN 同步、安全笔记集成、样式优化等历史计划 |
| `product/` | 7 | 产品特性基准、迭代任务、业务规格、UI 质量收敛 |
| `qa/` | 3 | 回归测试计划、测试运行清单、自动化测试指南 |
| `reports/execution/` | 30+ | 2026-04-28 至 2026-05-07 的逐日执行报告 |
| `security/` | 4 | 安全功能、本地数据库加密、Beta 风险清单、密钥同步 |
| `sync/` | 6 | 同步协议、保险库链接设计、恢复路线、状态图 |
| `wiki/` | 8 | 开发者速查：API 参考、架构概览、数据模型、测试指南、环境搭建 |
| 根目录 | 2 | `README.md`、`todo.md` |

---

## 二、过期信息清单（文档存在但代码已变更）

### P0 - 严重过期 / 引用错误

| 文档 | 具体问题 | 证据 |
|---|---|---|
| **`docs/wiki/testing-guide.md`** | **测试文件数写作 24，实际约 72 个 Dart 文件**（去除 fakes/harness 后约 66 个测试文件）。测试用例数写作 120+，实际仅 `test()` 调用即 **424 个**，`testWidgets()` **109 个**，合计 **533+**。Widget 测试写作 1 个，实际 **14 个 widget 测试文件**（`test/widgets/` 9 个 + `test/views/` 10 个）。目录结构完全遗漏 `providers/`、`system/`、`theme/`、`utils/`、`views/`。 | 最后更新 2026-05-01，但最近三次 commit 分别新增 +73、+48、+32 个用例，文档未跟进。 |
| **`docs/wiki/data-models.md`** | 附录 A 声称 `Vault` 模型位于 `lib/models/vault.dart`，**该文件不存在**。模型关系中 `Vault` 作为顶层容器描述，但代码中无独立 `Vault` 类，仅有 `AccountItem`、`AccountTemplate` 等。 | `find lib/models -type f` 确认无 `vault.dart`。 |
| **`docs/sync/sync-protocol.md`** | 伪代码中引用 **`ConflictLogService.save(...)`**，代码中**不存在该类**。引用的 `ConflictLog` 类名与实际模型 `TemplateConflictLog` 不符。 | `grep -r "class ConflictLogService" lib/` 无结果。 |
| **`docs/wiki/api-reference.md`** | `SecureStorageService` API 签名中使用 **`ConflictLog`**，实际应为 **`TemplateConflictLog`**。 | `lib/services/secure_storage_service.dart` 中使用 `TemplateConflictLog`。 |
| **`docs/product/application-characteristics.md`** | 全局功能地图中 `冲突收件箱` 一行引用 **`ConflictLog`**，应为 **`TemplateConflictLog`**。 | `lib/models/template_conflict_log.dart` 确认类名。 |

### P1 - 明显过期 / 基线未更新

| 文档 | 具体问题 | 证据 |
|---|---|---|
| **`docs/todo.md`** | 多处引用过时的测试基线："Stage 1 ✅ ... `flutter test` 120 passed / 1 skipped"、"`flutter test` 127 passed / 1 skipped"、"`flutter test` 123 passed / 1 skipped"。当前实际基线已达 **533+ 用例**。 | 该文档最后更新 2026-05-07，但 05-06 的 `application-characteristics.md` 已记录 187 passed，05-07 后又新增约 80 个用例。 |
| **`docs/product/application-characteristics.md`** | 历史基线段落（T8、T0-T7、T11、Vault Health）分别记录 78 passed、76 passed、187 passed，**均未更新到当前实际值**。 | 最近 commit 53c05fe 已新增 +32 cases。 |
| **`docs/architecture/01-system-architecture.md`** | `lib/` 核心结构描述为 `main.dart / l10n / models / providers / services / sync / views / widgets`，**完全遗漏 `system/`、`theme/`、`utils/`、`core/` 四个一级目录**。Container Diagram 中无 `system/` 模块、LAN Sync 组件、Theme 层。 | 最后更新 2026-04-20，`lib/system/` 已于此后大幅扩展。 |
| **`docs/architecture/02-runtime-and-sync.md`** | 同步架构序列图中引用 `CrdtMergeEngine` 返回 `conflict logs`，但未说明实际模型是 `TemplateConflictLog`。安全运行时评估提到 `SyncService` 的 `encrypted_signed_payload` "仍不是标准 AEAD/E2EE 终局方案"，但 **T3 已于 2026-04-30 完成升级**，该描述已过时。 | `docs/product/iteration-tasks.md` T3 完成记录确认已升级为 `sroy-sync:` AES-256-GCM + HKDF。 |

### P2 - 轻度过期 / 信息不全

| 文档 | 具体问题 | 证据 |
|---|---|---|
| **`docs/qa/testing-automation-guide.md`** | 分层图中 Widget Tests 写作 "20+ tests" 在 `test/views/*`，实际 views+widgets 合计 **23 个测试文件、100+ 用例**。E2E Smoke 写作 "(2 tests)"，`integration_test/` 实际有 **3 个文件**（`smoke_happy_path`、`smoke_full_workflows`、`regression_boundary`）。 | 目录 listing 确认。 |
| **`docs/wiki/development-setup.md`** | VS Code 推荐设置中 `dart.lineLength` 写作 **100**，项目实际使用 **120**（`.vscode/settings.json` 及 `AGENTS.md` 均确认）。 | `cat .vscode/settings.json` 确认 `dart.lineLength: 120`。 |
| **`docs/security/key-sync-implementation.md`** | 回归覆盖一节缺少大量新增测试：`test/system/vault_pairing_coordinator_test.dart`、`test/sync/lan_sync_*_test.dart`（6 个文件）、`test/services/vault_health_calculator_test.dart`（29 项）。 | `find test -name "*lan_sync*" -o -name "*vault_pairing*"` 确认存在。 |

---

## 三、文档缺失清单（代码存在但文档缺失）

### 一级模块缺失（architecture/wiki 中几乎未提及）

| 代码模块 | 实际内容 | 应补充的文档位置 |
|---|---|---|
| **`lib/system/`** | 含 `VaultDumpCoordinator`、`VaultImportExportCoordinator`、`VaultPairingCoordinator`、`VaultUnlockCoordinator`、`VaultDataRepository`、`SyncCoordinator`、`SyncServerUrlStore` 等 7+ 个核心协调器。 | `docs/architecture/01-system-architecture.md` 应新增 `system/` 分层说明。 |
| **`lib/theme/`** | `app_design_tokens.dart`、`app_layout.dart`、`app_text_styles.dart` 构成的 Token-based Design System。 | `docs/architecture/` 或 `docs/wiki/` 应补充设计系统文档。 |
| **`lib/core/`** | `AppLogger`、`CryptoRandom` 等基础工具。 | 架构文档缺少核心工具层描述。 |
| **`lib/utils/`** | `field_presets.dart`、`template_icons.dart`、`relative_time_formatter.dart`、`text_highlight.dart`。 | `docs/wiki/data-models.md` 或新增 utils 说明。 |

### 新服务/视图缺失（api-reference / architecture-overview 未覆盖）

| 代码存在 | 说明 |
|---|---|
| `lib/services/device_alias_service.dart` | 设备别名服务，未在 API 参考中列出。 |
| `lib/services/notification_service.dart` | 通知服务，未在 API 参考中列出。 |
| `lib/services/totp_import_service.dart` | TOTP URI/文本导入，未在 API 参考中列出。 |
| `lib/services/totp_qr_image_import_service.dart` | 二维码图片导入，未在 API 参考中列出。 |
| `lib/services/vault_health_calculator.dart` | Vault Health 计算服务（29 项测试），api-reference 未提及。 |
| `lib/views/settings/notification_settings_view.dart` | 通知设置页，architecture-overview 未列出。 |
| `lib/views/settings/vault_health_view.dart` | 体检面板页，architecture-overview 未列出。 |
| `lib/views/accounts/totp_credential_edit_view.dart` | TOTP 编辑页，architecture-overview 未列出。 |
| `lib/views/accounts/totp_qr_scanner_view.dart` | QR 扫码页，architecture-overview 未列出。 |
| `lib/views/sync/local_sync_queue_view.dart` | 本地同步队列页，architecture-overview 未列出。 |
| `lib/sync/lan_sync_client.dart` | LAN 同步客户端，sync-protocol.md 未提及。 |
| `lib/sync/lan_sync_coordinator.dart` | LAN 同步协调器，sync-protocol.md 未提及。 |
| `lib/sync/lan_sync_host_handler.dart` | LAN 同步主机处理器，sync-protocol.md 未提及。 |
| `lib/sync/lan_sync_session.dart` | LAN 同步会话，sync-protocol.md 未提及。 |
| `lib/sync/totp_credential_merge_engine.dart` | TOTP 凭据合并引擎，sync-protocol.md 未提及。 |

### 测试文档缺失

| 测试目录 | 文件数 | 现状 |
|---|---|---|
| `test/providers/` | 3 | testing-guide.md 完全未提及 |
| `test/system/` | 7 | testing-guide.md 完全未提及 |
| `test/theme/` | 2 | testing-guide.md 完全未提及 |
| `test/utils/` | 1 | testing-guide.md 完全未提及 |
| `test/views/` | 10 | testing-guide.md 完全未提及 |
| `test/sync/lan_sync_*_test.dart` | 6 | testing-guide.md 未提及 LAN sync 测试 |

---

## 四、`docs/todo.md` 任务状态核查

| 任务 | 文档状态 | 实际状态 | 结论 |
|---|---|---|---|
| P0 - T15 生物识别加密 | ✅ Completed 2026-05-01 | `biometric_auth_service.dart` 已使用 AES-256-GCM 信封 | **已完成，描述准确** |
| P0 - T16 服务端认证 | ✅ Completed 2026-05-01 | `X-Vault-Token` 已落地 | **已完成，描述准确** |
| P1 - Stage 1 (T9/T12) | ✅ 已完成 | 同步状态机 10 状态、敏感剪贴板策略已收敛 | **已完成，描述准确** |
| P1 - Stage 3 (T13) | 文档标记为 Stage 3 待做 | `vault_health_calculator.dart`、`vault_health_view.dart`、29 项测试已落地 | **T13 实际已完成，但 todo.md 未明确勾选** |
| P1 - Stage 3 (T14) | 文档标记为待做 | `VaultImportExportCoordinator`、导入预览、回滚测试已落地 | **T14 实际已完成，但 todo.md 未明确勾选** |
| P2 - Stage 4 (T17) | 部分勾选 | `SyncService` 已拆分、Design Tokens 已落地，但 account_edit_view / sync_settings_view 拆分未勾选 | **状态一致，部分完成** |
| P2 - Stage 4 (T18) | 未勾选 | QR 导出/恢复码模板未实现 | **状态一致** |
| T10 服务端持久化 | 未关闭 | `roy_server` 原子写入、校验已落地，但幂等/错误分类文档中仍标记为未完成 | **需确认是否已实际完成** |

**注意**：`todo.md` 的测试基线（120 passed 等）已严重过时，但任务勾选状态基本准确。T13/T14 在 `iteration-tasks.md` 中有详细完成记录，建议 `todo.md` 同步勾选并更新基线。

---

## 五、优先修正建议

### 立即执行（P0）

1. **重写 `docs/wiki/testing-guide.md`**
   - 测试文件数：24 → **~66**
   - 测试用例数：120+ → **533+**
   - Widget 测试：1 → **23 个文件（109 个 testWidgets）**
   - 补全遗漏目录：`providers/`、`system/`、`theme/`、`utils/`、`views/`、`sync/lan_sync_*`

2. **统一修正 `ConflictLog` → `TemplateConflictLog`**
   - 影响文件：`docs/wiki/api-reference.md`、`docs/wiki/data-models.md`、`docs/sync/sync-protocol.md`、`docs/product/application-characteristics.md`

3. **删除/修正 `lib/models/vault.dart` 引用**
   - `docs/wiki/data-models.md` 附录 A 中 `Vault` 条目应删除或指向实际代码位置（`Vault` 概念目前分散在 `IdentityService` / `SecureStorageService` 中，无独立模型文件）。

### 尽快执行（P1）

4. **更新 `docs/architecture/01-system-architecture.md`**
   - 补充 `lib/` 实际结构：`core/`、`system/`、`theme/`、`utils/`
   - Container Diagram 增加 `system/` 协调器、`LanPairingService`、`ThemeProvider`

5. **更新所有测试基线**
   - `docs/todo.md`、`docs/product/application-characteristics.md`、`docs/product/iteration-tasks.md` 中历史基线统一更新为当前实际值（约 533+ passed, 1 skipped）。

6. **更新 `docs/sync/sync-protocol.md`**
   - `ConflictLogService` 伪代码改为 `TemplateConflictLog` 或 `SecureStorageService.saveConflictLogs`
   - 补充 T3 AEAD 升级后的正式契约描述（当前文档底部虽有补充，但正文伪代码仍是旧语义）

### 中期补充（P2）

7. **为 `lib/system/` 编写架构说明**
   - `system/` 是当前 ServiceManager 拆分后的核心扩展点，建议在 `docs/architecture/` 新增 `07-system-modules.md`，说明各 Coordinator 职责边界。

8. **补充 LAN Sync 协议文档**
   - `lib/sync/lan_sync_*.dart` 已形成完整的局域网同步子系统，建议在 `docs/sync/` 新增 `lan-sync-protocol.md`。

9. **更新 `docs/wiki/api-reference.md`**
   - 新增 `DeviceAliasService`、`NotificationService`、`TotpImportService`、`TotpQrImageImportService`、`VaultHealthCalculator` 的 API 摘要。

### 长期维护机制（P3）

10. **建立文档维护检查清单**
    - 每次新增测试文件 → 同步更新 `testing-guide.md`
    - 每次新增 `lib/` 一级目录 → 同步更新 `architecture/01-system-architecture.md`
    - 每次新增模型类 → 同步更新 `data-models.md` 和 `api-reference.md`
    - 建议在 `docs/product/application-characteristics.md` 的"功能迭代准入检查表"中增加第 13 条："是否同步更新了 `testing-guide.md` 和 `architecture-overview.md`？"
