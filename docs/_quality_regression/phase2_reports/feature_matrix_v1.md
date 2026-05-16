# SecretRoy 功能清单 v1.0（Feature Matrix）

> 生成依据：Phase 1 扫描报告（视图层、服务层、基础设施、组件库）  
> 覆盖范围：24 个视图页面 + 18 个服务 + 25 个组件文件 + 基础设施层  
> 生成时间：2026-05-16

---

## 一、功能总览表

### 1. 认证 / 解锁

| 功能名称 | 功能描述 | 涉及页面 | 涉及服务 | 测试覆盖 |
|---|---|---|---|---|
| 首次创建保险库 | 新用户设置主密码，初始化加密数据库与身份 | `UnlockView` | `ServiceManager`, `EnhancedCryptoService`, `IdentityService`, `DatabaseFileKeyManager`, `DatabaseFileCipher` | 有 |
| 主密码解锁 | 输入主密码解锁保险库，加载所有业务数据 | `UnlockView` | `ServiceManager`, `EnhancedCryptoService`, `VaultUnlockCoordinator` | 有 |
| 生物识别解锁 | Face ID / 指纹解锁并自动填充主密码 | `UnlockView` | `BiometricAuthService`, `ServiceManager` | 有 |
| 无密码模式 | 允许不设置主密码直接解锁（降低安全级别） | `UnlockView` | `ServiceManager`, `VaultUnlockCoordinator` | 部分 |
| 自动锁定 | 应用切后台或超时时自动锁定，清理密钥状态 | `UnlockView`（返回） | `AutoLockService`, `AutoLockObserver`, `ServiceManager` | 有 |
| 修改主密码 | 验证旧密码后轮换数据库密钥 envelope | `SecuritySettingsView` | `EnhancedCryptoService`, `DatabaseFileKeyManager` | 有 |
| 保险库销毁 | 删除所有本地数据、身份与加密文件，重置应用 | `SecuritySettingsView` | `ServiceManager`, `SecureStorageService` | 有 |
| 生物识别开关 | 启用/禁用生物识别，加密存储/删除主密码 | `SecuritySettingsView` | `BiometricAuthService` | 有 |

### 2. 账号管理

| 功能名称 | 功能描述 | 涉及页面 | 涉及服务 | 测试覆盖 |
|---|---|---|---|---|
| 账号列表浏览 | 网格/列表双模式展示；模板下拉过滤；分组与置顶排序 | `AccountListView` | `EnhancedAppProvider`, `SecureStorageService` | 有 |
| 新建/编辑账号 | 基于模板创建或编辑账号；字段级密码生成；时间选择器 | `AccountEditView` | `EnhancedAppProvider`, `ServiceManager`, `SensitiveClipboardService` | 有 |
| 账号删除与软删除 | 软删除账号（保留同步标记），支持恢复逻辑 | `AccountListView`, `AccountEditView` | `SecureStorageService`, `VaultDataRepository` | 有 |
| 置顶（Pin） | 切换账号置顶状态，影响列表排序 | `AccountListView` | `SecureStorageService` | 有 |
| 字段复制（安全剪贴板） | 复制字段值到剪贴板并定时清理；SHA-256 hash 防误删 | `AccountListView`, `AccountEditView` | `SensitiveClipboardService` | 有 |
| 敏感信息掩码 | 密码等敏感字段默认掩码，点击展开 | `AccountListView` | — | 有 |
| 模板切换 | 编辑时切换账号模板，字段自动映射/保留 | `AccountEditView` | `EnhancedAppProvider` | 有 |
| 历史字段管理 | 保留旧模板字段值，避免数据丢失 | `AccountEditView` | `EnhancedAppProvider` | 部分 |
| 问题账号聚合 | 按字段哈希分组展示重复/异常账号（体检跳转） | `AccountSubsetView` | `EnhancedAppProvider` | 无 |
| TOTP 关联 | 账号与 2FA 凭证的关联/解绑 | `AccountEditView`, `TotpCredentialEditView` | `EnhancedAppProvider`, `TotpService` | 部分 |

### 3. 模板管理

| 功能名称 | 功能描述 | 涉及页面 | 涉及服务 | 测试覆盖 |
|---|---|---|---|---|
| 模板列表浏览 | 网格展示内置/自定义模板；使用率统计 | `TemplateListBody` | `EnhancedAppProvider`, `ServiceManager` | 有 |
| 新建/编辑模板 | 字段增删改、排序、预设选择、实时预览 | `TemplateEditView` | `EnhancedAppProvider` | 有 |
| 模板导入/导出 | 单条或批量导出模板为 JSON；导入覆盖 | `TemplateListBody` | `ServiceManager`, `VaultImportExportCoordinator` | 部分 |
| 内置模板预设 | 10 组字段预设（银行卡、身份证、WiFi 等） | `TemplateEditView` | `FieldPreset` / `kFieldPresets` | 部分 |
| 模板删除 | 软删除自定义模板（使用中则禁止删除） | `TemplateListBody`, `TemplateEditView` | `SecureStorageService` | 有 |
| 模板徽章联动 | 根据标题自动生成两字缩写徽章 | `TemplateListBody`, `TemplateEditView` | `templateBadgeText` | 部分 |
| 图标选择 | 57 个 Material outlined 图标可选 | `TemplateEditView` | `kTemplateIconOptions` | 无 |

### 4. TOTP / 2FA

| 功能名称 | 功能描述 | 涉及页面 | 涉及服务 | 测试覆盖 |
|---|---|---|---|---|
| TOTP 码生成 | 按 RFC 6238 生成 6/8 位 TOTP 码；支持 SHA1/SHA256/SHA512 | `AccountListView`（列表徽章） | `TotpService` | 有 |
| TOTP 凭证新建/编辑 | 手动输入 secret、issuer、account；otpauth URI 解析；实时预览 | `TotpCredentialEditView` | `TotpService`, `TotpImportService` | 无 |
| 扫码导入 TOTP | 相机扫描二维码导入（移动端专用） | `TotpQrScannerView` | `TotpImportService` | 无 |
| 图片 QR 解码导入 | 从剪贴板图片或文件解码 QR 并导入 | `TotpCredentialEditView` | `TotpQrImageImportService` | 有 |
| 文本/URI 导入 | 粘贴 otpauth URI 或纯 secret 文本 | `TotpCredentialEditView` | `TotpImportService` | 有 |
| 关联账号多选 | 将 TOTP 凭证关联到多个账号 | `TotpCredentialEditView` | `EnhancedAppProvider` | 部分 |
| 定时刷新 TOTP | 账号列表定时刷新 TOTP 码与倒计时 | `AccountListView` | `TotpService` | 部分 |

### 5. 密码工具

| 功能名称 | 功能描述 | 涉及页面 | 涉及服务 | 测试覆盖 |
|---|---|---|---|---|
| 密码生成器 | 长度滑块、大写/小写/数字/符号开关、一键生成 | `PasswordToolsView`, `AccountEditView` | `EnhancedCryptoService`, `ServiceManagerPasswordTools` | 有 |
| 密码强度评估 | 0-100 分评分 + 文字等级（弱/中/强） | `PasswordToolsView`, `AccountEditView` | `EnhancedCryptoService` | 有 |
| 保留最近结果 | 保存最近生成的密码记录 | `PasswordToolsView` | `ServiceManagerPasswordTools` | 无 |
| 字段级密码生成 | 账号编辑时直接为密码字段生成并应用 | `AccountEditView` | `PasswordGeneratorSheet`, `EnhancedCryptoService` | 有 |

### 6. 同步

| 功能名称 | 功能描述 | 涉及页面 | 涉及服务 | 测试覆盖 |
|---|---|---|---|---|
| 同步服务器配置 | 设置/修改同步服务器 URL；移动端禁止 loopback | `SyncSettingsView` | `SyncCoordinator`, `SyncServerUrlStore` | 无 |
| 即时同步（Pull/Push） | 手动触发与服务端的同步拉取/推送 | `SyncSettingsView`, `LocalSyncQueueView` | `SyncService`, `SyncCoordinator` | 有 |
| 本地同步变更箱 | 查看未推送的 create/update/delete 变更；单条/批量推送；撤销 | `LocalSyncQueueView` | `SyncService`, `SecureStorageService` | 无 |
| CRDT 冲突合并 | 字段级 CRDT 自动合并；冲突日志记录 | `ConflictInboxView`（后台） | `CRDTMergeEngine`, `SyncService` | 有 |
| 冲突收件箱 | 字段级冲突展示；接受本地/全部忽略 | `ConflictInboxView` | `ServiceManager`, `EnhancedAppProvider`, `CRDTMergeEngine` | 有 |
| 同步状态机 | offline / syncing / synced / error / conflictRecovery | `SyncSettingsView`, `HomeView` | `SyncService`, `SyncCoordinator` | 有 |
| LAN 同步冲突弹窗 | LAN 直连同步时自动弹出冲突确认 Sheet | `HomeView`（Overlay） | `LanSyncCoordinator`, `LanSyncConflictSheet` | 无 |
| 离线恢复码导入/导出 | PBKDF2+AES-GCM-256 加密的安全链接码 | `SyncSettingsView` | `IdentityService`, `VaultImportExportCoordinator` | 有 |
| 备份包导出/验证 | 加密导出完整备份包并验证完整性 | `SyncSettingsView` | `VaultDumpCoordinator` | 有 |

### 7. 设备配对

| 功能名称 | 功能描述 | 涉及页面 | 涉及服务 | 测试覆盖 |
|---|---|---|---|---|
| LAN 面对面配对 | UDP 广播 + HTTP claim + X25519 加密传输 | `SyncSettingsView` | `LanPairingService`, `VaultPairingCrypto` | 有 |
| 服务端配对（中继） | 创建/加入配对会话；审批请求；拉取 bundle | `SyncSettingsView` | `VaultPairingService`, `VaultPairingCoordinator` | 有 |
| 配对码协商 | 8 位可读字符配对码生成与校验 | `SyncSettingsView` | `LanPairingService` | 有 |
| 设备别名 | 自定义设备显示名称，优先缓存回退 l10n | `SyncSettingsView`, `AccountEditView`（元数据） | `DeviceAliasService` | 无 |
| 身份导出/导入 | 设备与 Vault 身份的加密导出与导入 | `SyncSettingsView` | `IdentityService`, `VaultImportExportCoordinator` | 有 |

### 8. 保险库健康

| 功能名称 | 功能描述 | 涉及页面 | 涉及服务 | 测试覆盖 |
|---|---|---|---|---|
| 健康评分计算 | 弱密码、重复密码、过期记录、不完整记录、缺失 2FA 综合评分 | `VaultHealthView` | `VaultHealthCalculator` | 有 |
| 风险项展示 | 分数/等级展示；分类风险卡片 | `VaultHealthView` | `VaultHealthCalculator`, `ServiceManager` | 无 |
| 一键跳转修复 | 从风险项直接跳转到编辑页或聚合页 | `VaultHealthView` | `ServiceManager` | 无 |
| 通知生成体检项 | 通知中心聚合体检结果通知 | `NotificationCenterView` | `NotificationService`, `VaultHealthCalculator` | 部分 |

### 9. 通知中心

| 功能名称 | 功能描述 | 涉及页面 | 涉及服务 | 测试覆盖 |
|---|---|---|---|---|
| 通知聚合页 | 冲突/同步/体检/普通通知分组；可展开区块；未读标记 | `NotificationCenterView` | `NotificationProvider`, `EnhancedAppProvider` | 无 |
| 密码过期提醒 | 按设定天数扫描并生成密码过期通知 | `NotificationCenterView`（后台） | `NotificationService`, `SecureStorageService` | 部分 |
| 弱密码提醒 | 扫描并生成弱密码通知 | `NotificationCenterView`（后台） | `NotificationService`, `EnhancedAppProvider` | 部分 |
| 定时每日检查 | 本地推送每日定时检查提醒 | `NotificationSettingsView`（后台） | `NotificationService` | 无 |
| 通知已读/删除 | 标记已读、删除单条/全部通知 | `NotificationCenterView` | `NotificationProvider`, `SecureStorageService` | 无 |
| 推送开关 | 启用/禁用本地推送通知 | `NotificationSettingsView` | `NotificationProvider` | 无 |

### 10. 设置 / 个性化

| 功能名称 | 功能描述 | 涉及页面 | 涉及服务 | 测试覆盖 |
|---|---|---|---|---|
| 主题模式切换 | 跟随系统 / 浅色 / 深色 | `AppearanceSettingsView` | `AppThemeProvider` | 有 |
| OLED 极致黑 | 深色模式下使用纯黑背景 | `AppearanceSettingsView` | `AppThemeProvider` | 有 |
| 主题色预设 | 11 个品牌种子色切换 | `AppearanceSettingsView` | `AppThemeProvider` | 有 |
| 自动锁定时长 | 设置锁定间隔（立即 / 5s~10m / 永不） | `SecuritySettingsView` | `AutoLockService` | 有 |
| 密码过期提醒天数 | 设置密码过期检查阈值 | `NotificationSettingsView` | `NotificationProvider` | 无 |
| 版本说明 | 版本特性展示静态页 | `ReleaseNoteView` | — | 无 |
| 设置入口导航 | 汇总各子设置页入口 | `SettingsView` | — | 无 |

### 11. 搜索

| 功能名称 | 功能描述 | 涉及页面 | 涉及服务 | 测试覆盖 |
|---|---|---|---|---|
| 全局搜索 | 账号关键字实时过滤；模板多选过滤 | `HomeSearchView` | `EnhancedAppProvider` | 无 |
| 快捷键支持 | Ctrl+F 唤起搜索、Esc 关闭 | `HomeSearchView` | — | 无 |
| 搜索结果列表 | 复用 `AccountListTile` 展示搜索结果 | `HomeSearchView` | `EnhancedAppProvider` | 无 |

---

## 二、用户旅程映射

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           首次打开 App（冷启动）                                   │
│  1. main() → ServiceManager.initialize() → 检测数据库存在                           │
│     └─ 无数据库 → UnlockView（创建保险库）                                          │
│     └─ 有数据库 → UnlockView（解锁）                                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           解锁成功 → HomeView                                      │
│  2. 四栏主页壳层（IndexedStack：账号 / 模板 / 设置 / 通知）                          │
│     └─ 自动初始化通知调度、生命周期监听                                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           账号管理旅程                                              │
│  3. AccountListView                                                             │
│     ├─ 浏览账号 → 展开/折叠 → 复制字段 → 长按菜单 → 置顶/编辑/删除                 │
│     ├─ 模板下拉过滤 → 切换 showTemplates → TemplateListBody                        │
│     ├─ 点击「+」→ AccountEditView（新建）                                         │
│     │    ├─ 选择模板 → 填写字段 → 密码生成器 → 保存                               │
│     │    ├─ 关联 TOTP → TotpCredentialEditView                                    │
│     │    └─ 模板切换 → 字段映射/历史保留                                          │
│     ├─ 点击账号 → AccountEditView（编辑）                                         │
│     └─ 定时刷新 TOTP 码（列表徽章）                                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           模板管理旅程                                              │
│  4. TemplateListBody                                                            │
│     ├─ 浏览内置/自定义模板 → 使用率统计                                           │
│     ├─ 点击「+」/模板 → TemplateEditView（新建/编辑）                             │
│     │    ├─ 字段增删改排序 → 字段预设选择 → 实时预览                               │
│     │    └─ 图标选择 → 徽章联动                                                   │
│     ├─ 导入/导出模板 JSON                                                         │
│     └─ 删除自定义模板（使用中则禁止）                                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           搜索旅程                                                  │
│  5. HomeSearchView（Ctrl+F 唤起）                                                │
│     ├─ 输入关键字 → 实时过滤账号                                                  │
│     ├─ 模板多选过滤                                                               │
│     └─ 点击结果 → AccountEditView                                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           TOTP / 2FA 旅程                                          │
│  6. TotpCredentialEditView                                                      │
│     ├─ 手动输入 secret / issuer / account → 实时预览                              │
│     ├─ 粘贴 otpauth URI → 自动解析                                                │
│     ├─ 移动端：点击「扫码」→ TotpQrScannerView → 相机扫码                         │
│     ├─ 桌面端/Web：粘贴 QR 图片 → TotpQrImageImportService 解码                   │
│     └─ 关联账号多选 → 保存                                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           同步与配对旅程                                            │
│  7. SyncSettingsView                                                            │
│     ├─ 配置同步服务器 URL                                                         │
│     ├─ 点击「即时同步」→ 触发 Pull/Push                                           │
│     ├─ LAN 面对面链接 → 启动/停止主机 → 配对码协商 → X25519 加密传输               │
│     ├─ 远程配对 → 创建/加入配对会话 → 审批 → 拉取 bundle                          │
│     ├─ 离线恢复码导出/导入（PBKDF2+AES-GCM-256）                                  │
│     ├─ 备份包导出/验证                                                            │
│     └─ 查看诊断信息                                                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           冲突与队列旅程                                            │
│  8. LocalSyncQueueView                                                          │
│     ├─ 查看本地待同步变更列表（create/update/delete）                             │
│     ├─ 单条/批量推送                                                              │
│     └─ 撤销变更                                                                   │
│  9. ConflictInboxView                                                           │
│     ├─ 查看字段级冲突详情                                                         │
│     ├─ 接受本地 / 全部忽略                                                        │
│     └─ 自动 CRDT 合并（后台）                                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           保险库健康旅程                                            │
│  10. VaultHealthView                                                            │
│     ├─ 查看健康评分与等级                                                         │
│     ├─ 风险项卡片 → 一键跳转                                                      │
│     │    ├─ 单账号问题 → AccountEditView                                          │
│     │    ├─ 多账号问题 → AccountSubsetView                                        │
│     │    ├─ 同步/冲突问题 → LocalSyncQueueView / ConflictInboxView               │
│     │    └─ 导出 → SyncSettingsView                                               │
│     └─ 触发通知中心体检通知                                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           通知中心旅程                                              │
│  11. NotificationCenterView                                                     │
│     ├─ 浏览冲突/同步/体检/普通通知分组                                            │
│     ├─ 展开区块查看详情                                                           │
│     ├─ 标记已读 / 删除                                                            │
│     └─ 未读标记（红点角标）                                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           设置旅程                                                  │
│  12. SettingsView → 各子设置页                                                    │
│     ├─ AppearanceSettingsView → 主题模式 / OLED黑 / 主题色                        │
│     ├─ SecuritySettingsView → 修改密码 / 自动锁定 / 生物识别 / 销毁保险库          │
│     ├─ SyncSettingsView → 同步服务器 / 即时同步 / 配对 / 恢复码 / 诊断            │
│     ├─ NotificationSettingsView → 过期提醒天数 / 推送开关                         │
│     ├─ PasswordToolsView → 密码生成 / 强度评估 / 最近结果                         │
│     └─ ReleaseNoteView → 版本说明                                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           日常使用闭环                                              │
│  13. 自动锁定 → 回到 UnlockView → 主密码/生物识别/无密码解锁 → 回到 HomeView       │
│  14. 后台通知 → 密码过期/弱密码提醒 → 点击通知 → 对应页面                         │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 三、功能成熟度评估

### 评估标准

| 成熟度 | 判定依据 |
|---|---|
| **稳定** | 有完整测试覆盖（单元/Widget/集成）；无已知平台限制；文档或代码自解释；核心业务路径已验证 |
| **开发中** | 有测试但非完整覆盖；存在部分平台差异或条件编译；UI 已成型但交互细节可能调整 |
| **实验性** | 测试覆盖薄弱或无测试；重度依赖特定平台硬件（相机等）；API 可能变动；主要依赖手动验证 |

### 按模块成熟度汇总

| 模块 | 功能数 | 稳定 | 开发中 | 实验性 | 关键风险点 |
|---|---|---|---|---|---|
| 认证 / 解锁 | 8 | 6 | 2 | 0 | 无密码模式缺少专项边界测试 |
| 账号管理 | 10 | 6 | 3 | 1 | `AccountSubsetView` 无测试；TOTP 关联覆盖不完整 |
| 模板管理 | 7 | 4 | 2 | 1 | 图标选择无测试；导入导出依赖手动验证 |
| TOTP / 2FA | 7 | 3 | 1 | 3 | `TotpQrScannerView` 重度依赖相机硬件；`TotpCredentialEditView` 无测试 |
| 密码工具 | 4 | 3 | 0 | 1 | 保留最近结果无测试 |
| 同步 | 9 | 5 | 2 | 2 | `SyncSettingsView`、`LocalSyncQueueView` 无 Widget 测试；LAN 冲突弹窗无测 |
| 设备配对 | 5 | 3 | 1 | 1 | 设备别名无测试；LAN 配对端到端依赖手动验证 |
| 保险库健康 | 4 | 1 | 2 | 1 | 风险项展示、一键跳转无 Widget 测试 |
| 通知中心 | 6 | 1 | 2 | 3 | 通知聚合页、定时提醒、推送开关均无测试 |
| 设置 / 个性化 | 7 | 4 | 2 | 1 | 密码过期天数、版本说明无测试 |
| 搜索 | 3 | 0 | 1 | 2 | 全局搜索无 Widget 测试；快捷键依赖集成测试 |

### 重点功能成熟度明细

| 功能 | 成熟度 | 依据说明 |
|---|---|---|
| 主密码解锁 | 稳定 | `unlock_view_test.dart` + `enhanced_crypto_service_test.dart` + `database_file_cipher_test.dart` 多层覆盖 |
| 生物识别解锁 | 稳定 | `biometric_auth_service_test.dart` 覆盖状态机与错误路径 |
| 密码生成器 | 稳定 | `password_generator_sheet_test.dart` + `enhanced_crypto_service_test.dart` 覆盖 |
| 自动锁定 | 稳定 | `auto_lock_service_test.dart` 覆盖生命周期与状态迁移 |
| CRDT 冲突合并 | 稳定 | `crdt_merge_engine_test.dart` + `crdt_merge_invariants_test.dart` + `sync_conflict_recovery_test.dart` |
| 同步状态机 | 稳定 | `sync_state_machine_test.dart` + `multi_device_sync_test.dart` |
| TOTP 码生成 | 稳定 | `totp_service_test.dart` 使用 RFC 6238 标准向量验证 |
| 敏感剪贴板 | 稳定 | `sensitive_clipboard_service_test.dart` 覆盖定时清理与 hash 防误删 |
| 加密 Payload | 稳定 | `sync_payload_codec_test.dart` 覆盖篡改拒绝、vault 隔离、旧格式兼容 |
| 身份导入导出 | 稳定 | `identity_service_test.dart` + `vault_pairing_crypto_test.dart` |
| 账号列表浏览 | 稳定 | `account_list_view_test.dart` + `account_list_tile_test.dart` |
| 模板编辑 | 稳定 | `template_edit_view_test.dart` |
| 主题切换 | 稳定 | `appearance_settings_view_test.dart` + `app_design_tokens_test.dart` |
| LAN 面对面配对 | 开发中 | `lan_pairing_service_test.dart` 存在但端到端流程依赖手动验证；UDP/HTTP 双通道复杂 |
| 服务端配对 | 开发中 | `vault_pairing_service_test.dart` 存在但需真实 server 环境做集成验证 |
| 扫码导入 TOTP | 实验性 | `TotpQrScannerView` 无测试；重度依赖 `MobileScanner` 与相机硬件，通常需 mock |
| 全局搜索 | 实验性 | `HomeSearchView` 无 Widget 测试；快捷键（Ctrl+F/Esc）需集成测试验证 |
| 通知中心 | 实验性 | `NotificationCenterView` 无测试；聚合状态复杂（冲突/同步/体检/通知） |

---

## 四、测试回归用例基础

### 4.1 认证 / 解锁

| 功能 | 建议回归测试要点 |
|---|---|
| 首次创建保险库 | 新用户流程：设置密码 → 确认密码一致性 → 数据库初始化成功 → 自动解锁进入 HomeView |
| 主密码解锁 | 正确密码解锁成功；错误密码返回 `invalidPassword`；连续错误不崩溃；空密码处理 |
| 生物识别解锁 | 启用后下次解锁显示生物识别入口；取消后回退密码输入；禁用后删除密钥 |
| 无密码模式 | 启用后 UnlockView 直接显示「进入」按钮；禁用后恢复密码输入；数据库密钥仍加密 |
| 自动锁定 | 切后台超时时自动回到 UnlockView；立即锁定快捷键/API；永不锁定模式下不触发 |
| 修改主密码 | 旧密码验证失败不修改；成功后轮转 envelope；不解锁状态下不可用 |
| 保险库销毁 | 确认对话框 → 删除所有文件 → 回到根路由 → 下次启动为新用户流程 |

### 4.2 账号管理

| 功能 | 建议回归测试要点 |
|---|---|
| 账号 CRUD | 新建 → 列表出现；编辑 → 字段更新；删除 → 软删除标记； reopen 数据库后数据持久 |
| 置顶 | 置顶后排序到顶部；取消置顶恢复默认；数据库 `isPinned` 字段持久 |
| 字段复制 | 点击复制 → 剪贴板有值 → 定时清理后为空；手动覆盖后 hash 不匹配不清理 |
| 模板切换 | 切换模板后旧字段保留在历史区；新字段按预设填充；保存后 JSON 结构正确 |
| TOTP 关联 | 关联后列表显示 TOTP 徽章；取消关联后徽章消失；关联不存在的凭证 graceful 处理 |
| 问题账号聚合 | 体检跳转后正确分组；空状态显示；点击跳转编辑页 |

### 4.3 模板管理

| 功能 | 建议回归测试要点 |
|---|---|
| 模板 CRUD | 新建自定义模板 → 列表出现；编辑字段 → 实时预览更新；删除使用中模板抛异常 |
| 字段预设 | 选择预设后字段自动填充；预设字段 key 唯一；重复添加同一 preset 处理 |
| 导入导出 | 导出 JSON 包含完整字段定义；导入后模板可用；批量导入无重复 ID 冲突 |
| 内置模板 | 内置模板不可删除；首次启动自动创建；内置模板图标映射正确 |

### 4.4 TOTP / 2FA

| 功能 | 建议回归测试要点 |
|---|---|
| TOTP 生成 | RFC 6238 标准向量验证；30s/60s 周期；SHA1/SHA256/SHA512；8 位码正确 |
| URI 解析 | `otpauth://totp/...` 完整解析；缺失参数 graceful fallback；非法 URI 报错 |
| 扫码导入 | 相机权限处理；有效 QR 码正确导入；无效 QR 码报错；取消返回 |
| 图片 QR 解码 | 剪贴板无图片时 graceful 处理；有效图片解码成功；非 QR 图片报错 |
| 关联账号 | 多选关联保存正确；取消关联后列表更新；删除账号后关联自动清理 |

### 4.5 密码工具

| 功能 | 建议回归测试要点 |
|---|---|
| 密码生成 | 各字符类型开关生效；最小/最大长度边界；空选择时至少有一种字符类型 fallback |
| 强度评估 | 已知弱密码得低分；混合长密码得高分；空密码为 0 分；相同密码评分稳定 |
| 最近结果 | 生成后保留在列表；重启后持久；清除后为空；上限限制 |

### 4.6 同步

| 功能 | 建议回归测试要点 |
|---|---|
| 服务器配置 | URL 格式校验；移动端 loopback 拒绝；保存后下次启动仍有效；空 URL 表示禁用同步 |
| 即时同步 | 在线时触发 Pull → 合并远程变更；Push → 推送本地变更；网络错误进入 error 状态 |
| 本地变更箱 | create/update/delete 三种变更正确记录；推送成功后清除；撤销后数据库回退 |
| CRDT 合并 | 字段级冲突自动合并；HLC 时钟递增；同一字段多设备编辑 deterministic |
| 冲突收件箱 | 冲突正确展示为 inbox 项；接受本地后覆盖远程；全部忽略后保留远程 |
| 离线恢复码 | 导出码加密不可读；正确密码解密成功；错误密码解密失败；导入后身份一致 |
| 备份包 | 导出包加密完整；验证通过；导入后数据一致；损坏包验证失败 |

### 4.7 设备配对

| 功能 | 建议回归测试要点 |
|---|---|
| LAN 配对 | 主机广播可达；客户端发现主机；配对码校验；claim 成功；X25519 加密传输 |
| 服务端配对 | 创建会话返回 pairingCode；加入会话成功；审批后状态变更；拉取 bundle 解密正确 |
| 设备别名 | 设置别名后同步设置页显示；未设置时回退 deviceId 缩写；跨设备别名解析 |

### 4.8 保险库健康

| 功能 | 建议回归测试要点 |
|---|---|
| 评分计算 | 全健康为满分；弱密码扣分；重复密码扣分；过期记录扣分；缺失 2FA 扣分 |
| 风险跳转 | 单账号风险 → AccountEditView；多账号风险 → AccountSubsetView；同步风险 → Sync 页面 |
| 通知生成 | 体检后生成对应通知；通知内容包含风险摘要；已修复后通知自动清除 |

### 4.9 通知中心

| 功能 | 建议回归测试要点 |
|---|---|
| 通知聚合 | 各类型通知正确分组；未读标记红点；全部已读后红点消失 |
| 过期提醒 | 设置 30 天阈值 → 过期账号生成通知；修改阈值后重新扫描；关闭推送后不生成 |
| 定时检查 | 每日定时触发扫描；时区变更后调整；取消所有定时后不再触发 |

### 4.10 设置 / 个性化

| 功能 | 建议回归测试要点 |
|---|---|
| 主题切换 | 跟随/浅色/深色实时生效；OLED 黑在深色下生效；重启后持久 |
| 主题色 | 选择后全局 ColorScheme 更新；重启后持久；未知种子色 graceful 处理 |
| 自动锁定 | 各档位切换后行为正确；永不锁定模式下切后台不锁；立即锁定 API 生效 |
| 保险库销毁 | 二次确认对话框；取消后无数据丢失；确认后所有文件删除、身份清除 |

### 4.11 搜索

| 功能 | 建议回归测试要点 |
|---|---|
| 全局搜索 | 输入关键字实时过滤；空结果显示空状态；清除输入后恢复全部 |
| 模板过滤 | 多选模板后仅显示该模板账号；取消选择后恢复；组合关键字+模板过滤 |
| 快捷键 | Ctrl+F 唤起搜索页；Esc 关闭搜索页；非桌面平台不注册快捷键 |

---

## 附录 A：视图层 ↔ 功能映射速查

| 视图文件 | 所属功能模块 | 测试文件 |
|---|---|---|
| `unlock_view.dart` | 认证/解锁 | `test/views/unlock_view_test.dart` ✅ |
| `home/home_view.dart` | 主页导航 | ❌ |
| `home/layouts/home_view_desktop.dart` | 主页导航 | ❌ |
| `home/layouts/home_view_mobile.dart` | 主页导航 | ❌ |
| `home/home_search_view.dart` | 搜索 | ❌ |
| `accounts/account_list_view.dart` | 账号管理 | `test/views/account_list_view_test.dart` ✅ |
| `accounts/account_edit_view.dart` | 账号管理 | `test/views/account_edit_view_test.dart` ✅ |
| `accounts/account_subset_view.dart` | 账号管理 / 保险库健康 | ❌ |
| `accounts/totp_credential_edit_view.dart` | TOTP/2FA | ❌ |
| `accounts/totp_qr_scanner_view.dart` | TOTP/2FA | ❌ |
| `accounts/account_edit_utils.dart` | 账号管理（工具） | — |
| `templates/template_list_view.dart` | 模板管理 | `test/views/template_list_view_test.dart` ✅ |
| `templates/template_edit_view.dart` | 模板管理 | `test/views/template_edit_view_test.dart` ✅ |
| `settings_view.dart` | 设置 | ❌ |
| `appearance_settings_view.dart` | 设置/个性化 | `test/views/appearance_settings_view_test.dart` ✅ |
| `security_settings_view.dart` | 认证/解锁 | `test/views/security_settings_view_test.dart` ✅ |
| `sync_settings_view.dart` | 同步 / 设备配对 | ❌ |
| `settings/notification_settings_view.dart` | 通知中心 | ❌ |
| `settings/vault_health_view.dart` | 保险库健康 | ❌ |
| `password_tools_view.dart` | 密码工具 | `test/views/password_tools_view_test.dart` ✅ |
| `release_note_view.dart` | 设置 | ❌ |
| `sync/local_sync_queue_view.dart` | 同步 | ❌ |
| `conflict_inbox_view.dart` | 同步 | `test/views/conflict_inbox_view_test.dart` ✅ |
| `notifications/notification_center_view.dart` | 通知中心 | ❌ |

## 附录 B：服务层 ↔ 功能映射速查

| 服务文件 | 核心功能模块 | 关键测试文件 |
|---|---|---|
| `auto_lock_service.dart` | 认证/解锁 | `test/services/auto_lock_service_test.dart` |
| `biometric_auth_service.dart` | 认证/解锁 | `test/services/biometric_auth_service_test.dart` |
| `database_file_cipher.dart` | 认证/解锁 / 存储 | `test/services/database_file_cipher_test.dart` |
| `database_file_key_manager.dart` | 认证/解锁 | `test/services/database_file_key_manager_test.dart` |
| `device_alias_service.dart` | 设备配对 | ❌ |
| `enhanced_crypto_service.dart` | 认证/解锁 / 密码工具 | `test/services/enhanced_crypto_service_test.dart` |
| `identity_service.dart` | 设备配对 / 同步 | `test/services/identity_service_test.dart` |
| `lan_pairing_service.dart` | 设备配对 | `test/sync/lan_pairing_service_test.dart` |
| `notification_service.dart` | 通知中心 | `test/services/notification_service_test.dart` |
| `secure_storage_service.dart` | 存储 / 同步 | `test/services/secure_storage_service_*_test.dart` |
| `sensitive_clipboard_service.dart` | 账号管理 | `test/services/sensitive_clipboard_service_test.dart` |
| `service_manager.dart` | 全局门面 | 间接通过 coordinator 测试覆盖 |
| `totp_import_service.dart` | TOTP/2FA | `test/services/totp_import_service_test.dart` |
| `totp_qr_image_import_service.dart` | TOTP/2FA | `test/services/totp_qr_image_import_service_test.dart` |
| `totp_service.dart` | TOTP/2FA | `test/services/totp_service_test.dart` |
| `vault_health_calculator.dart` | 保险库健康 | `test/services/vault_health_calculator_test.dart` |
| `vault_pairing_crypto.dart` | 设备配对 | `test/services/vault_pairing_crypto_test.dart` |
| `vault_pairing_service.dart` | 设备配对 | `test/services/vault_pairing_service_test.dart` |

## 附录 C：测试覆盖总览

| 层级 | 总数 | 已测 | 覆盖率 |
|---|---|---|---|
| 视图页面（`test/views/`） | 24 | 9 | 37.5% |
| 服务单元（`test/services/`） | 18 | 14+ | ~78% |
| 同步逻辑（`test/sync/`） | — | 8+ 文件 | — |
| 组件库（`test/widgets/`） | 25 文件 | 9 | 36% |
| 模型（`test/models/`） | — | 有 | — |
| 系统协调器（`test/system/`） | — | 有 | — |
| 主题/工具（`test/theme/`, `test/utils/`） | — | 有 | — |
| 集成测试（`integration_test/`） | 2 | 2 | 100% |
