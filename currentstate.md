# SecretRoy 任务状态

## 当前目标
全面自动化测试扩展，以替代手动 QA 工作。覆盖核心状态层、服务层、模型层和视图层。

## 已完成内容

### 本轮测试扩展（Commit ffd1961）
新增 5 个测试文件，+48 测试用例：
- `test/providers/enhanced_app_provider_test.dart`（26 cases）— 核心状态层：加载、搜索、标签过滤、CRUD、同步委托
- `test/services/auto_lock_service_test.dart`（9 cases）— 自动锁定：状态机、duration、通知、enum 映射
- `test/services/notification_service_test.dart`（8 cases）— 通知生成：密码过期、弱密码检测、去重、跳过逻辑
- `test/models/vault_health_report_test.dart`（3 cases）— 健康报告模型构造、失败项过滤、Action 目标 ID
- `test/models/template_conflict_log_test.dart`（3 cases）— 模板冲突日志：构造、JSON 往返、唯一 ID 生成

### 历史测试扩展
- Commit `cef217e`：10 个新测试文件，+73 cases
- Commit `eb885c7` / `85cb0f0`：通知中心重构 + style debt 修复

## 关键架构信息
- **测试总数**：462 passing，1 skipped
- **核心 fake**：`FakeSecureStorageService`（`test/sync/sync_server_test_harness.dart`）— 所有测试的中心存根
- **Fake 现代化**：已同步 deleteTemplate/deleteTotpCredential 的 `syncDeleteHlc`、recordLocalSyncChange 存储、通知生命周期
- **源代码加固**（测试驱动修复）：
  - `NotificationProvider.markRead` / `deleteNotification`：避免修改不可变列表
  - `ActionItemCard._severityColor` / `PasswordGeneratorSheet._strengthColor`：主题扩展空安全 fallback

## 重要文件
| 文件 | 作用 |
|------|------|
| `test/providers/enhanced_app_provider_test.dart` | EnhancedAppProvider 核心测试（26 cases） |
| `test/services/auto_lock_service_test.dart` | AutoLockService 状态与设置测试 |
| `test/services/notification_service_test.dart` | 通知生成逻辑测试 |
| `test/sync/sync_server_test_harness.dart` | FakeSecureStorageService + InMemoryVaultServer |
| `test/fakes/` | FakeAutoLockService、FakeIdentityService、FakeSyncService 等 |

## 未解决问题 / 剩余缺口
1. **ThemeProvider**：无 dedicated 测试
2. **Coordinators**：`VaultPairingCoordinator`、`VaultImportExportCoordinator` 缺乏覆盖
3. **Services**：`EnhancedCryptoService` 缺少 dedicated 单元测试（部分逻辑被 ServiceManager 间接覆盖）
4. **Views**：`PasswordToolsView`、`SyncSettingsView`、`AppearanceSettingsView` 未测试
5. **Integration**：真实网络环境下的客户端/服务端联合测试缺失

## 待办事项
- [x] VaultHealthReport + TemplateConflictLog 模型测试
- [x] AutoLockService 测试
- [x] NotificationService 测试
- [x] EnhancedAppProvider 测试
- [ ] ThemeProvider 测试
- [ ] VaultPairingCoordinator / VaultImportExportCoordinator 测试
- [ ] EnhancedCryptoService 测试
- [ ] PasswordToolsView / SyncSettingsView / AppearanceSettingsView 测试
- [ ] 提交本轮代码

## 风险与注意事项
- **FakeSecureStorageService API 漂移**：`SecureStorageService` 新增命名参数时必须同步更新 fake，否则所有依赖测试编译失败
- **Theme 扩展空安全**：widget 测试中 `MaterialApp` 未必注册 `AppVisualTokens`，源码应使用 `?.color ?? fallback`
- **Unmodifiable list 防御**：fake 返回 `List.unmodifiable()` 时，consumer 禁止原地修改
- **AccountTemplate.isCustom**：构造函数默认 `false`，`loadCustomTemplates()` 会过滤，测试构造时必须显式 `isCustom: true`
- **TotpCredential 构造函数**：使用 `label`/`config`/`linkedAccountIds` 等，非旧版的 `secret`/`issuer`/`linkedAccountId`
- **basicAccountTemplates**：包含 `builtin_generic_info`、`secure_note_generic`、`secure_note_mnemonic`、`api_service`，无 `login`
