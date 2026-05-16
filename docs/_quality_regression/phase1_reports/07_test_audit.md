[stage] runner_started
[stage] agent_built
[stage] context_restored
[stage] context_ready
[stage] run_soul_start
[tool] Glob
[tool] Glob
[tool_result] success
[tool] Glob
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
[tool] ReadFile
[tool_result] success
[tool_result] success
[tool] Shell
[tool] ReadFile
[tool_result] error: Failed with exit code: 49
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool_result] success
[tool] Shell
[tool] Shell
[tool] ReadFile
[tool_result] error: Failed with exit code: 49
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool_result] success
[tool_result] error: Failed with exit code: 49
[tool] Shell
[tool_result] success
[tool] Shell
[tool_result] error: Failed with exit code: 254
[tool] Shell
[tool_result] success
[tool] Shell
[tool] Shell
[tool_result] success
[tool_result] success
[tool] Shell
[tool] Shell
[tool_result] success
[tool_result] success
[tool] Shell
[tool] Shell
[tool_result] success
[tool_result] success
# SecretRoy 客户端测试覆盖映射与缺口分析报告

---

## 1. 测试统计总览

| 类别 | 测试文件数 | 测试用例数 | Group 数 |
|------|-----------|-----------|---------|
| `test/models/` | 8 | 53 | 11 |
| `test/services/` | 17 | 123 | 19 |
| `test/sync/` | 15 | 124 | 22 |
| `test/system/` | 7 | 76 | 8 |
| `test/theme/` | 2 | 13 | 5 |
| `test/utils/` | 1 | 10 | 3 |
| `test/views/` | 9 | 45 | 9 |
| `test/widgets/` | 9 | 45 | 11 |
| `test/providers/` | 3 | 44 | 3 |
| `integration_test/` | 3 | 7 | — |
| **合计** | **74** | **540** | **91** |

辅助文件（非测试本身）：
- `test/fakes/`：6 个 Fake 服务
- `test/sync/*_harness.dart`：2 个测试 harness
- `integration_test/support/`：1 个 helper

---

## 2. 测试-源码映射表

### Models（8 → 8，全覆盖）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/models/account_item.dart` | `test/models/account_item_test.dart` |
| `lib/models/account_template.dart` | `test/models/account_template_test.dart` |
| `lib/models/app_notification.dart` | `test/models/app_notification_test.dart` |
| `lib/models/hlc.dart` | `test/models/hlc_test.dart` |
| `lib/models/local_sync_change.dart` | `test/models/local_sync_change_test.dart` |
| `lib/models/template_conflict_log.dart` | `test/models/template_conflict_log_test.dart` |
| `lib/models/totp_credential.dart` | `test/models/totp_credential_test.dart` |
| `lib/models/vault_health_report.dart` | `test/models/vault_health_report_test.dart` |

### Services（17 → 18，有1个未覆盖）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/services/auto_lock_service.dart` | `test/services/auto_lock_service_test.dart` |
| `lib/services/biometric_auth_service.dart` | `test/services/biometric_auth_service_test.dart` |
| `lib/services/database_file_cipher.dart` | `test/services/database_file_cipher_test.dart` |
| `lib/services/database_file_key_manager.dart` | `test/services/database_file_key_manager_test.dart` |
| `lib/services/enhanced_crypto_service.dart` | `test/services/enhanced_crypto_service_test.dart` |
| `lib/services/identity_service.dart` | `test/services/identity_service_test.dart` |
| `lib/services/notification_service.dart` | `test/services/notification_service_test.dart` |
| `lib/services/secure_storage_service.dart` | `test/services/secure_storage_service_encryption_test.dart`<br>`test/services/secure_storage_service_sync_outbox_test.dart` |
| `lib/services/sensitive_clipboard_service.dart` | `test/services/sensitive_clipboard_service_test.dart` |
| `lib/services/service_manager.dart` | `test/services/service_manager_no_password_test.dart`<br>`test/services/service_manager_state_machine_test.dart` |
| `lib/services/totp_import_service.dart` | `test/services/totp_import_service_test.dart` |
| `lib/services/totp_qr_image_import_service.dart` | `test/services/totp_qr_image_import_service_test.dart` |
| `lib/services/totp_service.dart` | `test/services/totp_service_test.dart` |
| `lib/services/vault_health_calculator.dart` | `test/services/vault_health_calculator_test.dart` |
| `lib/services/vault_pairing_crypto.dart` | `test/services/vault_pairing_crypto_test.dart` |
| **❌ `lib/services/device_alias_service.dart`** | **无** |
| `lib/services/lan_pairing_service.dart` | `test/sync/lan_pairing_service_test.dart`（跨目录） |
| `lib/services/vault_pairing_service.dart` | 无独立测试（被集成/其他测试间接触及） |

### Sync（15 → 15+，拆分文件多对多）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/sync/crdt_merge_engine.dart` | `test/sync/crdt_merge_engine_test.dart`<br>`test/sync/crdt_merge_invariants_test.dart` |
| `lib/sync/lan_sync_client.dart` | `test/sync/lan_sync_client_test.dart` |
| `lib/sync/lan_sync_coordinator.dart` | `test/sync/lan_sync_coordinator_test.dart` |
| `lib/sync/lan_sync_host_handler.dart` | `test/sync/lan_sync_host_handler_test.dart` |
| `lib/sync/lan_sync_session.dart` | `test/sync/lan_sync_session_test.dart` |
| `lib/sync/sync_payload_codec.dart` | `test/sync/sync_payload_codec_test.dart` |
| `lib/sync/sync_service.dart`（含 pull/push/conflict/types） | `test/sync/sync_state_machine_test.dart`<br>`test/sync/multi_device_sync_test.dart`<br>`test/sync/sync_conflict_recovery_test.dart`<br>`test/sync/sync_fault_injection_test.dart`<br>`test/sync/sync_recovery_loop_test.dart`<br>`test/sync/sync_service_identity_test.dart`<br>`test/sync/lan_sync_abc_integration_test.dart` |
| `lib/sync/totp_credential_merge_engine.dart` | 被 `crdt_merge_engine_test.dart` 等间接覆盖 |

### System（7 → 8）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/system/service_manager/sync_coordinator.dart` | `test/system/sync_coordinator_test.dart` |
| `lib/system/service_manager/vault_data_repository.dart` | `test/system/vault_data_repository_test.dart` |
| `lib/system/service_manager/vault_dump_coordinator.dart` | `test/system/vault_dump_coordinator_test.dart` |
| `lib/system/service_manager/vault_import_export_coordinator.dart` | `test/system/vault_import_export_coordinator_test.dart` |
| `lib/system/service_manager/vault_import_types.dart` | 被 `vault_import_rollback_test.dart` 触及 |
| `lib/system/service_manager/vault_import_rollback_test.dart` | `test/system/vault_import_rollback_test.dart` |
| `lib/system/service_manager/vault_pairing_coordinator.dart` | `test/system/vault_pairing_coordinator_test.dart` |
| `lib/system/service_manager/vault_unlock_coordinator.dart` | `test/system/vault_unlock_coordinator_test.dart` |
| `lib/system/service_manager/sync_server_url_store.dart` | 被 `sync_coordinator_test.dart` 等间接覆盖 |
| `lib/system/service_manager/default_sync_server_url.dart` | **无** |
| `lib/system/service_manager/password_tools.dart` | 被 `test/views/password_tools_view_test.dart` 间接触及 |

### Theme & Utils（3 → 3）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/theme/app_design_tokens.dart` | `test/theme/app_design_tokens_test.dart` |
| `lib/theme/app_layout.dart` | `test/theme/app_layout_test.dart` |
| `lib/utils/field_presets.dart` | `test/utils/field_presets_test.dart` |

### Views（9 → 9，部分源码未覆盖）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/views/accounts/account_edit_view.dart` | `test/views/account_edit_view_test.dart` |
| `lib/views/accounts/account_list_view.dart` | `test/views/account_list_view_test.dart` |
| `lib/views/appearance_settings_view.dart` | `test/views/appearance_settings_view_test.dart` |
| `lib/views/conflict_inbox_view.dart` | `test/views/conflict_inbox_view_test.dart` |
| `lib/views/password_tools_view.dart` | `test/views/password_tools_view_test.dart` |
| `lib/views/security_settings_view.dart` | `test/views/security_settings_view_test.dart` |
| `lib/views/templates/template_edit_view.dart` | `test/views/template_edit_view_test.dart` |
| `lib/views/templates/template_list_view.dart` | `test/views/template_list_view_test.dart` |
| `lib/views/unlock_view.dart` | `test/views/unlock_view_test.dart` |

### Widgets（9 → 9，大量源码未覆盖）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/widgets/account_list_tile.dart` | `test/widgets/account_list_tile_test.dart` |
| `lib/widgets/app_hero_card.dart` | `test/widgets/app_hero_card_test.dart` |
| `lib/widgets/app_nav_bar.dart` / `app_nav_rail.dart` | `test/widgets/app_nav_test.dart` |
| `lib/widgets/app_option_tile.dart` | `test/widgets/app_option_tile_test.dart` |
| `lib/widgets/app_selectable_scrollable.dart` | `test/widgets/app_selectable_scrollable_test.dart` |
| `lib/widgets/app_settings_group.dart` / `app_settings_tile.dart` | `test/widgets/app_settings_test.dart` |
| `lib/widgets/inbox/inbox_action_card.dart` | `test/widgets/inbox_action_card_test.dart` |
| `lib/widgets/password_generator_sheet.dart` | `test/widgets/password_generator_sheet_test.dart` |
| `lib/widgets/section_card.dart` | `test/widgets/section_card_test.dart` |

### Providers（3 → 3）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/providers/enhanced_app_provider.dart` | `test/providers/enhanced_app_provider_test.dart` |
| `lib/providers/notification_provider.dart` | `test/providers/notification_provider_test.dart` |
| `lib/providers/theme_provider.dart` | `test/providers/theme_provider_test.dart` |

---

## 3. 未覆盖模块清单（按优先级排序）

### 3.1 完全无追踪（0%）— 19 个文件

| 优先级 | 文件 | 说明 |
|--------|------|------|
| 🔴 P0 | `lib/main.dart` | 应用入口、ServiceManager/Provider/主题初始化 |
| 🔴 P0 | `lib/views/home/home_view.dart` | 主页核心 |
| 🔴 P0 | `lib/views/home/layouts/home_view_desktop.dart` | 桌面端主页布局 |
| 🔴 P0 | `lib/views/home/layouts/home_view_mobile.dart` | 移动端主页布局 |
| 🔴 P0 | `lib/views/settings_view.dart` | 设置中心入口 |
| 🟡 P1 | `lib/views/home/home_search_view.dart` | 搜索视图 |
| 🟡 P1 | `lib/views/settings/notification_settings_view.dart` | 通知设置 |
| 🟡 P1 | `lib/views/settings/vault_health_view.dart` | Vault 体检详情页 |
| 🟡 P1 | `lib/views/notifications/notification_center_view.dart` | 通知中心 |
| 🟡 P1 | `lib/views/sync/local_sync_queue_view.dart` | 本地同步队列 |
| 🟡 P1 | `lib/views/sync_settings_view.dart` | 同步设置 |
| 🟡 P1 | `lib/widgets/app_layout_builder.dart` | 跨平台布局构建器 |
| 🟡 P1 | `lib/widgets/lan_sync_conflict_sheet.dart` | LAN 同步冲突 BottomSheet |
| 🟡 P1 | `lib/widgets/sync_settings_dialogs.dart` | 同步设置对话框 |
| 🟢 P2 | `lib/views/accounts/account_subset_view.dart` | 账户子集 |
| 🟢 P2 | `lib/views/release_note_view.dart` | 发布说明 |
| 🟢 P2 | `lib/widgets/inbox/inbox_filter_bar.dart` | 收件箱过滤栏 |
| 🟢 P2 | `lib/widgets/selection_indicator.dart` | 选择指示器 |
| 🟢 P2 | `lib/theme/theme.dart` | 主题 barrel 导出文件 |

### 3.2 覆盖率极低（< 30%，有追踪但几乎未命中）

| 文件 | 覆盖率 | 说明 |
|------|--------|------|
| `lib/views/templates/template_list_view.dart` | **0.2%** | 598 行仅命中 1 行 |
| `lib/services/vault_pairing_service.dart` | **1.0%** | 配对服务核心逻辑 |
| `lib/system/service_manager/vault_import_export_coordinator.dart` | **1.3%** | 导入导出协调器 |
| `lib/system/service_manager/vault_pairing_coordinator.dart` | **5.3%** | 配对协调器 |
| `lib/sync/lan_sync_client.dart` | **21.7%** | LAN 同步客户端 |
| `lib/sync/lan_sync_host_handler.dart` | **22.1%** | LAN 同步主机处理器 |
| `lib/widgets/account_edit_widgets.dart` | **27.1%** | 账户编辑表单组件 |
| `lib/theme/app_design_tokens.dart` | **32.6%** | 设计令牌（部分被测试） |
| `lib/services/device_alias_service.dart` | **33.3%** | 设备别名服务 |

---

## 4. 覆盖率数据分析

基于 `coverage/lcov.info`（96 个被追踪文件，115 个源码文件）：

| 指标 | 数值 |
|------|------|
| 被追踪文件 | 96 / 115 |
| 未追踪文件 | 19（见 3.1） |
| 总可执行行 | 13,541 |
| 命中行 | 7,892 |
| **整体行覆盖率** | **58.3%** |

### 覆盖率 TOP 10（高置信模块）
| 文件 | 覆盖率 | 命中/总行 |
|------|--------|----------|
| `utils/field_presets.dart` | 100.0% | 18/18 |
| `models/template_conflict_log.dart` | 100.0% | 24/24 |
| `widgets/inbox/inbox_action_card.dart` | 100.0% | 86/86 |
| `providers/theme_provider.dart` | 100.0% | 34/34 |
| `widgets/app_option_tile.dart` | 100.0% | 40/40 |
| `core/crypto_random.dart` | 100.0% | 5/5 |
| `sync/lan_sync_session.dart` | 100.0% | 30/30 |
| `system/service_manager/sync_server_url_store.dart` | 100.0% | 27/27 |
| `widgets/app_page_header.dart` | 97.2% | 35/36 |
| `system/service_manager/sync_coordinator.dart` | 97.1% | 33/34 |

### 覆盖率 BOTTOM 10（高风险缺口）
| 文件 | 覆盖率 | 命中/总行 |
|------|--------|----------|
| `widgets/inbox/inbox_models.dart` | 0.0% | 0/1 |
| `system/service_manager/default_sync_server_url.dart` | 0.0% | 0/8 |
| `views/accounts/totp_qr_scanner_view.dart` | 0.0% | 0/63 |
| `views/accounts/totp_credential_edit_view.dart` | 0.0% | 0/189 |
| `views/accounts/account_edit_utils.dart` | 0.0% | 0/57 |
| `views/templates/template_list_view.dart` | 0.2% | 1/598 |
| `services/vault_pairing_service.dart` | 1.0% | 1/98 |
| `l10n/app_localizations_en.dart` | 1.2% | 1/85 |
| `system/service_manager/vault_import_export_coordinator.dart` | 1.3% | 1/77 |
| `system/service_manager/vault_pairing_coordinator.dart` | 5.3% | 3/57 |

---

## 5. 测试模式总结

通过扫描 `test/` 目录，归纳出项目中反复出现的测试设计模式：

| 模式 | 典型用法 | 出现位置 |
|------|---------|---------|
| **Fake 服务注入** | `FakeIdentityService`、`FakeCryptoService`、`FakeAutoLockService` 等 | `test/fakes/` 被广泛引用 |
| **内存 SecureStorage** | `MemorySecureKeyValueStore` / `FakeSecureStorageService` | `identity_service_test.dart`、`sync_server_test_harness.dart` |
| **ServiceManager.testable** | 通过 `setInstanceForTesting` 注入全套 fake 依赖 | 几乎所有 View/Widget 测试 |
| **Mock 平台通道** | `TestDefaultBinaryMessengerBinding` 模拟 `flutter_secure_storage`、`Clipboard` | `unlock_view_test.dart`、`sensitive_clipboard_service_test.dart` |
| **Mock SharedPreferences** | `SharedPreferences.setMockInitialValues({})` | `sync_state_machine_test.dart`、`unlock_view_test.dart` |
| **固定屏幕尺寸** | `tester.binding.setSurfaceSize(Size(1200, 2000))` | `account_edit_view_test.dart` 等 Widget 测试 |
| **异步 pump 辅助** | `pumpUntilFound()` / `pumpUntilGone()` | `integration_test/support/smoke_test_helpers.dart` |
| **ChangeNotifier 状态监听** | `addListener(() => states.add(service.state))` | `sync_state_machine_test.dart`、`auto_lock_service_test.dart` |
| **临时目录隔离** | `Directory.systemTemp.createTempSync()` | `database_file_cipher_test.dart` |
| **addTearDown 清理** | `ServiceManager.resetInstance()`、`cancelPendingClear()` | 大量测试文件 |
| **Group 嵌套组织** | `group('ClassName', () { group('method', () { test(...) }) })` | 全局惯例 |

---

## 6. 集成测试覆盖评估

共 3 个集成测试文件、7 个 `testWidgets` 用例，均在 **PC 桌面端模拟环境**（`Size(1440, 1400)`）下运行。

### `smoke_happy_path_test.dart`（1 个用例）
- **目标**：最核心端到端路径快速验证
- **覆盖动作**：
  1. 启动应用并解锁
  2. 创建网站账户（名称、邮箱、网站、账号、密码）
  3. 搜索账户（SearchBar 输入、结果匹配）
  4. 导航到设置中心（验证“个性化与外观”、“安全设置”存在）

### `smoke_full_workflows_test.dart`（1 个用例）
- **目标**：主要工作区浅层遍历，防止大面积回归
- **覆盖动作**：
  1. 创建并编辑账户（预览 → 编辑 → 保存）
  2. 创建 TOTP 并关联到账户（otpauth URI 输入）
  3. 密码工具 → 打开生成器 → 保留结果
  4. Vault 体检（验证体检时间展示）
  5. 模板管理 → 新建自定义模板 → 添加字段 → 保存

### `regression_boundary_test.dart`（4 个用例）
- **目标**：QA 手工回归中最高频、最高风险路径
- **覆盖动作**：
  1. **删除账户确认流程**：长按 tile → 底部 sheet 删除 → AlertDialog 确认 → 验证消失
  2. **搜索过滤与清除**：输入匹配关键词 → 结果存在；输入不存在关键词 → 结果为空；点击清除 → 恢复
  3. **分类 Tab 切换**：全部 → 账户 → 安全笔记 → 2FA → 全部
  4. **错误密码解锁 → 正确密码解锁**：输入错误密码 → 预期“主密码不正确”；输入正确密码 → 进入账户中心

### 集成测试缺口
- **未覆盖**：生物识别解锁、同步设置/配对、模板冲突处理、通知中心、暗色/主题切换、数据导入导出、账户子集筛选、LAN 同步、TOTP 扫码
- **平台局限**：当前集成测试仅针对桌面端尺寸，缺少移动端布局验证

---

## 7. TODO / FIXME / HACK 清单

**结果：零条记录**

扫描 `test/` 与 `integration_test/` 全部 Dart 文件后，未找到 `TODO`、`FIXME`、`HACK`、`XXX`、`BUG`、`OPTIMIZE`、`NOTE` 等标记注释。

---

## 8. 关键结论与建议

1. **模型与基础服务层覆盖优秀**：`models/`、`core/`、`theme/` 部分文件达 100%，CRDT、加密、身份、TOTP 等核心逻辑测试充分。
2. **View 层覆盖严重倾斜**：`account_edit_view.dart`（1606 行，575 命中，35.8%）和 `template_list_view.dart`（598 行，1 命中，0.2%）是最大缺口。大量页面（home、settings、notifications、sync）完全无测试。
3. **配对/导入导出服务几乎裸奔**：`vault_pairing_service.dart`（1.0%）、`vault_import_export_coordinator.dart`（1.3%）、`vault_pairing_coordinator.dart`（5.3%）属于安全关键路径，应优先补测。
4. **LAN 同步覆盖不足**：`lan_sync_client.dart`（21.7%）、`lan_sync_host_handler.dart`（22.1%）虽存在单元测试，但实际命中行数偏低。
5. **Widget 组件大量未覆盖**：`account_edit_widgets.dart`、`inbox_filter_bar`、`selection_indicator`、`app_layout_builder` 等缺少独立 Widget 测试。
6. **集成测试仅 7 个用例，且全为桌面端**：建议增加移动端 surface size 的集成测试，以及覆盖同步、导入导出、生物识别等高风险路径的用例。[stage] run_soul_finished

[summary]
# SecretRoy 客户端测试覆盖映射与缺口分析报告

---

## 1. 测试统计总览

| 类别 | 测试文件数 | 测试用例数 | Group 数 |
|------|-----------|-----------|---------|
| `test/models/` | 8 | 53 | 11 |
| `test/services/` | 17 | 123 | 19 |
| `test/sync/` | 15 | 124 | 22 |
| `test/system/` | 7 | 76 | 8 |
| `test/theme/` | 2 | 13 | 5 |
| `test/utils/` | 1 | 10 | 3 |
| `test/views/` | 9 | 45 | 9 |
| `test/widgets/` | 9 | 45 | 11 |
| `test/providers/` | 3 | 44 | 3 |
| `integration_test/` | 3 | 7 | — |
| **合计** | **74** | **540** | **91** |

辅助文件（非测试本身）：
- `test/fakes/`：6 个 Fake 服务
- `test/sync/*_harness.dart`：2 个测试 harness
- `integration_test/support/`：1 个 helper

---

## 2. 测试-源码映射表

### Models（8 → 8，全覆盖）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/models/account_item.dart` | `test/models/account_item_test.dart` |
| `lib/models/account_template.dart` | `test/models/account_template_test.dart` |
| `lib/models/app_notification.dart` | `test/models/app_notification_test.dart` |
| `lib/models/hlc.dart` | `test/models/hlc_test.dart` |
| `lib/models/local_sync_change.dart` | `test/models/local_sync_change_test.dart` |
| `lib/models/template_conflict_log.dart` | `test/models/template_conflict_log_test.dart` |
| `lib/models/totp_credential.dart` | `test/models/totp_credential_test.dart` |
| `lib/models/vault_health_report.dart` | `test/models/vault_health_report_test.dart` |

### Services（17 → 18，有1个未覆盖）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/services/auto_lock_service.dart` | `test/services/auto_lock_service_test.dart` |
| `lib/services/biometric_auth_service.dart` | `test/services/biometric_auth_service_test.dart` |
| `lib/services/database_file_cipher.dart` | `test/services/database_file_cipher_test.dart` |
| `lib/services/database_file_key_manager.dart` | `test/services/database_file_key_manager_test.dart` |
| `lib/services/enhanced_crypto_service.dart` | `test/services/enhanced_crypto_service_test.dart` |
| `lib/services/identity_service.dart` | `test/services/identity_service_test.dart` |
| `lib/services/notification_service.dart` | `test/services/notification_service_test.dart` |
| `lib/services/secure_storage_service.dart` | `test/services/secure_storage_service_encryption_test.dart`<br>`test/services/secure_storage_service_sync_outbox_test.dart` |
| `lib/services/sensitive_clipboard_service.dart` | `test/services/sensitive_clipboard_service_test.dart` |
| `lib/services/service_manager.dart` | `test/services/service_manager_no_password_test.dart`<br>`test/services/service_manager_state_machine_test.dart` |
| `lib/services/totp_import_service.dart` | `test/services/totp_import_service_test.dart` |
| `lib/services/totp_qr_image_import_service.dart` | `test/services/totp_qr_image_import_service_test.dart` |
| `lib/services/totp_service.dart` | `test/services/totp_service_test.dart` |
| `lib/services/vault_health_calculator.dart` | `test/services/vault_health_calculator_test.dart` |
| `lib/services/vault_pairing_crypto.dart` | `test/services/vault_pairing_crypto_test.dart` |
| **❌ `lib/services/device_alias_service.dart`** | **无** |
| `lib/services/lan_pairing_service.dart` | `test/sync/lan_pairing_service_test.dart`（跨目录） |
| `lib/services/vault_pairing_service.dart` | 无独立测试（被集成/其他测试间接触及） |

### Sync（15 → 15+，拆分文件多对多）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/sync/crdt_merge_engine.dart` | `test/sync/crdt_merge_engine_test.dart`<br>`test/sync/crdt_merge_invariants_test.dart` |
| `lib/sync/lan_sync_client.dart` | `test/sync/lan_sync_client_test.dart` |
| `lib/sync/lan_sync_coordinator.dart` | `test/sync/lan_sync_coordinator_test.dart` |
| `lib/sync/lan_sync_host_handler.dart` | `test/sync/lan_sync_host_handler_test.dart` |
| `lib/sync/lan_sync_session.dart` | `test/sync/lan_sync_session_test.dart` |
| `lib/sync/sync_payload_codec.dart` | `test/sync/sync_payload_codec_test.dart` |
| `lib/sync/sync_service.dart`（含 pull/push/conflict/types） | `test/sync/sync_state_machine_test.dart`<br>`test/sync/multi_device_sync_test.dart`<br>`test/sync/sync_conflict_recovery_test.dart`<br>`test/sync/sync_fault_injection_test.dart`<br>`test/sync/sync_recovery_loop_test.dart`<br>`test/sync/sync_service_identity_test.dart`<br>`test/sync/lan_sync_abc_integration_test.dart` |
| `lib/sync/totp_credential_merge_engine.dart` | 被 `crdt_merge_engine_test.dart` 等间接覆盖 |

### System（7 → 8）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/system/service_manager/sync_coordinator.dart` | `test/system/sync_coordinator_test.dart` |
| `lib/system/service_manager/vault_data_repository.dart` | `test/system/vault_data_repository_test.dart` |
| `lib/system/service_manager/vault_dump_coordinator.dart` | `test/system/vault_dump_coordinator_test.dart` |
| `lib/system/service_manager/vault_import_export_coordinator.dart` | `test/system/vault_import_export_coordinator_test.dart` |
| `lib/system/service_manager/vault_import_types.dart` | 被 `vault_import_rollback_test.dart` 触及 |
| `lib/system/service_manager/vault_import_rollback_test.dart` | `test/system/vault_import_rollback_test.dart` |
| `lib/system/service_manager/vault_pairing_coordinator.dart` | `test/system/vault_pairing_coordinator_test.dart` |
| `lib/system/service_manager/vault_unlock_coordinator.dart` | `test/system/vault_unlock_coordinator_test.dart` |
| `lib/system/service_manager/sync_server_url_store.dart` | 被 `sync_coordinator_test.dart` 等间接覆盖 |
| `lib/system/service_manager/default_sync_server_url.dart` | **无** |
| `lib/system/service_manager/password_tools.dart` | 被 `test/views/password_tools_view_test.dart` 间接触及 |

### Theme & Utils（3 → 3）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/theme/app_design_tokens.dart` | `test/theme/app_design_tokens_test.dart` |
| `lib/theme/app_layout.dart` | `test/theme/app_layout_test.dart` |
| `lib/utils/field_presets.dart` | `test/utils/field_presets_test.dart` |

### Views（9 → 9，部分源码未覆盖）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/views/accounts/account_edit_view.dart` | `test/views/account_edit_view_test.dart` |
| `lib/views/accounts/account_list_view.dart` | `test/views/account_list_view_test.dart` |
| `lib/views/appearance_settings_view.dart` | `test/views/appearance_settings_view_test.dart` |
| `lib/views/conflict_inbox_view.dart` | `test/views/conflict_inbox_view_test.dart` |
| `lib/views/password_tools_view.dart` | `test/views/password_tools_view_test.dart` |
| `lib/views/security_settings_view.dart` | `test/views/security_settings_view_test.dart` |
| `lib/views/templates/template_edit_view.dart` | `test/views/template_edit_view_test.dart` |
| `lib/views/templates/template_list_view.dart` | `test/views/template_list_view_test.dart` |
| `lib/views/unlock_view.dart` | `test/views/unlock_view_test.dart` |

### Widgets（9 → 9，大量源码未覆盖）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/widgets/account_list_tile.dart` | `test/widgets/account_list_tile_test.dart` |
| `lib/widgets/app_hero_card.dart` | `test/widgets/app_hero_card_test.dart` |
| `lib/widgets/app_nav_bar.dart` / `app_nav_rail.dart` | `test/widgets/app_nav_test.dart` |
| `lib/widgets/app_option_tile.dart` | `test/widgets/app_option_tile_test.dart` |
| `lib/widgets/app_selectable_scrollable.dart` | `test/widgets/app_selectable_scrollable_test.dart` |
| `lib/widgets/app_settings_group.dart` / `app_settings_tile.dart` | `test/widgets/app_settings_test.dart` |
| `lib/widgets/inbox/inbox_action_card.dart` | `test/widgets/inbox_action_card_test.dart` |
| `lib/widgets/password_generator_sheet.dart` | `test/widgets/password_generator_sheet_test.dart` |
| `lib/widgets/section_card.dart` | `test/widgets/section_card_test.dart` |

### Providers（3 → 3）
| 源码文件 | 测试文件 |
|---------|---------|
| `lib/providers/enhanced_app_provider.dart` | `test/providers/enhanced_app_provider_test.dart` |
| `lib/providers/notification_provider.dart` | `test/providers/notification_provider_test.dart` |
| `lib/providers/theme_provider.dart` | `test/providers/theme_provider_test.dart` |

---

## 3. 未覆盖模块清单（按优先级排序）

### 3.1 完全无追踪（0%）— 19 个文件

| 优先级 | 文件 | 说明 |
|--------|------|------|
| 🔴 P0 | `lib/main.dart` | 应用入口、ServiceManager/Provider/主题初始化 |
| 🔴 P0 | `lib/views/home/home_view.dart` | 主页核心 |
| 🔴 P0 | `lib/views/home/layouts/home_view_desktop.dart` | 桌面端主页布局 |
| 🔴 P0 | `lib/views/home/layouts/home_view_mobile.dart` | 移动端主页布局 |
| 🔴 P0 | `lib/views/settings_view.dart` | 设置中心入口 |
| 🟡 P1 | `lib/views/home/home_search_view.dart` | 搜索视图 |
| 🟡 P1 | `lib/views/settings/notification_settings_view.dart` | 通知设置 |
| 🟡 P1 | `lib/views/settings/vault_health_view.dart` | Vault 体检详情页 |
| 🟡 P1 | `lib/views/notifications/notification_center_view.dart` | 通知中心 |
| 🟡 P1 | `lib/views/sync/local_sync_queue_view.dart` | 本地同步队列 |
| 🟡 P1 | `lib/views/sync_settings_view.dart` | 同步设置 |
| 🟡 P1 | `lib/widgets/app_layout_builder.dart` | 跨平台布局构建器 |
| 🟡 P1 | `lib/widgets/lan_sync_conflict_sheet.dart` | LAN 同步冲突 BottomSheet |
| 🟡 P1 | `lib/widgets/sync_settings_dialogs.dart` | 同步设置对话框 |
| 🟢 P2 | `lib/views/accounts/account_subset_view.dart` | 账户子集 |
| 🟢 P2 | `lib/views/release_note_view.dart` | 发布说明 |
| 🟢 P2 | `lib/widgets/inbox/inbox_filter_bar.dart` | 收件箱过滤栏 |
| 🟢 P2 | `lib/widgets/selection_indicator.dart` | 选择指示器 |
| 🟢 P2 | `lib/theme/theme.dart` | 主题 barrel 导出文件 |

### 3.2 覆盖率极低（< 30%，有追踪但几乎未命中）

| 文件 | 覆盖率 | 说明 |
|------|--------|------|
| `lib/views/templates/template_list_view.dart` | **0.2%** | 598 行仅命中 1 行 |
| `lib/services/vault_pairing_service.dart` | **1.0%** | 配对服务核心逻辑 |
| `lib/system/service_manager/vault_import_export_coordinator.dart` | **1.3%** | 导入导出协调器 |
| `lib/system/service_manager/vault_pairing_coordinator.dart` | **5.3%** | 配对协调器 |
| `lib/sync/lan_sync_client.dart` | **21.7%** | LAN 同步客户端 |
| `lib/sync/lan_sync_host_handler.dart` | **22.1%** | LAN 同步主机处理器 |
| `lib/widgets/account_edit_widgets.dart` | **27.1%** | 账户编辑表单组件 |
| `lib/theme/app_design_tokens.dart` | **32.6%** | 设计令牌（部分被测试） |
| `lib/services/device_alias_service.dart` | **33.3%** | 设备别名服务 |

---

## 4. 覆盖率数据分析

基于 `coverage/lcov.info`（96 个被追踪文件，115 个源码文件）：

| 指标 | 数值 |
|------|------|
| 被追踪文件 | 96 / 115 |
| 未追踪文件 | 19（见 3.1） |
| 总可执行行 | 13,541 |
| 命中行 | 7,892 |
| **整体行覆盖率** | **58.3%** |

### 覆盖率 TOP 10（高置信模块）
| 文件 | 覆盖率 | 命中/总行 |
|------|--------|----------|
| `utils/field_presets.dart` | 100.0% | 18/18 |
| `models/template_conflict_log.dart` | 100.0% | 24/24 |
| `widgets/inbox/inbox_action_card.dart` | 100.0% | 86/86 |
| `providers/theme_provider.dart` | 100.0% | 34/34 |
| `widgets/app_option_tile.dart` | 100.0% | 40/40 |
| `core/crypto_random.dart` | 100.0% | 5/5 |
| `sync/lan_sync_session.dart` | 100.0% | 30/30 |
| `system/service_manager/sync_server_url_store.dart` | 100.0% | 27/27 |
| `widgets/app_page_header.dart` | 97.2% | 35/36 |
| `system/service_manager/sync_coordinator.dart` | 97.1% | 33/34 |

### 覆盖率 BOTTOM 10（高风险缺口）
| 文件 | 覆盖率 | 命中/总行 |
|------|--------|----------|
| `widgets/inbox/inbox_models.dart` | 0.0% | 0/1 |
| `system/service_manager/default_sync_server_url.dart` | 0.0% | 0/8 |
| `views/accounts/totp_qr_scanner_view.dart` | 0.0% | 0/63 |
| `views/accounts/totp_credential_edit_view.dart` | 0.0% | 0/189 |
| `views/accounts/account_edit_utils.dart` | 0.0% | 0/57 |
| `views/templates/template_list_view.dart` | 0.2% | 1/598 |
| `services/vault_pairing_service.dart` | 1.0% | 1/98 |
| `l10n/app_localizations_en.dart` | 1.2% | 1/85 |
| `system/service_manager/vault_import_export_coordinator.dart` | 1.3% | 1/77 |
| `system/service_manager/vault_pairing_coordinator.dart` | 5.3% | 3/57 |

---

## 5. 测试模式总结

通过扫描 `test/` 目录，归纳出项目中反复出现的测试设计模式：

| 模式 | 典型用法 | 出现位置 |
|------|---------|---------|
| **Fake 服务注入** | `FakeIdentityService`、`FakeCryptoService`、`FakeAutoLockService` 等 | `test/fakes/` 被广泛引用 |
| **内存 SecureStorage** | `MemorySecureKeyValueStore` / `FakeSecureStorageService` | `identity_service_test.dart`、`sync_server_test_harness.dart` |
| **ServiceManager.testable** | 通过 `setInstanceForTesting` 注入全套 fake 依赖 | 几乎所有 View/Widget 测试 |
| **Mock 平台通道** | `TestDefaultBinaryMessengerBinding` 模拟 `flutter_secure_storage`、`Clipboard` | `unlock_view_test.dart`、`sensitive_clipboard_service_test.dart` |
| **Mock SharedPreferences** | `SharedPreferences.setMockInitialValues({})` | `sync_state_machine_test.dart`、`unlock_view_test.dart` |
| **固定屏幕尺寸** | `tester.binding.setSurfaceSize(Size(1200, 2000))` | `account_edit_view_test.dart` 等 Widget 测试 |
| **异步 pump 辅助** | `pumpUntilFound()` / `pumpUntilGone()` | `integration_test/support/smoke_test_helpers.dart` |
| **ChangeNotifier 状态监听** | `addListener(() => states.add(service.state))` | `sync_state_machine_test.dart`、`auto_lock_service_test.dart` |
| **临时目录隔离** | `Directory.systemTemp.createTempSync()` | `database_file_cipher_test.dart` |
| **addTearDown 清理** | `ServiceManager.resetInstance()`、`cancelPendingClear()` | 大量测试文件 |
| **Group 嵌套组织** | `group('ClassName', () { group('method', () { test(...) }) })` | 全局惯例 |

---

## 6. 集成测试覆盖评估

共 3 个集成测试文件、7 个 `testWidgets` 用例，均在 **PC 桌面端模拟环境**（`Size(1440, 1400)`）下运行。

### `smoke_happy_path_test.dart`（1 个用例）
- **目标**：最核心端到端路径快速验证
- **覆盖动作**：
  1. 启动应用并解锁
  2. 创建网站账户（名称、邮箱、网站、账号、密码）
  3. 搜索账户（SearchBar 输入、结果匹配）
  4. 导航到设置中心（验证“个性化与外观”、“安全设置”存在）

### `smoke_full_workflows_test.dart`（1 个用例）
- **目标**：主要工作区浅层遍历，防止大面积回归
- **覆盖动作**：
  1. 创建并编辑账户（预览 → 编辑 → 保存）
  2. 创建 TOTP 并关联到账户（otpauth URI 输入）
  3. 密码工具 → 打开生成器 → 保留结果
  4. Vault 体检（验证体检时间展示）
  5. 模板管理 → 新建自定义模板 → 添加字段 → 保存

### `regression_boundary_test.dart`（4 个用例）
- **目标**：QA 手工回归中最高频、最高风险路径
- **覆盖动作**：
  1. **删除账户确认流程**：长按 tile → 底部 sheet 删除 → AlertDialog 确认 → 验证消失
  2. **搜索过滤与清除**：输入匹配关键词 → 结果存在；输入不存在关键词 → 结果为空；点击清除 → 恢复
  3. **分类 Tab 切换**：全部 → 账户 → 安全笔记 → 2FA → 全部
  4. **错误密码解锁 → 正确密码解锁**：输入错误密码 → 预期“主密码不正确”；输入正确密码 → 进入账户中心

### 集成测试缺口
- **未覆盖**：生物识别解锁、同步设置/配对、模板冲突处理、通知中心、暗色/主题切换、数据导入导出、账户子集筛选、LAN 同步、TOTP 扫码
- **平台局限**：当前集成测试仅针对桌面端尺寸，缺少移动端布局验证

---

## 7. TODO / FIXME / HACK 清单

**结果：零条记录**

扫描 `test/` 与 `integration_test/` 全部 Dart 文件后，未找到 `TODO`、`FIXME`、`HACK`、`XXX`、`BUG`、`OPTIMIZE`、`NOTE` 等标记注释。

---

## 8. 关键结论与建议

1. **模型与基础服务层覆盖优秀**：`models/`、`core/`、`theme/` 部分文件达 100%，CRDT、加密、身份、TOTP 等核心逻辑测试充分。
2. **View 层覆盖严重倾斜**：`account_edit_view.dart`（1606 行，575 命中，35.8%）和 `template_list_view.dart`（598 行，1 命中，0.2%）是最大缺口。大量页面（home、settings、notifications、sync）完全无测试。
3. **配对/导入导出服务几乎裸奔**：`vault_pairing_service.dart`（1.0%）、`vault_import_export_coordinator.dart`（1.3%）、`vault_pairing_coordinator.dart`（5.3%）属于安全关键路径，应优先补测。
4. **LAN 同步覆盖不足**：`lan_sync_client.dart`（21.7%）、`lan_sync_host_handler.dart`（22.1%）虽存在单元测试，但实际命中行数偏低。
5. **Widget 组件大量未覆盖**：`account_edit_widgets.dart`、`inbox_filter_bar`、`selection_indicator`、`app_layout_builder` 等缺少独立 Widget 测试。
6. **集成测试仅 7 个用例，且全为桌面端**：建议增加移动端 surface size 的集成测试，以及覆盖同步、导入导出、生物识别等高风险路径的用例。
