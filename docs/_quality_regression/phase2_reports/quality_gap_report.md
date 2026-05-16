# SecretRoy 客户端 — 质量缺口报告（阶段2）

> 生成时间：2026-05-16  
> 数据来源：`coverage/lcov.info`、`dart analyze`、阶段1扫描报告（01/03/07/08/00）  
> 分析范围：`lib/` 115个Dart文件、`test/` 74个测试文件、`docs/` 87个文档文件

---

## 1. 质量指标仪表盘

| 指标 | 当前值 | 来源/依据 |
|------|--------|----------|
| **整体行覆盖率** | **58.3%** (7,892 / 13,541 行) | `coverage/lcov.info`，96/115 文件被追踪 |
| **静态分析 Errors** | **0** | `dart analyze lib test` |
| **静态分析 Warnings** | **14** | 12 unused/duplicate import（均在 `test/`）、1 unused local variable |
| **静态分析 Infos** | **11** | 9 个 `no_leading_underscores_for_local_identifiers`（`test/`）、1 `annotate_overrides`、1 `await_only_futures` |
| **TODO / FIXME / HACK** | **0** | 全项目扫描（`lib/` + `test/` + `integration_test/`）零条记录 |
| **Style Token 违规** | **0** | 基线报告确认无硬编码 `BorderRadius.circular` / `withAlpha` / `AppBreakpoints.isDesktop` 违规 |
| **文档覆盖率（估算）** | **~15%** | 服务层 18 个公共类仅 1 个有完整类级 dartdoc；模型/视图/组件层类级文档普遍缺失 |
| **国际化完整度** | **100%** | 75 个 ARB key（zh/en）完全对齐，无缺失或漂移 |
| **测试用例总数** | **540** | `test/` 533 个 + `integration_test/` 7 个 |

**结论**：`lib/` 源码目录静态分析清洁（0 error、0 warning in lib/），质量风险集中在 **测试覆盖不足** 与 **文档缺失** 两个维度。

---

## 2. 按模块的质量缺口热力图

> 风险等级定义：🔴 高风险（覆盖率 <30% 或文档严重缺失）/ 🟡 中风险（有基础但存在明显缺口）/ 🟢 低风险（基本达标或轻微缺口）

| 模块 | 文件数 | 测试覆盖 | 文档完整 | 静态分析清洁度 | 关键缺口 |
|------|--------|---------|---------|---------------|---------|
| **models** | 8 | 🟢 | 🟡 | 🟢 | copyWith 缺失 3 个类；`TemplateConflictLog.fromJson` 零容错 |
| **services** | 18 | 🟡 | 🔴 | 🟢 | `vault_pairing_service.dart` 1.0%；18 个公共类仅 1 个有类级 dartdoc |
| **sync** | 12 | 🟡 | 🟡 | 🟢 | `lan_sync_client.dart` 21.7%；`lan_sync_host_handler.dart` 22.1% |
| **system** | 10 | 🟡 | 🔴 | 🟢 | `vault_import_export_coordinator.dart` 1.3%；`vault_pairing_coordinator.dart` 5.3%；架构文档完全缺失 |
| **views** | 24 | 🔴 | 🟡 | 🟢 | 19 个文件中有 6 个核心页面 0% 覆盖；`template_list_view.dart` 0.2% |
| **widgets** | 25 | 🔴 | 🟡 | 🟢 | `account_edit_widgets.dart` 27.1%；5+ 个组件无独立测试 |
| **providers** | 3 | 🟢 | 🟡 | 🟢 | 全部有测试，`theme_provider.dart` 100%；类级 dartdoc 待补 |

---

## 3. 高优先级修复清单（P0）

### 3.1 安全关键路径的低覆盖率模块

安全关键路径指涉及加密密钥、身份凭证、配对授权、数据导入导出的模块。当前以下模块覆盖率低于 10%，属于裸奔状态：

| 文件 | 覆盖率 | 可执行行 | 命中行 | 风险说明 |
|------|--------|---------|--------|---------|
| `lib/services/vault_pairing_service.dart` | **1.0%** | 98 | 1 | 服务端配对 HTTP API（创建/加入/审批/拉取 bundle），涉及 X-Vault-Token 与服务端通信 |
| `lib/system/service_manager/vault_import_export_coordinator.dart` | **1.3%** | 77 | 1 | 保险库导入导出协调器，涉及数据库整体替换（`replaceAllDataForImport`）与回滚 |
| `lib/system/service_manager/vault_pairing_coordinator.dart` | **5.3%** | 57 | 3 | 配对流程编排，调用 `VaultPairingCrypto` 与 `IdentityService`，安全敏感 |
| `lib/views/accounts/totp_credential_edit_view.dart` | **0.0%** | 189 | 0 | TOTP 凭证编辑页，用户直接输入/修改 2FA 密钥 |
| `lib/views/accounts/totp_qr_scanner_view.dart` | **0.0%** | 63 | 0 | QR 扫码页，调用相机权限与 `zxing2` 解码 |

### 3.2 无测试的核心页面

以下页面是用户旅程的必经节点，当前在 `lcov.info` 中完全无追踪（0%）：

- `lib/main.dart` — 应用入口，初始化 `ServiceManager`、Provider、主题、通知服务
- `lib/views/home/home_view.dart` — 主页根视图
- `lib/views/home/layouts/home_view_desktop.dart` — 桌面端主页布局
- `lib/views/home/layouts/home_view_mobile.dart` — 移动端主页布局
- `lib/views/settings_view.dart` — 设置中心入口
- `lib/views/accounts/account_edit_utils.dart` — 账户编辑通用工具（57 行）

### 3.3 文档与代码严重漂移的模块

| 文档 | 漂移类型 | 严重程度 | 证据 |
|------|---------|---------|------|
| `docs/guides/technical-documentation.md` | 遗漏 10 个服务文件；`ServiceManager` 内部服务列表过时；解锁流程描述与实际实现不一致 | 🔴 高 | 实际已使用 `VaultUnlockCoordinator`，文档仍描述逐行调用 |
| `docs/wiki/testing-guide.md` | 测试文件数 24→~66；用例数 120+→533+；Widget 测试 1→23 个文件；完全遗漏 `providers/`/`system/`/`theme/`/`utils/`/`views/` | 🔴 高 | 最后更新 2026-05-01，此后新增约 150+ 用例未同步 |
| `docs/sync/sync-protocol.md` | 伪代码引用不存在的 `ConflictLogService`；类名 `ConflictLog` 与实际 `TemplateConflictLog` 不符；未提及 LAN 同步子系统 | 🔴 高 | `grep -r "class ConflictLogService" lib/` 无结果 |
| `docs/wiki/data-models.md` | 声称 `lib/models/vault.dart` 存在，实际不存在 | 🔴 高 | `find lib/models -type f` 确认无该文件 |

---

## 4. 中优先级修复清单（P1）

### 4.1 有测试但覆盖率 <50% 的模块

| 文件 | 覆盖率 | 可执行行 | 命中行 | 说明 |
|------|--------|---------|--------|------|
| `lib/views/templates/template_list_view.dart` | **0.2%** | 598 | 1 | 598 行仅命中 1 行，虽有测试文件但实际未有效执行 |
| `lib/sync/lan_sync_client.dart` | **21.7%** | — | — | LAN 同步客户端，存在单元测试但命中行数偏低 |
| `lib/sync/lan_sync_host_handler.dart` | **22.1%** | — | — | LAN 同步主机处理器 |
| `lib/widgets/account_edit_widgets.dart` | **27.1%** | — | — | 账户编辑表单组件，被 `account_edit_view_test.dart` 间接触及 |
| `lib/services/device_alias_service.dart` | **33.3%** | — | — | 无独立测试文件，覆盖率来自间接触及 |
| `lib/theme/app_design_tokens.dart` | **32.6%** | — | — | 设计令牌，部分被测试 |
| `lib/views/accounts/account_edit_view.dart` | **~35.8%** | 1,606 | 575 | 最大视图文件之一，测试深度不足 |

### 4.2 缺失 dartdoc 的公共 API

以下公共类/枚举 **完全无类级 dartdoc**（依据 `01_services_api_scan.md`）：

**服务层（18 个）**：`AutoLockService`、`AutoLockObserver`、`AutoLockDuration`、`BiometricAuthService`、`DatabaseFileCipher`、`DatabaseFileKeyManager`、`DeviceAliasService`、`EnhancedCryptoService`、`IdentityService`、`LanPairingService`、`NotificationService`、`SecureStorageService`、`ServiceManager`、`TotpImportService`、`TotpQrImageImportService`、`TotpService`/`TotpConfig`/`TotpCode`、`VaultHealthCalculator`、`VaultPairingCrypto`/`VaultPairingService`

**关键门面方法无文档**：`ServiceManager.unlockWithPassword`、`saveAccount`、`syncNow`、`connectToSyncServer`、`changeMasterPassword`、`resetApplication` 等。

### 4.3 代码质量风险

| 位置 | 问题 | 风险 | 来源 |
|------|------|------|------|
| `TemplateConflictLog.fromJson` | **零容错**：任何字段缺失或类型错误均抛 `TypeError`，与项目中其他模型的宽容策略不一致 | 数据损坏/同步冲突时无法恢复日志 | `03_models_scan.md` |
| `AccountTemplate.fromJson` | `category` 依赖智能推断（含中英文关键词 + `iconCodePoint` + `fields` 内容），推断逻辑变更影响旧数据反序列化 | 分类不一致导致模板归类错误 | `03_models_scan.md` |
| `AccountItem` / `AccountTemplate` / `TotpCredential` | `isDeleted` 布尔解析策略不一致：`AccountItem` 支持 `1` 或 `true`；`AccountTemplate` 仅支持 `true` | 若在同一 SQLite 风格表中存储，可能存在兼容性隐患 | `03_models_scan.md` |
| `AccountFieldMeta` / `AccountFieldAttributes` / `TemplateConflictLog` | 缺少 `copyWith` 方法 | UI 状态更新或 CRDT 合并时容易因手动构造对象导致 HLC 丢失 | `03_models_scan.md` |

---

## 5. 低优先级修复清单（P2）

### 5.1 边缘页面/组件的测试补充

以下文件有 0% 覆盖率或几乎未覆盖，但属于低频/边缘路径：

- `lib/views/accounts/account_subset_view.dart` — 账户子集筛选
- `lib/views/release_note_view.dart` — 发布说明页
- `lib/widgets/inbox/inbox_filter_bar.dart` — 收件箱过滤栏
- `lib/widgets/selection_indicator.dart` — 选择指示器
- `lib/widgets/app_layout_builder.dart` — 跨平台布局构建器
- `lib/widgets/lan_sync_conflict_sheet.dart` — LAN 同步冲突 BottomSheet
- `lib/widgets/sync_settings_dialogs.dart` — 同步设置对话框
- `lib/theme/theme.dart` — 主题 barrel 导出文件（无复杂逻辑）

### 5.2 文档完善

| 任务 | 说明 |
|------|------|
| 为 `lib/system/` 编写架构说明 | 当前 `system/` 含 7+ 个核心协调器，但 `architecture/01-system-architecture.md` 完全未提及该目录 |
| 补充 LAN Sync 协议文档 | `lib/sync/lan_sync_*.dart` 已形成完整局域网同步子系统，`docs/sync/` 下无对应文档 |
| 更新 `docs/wiki/api-reference.md` | 缺失 `DeviceAliasService`、`NotificationService`、`TotpImportService`、`TotpQrImageImportService`、`VaultHealthCalculator` 等 5 个服务的 API 摘要 |
| 统一修正 `ConflictLog` → `TemplateConflictLog` | 影响 4 个文档文件：`api-reference.md`、`data-models.md`、`sync-protocol.md`、`application-characteristics.md` |

### 5.3 样式债务

| 位置 | 问题 | 依据 |
|------|------|------|
| `lib/widgets/green_add_button.dart` | 硬编码品牌色 `Color(0xFF1FA463)`，未使用 `AppDesignTokens` | `00_tech_baseline_overview.md` |
| `lib/views/accounts/account_list_tile.dart` | 单文件 1,321 行，含 10 个 class，维护成本高 | `00_tech_baseline_overview.md` |
| `lib/widgets/account_edit_widgets.dart` 内 `AccountFieldRow` / `AccountFieldRowBody` | Legacy 兼容层，标注 "backward compatibility" | `00_tech_baseline_overview.md` |

---

## 6. 量化指标与趋势建议

### 6.1 当前状态 vs 行业基准

| 维度 | SecretRoy 当前 | Flutter 项目常见基准 | 差距 |
|------|---------------|---------------------|------|
| **行覆盖率** | 58.3% | 60%–70%（中等规模商业项目） | **-1.7% ~ -11.7%** |
| **静态分析** | 0 error / 14 warning（均不在 `lib/`） | 0 error / 少量 warning | **达标** |
| **TODO/FIXME 密度** | 0 / 13,541 行 | 越低越好 | **显著优于基准** |
| **公共 API 文档率** | ~15% | 50%–80%（开源/企业级） | **-35% ~ -65%** |
| **国际化完整度** | 100% | 100% | **达标** |

### 6.2 达到 70% 覆盖率需要补充的测试估算

**数学缺口**：
- 目标命中行：13,541 × 70% = **9,479 行**
- 当前命中：7,892 行
- 需新增命中：**1,587 行**

**文件缺口**：
- 完全无追踪（0%）：19 个文件
- 覆盖率极低（<30%）：9 个文件（含 template_list_view 的 0.2%）

**估算策略**：
- 19 个 0% 文件中有约 10 个属于核心/高频路径（`main.dart`、`home_view` 系列、`settings_view`、`totp` 系列等），每个补充 1 个测试文件，预计可覆盖 800–1,200 行。
- 9 个极低覆盖率文件中，`template_list_view.dart`（598 行，1 命中）和 `vault_pairing_service.dart`（98 行，1 命中）是最大单体缺口，各需 1 个针对性测试文件，预计可覆盖 500–600 行。
- **结论**：预计需要新增 **12–18 个测试文件**（主要集中在 `test/views/`、`test/services/`、`test/system/`、`test/widgets/`），可将覆盖率提升至 68%–72%。

### 6.3 达到 80% 文档覆盖率需要补充的 dartdoc 估算

**当前缺口估算依据**：
- 服务层 18 个公共类/枚举 + ~30 个高频公共方法 → 约 48 个文档点，仅 ~3 个有文档 → 缺口 45
- 模型层 25 个类/枚举 → 约 25 个文档点，按现有稀疏程度估计已有 ~5 个 → 缺口 20
- 视图层 24 个文件（主要 StatefulWidget/StatelessWidget）→ 约 30 个类级文档点，估计已有 ~8 个 → 缺口 22
- 组件层 25 个文件 → 约 30 个类级文档点，估计已有 ~6 个 → 缺口 24
- Providers 3 个文件 → 约 5 个文档点，估计已有 ~2 个 → 缺口 3
- 其他（core、utils、sync 公共 API）→ 约 40 个文档点，估计已有 ~15 个 → 缺口 25

**总计**：公共 API 文档点约 178 个，当前有文档约 39 个，当前覆盖率约 **22%**。要达到 80% 需要补充约 **100–120 个类/方法级 dartdoc**。

> 注：若优先覆盖服务层公共类和 `ServiceManager` 门面方法（约 50 个文档点），即可将整体文档率从 ~22% 提升至 ~40%，投入产出比最高。

---

## 7. 综合结论

1. **静态分析与代码整洁度优秀**：`lib/` 源码 0 error、0 style token 违规、0 TODO/FIXME，说明工程纪律良好。
2. **测试覆盖呈“两极分化”**：核心模型、CRDT、加密、身份、TOTP 等底层逻辑测试充分（部分 100%），但 **视图层、配对/导入导出服务、LAN 同步客户端** 存在大面积裸奔。
3. **文档是最大短板**：公共 API 的 dartdoc 覆盖率估计不足 25%，且已有文档中大量与代码实际状态漂移（测试指南、架构文档、协议文档尤为严重）。
4. **建议执行顺序**：
   - **Sprint 1**：补齐 `vault_pairing_service.dart`、`vault_import_export_coordinator.dart`、`vault_pairing_coordinator.dart` 的单元测试（安全关键）。
   - **Sprint 2**：为 `home_view`、`settings_view`、`main.dart` 补充 Widget/集成测试（核心用户旅程）。
   - **Sprint 3**：重写 `testing-guide.md`、修正 `ConflictLog`→`TemplateConflictLog`、更新 `technical-documentation.md` 中的服务列表与解锁流程。
   - **Sprint 4**：批量补充服务层公共类 dartdoc、补齐边缘页面/组件测试。
