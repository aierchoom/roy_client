# SecretRoy 客户端 — 质量回归执行清单

> 生成时间：2026-05-16
> 依据来源：Phase 1 扫描报告（00/01/03/07/08）+ Phase 2 报告（quality_gap / platform_capability / feature_matrix）
> 适用范围：`lib/` 115 个 Dart 文件、`test/` 74 个测试文件、`docs/` 87 个文档文件

---

## 执行摘要

| 指标 | 当前状态 | 目标状态 | 差距 |
|------|---------|---------|------|
| 整体行覆盖率 | **58.3%** (7,892/13,541) | **70%** (9,479/13,541) | +1,587 行 |
| 静态分析 (lib/) | 0 error / 0 warning | 保持 0 error / 0 warning | — |
| 测试用例数 | 540 | 650+ | +110 个 |
| 公共 API dartdoc 覆盖率 | ~22% | 50%（优先服务层） | +~50 个文档点 |
| 文档一致性 | 多处严重漂移 | 核心文档与代码同步 | 7 份文档待修 |
| TODO/FIXME/HACK | 0 | 0 | — |

**总任务数**：58 个  
**预估总工作量**：约 35–42 人天  
**建议迭代周期**：2 个 Sprint（Sprint 1: P0+Quick Wins，约 18–22 人天；Sprint 2: P1+P2，约 17–20 人天）

---

## P0 紧急任务（安全/核心功能风险）

> **执行原则**：P0 任务阻塞发布评审，必须优先完成。

### T-001 — 为 `VaultPairingService` 补充单元测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/services/vault_pairing_service.dart` |
| **当前覆盖率** | **1.0%** (98 行仅命中 1 行) |
| **问题描述** | 服务端配对 HTTP API 客户端（创建/加入/审批/拉取 bundle）完全无有效测试。涉及 X-Vault-Token 鉴权与敏感 bundle 传输，属于安全关键路径。 |
| **建议修复方式** | 新建 `test/services/vault_pairing_service_test.dart`，使用 `MockClient` 模拟 5 个端点（createSession / joinSession / getHostSessionStatus / approveSession / getBundle），覆盖成功/HTTP 错误/网络异常/JSON 异常路径。 |
| **验收标准** | 1. 覆盖率 ≥ 80%；2. 至少覆盖 4 种 HTTP 错误码（401/403/404/500）；3. `flutter test` 通过。 |
| **工作量** | 中 |
| **关联测试文件** | 新建 `test/services/vault_pairing_service_test.dart` |

### T-002 — 为 `VaultImportExportCoordinator` 补充单元测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/system/service_manager/vault_import_export_coordinator.dart` |
| **当前覆盖率** | **1.3%** (77 行仅命中 1 行) |
| **问题描述** | 保险库导入导出协调器涉及数据库整体替换（`replaceAllDataForImport`）与回滚逻辑，当前几乎裸奔。数据导入是单点故障高危操作。 |
| **建议修复方式** | 利用已有的 `test/system/vault_import_rollback_test.dart` 作为参考，扩展覆盖导入预览、格式校验、部分失败回滚、T14 规则执行路径。 |
| **验收标准** | 1. 覆盖率 ≥ 75%；2. 验证回滚后数据库状态与导入前一致；3. 验证 `replaceAllDataForImport` 的 HLC/deviceId 保留行为。 |
| **工作量** | 中 |
| **关联测试文件** | `test/system/vault_import_export_coordinator_test.dart`（已有，需大幅扩展） |

### T-003 — 为 `VaultPairingCoordinator` 补充单元测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/system/service_manager/vault_pairing_coordinator.dart` |
| **当前覆盖率** | **5.3%** (57 行仅命中 3 行) |
| **问题描述** | 配对流程编排器，调用 `VaultPairingCrypto` 与 `IdentityService`，处理 X25519 密钥交换和 bundle 解密。安全敏感且逻辑分支多。 |
| **建议修复方式** | 扩展 `test/system/vault_pairing_coordinator_test.dart`，注入 Fake 的 `VaultPairingService` / `IdentityService`，覆盖 LAN 配对与服务端配对两条主路径，以及 Web 平台抛异常分支。 |
| **验收标准** | 1. 覆盖率 ≥ 75%；2. 覆盖 `kIsWeb` 抛异常分支；3. 覆盖配对码校验失败路径。 |
| **工作量** | 中 |
| **关联测试文件** | `test/system/vault_pairing_coordinator_test.dart`（已有，需扩展） |

### T-004 — 为 `HomeView` 及布局文件补充 Widget/集成测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/views/home/home_view.dart`、`home_view_desktop.dart`、`home_view_mobile.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | 主页根视图及桌面/移动端布局文件完全无测试，是用户解锁后的首个必经页面。 |
| **建议修复方式** | 新建 `test/views/home_view_test.dart`，使用 `ServiceManager.testable` 注入 Fake 依赖，验证：四栏 IndexedStack 切换、NavRail/NavBar 根据尺寸自适应、自动锁定监听挂载。桌面端和移动端分别用 `setSurfaceSize` 模拟。 |
| **验收标准** | 1. 桌面端尺寸 (≥1080px) 下验证 NavRail 存在；2. 移动端尺寸 (<720px) 下验证 BottomNavBar 存在；3. 验证四栏切换后各页标题/图标高亮正确。 |
| **工作量** | 大 |
| **关联测试文件** | 新建 `test/views/home_view_test.dart` |

### T-005 — 为 `SettingsView` 补充 Widget 测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/views/settings_view.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | 设置中心入口页面完全无测试，汇总各子设置页导航，是高频访问页面。 |
| **建议修复方式** | 新建 `test/views/settings_view_test.dart`，验证各设置分类标题/图标存在、点击跳转正确路由、当前版本号展示。 |
| **验收标准** | 1. 验证"个性化与外观"、"安全设置"、"同步设置"、"通知设置"入口可见；2. 点击后导航目标正确；3. `flutter test` 通过。 |
| **工作量** | 小 |
| **关联测试文件** | 新建 `test/views/settings_view_test.dart` |

### T-006 — 为 `main.dart` 启动流程补充测试/验证

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/main.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | 应用入口初始化 ServiceManager、Provider、主题、通知服务，无自动化验证。 |
| **建议修复方式** | 方案 A：新建 `test/main_test.dart` 提取 `main()` 中的初始化逻辑为可测试函数；方案 B：在集成测试中增加一条用例验证冷启动流程。建议采用方案 B（`integration_test/smoke_happy_path_test.dart` 已覆盖解锁，扩展验证主题/通知初始化标记）。 |
| **验收标准** | 1. 冷启动后 `ServiceManager.instance.state == locked`；2. `ThemeProvider` 已加载持久化主题设置；3. `NotificationService` 初始化完成无异常。 |
| **工作量** | 中 |
| **关联测试文件** | `integration_test/smoke_happy_path_test.dart`（扩展） |

### T-007 — 为 TOTP 编辑/扫码页面补充 Widget 测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/views/accounts/totp_credential_edit_view.dart`、`totp_qr_scanner_view.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | TOTP 凭证编辑页（189 行）和 QR 扫码页（63 行）完全无测试，涉及 2FA 密钥输入与相机权限，属于安全敏感路径。 |
| **建议修复方式** | `totp_credential_edit_view.dart`：使用 `tester.enterText` 模拟 secret/issuer 输入，验证 otpauth URI 粘贴解析、实时预览更新、保存后数据正确。`totp_qr_scanner_view.dart`：因依赖 `MobileScanner`，建议 mock 平台通道返回扫描结果字符串，验证解析成功/失败路径。 |
| **验收标准** | 1. 手动输入 secret → 预览区显示正确 TOTP 码；2. 粘贴合法 otpauth URI → 字段自动填充；3. 扫码 mock 返回合法 URI → 跳转编辑页并预填充。 |
| **工作量** | 大 |
| **关联测试文件** | 新建 `test/views/totp_credential_edit_view_test.dart`、`test/views/totp_qr_scanner_view_test.dart` |

### T-008 — 修复 `TemplateConflictLog.fromJson` 零容错反序列化

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/models/template_conflict_log.dart` |
| **当前覆盖率** | 模型测试 100%，但生产风险高 |
| **问题描述** | `fromJson` 为严格模式，任何字段缺失或类型错误均抛出 `TypeError`，与项目中其他模型的宽容策略不一致。同步冲突或数据损坏时可能导致日志无法恢复。 |
| **建议修复方式** | 为各字段补充 fallback：`id` 缺失时生成 UUID；`localHlc`/`remoteHlc` 缺失时 fallback `Hlc.zero('local')`；`savedAt` 缺失时 fallback 当前时间戳；字符串字段缺失时 fallback `''`。保持与 `AccountItem.fromJson` 风格一致。 |
| **验收标准** | 1. 缺失 1–3 个字段的 JSON 仍可反序列化成功；2. 补充的 fallback 值不会导致 CRDT 比较逻辑异常；3. 原有完整 JSON 的测试仍通过；4. `test/models/template_conflict_log_test.dart` 新增容错用例。 |
| **工作量** | 小 |
| **关联测试文件** | `test/models/template_conflict_log_test.dart` |

### T-009 — 统一 `isDeleted` 布尔值解析策略

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/models/account_item.dart`、`account_template.dart`、`totp_credential.dart` |
| **当前覆盖率** | — |
| **问题描述** | `AccountItem` 和 `TotpCredential` 的 `isDeleted` 支持 `1` 或 `true`，但 `AccountTemplate` 的 `isDeleted` 仅支持 `true`。若在同一 SQLite 风格表中存储，存在兼容性隐患。 |
| **建议修复方式** | 将 `AccountTemplate.fromJson` 中 `isDeleted` 的解析改为与 `AccountItem` 一致：`json['isDeleted'] == true \|\| json['isDeleted'] == 1`。同步更新 `toJson` 保持输出一致。 |
| **验收标准** | 1. `AccountTemplate.fromJson({'isDeleted': 1})` 返回 `isDeleted == true`；2. 三个模型的解析逻辑在测试中被显式对比验证；3. 现有测试全部通过。 |
| **工作量** | 小 |
| **关联测试文件** | `test/models/account_template_test.dart` |

### T-010 — 重写 `docs/wiki/testing-guide.md`

| 字段 | 内容 |
|------|------|
| **文件路径** | `docs/wiki/testing-guide.md` |
| **当前覆盖率** | — |
| **问题描述** | 严重过期：测试文件数写作 24，实际约 66；用例数写作 120+，实际 533+；Widget 测试写作 1 个，实际 23 个文件；完全遗漏 `providers/`、`system/`、`theme/`、`utils/`、`views/` 目录。 |
| **建议修复方式** | 按当前 `test/` 实际结构重写：列出 10 个测试子目录及文件数、说明 540+ 用例构成、更新 Fake/ harness/ mock 平台通道等测试模式说明、补充 Windows 测试特殊命令。 |
| **验收标准** | 1. 测试文件数、用例数、Widget 测试数与实际代码误差 ≤ 5%；2. 涵盖所有 10 个子目录；3. 提及 `tool/flutter_test.ps1`。 |
| **工作量** | 中 |
| **关联测试文件** | — |

### T-011 — 修正文档中的 `ConflictLog`/`vault.dart` 错误引用

| 字段 | 内容 |
|------|------|
| **文件路径** | `docs/wiki/api-reference.md`、`data-models.md`、`sync/sync-protocol.md`、`product/application-characteristics.md` |
| **当前覆盖率** | — |
| **问题描述** | 多处文档引用不存在的 `ConflictLogService` 和 `ConflictLog` 类名，以及不存在的 `lib/models/vault.dart` 文件，误导开发者。 |
| **建议修复方式** | 统一全局替换：`ConflictLogService` → `SecureStorageService.saveConflictLogs` / `TemplateConflictLog` 相关描述；`ConflictLog` → `TemplateConflictLog`；`lib/models/vault.dart` → 删除或改为说明 Vault 概念分散在 `IdentityService` / `SecureStorageService` 中。 |
| **验收标准** | 1. 4 份文档中无 `ConflictLogService`、`ConflictLog`（除历史上下文外）、`lib/models/vault.dart` 残留；2. `grep` 验证通过。 |
| **工作量** | 小 |
| **关联测试文件** | — |

### T-012 — 为 `account_edit_utils.dart` 补充单元测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/views/accounts/account_edit_utils.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | 账号编辑通用工具（57 行）完全无测试，被 `account_edit_view.dart` 高频调用。 |
| **建议修复方式** | 新建 `test/views/account_edit_utils_test.dart`，覆盖字段映射、历史保留、模板切换时的数据迁移逻辑。 |
| **验收标准** | 1. 覆盖率 ≥ 80%；2. 覆盖模板切换时旧字段保留逻辑；3. `flutter test` 通过。 |
| **工作量** | 小 |
| **关联测试文件** | 新建 `test/views/account_edit_utils_test.dart` |

---

## P1 重要任务（质量提升）

> **执行原则**：P1 任务不阻塞发布，但直接影响 70% 覆盖率目标与代码可维护性。

### T-013 — 修复并增强 `TemplateListView` 测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/views/templates/template_list_view.dart` |
| **当前覆盖率** | **0.2%** (598 行仅命中 1 行) |
| **问题描述** | 已有 `test/views/template_list_view_test.dart` 但几乎未有效执行源码（598 行仅 1 命中），可能是测试未 pump 到目标 widget 或 widget 被条件渲染绕过。 |
| **建议修复方式** | 检查现有测试的 `pumpWidget` 路径，确保 `TemplateListView` 被正确渲染（而非仅渲染外层 shell）。补充：模板网格存在性、内置/自定义模板分类展示、使用率统计展示、点击跳转编辑。 |
| **验收标准** | 1. 覆盖率 ≥ 50%；2. 至少命中 300+ 行；3. 现有测试文件通过且不删除已有用例。 |
| **工作量** | 大 |
| **关联测试文件** | `test/views/template_list_view_test.dart` |

### T-014 — 提升 `LanSyncClient` 测试覆盖率

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/sync/lan_sync_client.dart` |
| **当前覆盖率** | **21.7%** |
| **问题描述** | LAN 同步客户端存在单元测试但命中行数偏低，UDP 发现 / HTTP 请求 / 超时处理分支未充分覆盖。 |
| **建议修复方式** | 扩展 `test/sync/lan_sync_client_test.dart`，使用 `MockClient` 模拟 HTTP 响应，注入可控的 UDP socket mock（或抽象 UDP 层），覆盖发现超时、claim 成功/失败、bundle 解密路径。 |
| **验收标准** | 1. 覆盖率 ≥ 60%；2. 覆盖网络超时和 HTTP 4xx 错误路径；3. `flutter test` 通过。 |
| **工作量** | 中 |
| **关联测试文件** | `test/sync/lan_sync_client_test.dart` |

### T-015 — 提升 `LanSyncHostHandler` 测试覆盖率

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/sync/lan_sync_host_handler.dart` |
| **当前覆盖率** | **22.1%** |
| **问题描述** | LAN 同步主机处理器与 `LanSyncClient` 对称，覆盖率同样偏低。 |
| **建议修复方式** | 扩展 `test/sync/lan_sync_host_handler_test.dart`，覆盖主机启动/停止、配对码校验、请求方公钥接收、bundle 加密传输路径。 |
| **验收标准** | 1. 覆盖率 ≥ 60%；2. 覆盖非法配对码拒绝路径；3. `flutter test` 通过。 |
| **工作量** | 中 |
| **关联测试文件** | `test/sync/lan_sync_host_handler_test.dart` |

### T-016 — 为 `DeviceAliasService` 建立独立测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/services/device_alias_service.dart` |
| **当前覆盖率** | **33.3%**（间接触及，无独立测试文件） |
| **问题描述** | 设备别名解析与缓存服务无独立测试，是 `services/` 目录中唯一无测试文件的服务（除 `vault_pairing_service`）。 |
| **建议修复方式** | 新建 `test/services/device_alias_service_test.dart`，使用 `SharedPreferences.setMockInitialValues` 模拟缓存，覆盖 `resolve` 的缓存命中/l10n 回退/deviceId 缩写逻辑、`setAlias`/`setCurrentDeviceAlias` 持久化。 |
| **验收标准** | 1. 覆盖率 ≥ 80%；2. 覆盖别名缺失时的 l10n 回退路径；3. `flutter test` 通过。 |
| **工作量** | 小 |
| **关联测试文件** | 新建 `test/services/device_alias_service_test.dart` |

### T-017 — 提升 `AccountEditWidgets` 测试覆盖率

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/widgets/account_edit_widgets.dart` |
| **当前覆盖率** | **27.1%** |
| **问题描述** | 账户编辑表单组件被 `account_edit_view_test.dart` 间接触及，但独立 Widget 测试不足，大量分支未命中。 |
| **建议修复方式** | 新建 `test/widgets/account_edit_widgets_test.dart`，独立渲染各编辑字段组件，验证输入校验、密码掩码切换、字段复制按钮、TOTP 关联选择器。 |
| **验收标准** | 1. 覆盖率 ≥ 60%；2. 覆盖 `AccountFieldRow` / `AccountFieldRowBody` 的 Legacy 兼容路径；3. `flutter test` 通过。 |
| **工作量** | 中 |
| **关联测试文件** | 新建 `test/widgets/account_edit_widgets_test.dart` |

### T-018 — 提升 `AppDesignTokens` 测试覆盖率

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/theme/app_design_tokens.dart` |
| **当前覆盖率** | **32.6%** |
| **问题描述** | 设计令牌文件部分被测试，但大量颜色/间距/圆角常量未命中。 |
| **建议修复方式** | 扩展 `test/theme/app_design_tokens_test.dart`，为所有 `AppColors`、`AppSpacing`、`AppRadii`、`AppAlphas` 常量增加非空/类型断言，验证暗色/OLED 主题下的颜色差异。 |
| **验收标准** | 1. 覆盖率 ≥ 80%；2. 所有 Token 值非空且类型正确；3. `flutter test` 通过。 |
| **工作量** | 小 |
| **关联测试文件** | `test/theme/app_design_tokens_test.dart` |

### T-019 — 为 `ServiceManager` 门面方法补充 dartdoc

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/services/service_manager.dart` |
| **当前覆盖率** | — |
| **问题描述** | `ServiceManager` 是全局门面，但类本身及所有公共业务方法（`unlockWithPassword`、`saveAccount`、`syncNow`、`connectToSyncServer`、`changeMasterPassword`、`resetApplication` 等）均无 dartdoc。 |
| **建议修复方式** | 为类添加类级 dartdoc（说明全局单例职责、生命周期状态机、线程安全假设）；为高频调用的门面方法添加方法级 dartdoc（说明前置条件如 `isUnlocked`、参数含义、异常行为、返回值语义）。 |
| **验收标准** | 1. `ServiceManager` 类有 ≥ 3 行 dartdoc；2. ≥ 15 个公共方法有 dartdoc；3. `dartdoc` 生成无警告。 |
| **工作量** | 中 |
| **关联测试文件** | — |

### T-020 — 为核心服务类补充类级 dartdoc（批次一：安全/存储/身份）

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/services/secure_storage_service.dart`、`enhanced_crypto_service.dart`、`identity_service.dart`、`auto_lock_service.dart`、`database_file_cipher.dart`、`database_file_key_manager.dart` |
| **当前覆盖率** | — |
| **问题描述** | 6 个安全/存储/身份核心服务完全无类级 dartdoc，接入成本高。 |
| **建议修复方式** | 每个类补充类级 dartdoc：说明核心职责、生命周期方法（initialize/close/unlock）、关键设计约束（如 `SecureStorageService` 的原子写、AES-GCM-256 envelope 等）。 |
| **验收标准** | 1. 6 个类均有类级 dartdoc；2. 每个 dartdoc ≥ 2 行；3. 风格参考 `SensitiveClipboardService`（现有最佳实践）。 |
| **工作量** | 中 |
| **关联测试文件** | — |

### T-021 — 为剩余服务类补充类级 dartdoc（批次二：TOTP/配对/通知/健康）

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/services/totp_service.dart`、`totp_import_service.dart`、`totp_qr_image_import_service.dart`、`lan_pairing_service.dart`、`vault_pairing_crypto.dart`、`vault_pairing_service.dart`、`notification_service.dart`、`vault_health_calculator.dart`、`device_alias_service.dart` |
| **当前覆盖率** | — |
| **问题描述** | 9 个服务类/数据类无类级 dartdoc。 |
| **建议修复方式** | 批量补充类级 dartdoc（说明职责即可，方法级可后续迭代）。`TotpConfig`、`TotpCode` 作为数据类需说明字段含义。 |
| **验收标准** | 1. 9 个类均有类级 dartdoc；2. `TotpConfig`/`TotpCode` 有字段说明。 |
| **工作量** | 中 |
| **关联测试文件** | — |

### T-022 — 为 `AccountFieldMeta` 补充 `copyWith`

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/models/account_item.dart`（内嵌 `AccountFieldMeta`） |
| **当前覆盖率** | — |
| **问题描述** | `AccountFieldMeta` 无 `copyWith`，UI 状态更新或字段元数据修改时需手动构造对象，容易遗漏 `sourceTemplateVersion` 等字段。 |
| **建议修复方式** | 为 `AccountFieldMeta` 添加 `copyWith` 方法，覆盖 `type`、`label`、`sourceTemplateId`、`sourceTemplateVersion` 4 个字段。 |
| **验收标准** | 1. `copyWith` 覆盖全部 4 个字段；2. 补充 `test/models/account_item_test.dart` 或新建 `test/models/account_field_meta_test.dart` 验证；3. `flutter test` 通过。 |
| **工作量** | 小 |
| **关联测试文件** | `test/models/account_item_test.dart` |

### T-023 — 为 `AccountFieldAttributes` 补充 `copyWith`

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/models/account_template.dart`（内嵌 `AccountFieldAttributes`） |
| **当前覆盖率** | — |
| **问题描述** | `AccountFieldAttributes` 无 `copyWith`，模板字段属性变更时手动构造易丢失 HLC。 |
| **建议修复方式** | 为 `AccountFieldAttributes` 添加 `copyWith`，覆盖全部 13 个字段（含 nullable 的 `maxLength`/`minLength`/`regex`/`hint`）。 |
| **验收标准** | 1. `copyWith` 覆盖全部 13 个字段；2. 补充测试验证；3. `flutter test` 通过。 |
| **工作量** | 小 |
| **关联测试文件** | `test/models/account_template_test.dart` |

### T-024 — 为 `TemplateConflictLog` 补充 `copyWith`

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/models/template_conflict_log.dart` |
| **当前覆盖率** | — |
| **问题描述** | `TemplateConflictLog` 无 `copyWith`，冲突日志在 UI 状态流转中不方便安全复制。 |
| **建议修复方式** | 添加 `copyWith` 覆盖全部 9 个字段。 |
| **验收标准** | 1. `copyWith` 覆盖全部 9 个字段；2. 补充 `test/models/template_conflict_log_test.dart` 用例；3. `flutter test` 通过。 |
| **工作量** | 小 |
| **关联测试文件** | `test/models/template_conflict_log_test.dart` |

### T-025 — 为 `SyncSettingsView` 补充 Widget 测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/views/sync_settings_view.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | 同步设置页面完全无测试，包含服务器 URL 配置、即时同步触发、配对入口、恢复码/备份包入口等高风险路径。 |
| **建议修复方式** | 新建 `test/views/sync_settings_view_test.dart`，验证：URL 输入框存在、即时同步按钮触发 `syncNow`、配对入口可见、诊断信息区域存在。 |
| **验收标准** | 1. 验证服务器 URL 输入/保存交互；2. 验证移动端 loopback 拒绝提示（如代码中有条件渲染）；3. `flutter test` 通过。 |
| **工作量** | 中 |
| **关联测试文件** | 新建 `test/views/sync_settings_view_test.dart` |

### T-026 — 为 `LocalSyncQueueView` 补充 Widget 测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/views/sync/local_sync_queue_view.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | 本地同步变更箱页面完全无测试，展示 create/update/delete 变更列表，支持单条/批量推送和撤销。 |
| **建议修复方式** | 新建 `test/views/local_sync_queue_view_test.dart`，注入含预设变更的 Fake `SecureStorageService`，验证列表渲染、推送按钮状态、撤销交互。 |
| **验收标准** | 1. 空状态正确展示；2. 有变更时列表项渲染正确；3. 点击推送触发对应 ServiceManager 方法。 |
| **工作量** | 中 |
| **关联测试文件** | 新建 `test/views/local_sync_queue_view_test.dart` |

### T-027 — 为通知中心/通知设置页面补充 Widget 测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/views/notifications/notification_center_view.dart`、`settings/notification_settings_view.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | 通知聚合页和通知设置页完全无测试。 |
| **建议修复方式** | 新建 `test/views/notification_center_view_test.dart`：验证分组展示、未读标记、已读/删除交互。新建 `test/views/notification_settings_view_test.dart`：验证开关状态、过期天数滑块/输入。 |
| **验收标准** | 1. 通知中心空状态/有数据状态均验证；2. 通知设置页开关切换后状态持久（mock SharedPreferences）；3. `flutter test` 通过。 |
| **工作量** | 中 |
| **关联测试文件** | 新建 `test/views/notification_center_view_test.dart`、`test/views/notification_settings_view_test.dart` |

### T-028 — 为 `VaultHealthView` 补充 Widget 测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/views/settings/vault_health_view.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | 保险库体检详情页完全无测试，展示健康评分、风险卡片、一键跳转。 |
| **建议修复方式** | 新建 `test/views/vault_health_view_test.dart`，注入 Fake `VaultHealthCalculator` 返回预设报告，验证评分展示、风险项卡片渲染、跳转按钮存在。 |
| **验收标准** | 1. 各风险等级（excellent/good/warning/critical）UI 正确；2. 风险卡片点击跳转目标正确；3. `flutter test` 通过。 |
| **工作量** | 中 |
| **关联测试文件** | 新建 `test/views/vault_health_view_test.dart` |

### T-029 — 为 `HomeSearchView` 补充 Widget 测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/views/home/home_search_view.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | 全局搜索视图完全无测试，是高频使用功能。 |
| **建议修复方式** | 新建 `test/views/home_search_view_test.dart`，注入含预设账号的 Fake provider，验证关键字过滤、模板多选过滤、清除输入、结果点击跳转。 |
| **验收标准** | 1. 输入关键字后列表正确过滤；2. 无结果时展示空状态；3. `flutter test` 通过。 |
| **工作量** | 中 |
| **关联测试文件** | 新建 `test/views/home_search_view_test.dart` |

### T-030 — 扩展集成测试覆盖高风险路径

| 字段 | 内容 |
|------|------|
| **文件路径** | `integration_test/` |
| **当前覆盖率** | 7 个用例，全为桌面端 |
| **问题描述** | 集成测试未覆盖：生物识别解锁、同步设置/配对、模板冲突处理、通知中心、暗色主题切换、数据导入导出、LAN 同步、TOTP 扫码；缺少移动端布局验证。 |
| **建议修复方式** | 在 `regression_boundary_test.dart` 或新增文件中补充：移动端尺寸 (`Size(390, 844)`) 下的主页布局验证、主题切换后颜色验证、导入导出流程验证。受限于相机硬件，TOTP 扫码和生物识别以 mock 方式覆盖。 |
| **验收标准** | 1. 新增 ≥ 3 个集成测试用例；2. 至少 1 个用例在移动端尺寸下运行；3. CI 通过。 |
| **工作量** | 大 |
| **关联测试文件** | `integration_test/regression_boundary_test.dart`（扩展） |

### T-031 — 清理未使用的 pubspec 依赖

| 字段 | 内容 |
|------|------|
| **文件路径** | `pubspec.yaml` |
| **当前覆盖率** | — |
| **问题描述** | `file_picker: ^11.0.2` 和 `share_plus: ^12.0.2` 在 `lib/` 中零 import/调用，增加构建体积和供应链攻击面。 |
| **建议修复方式** | 从 `pubspec.yaml` 的 `dependencies` 中移除 `file_picker` 和 `share_plus`，运行 `flutter pub get`，确认 `lib/` 和 `test/` 无编译错误。 |
| **验收标准** | 1. `pubspec.yaml` 和 `pubspec.lock` 中无这两项；2. `flutter analyze` 0 error；3. `flutter test` 全部通过。 |
| **工作量** | 小 |
| **关联测试文件** | — |

### T-032 — 补充 Windows / Linux 本地通知初始化配置

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/services/notification_service.dart` |
| **当前覆盖率** | — |
| **问题描述** | `InitializationSettings` 仅配置了 android/iOS/macOS，Windows 完全不支持本地推送，Linux 因未初始化而实际上不可用。 |
| **建议修复方式** | 在 `NotificationService.init()` 中补充 `linux:` 初始化设置（`LinuxInitializationSettings`）。Windows 端 `flutter_local_notifications` 无官方实现，需在文档中明确标注不支持，或在代码中降级为应用内通知-only。 |
| **验收标准** | 1. Linux 平台初始化设置存在且 `flutter analyze` 通过；2. Windows 平台不抛异常（ graceful 降级）；3. 现有 macOS/Android 通知行为不变。 |
| **工作量** | 中 |
| **关联测试文件** | `test/services/notification_service_test.dart` |

### T-033 — 更新 `docs/architecture/01-system-architecture.md`

| 字段 | 内容 |
|------|------|
| **文件路径** | `docs/architecture/01-system-architecture.md` |
| **当前覆盖率** | — |
| **问题描述** | `lib/` 核心结构描述遗漏 `core/`、`system/`、`theme/`、`utils/` 四个一级目录；Container Diagram 中无 `system/` 协调器、LAN Sync 组件、Theme 层。 |
| **建议修复方式** | 更新目录结构描述为完整 10 个一级目录；在 Container Diagram 中增加 `system/` 协调器群、`LanPairingService`、`ThemeProvider` / `AppTheme`。 |
| **验收标准** | 1. 文档列出的 `lib/` 一级目录与实际完全一致；2. Container Diagram 与代码依赖关系一致；3. 无过时类名。 |
| **工作量** | 中 |
| **关联测试文件** | — |

### T-034 — 更新 `docs/sync/sync-protocol.md`

| 字段 | 内容 |
|------|------|
| **文件路径** | `docs/sync/sync-protocol.md` |
| **当前覆盖率** | — |
| **问题描述** | 伪代码引用不存在的 `ConflictLogService`；未提及 LAN 同步子系统；HLC 比较逻辑描述错误；安全评估段落低估当前实现（已是标准 AES-256-GCM+HKDF）。 |
| **建议修复方式** | 替换伪代码中的 `ConflictLogService` 为 `SecureStorageService.saveConflictLogs` / `TemplateConflictLog`；补充 LAN 同步协议概述（UDP 发现 + HTTP claim + X25519）；修正 HLC 比较逻辑描述；更新安全评估为 T3 完成后的正式契约。 |
| **验收标准** | 1. 无 `ConflictLogService` 残留；2. LAN 同步子系统至少有一节概述；3. 安全评估段落与当前 `SyncPayloadCodec` 实现一致。 |
| **工作量** | 中 |
| **关联测试文件** | — |

---

## P2 优化任务（长期维护）

> **执行原则**：P2 任务可在技术债日或后续迭代中逐步消化。

### T-035 — 为边缘视图页面补充 Widget 测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/views/accounts/account_subset_view.dart`、`release_note_view.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | 账户子集筛选页和发布说明页无测试，属于低频路径。 |
| **建议修复方式** | `account_subset_view.dart`：注入预设账号验证分组展示和空状态。`release_note_view.dart`：验证静态内容渲染无异常。 |
| **验收标准** | 1. 两个页面均有独立测试文件；2. `flutter test` 通过。 |
| **工作量** | 小 |
| **关联测试文件** | 新建 `test/views/account_subset_view_test.dart`、`test/views/release_note_view_test.dart` |

### T-036 — 为边缘组件补充 Widget 测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/widgets/inbox/inbox_filter_bar.dart`、`selection_indicator.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | 收件箱过滤栏和选择指示器无独立测试。 |
| **建议修复方式** | 新建对应测试文件，验证渲染和交互（过滤栏切换状态、指示器动画/状态）。 |
| **验收标准** | 1. 两个组件均有独立测试文件；2. `flutter test` 通过。 |
| **工作量** | 小 |
| **关联测试文件** | 新建 `test/widgets/inbox_filter_bar_test.dart`、`test/widgets/selection_indicator_test.dart` |

### T-037 — 为布局/同步相关组件补充 Widget 测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/widgets/app_layout_builder.dart`、`lan_sync_conflict_sheet.dart`、`sync_settings_dialogs.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | 跨平台布局构建器和同步相关 BottomSheet/对话框无测试。 |
| **建议修复方式** | 新建测试文件，验证各尺寸断点下的布局选择、冲突 Sheet 的接受/拒绝交互、同步设置对话框的表单校验。 |
| **验收标准** | 1. `app_layout_builder` 在 compact/medium/expanded 三种尺寸下返回正确布局；2. 冲突 Sheet 按钮触发正确回调；3. `flutter test` 通过。 |
| **工作量** | 中 |
| **关联测试文件** | 新建 `test/widgets/app_layout_builder_test.dart`、`lan_sync_conflict_sheet_test.dart`、`sync_settings_dialogs_test.dart` |

### T-038 — 编写 `lib/system/` 架构说明文档

| 字段 | 内容 |
|------|------|
| **文件路径** | 新建 `docs/architecture/07-system-modules.md` |
| **当前覆盖率** | — |
| **问题描述** | `system/` 含 7+ 核心协调器，但架构文档完全未提及该目录，新人难以理解 Coordinator 职责边界。 |
| **建议修复方式** | 新增文档，说明各 Coordinator 职责：`VaultUnlockCoordinator`、`VaultDataRepository`、`VaultDumpCoordinator`、`VaultImportExportCoordinator`、`VaultPairingCoordinator`、`SyncCoordinator`、`SyncServerUrlStore`、`LanSyncCoordinator`。附职责边界图和与 ServiceManager 的交互关系。 |
| **验收标准** | 1. 每个 Coordinator 有 ≥ 2 行职责说明；2. 有 mermaid 依赖关系图；3. 无与代码矛盾的描述。 |
| **工作量** | 中 |
| **关联测试文件** | — |

### T-039 — 补充 LAN Sync 协议文档

| 字段 | 内容 |
|------|------|
| **文件路径** | 新建 `docs/sync/lan-sync-protocol.md` |
| **当前覆盖率** | — |
| **问题描述** | `lib/sync/lan_sync_*.dart` 已形成完整局域网同步子系统，但 `docs/sync/` 下无对应协议文档。 |
| **建议修复方式** | 编写 LAN 同步协议文档：UDP 广播发现格式、HTTP claim 端点、配对码字符集、`X25519` 密钥交换流程、`VaultPairingCrypto` 加密 bundle 格式、会话生命周期。 |
| **验收标准** | 1. 涵盖发现/配对/传输三阶段；2. 配对码字符集与代码一致（`ABCDEFGHJKLMNPQRSTUVWXYZ23456789`）；3. 有 mermaid 序列图。 |
| **工作量** | 中 |
| **关联测试文件** | — |

### T-040 — 更新 `docs/wiki/api-reference.md`

| 字段 | 内容 |
|------|------|
| **文件路径** | `docs/wiki/api-reference.md` |
| **当前覆盖率** | — |
| **问题描述** | 缺少 `DeviceAliasService`、`NotificationService`、`TotpImportService`、`TotpQrImageImportService`、`VaultHealthCalculator` 的 API 摘要。 |
| **建议修复方式** | 补充上述 5 个服务的公共方法签名和职责摘要（可复用 `01_services_api_scan.md` 中的结构化信息）。 |
| **验收标准** | 1. 5 个服务均有 API 摘要表格；2. 无 `ConflictLog` 等错误引用。 |
| **工作量** | 小 |
| **关联测试文件** | — |

### T-041 — 批量更新文档中的测试基线数字

| 字段 | 内容 |
|------|------|
| **文件路径** | `docs/todo.md`、`product/application-characteristics.md`、`product/iteration-tasks.md`、`qa/testing-automation-guide.md` |
| **当前覆盖率** | — |
| **问题描述** | 多处引用过时的测试基线（120 passed、127 passed、187 passed 等），当前实际为 533+ passed。 |
| **建议修复方式** | 批量替换为当前基线：533+ passed / 1 skipped / 540 total（含集成测试）。`testing-automation-guide.md` 中 Widget Tests/E2E Smoke 数量同步更新。 |
| **验收标准** | 1. 4 份文档中的测试数字与实际误差 ≤ 5%；2. `grep` 无 "120 passed" / "127 passed" 等过时基线残留。 |
| **工作量** | 小 |
| **关联测试文件** | — |

### T-042 — 修复 `green_add_button.dart` 硬编码品牌色

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/widgets/green_add_button.dart` |
| **当前覆盖率** | — |
| **问题描述** | 硬编码 `Color(0xFF1FA463)`，未使用 `AppDesignTokens`，主题一致性风险。 |
| **建议修复方式** | 将品牌色提取到 `AppDesignTokens`（如新增 `AppColors.brandPrimary`），按钮引用该 Token。 |
| **验收标准** | 1. `green_add_button.dart` 无硬编码颜色值；2. 主题切换后按钮颜色仍正确；3. `flutter test` 通过。 |
| **工作量** | 小 |
| **关联测试文件** | — |

### T-043 — 拆分 `account_list_tile.dart` 超大文件

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/widgets/account_list_tile.dart` |
| **当前覆盖率** | — |
| **问题描述** | 单文件 1,321 行含 10 个 class，维护成本高，超出认知负荷。 |
| **建议修复方式** | 将内部子组件拆分为独立文件（如 `account_tile_header.dart`、`account_tile_field_row.dart`、`account_tile_actions.dart` 等），保持 `account_list_tile.dart` 作为 barrel 或主 tile 聚合。优先拆分已在其他位置复用的子组件。 |
| **验收标准** | 1. 拆分后原文件行数 ≤ 400 行；2. 所有拆分出的文件可被独立导入；3. `flutter test` 全部通过；4. `flutter analyze` 0 error。 |
| **工作量** | 大 |
| **关联测试文件** | `test/widgets/account_list_tile_test.dart` |

### T-044 — 清理 `AccountFieldRow` Legacy 兼容层

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/widgets/account_edit_widgets.dart` |
| **当前覆盖率** | — |
| **问题描述** | `AccountFieldRow` / `AccountFieldRowBody` 标注 "backward compatibility"，为 Legacy 兼容层，长期增加维护成本。 |
| **建议修复方式** | 检查全部引用点，确认新版字段编辑组件已完全替代后，删除 Legacy 兼容层及其测试分支。如仍有引用，先迁移引用再删除。 |
| **验收标准** | 1. `AccountFieldRow` / `AccountFieldRowBody` 相关代码已删除或确认仍必要；2. 如删除，所有原引用点已迁移；3. `flutter test` / `flutter analyze` 通过。 |
| **工作量** | 中 |
| **关联测试文件** | `test/widgets/account_edit_widgets_test.dart`（T-017） |

### T-045 — 为 `theme.dart` barrel 文件添加测试

| 字段 | 内容 |
|------|------|
| **文件路径** | `lib/theme/theme.dart` |
| **当前覆盖率** | **0%** |
| **问题描述** | 主题 barrel 导出文件无测试，虽无复杂逻辑，但可验证导出完整性。 |
| **建议修复方式** | 新建 `test/theme/theme_test.dart`，导入 `theme.dart` 验证所有导出符号可访问。 |
| **验收标准** | 1. 所有 barrel 导出类/函数可被正常导入；2. `flutter test` 通过。 |
| **工作量** | 小 |
| **关联测试文件** | 新建 `test/theme/theme_test.dart` |

---

## 按模块分组的任务清单

> 方便团队成员按模块认领。目标覆盖率为模块内加权估算值。

### Models（数据模型）

| 模块 | 文件数 | 当前覆盖率 | 目标覆盖率 | 任务 | 任务编号 |
|------|--------|-----------|-----------|------|---------|
| models | 8 | ~85% | ~90% | 修复 `TemplateConflictLog` 零容错 + copyWith | T-008, T-024 |
| models | 8 | ~85% | ~90% | 统一 `isDeleted` 布尔解析 | T-009 |
| models | 8 | ~85% | ~90% | 补充 `AccountFieldMeta` copyWith | T-022 |
| models | 8 | ~85% | ~90% | 补充 `AccountFieldAttributes` copyWith | T-023 |

### Services（服务层）

| 模块 | 文件数 | 当前覆盖率 | 目标覆盖率 | 任务 | 任务编号 |
|------|--------|-----------|-----------|------|---------|
| services | 18 | ~65% | ~80% | `VaultPairingService` 单元测试 | T-001 |
| services | 18 | ~65% | ~80% | `DeviceAliasService` 独立测试 | T-016 |
| services | 18 | ~65% | ~80% | `ServiceManager` 门面方法 dartdoc | T-019 |
| services | 18 | ~65% | ~80% | 核心服务类 dartdoc（批次一） | T-020 |
| services | 18 | ~65% | ~80% | 剩余服务类 dartdoc（批次二） | T-021 |
| services | 18 | ~65% | ~80% | Windows/Linux 通知初始化 | T-032 |
| services | 18 | ~65% | ~80% | 清理未使用 pubspec 依赖 | T-031 |

### Sync（同步核心）

| 模块 | 文件数 | 当前覆盖率 | 目标覆盖率 | 任务 | 任务编号 |
|------|--------|-----------|-----------|------|---------|
| sync | 12 | ~60% | ~75% | `LanSyncClient` 覆盖率提升 | T-014 |
| sync | 12 | ~60% | ~75% | `LanSyncHostHandler` 覆盖率提升 | T-015 |
| sync | 12 | ~60% | ~75% | LAN Sync 协议文档 | T-039 |

### System（系统协调器）

| 模块 | 文件数 | 当前覆盖率 | 目标覆盖率 | 任务 | 任务编号 |
|------|--------|-----------|-----------|------|---------|
| system | 10 | ~55% | ~75% | `VaultImportExportCoordinator` 测试 | T-002 |
| system | 10 | ~55% | ~75% | `VaultPairingCoordinator` 测试 | T-003 |
| system | 10 | ~55% | ~75% | `system/` 架构说明文档 | T-038 |

### Views（视图层）

| 模块 | 文件数 | 当前覆盖率 | 目标覆盖率 | 任务 | 任务编号 |
|------|--------|-----------|-----------|------|---------|
| views | 24 | ~35% | ~60% | `HomeView` + 布局测试 | T-004 |
| views | 24 | ~35% | ~60% | `SettingsView` 测试 | T-005 |
| views | 24 | ~35% | ~60% | `main.dart` 启动验证 | T-006 |
| views | 24 | ~35% | ~60% | TOTP 编辑/扫码测试 | T-007 |
| views | 24 | ~35% | ~60% | `TemplateListView` 测试修复 | T-013 |
| views | 24 | ~35% | ~60% | `SyncSettingsView` 测试 | T-025 |
| views | 24 | ~35% | ~60% | `LocalSyncQueueView` 测试 | T-026 |
| views | 24 | ~35% | ~60% | 通知中心/设置测试 | T-027 |
| views | 24 | ~35% | ~60% | `VaultHealthView` 测试 | T-028 |
| views | 24 | ~35% | ~60% | `HomeSearchView` 测试 | T-029 |
| views | 24 | ~35% | ~60% | `account_edit_utils.dart` 测试 | T-012 |
| views | 24 | ~35% | ~60% | 边缘视图测试（子集/版本说明） | T-035 |

### Widgets（组件层）

| 模块 | 文件数 | 当前覆盖率 | 目标覆盖率 | 任务 | 任务编号 |
|------|--------|-----------|-----------|------|---------|
| widgets | 25 | ~40% | ~60% | `AccountEditWidgets` 测试 | T-017 |
| widgets | 25 | ~40% | ~60% | 边缘组件测试（过滤栏/指示器） | T-036 |
| widgets | 25 | ~40% | ~60% | 布局/同步组件测试 | T-037 |
| widgets | 25 | ~40% | ~60% | `green_add_button.dart` 品牌色修复 | T-042 |
| widgets | 25 | ~40% | ~60% | `account_list_tile.dart` 拆分 | T-043 |
| widgets | 25 | ~40% | ~60% | `AccountFieldRow` Legacy 清理 | T-044 |

### Theme / Infrastructure（主题与基础设施）

| 模块 | 文件数 | 当前覆盖率 | 目标覆盖率 | 任务 | 任务编号 |
|------|--------|-----------|-----------|------|---------|
| theme | 4 | ~70% | ~85% | `AppDesignTokens` 覆盖率提升 | T-018 |
| theme | 4 | ~70% | ~85% | `theme.dart` barrel 测试 | T-045 |

### Docs（文档体系）

| 模块 | 文件数 | 当前状态 | 目标状态 | 任务 | 任务编号 |
|------|--------|---------|---------|------|---------|
| docs | 87 | 多处漂移 | 与代码同步 | `testing-guide.md` 重写 | T-010 |
| docs | 87 | 多处漂移 | 与代码同步 | 修正 `ConflictLog`/`vault.dart` 错误 | T-011 |
| docs | 87 | 多处漂移 | 与代码同步 | `architecture/01-system-architecture.md` 更新 | T-033 |
| docs | 87 | 多处漂移 | 与代码同步 | `sync/sync-protocol.md` 更新 | T-034 |
| docs | 87 | 多处漂移 | 与代码同步 | `api-reference.md` 更新 | T-040 |
| docs | 87 | 多处漂移 | 与代码同步 | 批量更新测试基线数字 | T-041 |

### Integration Tests（集成测试）

| 模块 | 当前用例 | 目标用例 | 任务 | 任务编号 |
|------|---------|---------|------|---------|
| integration_test | 7 | 10+ | 扩展集成测试覆盖 | T-030 |

---

## 快速收益任务（Quick Wins）

> 工作量 ≤ 0.5 人天、风险低、适合新人热身或碎片时间完成。

| 编号 | 任务 | 预估工作量 | 预期收益 | 关联任务 |
|------|------|-----------|---------|---------|
| Q-001 | `docs/wiki/development-setup.md` 中 `dart.lineLength` 100 → 120 | 10 分钟 | 消除新人配置误导 | — |
| Q-002 | `docs/todo.md` 勾选 T13/T14（实际已完成） | 10 分钟 | 文档状态准确 | T-041 |
| Q-003 | 为 `default_sync_server_url.dart` 补充简单单元测试（8 行，0% 覆盖） | 20 分钟 | +8 命中行，消除 0% 文件 | — |
| Q-004 | 为 `theme.dart` 编写 barrel 导入测试 | 20 分钟 | 验证导出完整性 | T-045 |
| Q-005 | 为 `inbox_models.dart`（1 行，0%）补充测试 | 15 分钟 | 消除 0% 文件 | — |
| Q-006 | 在 `test/fakes/` 中新增 `FakeDeviceAliasService` | 30 分钟 | 为 T-016 和后续视图测试提供依赖注入基础 | T-016 |
| Q-007 | `l10n/app_localizations_en.dart` 加入 coverage ignore（纯生成代码） | 10 分钟 | 避免生成代码拉低覆盖率统计 | — |
| Q-008 | 统一检查并补充 `views/` 中 6 个无测试文件的简单 `pumpWidget` 冒烟测试（settings_view / release_note_view / account_subset_view 等） | 2 小时 | 快速消除多个 0% 文件 | T-005, T-035 |

---

## 附录：验收检查清单

### 通用验收标准（适用于所有任务）

- [ ] `flutter analyze lib test` 返回 **0 error、0 warning（lib/ 目录内）**
- [ ] `flutter test` 全部通过（含新增测试）
- [ ] 新增/修改的代码符合现有代码风格（120 字符行宽、`package:` 导入）
- [ ] 如涉及模型变更，同步更新对应 `test/models/` 测试
- [ ] 如涉及文档变更，`grep` 确认无与代码矛盾的信息

### 测试类任务专项验收

- [ ] 新增测试文件命名符合现有惯例：`test/<层级>/<file_name>_test.dart`
- [ ] 使用 `ServiceManager.testable` / Fake 服务注入，避免污染真实数据
- [ ] Widget 测试使用 `addTearDown(() => ServiceManager.resetInstance())`
- [ ] 覆盖率目标达成（以 `flutter test --coverage` + `lcov` 为准）
- [ ] 测试包含至少一个负面路径（错误输入/异常/空状态）

### 文档类任务专项验收

- [ ] 文档中的数字/数量与实际代码误差 ≤ 5%
- [ ] 类名/文件名/路径名与代码完全一致
- [ ] 无 `ConflictLogService`、`ConflictLog`、`lib/models/vault.dart` 等错误引用残留
- [ ] 涉及架构变更的描述需经另一位开发者 review

### 代码质量修复类任务专项验收

- [ ] 兼容性修复需新增回归测试（旧格式/缺失字段/异常输入）
- [ ] `copyWith` 实现需覆盖全部字段，nullable 字段正确处理
- [ ] 布尔值/枚举解析统一后，三个模型（`AccountItem`/`AccountTemplate`/`TotpCredential`）的行为一致性在测试中显式断言
- [ ] 未使用的依赖清理后，`pubspec.lock` 同步更新

### 发布前最终检查（Sprint 结束 gate）

- [ ] 整体行覆盖率 ≥ **70%**（`coverage/lcov.info` 验证）
- [ ] P0 任务全部关闭
- [ ] `docs/wiki/testing-guide.md` 与实际测试结构一致
- [ ] 核心架构文档（`01-system-architecture.md`、`sync-protocol.md`）无与代码矛盾之处
- [ ] CI 流程（`flutter analyze` → `python3 tool/check_style_tokens.py` → `flutter test`）全部绿灯
