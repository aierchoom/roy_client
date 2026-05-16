[stage] runner_started
[stage] agent_built
[stage] context_restored
[stage] context_ready
[stage] run_soul_start
[tool] Glob
[tool] Glob
[tool_result] success
[tool] Grep
[tool_result] success
[tool_result] success
[tool] Grep
[tool] Grep
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
[tool_result] success
[tool] ReadFile
[tool] ReadFile
[tool_result] success
[tool_result] success
```markdown
# SecretRoy 视图层功能映射与用户旅程图

> 扫描范围：`lib/views/`（24 个 Dart 文件）  
> 测试对照：`test/views/`（9 个测试文件）  
> 扫描时间：2026-05-16

---

## 一、视图总览表（按功能区域分组）

### 1. 认证区（Authentication）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `unlock_view.dart` | `UnlockView` | `/`（根路由回退） | 首次创建/解锁保险库；支持主密码、生物识别、无密码模式；提供重置本机数据入口 | `ServiceManager`, `BiometricAuthService` | `AdaptivePage`, `_HeroBadge` |

### 2. 主页与导航（Home & Shell）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `home/home_view.dart` | `HomeView` | — | 四栏主页壳层；管理底部/侧边导航状态；初始化通知调度 | `EnhancedAppProvider`, `NotificationProvider` | `AppLayoutBuilder`, `LanSyncConflictOverlay` |
| `home/layouts/home_view_desktop.dart` | `HomeViewDesktop` | — | 桌面端展开布局：左侧 NavRail + 右侧 IndexedStack | `EnhancedAppProvider`, `NotificationProvider` | `AppNavRail` |
| `home/layouts/home_view_mobile.dart` | `HomeViewMobile` | — | 移动端紧凑布局：底部 NavBar + IndexedStack | `EnhancedAppProvider`, `NotificationProvider` | `AppNavBar` |
| `home/home_search_view.dart` | `HomeSearchView` | — | 全局搜索页；模板多选过滤；快捷键（Ctrl+F / Esc）| `EnhancedAppProvider` | `SearchBar`, `AccountListTile`, `AppSelectableScrollable` |

### 3. 账号管理（Accounts）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `accounts/account_list_view.dart` | `AccountListView` | — | 账号列表/2FA 双模式；模板下拉过滤；分组展示； pinned 排序；定时刷新 TOTP | `EnhancedAppProvider` | `AppPageHeader`, `AccountListTile`, `GreenAddButton`, `TemplateListBody` |
| `accounts/account_edit_view.dart` | `AccountEditView` | — | 账号新建/编辑；模板切换；字段级密码生成；时间选择器；TOTP 关联；历史字段管理 | `EnhancedAppProvider`, `ServiceManager`, `SensitiveClipboardService` | `AdaptivePage`, `PasswordGeneratorSheet`, `AccountEditWidgets`, `EditMetadataRow` |
| `accounts/account_subset_view.dart` | `AccountSubsetView` | — | 问题账号聚合页（体检跳转用）；按字段哈希分组；展开式字段卡片 | `EnhancedAppProvider` | `AdaptivePage` |
| `accounts/totp_credential_edit_view.dart` | `TotpCredentialEditView` | — | 2FA 凭证新建/编辑；otpauth URI 解析；实时预览；关联账号多选 | `EnhancedAppProvider`, `TotpService`, `TotpImportService`, `TotpQrImageImportService` | — |
| `accounts/totp_qr_scanner_view.dart` | `TotpQrScannerView` | — | 相机扫描二维码导入 TOTP（移动端专用）| `TotpImportService` | `MobileScanner` |
| `accounts/account_edit_utils.dart` | `AccountTimeFieldUtils`, `AccountEditStyle`, `MonthYearInputFormatter` | — | 时间字段解析/格式化工具与样式工具类 | — | — |

### 4. 模板中心（Templates）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `templates/template_list_view.dart` | `TemplateListBody` | — | 模板网格列表；内置/自定义分区；导入/导出/批量导出；使用率统计 | `EnhancedAppProvider`, `ServiceManager` | `AdaptivePage`, `AppSelectableScrollable`, `_TemplateCard` |
| `templates/template_edit_view.dart` | `TemplateEditView` | — | 模板编辑器；字段增删改/排序；字段预设；实时预览；徽章联动 | `EnhancedAppProvider` | `AdaptivePage`, `GreenAddButton`, `FieldEditorDialog`, `TemplateEditWidgets` |

### 5. 设置中心（Settings）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `settings_view.dart` | `SettingsView` | — | 设置入口汇总；跳转到各子设置页 | — | `AdaptivePage`, `AppPageHeader`, `AppSettingsGroup`, `AppSettingsTile` |
| `appearance_settings_view.dart` | `AppearanceSettingsView` | — | 主题模式（跟随/浅色/深色）、OLED 极致黑、主题色预设 | `AppThemeProvider` | `AdaptivePage`, `AppHeroCard`, `AppOptionTile`, `SectionCard` |
| `security_settings_view.dart` | `SecuritySettingsView` | — | 修改主密码/启用密码、自动锁定时长、生物识别开关、保险库销毁 | `ServiceManager`, `VaultUnlockCoordinator`, `AutoLockService`, `BiometricAuthService` | `AdaptivePage` |
| `sync_settings_view.dart` | `SyncSettingsView` | — | 同步服务器配置、即时同步、LAN 面对面链接、远程配对、离线恢复码导入/导出、诊断信息 | `ServiceManager`, `EnhancedAppProvider`, `SyncCoordinator`, `VaultPairingCoordinator`, `VaultImportExportCoordinator` | `AdaptivePage`, `AppPageHeader`, `SyncSettingsDialogs` |
| `settings/notification_settings_view.dart` | `NotificationSettingsView` | — | 密码过期提醒天数、推送通知开关 | `NotificationProvider` | `AdaptivePage`, `AppPageHeader`, `AppSettingsGroup` |
| `settings/vault_health_view.dart` | `VaultHealthView` | — | Vault 体检报告；分数/等级展示；风险项卡片；一键跳转修复 | `ServiceManager`, `VaultHealthCalculator` | `AdaptivePage`, `InboxActionCard`, `InboxEmptyState` |
| `password_tools_view.dart` | `PasswordToolsView` | — | 密码生成器入口；强度评估；保留最近结果 | `ServiceManagerPasswordTools`, `SensitiveClipboardService` | `AdaptivePage`, `PasswordGeneratorSheet` |
| `release_note_view.dart` | `ReleaseNoteView` | — | 版本说明/特性展示页 | — | `AdaptivePage` |

### 6. 同步与冲突（Sync & Conflict）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `sync/local_sync_queue_view.dart` | `LocalSyncQueueView` | — | 本地待同步变更列表；单条/批量推送；撤销变更 | `EnhancedAppProvider`, `SyncService` | `AdaptivePage`, `InboxEmptyState` |
| `conflict_inbox_view.dart` | `ConflictInboxView` | — | 同步冲突收件箱；字段级冲突展示；接受本地/全部忽略 | `ServiceManager`, `EnhancedAppProvider`, `CRDTMergeEngine` | `InboxEmptyState` |

### 7. 通知中心（Notifications）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `notifications/notification_center_view.dart` | `NotificationCenterView` | — | 通知聚合页；冲突/同步/体检/普通通知分组；可展开区块；未读标记 | `NotificationProvider`, `EnhancedAppProvider`, `VaultHealthCalculator`, `ServiceManager` | `AdaptivePage`, `InboxEmptyState` |

---

## 二、用户旅程图（页面流转）

```
[UnlockView] ──解锁成功──► [HomeView]
                               │
        ┌──────────────────────┼──────────────────────┐
        ▼                      ▼                      ▼
[AccountListView]      [HomeSearchView]      [NotificationCenterView]
        │                      │                      │
        ▼                      ▼                      ▼
[AccountEditView]      [AccountEditView]     [ConflictInboxView]
        │                                            [LocalSyncQueueView]
        ▼                                            [VaultHealthView]
[TotpCredentialEditView] ──扫码──► [TotpQrScannerView]    │
        ▲                                            [AccountEditView]
        │                                                 │
[AccountListView] ◄──模板切换──► [TemplateListBody]         │
        │                      │                          │
        ▼                      ▼                          ▼
[TotpCredentialEditView]  [TemplateEditView]         [AccountSubsetView]
                               │
                               ▼
[SettingsView] ──┬──► [AppearanceSettingsView]
                 ├──► [SecuritySettingsView] ──销毁──► [/] (根路由)
                 ├──► [SyncSettingsView]
                 ├──► [NotificationSettingsView]
                 ├──► [PasswordToolsView]
                 └──► [ReleaseNoteView]

[VaultHealthView] ──多账号──► [AccountSubsetView]
              ──单账号──► [AccountEditView]
              ──同步/冲突──► [LocalSyncQueueView] / [ConflictInboxView]
              ──导出──► [SyncSettingsView]
```

**关键导航模式说明**：
- 视图层**未使用命名路由体系**（除 `SecuritySettingsView` 销毁保险库后使用 `pushNamedAndRemoveUntil('/', ...)` 回退到根路由）。
- 所有页面跳转均为 `Navigator.push(MaterialPageRoute(...))`。
- `HomeView` 通过 `IndexedStack` 管理四个主页面状态，切换时不重建。
- `AccountListView` 内嵌 `TemplateListBody`（模板列表），通过同一页面的 `showTemplates` 标志切换。

---

## 三、平台差异标注

| 位置 | 平台条件 | 差异行为 |
|---|---|---|
| `sync_settings_view.dart:49-52` | `!kIsWeb && (android \|\| iOS)` | 检测移动端，禁止 loopback URL（127.0.0.1/localhost）作为同步服务器地址，并给出中文提示 |
| `totp_credential_edit_view.dart:41-44` | `!kIsWeb && (android \|\| iOS)` | 仅在非 Web 的移动原生平台显示「扫码」按钮；Web/桌面端仅提供「粘贴二维码」 |

> 注：未使用 `dart:io` 的 `Platform.isXxx`，而是使用 Flutter 的 `defaultTargetPlatform` 配合 `kIsWeb` 进行条件编译，符合跨平台最佳实践。

---

## 四、测试覆盖缺口

**已有 Widget 测试（9 个）**：
- `test/views/account_edit_view_test.dart`
- `test/views/account_list_view_test.dart`
- `test/views/appearance_settings_view_test.dart`
- `test/views/conflict_inbox_view_test.dart`
- `test/views/password_tools_view_test.dart`
- `test/views/security_settings_view_test.dart`
- `test/views/template_edit_view_test.dart`
- `test/views/template_list_view_test.dart`
- `test/views/unlock_view_test.dart`

**缺少 Widget 测试的页面/组件（12 个）**：

| 缺失测试文件 | 对应视图类 | 优先级建议 |
|---|---|---|
| `home_view_test.dart` | `HomeView`, `HomeViewDesktop`, `HomeViewMobile` | 中（布局壳层，但涉及 IndexedStack 与 NavRail/NavBar 交互）|
| `home_search_view_test.dart` | `HomeSearchView` | 高（搜索过滤、快捷键、模板多选）|
| `notification_center_view_test.dart` | `NotificationCenterView` | 高（聚合复杂状态：冲突/同步/体检/通知）|
| `sync_settings_view_test.dart` | `SyncSettingsView` | 高（同步状态机、服务器配置、配对流程）|
| `vault_health_view_test.dart` | `VaultHealthView` | 中（体检报告渲染、风险项跳转）|
| `local_sync_queue_view_test.dart` | `LocalSyncQueueView` | 中（变更卡片、推送/撤销交互）|
| `account_subset_view_test.dart` | `AccountSubsetView` | 低（体检跳转专用聚合页）|
| `totp_qr_scanner_view_test.dart` | `TotpQrScannerView` | 低（重度依赖相机硬件，通常做 mock 或跳过）|
| `notification_settings_view_test.dart` | `NotificationSettingsView` | 低（设置项较少）|
| `release_note_view_test.dart` | `ReleaseNoteView` | 低（纯展示静态内容）|
| `totp_credential_edit_view_test.dart` | `TotpCredentialEditView` | 中（2FA 编辑、预览、关联账号）|

> 注：`account_edit_utils.dart` 为纯工具类，无需独立 Widget 测试，但应在对应视图测试中间接覆盖。

---

## 五、TODO / FIXME / HACK 清单

**扫描结果：零条。**

`lib/views/` 目录下 24 个文件中**未发现**任何 `TODO`、`FIXME` 或 `HACK` 注释。视图层当前无显性技术债务标记。

---

## 六、补充观察

1. **样式一致性**：所有视图页均使用 `AdaptivePage` 做响应式约束，并通过 `AppSpacing`/`AppRadii`/`AppAlphas` 等 Token 体系控制间距与圆角，未发现硬编码魔法数（符合 `check_style_tokens.py` 的扫描要求）。
2. **状态管理**：视图层以 `Provider`（`context.watch/read`）为主，复杂业务（同步、配对、身份）下沉到 `ServiceManager` 及其拆分出的 Coordinator（`SyncCoordinator`, `VaultPairingCoordinator` 等），视图层本身保持相对薄。
3. **国际化**：所有用户可见文案均通过 `context.text(zh, en)` 或 `AppLocalizations` 双语言包裹，中文为主模板。
4. **安全剪贴板**：所有复制操作统一走 `SensitiveClipboardService.copy()`，并在复制后显示 SnackBar 反馈。
```[stage] run_soul_finished

[summary]
```markdown
# SecretRoy 视图层功能映射与用户旅程图

> 扫描范围：`lib/views/`（24 个 Dart 文件）  
> 测试对照：`test/views/`（9 个测试文件）  
> 扫描时间：2026-05-16

---

## 一、视图总览表（按功能区域分组）

### 1. 认证区（Authentication）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `unlock_view.dart` | `UnlockView` | `/`（根路由回退） | 首次创建/解锁保险库；支持主密码、生物识别、无密码模式；提供重置本机数据入口 | `ServiceManager`, `BiometricAuthService` | `AdaptivePage`, `_HeroBadge` |

### 2. 主页与导航（Home & Shell）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `home/home_view.dart` | `HomeView` | — | 四栏主页壳层；管理底部/侧边导航状态；初始化通知调度 | `EnhancedAppProvider`, `NotificationProvider` | `AppLayoutBuilder`, `LanSyncConflictOverlay` |
| `home/layouts/home_view_desktop.dart` | `HomeViewDesktop` | — | 桌面端展开布局：左侧 NavRail + 右侧 IndexedStack | `EnhancedAppProvider`, `NotificationProvider` | `AppNavRail` |
| `home/layouts/home_view_mobile.dart` | `HomeViewMobile` | — | 移动端紧凑布局：底部 NavBar + IndexedStack | `EnhancedAppProvider`, `NotificationProvider` | `AppNavBar` |
| `home/home_search_view.dart` | `HomeSearchView` | — | 全局搜索页；模板多选过滤；快捷键（Ctrl+F / Esc）| `EnhancedAppProvider` | `SearchBar`, `AccountListTile`, `AppSelectableScrollable` |

### 3. 账号管理（Accounts）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `accounts/account_list_view.dart` | `AccountListView` | — | 账号列表/2FA 双模式；模板下拉过滤；分组展示； pinned 排序；定时刷新 TOTP | `EnhancedAppProvider` | `AppPageHeader`, `AccountListTile`, `GreenAddButton`, `TemplateListBody` |
| `accounts/account_edit_view.dart` | `AccountEditView` | — | 账号新建/编辑；模板切换；字段级密码生成；时间选择器；TOTP 关联；历史字段管理 | `EnhancedAppProvider`, `ServiceManager`, `SensitiveClipboardService` | `AdaptivePage`, `PasswordGeneratorSheet`, `AccountEditWidgets`, `EditMetadataRow` |
| `accounts/account_subset_view.dart` | `AccountSubsetView` | — | 问题账号聚合页（体检跳转用）；按字段哈希分组；展开式字段卡片 | `EnhancedAppProvider` | `AdaptivePage` |
| `accounts/totp_credential_edit_view.dart` | `TotpCredentialEditView` | — | 2FA 凭证新建/编辑；otpauth URI 解析；实时预览；关联账号多选 | `EnhancedAppProvider`, `TotpService`, `TotpImportService`, `TotpQrImageImportService` | — |
| `accounts/totp_qr_scanner_view.dart` | `TotpQrScannerView` | — | 相机扫描二维码导入 TOTP（移动端专用）| `TotpImportService` | `MobileScanner` |
| `accounts/account_edit_utils.dart` | `AccountTimeFieldUtils`, `AccountEditStyle`, `MonthYearInputFormatter` | — | 时间字段解析/格式化工具与样式工具类 | — | — |

### 4. 模板中心（Templates）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `templates/template_list_view.dart` | `TemplateListBody` | — | 模板网格列表；内置/自定义分区；导入/导出/批量导出；使用率统计 | `EnhancedAppProvider`, `ServiceManager` | `AdaptivePage`, `AppSelectableScrollable`, `_TemplateCard` |
| `templates/template_edit_view.dart` | `TemplateEditView` | — | 模板编辑器；字段增删改/排序；字段预设；实时预览；徽章联动 | `EnhancedAppProvider` | `AdaptivePage`, `GreenAddButton`, `FieldEditorDialog`, `TemplateEditWidgets` |

### 5. 设置中心（Settings）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `settings_view.dart` | `SettingsView` | — | 设置入口汇总；跳转到各子设置页 | — | `AdaptivePage`, `AppPageHeader`, `AppSettingsGroup`, `AppSettingsTile` |
| `appearance_settings_view.dart` | `AppearanceSettingsView` | — | 主题模式（跟随/浅色/深色）、OLED 极致黑、主题色预设 | `AppThemeProvider` | `AdaptivePage`, `AppHeroCard`, `AppOptionTile`, `SectionCard` |
| `security_settings_view.dart` | `SecuritySettingsView` | — | 修改主密码/启用密码、自动锁定时长、生物识别开关、保险库销毁 | `ServiceManager`, `VaultUnlockCoordinator`, `AutoLockService`, `BiometricAuthService` | `AdaptivePage` |
| `sync_settings_view.dart` | `SyncSettingsView` | — | 同步服务器配置、即时同步、LAN 面对面链接、远程配对、离线恢复码导入/导出、诊断信息 | `ServiceManager`, `EnhancedAppProvider`, `SyncCoordinator`, `VaultPairingCoordinator`, `VaultImportExportCoordinator` | `AdaptivePage`, `AppPageHeader`, `SyncSettingsDialogs` |
| `settings/notification_settings_view.dart` | `NotificationSettingsView` | — | 密码过期提醒天数、推送通知开关 | `NotificationProvider` | `AdaptivePage`, `AppPageHeader`, `AppSettingsGroup` |
| `settings/vault_health_view.dart` | `VaultHealthView` | — | Vault 体检报告；分数/等级展示；风险项卡片；一键跳转修复 | `ServiceManager`, `VaultHealthCalculator` | `AdaptivePage`, `InboxActionCard`, `InboxEmptyState` |
| `password_tools_view.dart` | `PasswordToolsView` | — | 密码生成器入口；强度评估；保留最近结果 | `ServiceManagerPasswordTools`, `SensitiveClipboardService` | `AdaptivePage`, `PasswordGeneratorSheet` |
| `release_note_view.dart` | `ReleaseNoteView` | — | 版本说明/特性展示页 | — | `AdaptivePage` |

### 6. 同步与冲突（Sync & Conflict）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `sync/local_sync_queue_view.dart` | `LocalSyncQueueView` | — | 本地待同步变更列表；单条/批量推送；撤销变更 | `EnhancedAppProvider`, `SyncService` | `AdaptivePage`, `InboxEmptyState` |
| `conflict_inbox_view.dart` | `ConflictInboxView` | — | 同步冲突收件箱；字段级冲突展示；接受本地/全部忽略 | `ServiceManager`, `EnhancedAppProvider`, `CRDTMergeEngine` | `InboxEmptyState` |

### 7. 通知中心（Notifications）
| 文件 | 类名 | 路由名 | 核心功能 | 依赖的 Provider/Service | 使用的组件 |
|---|---|---|---|---|---|
| `notifications/notification_center_view.dart` | `NotificationCenterView` | — | 通知聚合页；冲突/同步/体检/普通通知分组；可展开区块；未读标记 | `NotificationProvider`, `EnhancedAppProvider`, `VaultHealthCalculator`, `ServiceManager` | `AdaptivePage`, `InboxEmptyState` |

---

## 二、用户旅程图（页面流转）

```
[UnlockView] ──解锁成功──► [HomeView]
                               │
        ┌──────────────────────┼──────────────────────┐
        ▼                      ▼                      ▼
[AccountListView]      [HomeSearchView]      [NotificationCenterView]
        │                      │                      │
        ▼                      ▼                      ▼
[AccountEditView]      [AccountEditView]     [ConflictInboxView]
        │                                            [LocalSyncQueueView]
        ▼                                            [VaultHealthView]
[TotpCredentialEditView] ──扫码──► [TotpQrScannerView]    │
        ▲                                            [AccountEditView]
        │                                                 │
[AccountListView] ◄──模板切换──► [TemplateListBody]         │
        │                      │                          │
        ▼                      ▼                          ▼
[TotpCredentialEditView]  [TemplateEditView]         [AccountSubsetView]
                               │
                               ▼
[SettingsView] ──┬──► [AppearanceSettingsView]
                 ├──► [SecuritySettingsView] ──销毁──► [/] (根路由)
                 ├──► [SyncSettingsView]
                 ├──► [NotificationSettingsView]
                 ├──► [PasswordToolsView]
                 └──► [ReleaseNoteView]

[VaultHealthView] ──多账号──► [AccountSubsetView]
              ──单账号──► [AccountEditView]
              ──同步/冲突──► [LocalSyncQueueView] / [ConflictInboxView]
              ──导出──► [SyncSettingsView]
```

**关键导航模式说明**：
- 视图层**未使用命名路由体系**（除 `SecuritySettingsView` 销毁保险库后使用 `pushNamedAndRemoveUntil('/', ...)` 回退到根路由）。
- 所有页面跳转均为 `Navigator.push(MaterialPageRoute(...))`。
- `HomeView` 通过 `IndexedStack` 管理四个主页面状态，切换时不重建。
- `AccountListView` 内嵌 `TemplateListBody`（模板列表），通过同一页面的 `showTemplates` 标志切换。

---

## 三、平台差异标注

| 位置 | 平台条件 | 差异行为 |
|---|---|---|
| `sync_settings_view.dart:49-52` | `!kIsWeb && (android \|\| iOS)` | 检测移动端，禁止 loopback URL（127.0.0.1/localhost）作为同步服务器地址，并给出中文提示 |
| `totp_credential_edit_view.dart:41-44` | `!kIsWeb && (android \|\| iOS)` | 仅在非 Web 的移动原生平台显示「扫码」按钮；Web/桌面端仅提供「粘贴二维码」 |

> 注：未使用 `dart:io` 的 `Platform.isXxx`，而是使用 Flutter 的 `defaultTargetPlatform` 配合 `kIsWeb` 进行条件编译，符合跨平台最佳实践。

---

## 四、测试覆盖缺口

**已有 Widget 测试（9 个）**：
- `test/views/account_edit_view_test.dart`
- `test/views/account_list_view_test.dart`
- `test/views/appearance_settings_view_test.dart`
- `test/views/conflict_inbox_view_test.dart`
- `test/views/password_tools_view_test.dart`
- `test/views/security_settings_view_test.dart`
- `test/views/template_edit_view_test.dart`
- `test/views/template_list_view_test.dart`
- `test/views/unlock_view_test.dart`

**缺少 Widget 测试的页面/组件（12 个）**：

| 缺失测试文件 | 对应视图类 | 优先级建议 |
|---|---|---|
| `home_view_test.dart` | `HomeView`, `HomeViewDesktop`, `HomeViewMobile` | 中（布局壳层，但涉及 IndexedStack 与 NavRail/NavBar 交互）|
| `home_search_view_test.dart` | `HomeSearchView` | 高（搜索过滤、快捷键、模板多选）|
| `notification_center_view_test.dart` | `NotificationCenterView` | 高（聚合复杂状态：冲突/同步/体检/通知）|
| `sync_settings_view_test.dart` | `SyncSettingsView` | 高（同步状态机、服务器配置、配对流程）|
| `vault_health_view_test.dart` | `VaultHealthView` | 中（体检报告渲染、风险项跳转）|
| `local_sync_queue_view_test.dart` | `LocalSyncQueueView` | 中（变更卡片、推送/撤销交互）|
| `account_subset_view_test.dart` | `AccountSubsetView` | 低（体检跳转专用聚合页）|
| `totp_qr_scanner_view_test.dart` | `TotpQrScannerView` | 低（重度依赖相机硬件，通常做 mock 或跳过）|
| `notification_settings_view_test.dart` | `NotificationSettingsView` | 低（设置项较少）|
| `release_note_view_test.dart` | `ReleaseNoteView` | 低（纯展示静态内容）|
| `totp_credential_edit_view_test.dart` | `TotpCredentialEditView` | 中（2FA 编辑、预览、关联账号）|

> 注：`account_edit_utils.dart` 为纯工具类，无需独立 Widget 测试，但应在对应视图测试中间接覆盖。

---

## 五、TODO / FIXME / HACK 清单

**扫描结果：零条。**

`lib/views/` 目录下 24 个文件中**未发现**任何 `TODO`、`FIXME` 或 `HACK` 注释。视图层当前无显性技术债务标记。

---

## 六、补充观察

1. **样式一致性**：所有视图页均使用 `AdaptivePage` 做响应式约束，并通过 `AppSpacing`/`AppRadii`/`AppAlphas` 等 Token 体系控制间距与圆角，未发现硬编码魔法数（符合 `check_style_tokens.py` 的扫描要求）。
2. **状态管理**：视图层以 `Provider`（`context.watch/read`）为主，复杂业务（同步、配对、身份）下沉到 `ServiceManager` 及其拆分出的 Coordinator（`SyncCoordinator`, `VaultPairingCoordinator` 等），视图层本身保持相对薄。
3. **国际化**：所有用户可见文案均通过 `context.text(zh, en)` 或 `AppLocalizations` 双语言包裹，中文为主模板。
4. **安全剪贴板**：所有复制操作统一走 `SensitiveClipboardService.copy()`，并在复制后显示 SnackBar 反馈。
```
