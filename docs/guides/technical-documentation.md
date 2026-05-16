# SecretRoy 技术文档

**最后更新**: 2026-05-16

本文档是当前 `roy_client` 代码的简明技术地图。服务端代码位于同级
`../roy_server/` 仓库；本文件只描述客户端仓库中仍然真实存在的结构、API 和数据流。

## 1. 项目信息

| 字段 | 当前值 |
|---|---|
| 包名 | `secret_roy` |
| 版本 | `1.0.0+1` |
| Dart SDK | `^3.10.1` |
| UI | Flutter + Material 3 |
| 状态管理 | `provider ^6.1.5+1` |
| 本地数据库 | `sqflite` / `sqflite_common_ffi` |
| 本地加密 | `cryptography` + AES-GCM-256 文件信封 |
| 同步传输 | `http` |
| 安全存储 | `flutter_secure_storage` |
| 生物识别 | `local_auth` |

## 2. 当前目录结构

```text
lib/
├── main.dart
├── core/                          <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── app_logger.dart
│   └── crypto_random.dart
├── l10n/
├── models/
│   ├── account_item.dart
│   ├── account_template.dart
│   ├── app_notification.dart      <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── hlc.dart
│   ├── local_sync_change.dart     <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── template_conflict_log.dart <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── totp_credential.dart       <!-- 2026-05-16 修正：原遗漏，新增 -->
│   └── vault_health_report.dart   <!-- 2026-05-16 修正：原遗漏，新增 -->
├── providers/
│   ├── enhanced_app_provider.dart
│   ├── notification_provider.dart <!-- 2026-05-16 修正：原遗漏，新增 -->
│   └── theme_provider.dart
├── services/
│   ├── auto_lock_service.dart
│   ├── biometric_auth_service.dart
│   ├── database_file_cipher.dart       <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── database_file_key_manager.dart  <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── device_alias_service.dart       <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── enhanced_crypto_service.dart
│   ├── identity_service.dart
│   ├── lan_pairing_service.dart
│   ├── notification_service.dart       <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── secure_storage_service.dart
│   ├── sensitive_clipboard_service.dart <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── service_manager.dart
│   ├── totp_import_service.dart         <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── totp_qr_image_import_service.dart <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── totp_service.dart
│   ├── vault_health_calculator.dart     <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── vault_pairing_crypto.dart        <!-- 2026-05-16 修正：原遗漏，新增 -->
│   └── vault_pairing_service.dart
├── sync/
│   ├── crdt_merge_engine.dart
│   ├── lan_sync_client.dart          <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── lan_sync_coordinator.dart     <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── lan_sync_host_handler.dart    <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── lan_sync_session.dart         <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── sync_payload_codec.dart
│   ├── sync_service.dart
│   ├── sync_service_conflict.dart    <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── sync_service_pull.dart        <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── sync_service_push.dart        <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── sync_service_types.dart       <!-- 2026-05-16 修正：原遗漏，新增 -->
│   └── totp_credential_merge_engine.dart <!-- 2026-05-16 修正：原遗漏，新增 -->
├── system/                              <!-- 2026-05-16 修正：原仅列 4 个，更新为 10 个 -->
│   └── service_manager/
│       ├── default_sync_server_url.dart
│       ├── password_tools.dart
│       ├── sync_coordinator.dart          <!-- 2026-05-16 修正：原遗漏，新增 -->
│       ├── sync_server_url_store.dart
│       ├── vault_data_repository.dart     <!-- 2026-05-16 修正：原遗漏，新增 -->
│       ├── vault_dump_coordinator.dart
│       ├── vault_import_export_coordinator.dart <!-- 2026-05-16 修正：原遗漏，新增 -->
│       ├── vault_import_types.dart        <!-- 2026-05-16 修正：原遗漏，新增 -->
│       ├── vault_pairing_coordinator.dart <!-- 2026-05-16 修正：原遗漏，新增 -->
│       └── vault_unlock_coordinator.dart  <!-- 2026-05-16 修正：原遗漏，新增 -->
├── theme/                               <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── app_design_tokens.dart
│   ├── app_layout.dart
│   ├── app_text_styles.dart
│   └── theme.dart
├── utils/                               <!-- 2026-05-16 修正：原遗漏，新增 -->
│   ├── field_presets.dart
│   ├── relative_time_formatter.dart
│   ├── template_icons.dart
│   └── text_highlight.dart
├── views/
│   ├── unlock_view.dart
│   ├── home/
│   ├── accounts/
│   ├── templates/
│   ├── settings/
│   ├── sync/
│   ├── notifications/
│   └── settings/security/sync/appearance/conflict 等页面
└── widgets/
```

同级服务端仓库：

```text
../roy_server/
├── index.js
├── system/
├── test/
└── data/        # 运行期数据目录，忽略提交
```

## 3. 启动和全局状态

`lib/main.dart` 是入口：

```text
main()
↓
WidgetsFlutterBinding.ensureInitialized()
↓
SharedPreferences.getInstance()
↓
ServiceManager.instance.initialize()
↓
runApp(SecretRoyApp)
```

`SecretRoyApp` 注册三个全局状态对象：

| Provider | 作用 |
|---|---|
| `ServiceManager` | 解锁状态、服务生命周期、保存/删除/同步等业务入口 |
| `EnhancedAppProvider` | 账号、模板、搜索、冲突数量等 UI 数据 |
| `AppThemeProvider` | 主题模式、主题色、纯黑模式 |

首页由 `ServiceManager.state` 决定：

```text
locked / unlocking / error
↓
UnlockView

unlocked
↓
HomeView
```

## 4. 核心服务

### ServiceManager

文件：`lib/services/service_manager.dart`

`ServiceManager` 是业务门面，内部持有/委托：

- `EnhancedCryptoService`
- `BiometricAuthService`
- `AutoLockService`
- `IdentityService`
- `SecureStorageService`
- `SyncService`
- `VaultPairingService`
- `LanPairingService`
- `SyncServerUrlStore`
- `VaultDumpCoordinator`
- `VaultUnlockCoordinator`       <!-- 2026-05-16 修正：原遗漏，新增 -->
- `VaultDataRepository`          <!-- 2026-05-16 修正：原遗漏，新增 -->
- `SyncCoordinator`              <!-- 2026-05-16 修正：原遗漏，新增 -->
- `VaultImportExportCoordinator` <!-- 2026-05-16 修正：原遗漏，新增 -->
- `VaultPairingCoordinator`      <!-- 2026-05-16 修正：原遗漏，新增 -->
- `NotificationService`          <!-- 2026-05-16 修正：原遗漏，新增 -->
- `SensitiveClipboardService`    <!-- 2026-05-16 修正：原遗漏，新增 -->
- `DeviceAliasService`           <!-- 2026-05-16 修正：原遗漏，新增 -->
- `TotpImportService`            <!-- 2026-05-16 修正：原遗漏，新增 -->
- `TotpQrImageImportService`     <!-- 2026-05-16 修正：原遗漏，新增 -->
- `VaultHealthCalculator`        <!-- 2026-05-16 修正：原遗漏，新增 -->

<!-- 2026-05-16 修正：原列表遗漏 10+ 个服务/协调器，实际 ServiceManager 已拆分大量职责到 system/ 协调器 -->

解锁流程：

```text
unlockWithPassword(password)
↓
VaultUnlockCoordinator.initializeAndUnlock(password)
  ↓
  IdentityService.initialize()
  ↓
  EnhancedCryptoService.initMasterKey(password)
  ↓
  SecureStorageService.setDatabaseCipher(...)
  ↓
  SecureStorageService.initialize(deviceId)
  ↓
  AutoLockService.unlock()
  ↓
  SyncService.initialize()
  ↓
  后台尝试 SyncService.connect()
↓
state = unlocked
↓
notifyListeners()
```

保存账号：

```text
ServiceManager.saveAccount(account)
↓
SecureStorageService.saveAccount(account)
↓
SyncService.markDirty()
↓
后台尝试 SyncService.syncNow()
```

### SecureStorageService

文件：`lib/services/secure_storage_service.dart`

长期落盘文件是加密文件：

```text
secret_roy_vault.db.enc
```

解锁期间才会生成临时运行库：

```text
secret_roy_vault.runtime.db
```

主要数据表：

- `accounts`
- `templates`
- `conflict_logs`
- `settings`
- `totp_credentials`    <!-- 2026-05-16 修正：原遗漏，新增 -->
- `app_notifications`   <!-- 2026-05-16 修正：原遗漏，新增 -->

`SecureStorageService` 在保存、删除、写设置后会发出 `StorageChangeEvent`。`EnhancedAppProvider`
订阅这个事件并重新加载账号/模板。

### EnhancedCryptoService

文件：`lib/services/enhanced_crypto_service.dart`

当前职责：

- 使用 `master_password_v2` PBKDF2-HMAC-SHA256 记录验证主密码。
- 兼容并迁移旧 `master_password_v1`。
- 解开数据库文件数据密钥。
- 生成 `DatabaseFileCipher` 交给 `SecureStorageService`。
- 提供密码生成和强度计算工具。

### IdentityService

文件：`lib/services/identity_service.dart`

当前职责：

- 维护 `deviceId`、`vaultId`、`privateKey`、`symmetricKey`。
- 首次运行时生成本地身份。
- 解析 `sroy-link:` 内部兼容码；该格式不作为普通用户恢复入口。
- 导出/导入 `sroy-recovery:` 离线恢复码。
- 提供 preview/apply 两阶段导入能力，避免 dump 失败后出现半成功恢复。

### SyncService

文件：`lib/sync/sync_service.dart`

同步状态：

```dart
enum SyncState { offline, syncing, synced, error, conflictRecovery }
```

同步流程：

```text
syncNow()
↓
解析同步服务器 URL
↓
pull: GET /vaults/{vaultId}/sync?since={localVersion}
↓
解密并校验 encrypted_signed_payload
↓
写入或 CRDT 合并账号/模板
↓
push: POST /vaults/{vaultId}/sync
↓
记录 accepted server versions
↓
更新 sync_version_$vaultId / sync_dirty_$vaultId / sync_last_time_$vaultId
```

`markDirty()` 只负责标记本地有待同步数据，不再直接递增本地版本号。

同步服务器地址优先级：

```text
SharedPreferences('sync_server_url')
↓
SecureStorageService.getSetting('sync_server_url')  # 旧配置迁移
↓
SyncConfig.serverUrl / ServiceManager.defaultSyncServerUrl
```

平台默认地址：

- Windows / macOS / Linux：`http://127.0.0.1:8080`
- Android / iOS / Web：空字符串，需要用户配置可访问地址

## 5. 数据模型

### AccountItem

文件：`lib/models/account_item.dart`

关键字段：

```dart
id
name
email
templateId
data
createdAt
nameHlc
emailHlc
dataHlc
serverVersion
syncStatus
isDeleted
deleteHlc
```

`data` 保存模板字段值。同步相关字段用于 CRDT/HLC 合并和软删除。

### AccountTemplate

文件：`lib/models/account_template.dart`

当前内置模板：

| ID | 标题 | 字段 |
|---|---|---|
| `builtin_generic_info` | 网站模板 | `website`, `username`, `password`, `totp`, `notes` |
| `builtin_secure_note` | 通用安全笔记 | `content` |
| `builtin_mnemonic` | 助记词 | `mnemonic_words` |
| `builtin_api_service` | API 服务 | `service_name`, `api_keys`, `endpoint` |

自定义模板存入 `templates` 表，内置模板来自代码常量 `basicAccountTemplates`。

## 6. UI 层

当前主页面结构：

```text
HomeView
↓
PlatformBuilder
↓
HomeViewDesktop / HomeViewMobile
↓
IndexedStack
↓
AccountListView / HomeSearchView / SettingsView
```

关键页面：

| 页面 | 文件 | 类型 | 说明 |
|---|---|---|---|
| `UnlockView` | `lib/views/unlock_view.dart` | `StatefulWidget` | 解锁、首次创建、免密码模式、重置 |
| `HomeView` | `lib/views/home/home_view.dart` | `StatefulWidget` | 主框架和 tab 状态 |
| `HomeSearchView` | `lib/views/home/home_search_view.dart` | `StatefulWidget` | 首页搜索和冲突入口 |
| `AccountListView` | `lib/views/accounts/account_list_view.dart` | `StatefulWidget` | 账号列表、模板筛选、新增入口 |
| `AccountEditView` | `lib/views/accounts/account_edit_view.dart` | `StatefulWidget` | 账号新增/编辑/预览 |
| `SettingsView` | `lib/views/settings_view.dart` | `StatelessWidget` | 设置中心 |
| `TemplateListView` | `lib/views/templates/template_list_view.dart` | `StatelessWidget` | 模板管理 |

页面跳转主要使用 `Navigator.push(MaterialPageRoute(...))`。解锁页到主页不是普通跳转，而是由
`ServiceManager.state` 驱动 `MaterialApp.home` 重新选择。

## 7. 常见数据流

新增账号：

```text
AccountListView._openEditor()
↓
Navigator.push(AccountEditView)
↓
AccountEditView._save()
↓
Navigator.pop(AccountItem)
↓
EnhancedAppProvider.addAccount()
↓
ServiceManager.saveAccount()
↓
SecureStorageService.saveAccount()
↓
SyncService.markDirty()
↓
EnhancedAppProvider.notifyListeners()
↓
AccountListView 重新 build
```

解锁后加载数据：

```text
ServiceManager.state = unlocked
↓
EnhancedAppProvider._onServiceManagerStateChanged()
↓
refresh()
↓
SecureStorageService.loadAccounts()
↓
SecureStorageService.loadCustomTemplates()
↓
getConflictLogs()
↓
notifyListeners()
```

同步拉取后刷新：

```text
ServiceManager.syncNow()
↓
SyncService.syncNow()
↓
如果 pulled=true，重新 initialize storage/sync
↓
ServiceManager.notifyListeners()
↓
EnhancedAppProvider.refresh()
↓
UI 刷新
```

## 8. 当前风险和技术债

- 解锁期间存在临时明文 SQLite 运行库，需要依赖系统权限、自动锁定和关闭清理。
- 同步服务端是可选的轻量自托管服务，仍不等同于正式零知识托管平台。
- 生物识别会把回填用主密码存入 `FlutterSecureStorage`，适合功能测试，正式安全边界仍需复核。
- 同步 payload 已加密和校验，但传输部署仍应使用可信网络或 HTTPS。
- 端到端跨设备测试仍需要继续补齐。

更细的安全结论见：

- `../security/security-features.md`
- `../security/local-database-encryption.md`
- `../security/key-sync-implementation.md`
