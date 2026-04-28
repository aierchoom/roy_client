# 架构概览

**最后更新**: 2026-04-28

本文描述当前 `roy_client` 的实现结构。SecretRoy 客户端是本地优先的 Flutter
保险库应用，同步服务端是可选的同级 `../roy_server/` 项目。

## 1. 系统架构

```text
Flutter App
↓
Views / Widgets
↓
Provider + ChangeNotifier
↓
ServiceManager
↓
SecureStorageService / SyncService / IdentityService / Crypto / Pairing
↓
Encrypted local SQLite + optional roy_server sync
```

核心原则：

- 客户端先保证本地可用，网络同步是可选能力。
- 页面不直接操作 SQLite 或 HTTP，同一类业务通过 Provider 和 ServiceManager 进入。
- 长期落盘数据库是 `secret_roy_vault.db.enc` 加密文件。
- 同步服务端只保存 opaque encrypted payload，不应接触明文账号内容。

## 2. 技术栈

| 层面 | 当前实现 |
|---|---|
| UI | Flutter + Material 3 |
| 状态 | `provider` / `ChangeNotifier` |
| 本地存储 | `sqflite` / `sqflite_common_ffi` |
| 本地加密 | AES-GCM-256 文件信封 + 主密码派生包装密钥 |
| 安全存储 | `flutter_secure_storage` |
| 生物识别 | `local_auth` |
| 同步 | HTTP pull/push + HLC/CRDT 合并 |
| 可选服务端 | `../roy_server/` Node.js 服务 |

## 3. 分层说明

### 3.1 UI 层

目录：

- `lib/views/`
- `lib/widgets/`

主要页面：

| 页面 | 作用 |
|---|---|
| `UnlockView` | 首次创建、主密码解锁、生物识别解锁、重置本机库 |
| `HomeView` | 解锁后的主框架，维护当前 tab |
| `HomeSearchView` | 首页搜索、模板筛选、冲突入口 |
| `AccountListView` | 账号列表、模板分组、新增/编辑/删除入口 |
| `AccountEditView` | 根据模板动态生成账号字段 |
| `SettingsView` | 外观、安全、同步、模板、关于入口 |
| `TemplateListView` / `TemplateEditView` | 模板列表和模板编辑 |

UI 层只负责展示和收集用户操作。典型写法：

```dart
final provider = context.watch<EnhancedAppProvider>();
```

保存或删除时使用：

```dart
await context.read<EnhancedAppProvider>().addAccount(item);
```

### 3.2 状态层

目录：

- `lib/providers/enhanced_app_provider.dart`
- `lib/providers/theme_provider.dart`
- `lib/services/service_manager.dart`

`main.dart` 中注册：

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: ServiceManager.instance),
    ChangeNotifierProvider(create: (_) => EnhancedAppProvider(...)),
    ChangeNotifierProvider(create: (_) => AppThemeProvider(prefs)),
  ],
)
```

职责：

- `ServiceManager`：解锁状态、服务生命周期、业务入口。
- `EnhancedAppProvider`：账号、模板、搜索筛选、冲突数量。
- `AppThemeProvider`：主题模式、主题色、纯黑模式。

### 3.3 业务服务层

目录：

- `lib/services/`
- `lib/sync/`
- `lib/system/service_manager/`

关键服务：

| 服务 | 作用 |
|---|---|
| `ServiceManager` | 统一业务门面和服务生命周期 |
| `SecureStorageService` | 加密数据库打开、CRUD、变更事件 |
| `EnhancedCryptoService` | 主密码验证、数据库文件密钥解封 |
| `IdentityService` | 设备/保险库身份、内部兼容码和离线恢复码 |
| `SyncService` | pull/push、同步状态、冲突恢复 |
| `CrdtMergeEngine` | 多设备并发修改合并 |
| `VaultPairingService` | 经同步服务端的保险库配对 |
| `LanPairingService` | 面对面链接和 8 位临时码领取 |
| `AutoLockService` | 自动锁定和应用生命周期联动 |

### 3.4 数据层

目录：

- `lib/models/`
- `SecureStorageService` 内部 SQLite schema

核心模型：

- `AccountItem`
- `AccountTemplate`
- `AccountField`
- `Hlc`
- `ConflictLog`

SQLite 表：

- `accounts`
- `templates`
- `conflict_logs`
- `settings`

## 4. 核心数据流

### 4.1 启动与解锁

```text
main.dart
↓
ServiceManager.initialize()
↓
state = locked
↓
UnlockView
↓
用户输入主密码
↓
IdentityService.initialize()
↓
EnhancedCryptoService.initMasterKey()
↓
SecureStorageService.initialize()
↓
SyncService.initialize()
↓
state = unlocked
↓
HomeView
```

### 4.2 账号创建

```text
用户点击新增按钮
↓
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
notifyListeners()
↓
账号列表刷新
```

### 4.3 解锁后加载数据

```text
ServiceManager 进入 unlocked
↓
EnhancedAppProvider 监听到状态变化
↓
refresh()
↓
loadAccounts()
↓
loadCustomTemplates()
↓
getConflictLogs()
↓
notifyListeners()
```

### 4.4 同步

```text
ServiceManager.syncNow()
↓
SyncService.syncNow()
↓
GET /vaults/{vaultId}/sync?since={version}
↓
解密并校验远端 payload
↓
写入或 CRDT 合并本地数据
↓
POST /vaults/{vaultId}/sync
↓
记录 accepted server versions
↓
更新 settings 中的 sync metadata
```

## 5. 安全架构

本地数据库长期落盘为：

```text
secret_roy_vault.db.enc
```

解锁期间流程：

```text
主密码
↓
PBKDF2-HMAC-SHA256 校验
↓
解封数据库文件数据密钥
↓
创建 DatabaseFileCipher
↓
解密临时 runtime SQLite
↓
锁定或关闭时重新加密落盘并清理 runtime 文件
```

保险库链接码：

- 内部兼容码：`sroy-link:`，不作为普通用户恢复入口
- 离线恢复码：`sroy-recovery:`
- 远程配对密文包：`sroy-pairing:`
- 当前恢复导入：`sroy-recovery:`

仍需注意：

- 解锁期间存在临时 runtime DB。
- 生物识别回填依赖 `FlutterSecureStorage` 保存口令材料。
- 同步服务端部署仍需要可信网络或 HTTPS。

## 6. 同步架构

客户端同步由 `SyncService` 负责：

```text
local accounts/templates
↓
SyncPayloadCodec encode
↓
encrypted_signed_payload
↓
roy_server
↓
pull remote payload
↓
SyncPayloadCodec decode
↓
CrdtMergeEngine
↓
SecureStorageService
```

同步元数据按 vault 命名空间保存，例如：

- `sync_version_$vaultId`
- `sync_dirty_$vaultId`
- `sync_last_time_$vaultId`
- `sync_recovery_$vaultId`

## 7. 相关文档

- [../beginner/app_flow.md](../beginner/app_flow.md)
- [../guides/technical-documentation.md](../guides/technical-documentation.md)
- [../security/security-features.md](../security/security-features.md)
- [../security/local-database-encryption.md](../security/local-database-encryption.md)
- [../sync/sync-protocol.md](../sync/sync-protocol.md)
