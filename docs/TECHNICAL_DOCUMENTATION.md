# SecretRoy 技术文档

> **本文档以代码为唯一事实依据**，所有描述均来自对 `lib/`、`sync_server/`、`pubspec.yaml` 的逐文件扫描。  
> **最后扫描时间**: 2026-04-18

---

## 1. 项目信息

| 字段 | 值 |
|------|------|
| 包名 | `secret_roy` |
| 版本 | `1.0.0+1` |
| SDK 约束 | `^3.10.1` |
| 目标平台 | Windows、Android（macOS 有注册但未积极维护） |
| UI 框架 | Flutter + Material 3 |
| 状态管理 | `provider ^6.1.5` |
| 国际化 | Flutter gen-l10n（中文 / 英文） |
| 数据库 | `sqflite ^2.2.0`（移动端）+ `sqflite_common_ffi ^2.3.5`（桌面端） |
| 同步传输 | `http ^1.2.0`（HTTP PUT/GET） |
| 安全存储 | `flutter_secure_storage ^10.0.0` |
| 生物识别 | `local_auth ^2.3.0` + `local_auth_windows ^1.0.11` |

---

## 2. 架构图

```
┌──────────────────────────────────────────────────────────┐
│                     main.dart                             │
│  ┌─ MultiProvider ──────────────────────────────────────┐ │
│  │  • ChangeNotifierProvider.value(ServiceManager)      │ │
│  │  • ChangeNotifierProvider(EnhancedAppProvider)       │ │
│  └──────────────────────────────────────────────────────┘ │
│  ┌─ Consumer<ServiceManager> ───────────────────────────┐ │
│  │  state==unlocked → HomeView                          │ │
│  │  else            → UnlockView                        │ │
│  └──────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                         ↕
┌──────────────────────────────────────────────────────────┐
│              ServiceManager (单例, ChangeNotifier)        │
│  ┌────────────────────────────────────────────────────┐  │
│  │ EnhancedCryptoService    ← 加密（当前明文透传）      │  │
│  │ SecureStorageService     ← SQLite CRUD              │  │
│  │ SyncService              ← 版本号同步               │  │
│  │ AutoLockService          ← 自动锁定                 │  │
│  │ BiometricAuthService     ← 生物识别                 │  │
│  └────────────────────────────────────────────────────┘  │
└───────────────────────────┬──────────────────────────────┘
                            │ HTTP
                   ┌────────▼────────┐
                   │  sync_server/   │
                   │  Express.js     │
                   │  port 8080      │
                   └─────────────────┘
```

---

## 3. 目录结构（实际文件）

```
lib/
├── main.dart                          # 入口、Provider 注册、主题、路由
├── core/                              # （空目录，无内容）
├── l10n/
│   ├── app_en.arb                     # 英文翻译
│   ├── app_zh.arb                     # 中文翻译
│   ├── app_localizations.dart         # 生成的 i18n 委托
│   ├── app_localizations_en.dart      # 生成的英文实现
│   └── app_localizations_zh.dart      # 生成的中文实现
├── models/
│   ├── account_item.dart              # AccountItem 数据类
│   └── account_template.dart          # AccountTemplate / AccountField / 内置模板
├── providers/
│   └── enhanced_app_provider.dart     # EnhancedAppProvider (ChangeNotifier)
├── services/
│   ├── services.dart                  # 统一 barrel 导出
│   ├── service_manager.dart           # ServiceManager 单例 (ChangeNotifier)
│   ├── secure_storage_service.dart    # SecureStorageService (SQLite)
│   ├── enhanced_crypto_service.dart   # EnhancedCryptoService (明文占位)
│   ├── auto_lock_service.dart         # AutoLockService (ChangeNotifier)
│   └── biometric_auth_service.dart    # BiometricAuthService
├── sync/
│   ├── sync.dart                      # barrel 导出 (仅 sync_service.dart)
│   └── sync_service.dart              # SyncService / SyncResult / SyncConfig
└── views/
    ├── unlock_view.dart               # 解锁/首次创建密库 (StatefulWidget)
    ├── home_view.dart                 # 底部导航主页 (StatefulWidget)
    ├── settings_view.dart             # 设置页入口 (StatelessWidget)
    ├── security_settings_view.dart    # 安全设置 (StatefulWidget)
    ├── accounts/
    │   ├── account_list_view.dart     # 账号列表 (StatelessWidget)
    │   └── account_edit_view.dart     # 账号编辑 (StatefulWidget)
    └── templates/
        ├── template_list_view.dart    # 模板列表 (StatelessWidget)
        └── template_edit_view.dart    # 模板编辑 (StatefulWidget)

sync_server/
├── index.js                           # Express 同步服务器
├── package.json
└── data/
    ├── vault.db.enc                   # 同步的数据库文件
    └── sync_version.json             # 版本号持久化 {"version": N}
```

---

## 4. 数据模型

### 4.1 AccountItem

**文件**: `lib/models/account_item.dart`

```dart
class AccountItem {
  final String id;                     // 时间戳字符串或 UUID
  final String name;                   // 账号名称（必填）
  final String email;                  // 邮箱（可选，默认 ""）
  final String templateId;             // 关联模板 ID
  final Map<String, String> data;      // 自定义字段键值对
  final int createdAt;                 // 创建时间（毫秒时间戳）
}
```

- 支持 `fromJson()` / `toJson()` 序列化
- JSON 中 `templateId` 兼容旧键名 `template`
- 支持 `copyWith()` 方法

### 4.2 AccountTemplate

**文件**: `lib/models/account_template.dart`

```dart
class AccountTemplate {
  final String templateId;             // 模板唯一 ID
  final String title;                  // 显示标题
  final String subTitle;               // 副标题
  final IconData? icon;                // Material 图标
  final List<AccountField> fields;     // 字段定义列表
  final bool isCustom;                 // false=内置, true=用户创建
}

class AccountField {
  final String fieldKey;               // 字段键名
  final String label;                  // 显示标签
  final String? description;           // 描述
  final AccountFieldAttributes attributes;  // 类型+约束
}

class AccountFieldAttributes {
  final AccountFieldType type;         // text/password/number/email/phone/url/custom
  final bool isPrimary;                // 主字段标记
  final bool isRequired;               // 必填
  final bool isSecret;                 // 密文显示（obscureText）
  final bool isEditable;               // 可编辑（默认 true）
  final bool isSearchable;             // 可搜索
  final bool isCopyable;               // 可复制（默认 true）
  final int? maxLength / minLength;    // 长度约束
  final String? regex;                 // 正则校验
  final String? hint;                  // 输入提示
}
```

### 4.3 内置模板

代码中硬编码了 4 个内置模板：

| ID | 标题 | 图标 | 核心字段 |
|------|------|------|------|
| `bank_card` | 银行卡 | `credit_card` | 持卡人、卡号★、银行、有效期、CVV |
| `email_account` | 邮箱账号 | `email` | 邮箱地址★、邮箱密码、备注 |
| `web_account` | 网站/App 账号 | `web` | 网站名称、账号★、密码、登录地址 |
| `phone_account` | 手机号 | `phone` | 手机号★、运营商、SIM PIN |

（★=isPrimary+isRequired）

全局列表 `basicAccountTemplates` 包含以上 4 个。`EnhancedAppProvider.allTemplates` 合并了内置和用户自定义模板。

---

## 5. 服务层详解

### 5.1 ServiceManager

**文件**: `lib/services/service_manager.dart`  
**模式**: 单例 (`ServiceManager.instance`)，`ChangeNotifier`

#### 构造时创建的子服务

```dart
_cryptoService       = EnhancedCryptoService()
_biometricService    = BiometricAuthService(secureStorage: secureStorage)
_autoLockService     = AutoLockService(cryptoService, secureStorage)
_secureStorageService = SecureStorageService(_cryptoService)
_syncService         = SyncService(cryptoService, storageService, config)
```

- `SyncConfig` 默认 `serverUrl: 'http://127.0.0.1:8080'`，但实际运行时由 `SharedPreferences` 中的 `sync_server_url` 覆盖

#### 状态机 (ServiceManagerState)

```
uninitialized → locked → unlocking → unlocked
                  ↑                     │
                  └─────── lock() ──────┘
                  ↑
                  └─── error (从 unlocking 失败时)
```

#### 解锁流程 (`unlockWithPassword`)

```
1. secureStorageService.initialize()          // 打开 SQLite
2. secureStorageService.getDatabaseDiagnostics()  // 调试输出表行数
3. cryptoService.initMasterKey(password)       // 设置 _isUnlocked=true
4. _currentDbPassword = password               // 缓存密码
5. autoLockService.unlock()
6. syncService.initialize()                    // 读 settings 表中的 sync_version/sync_dirty
7. connectToSyncServer('dummy_token')          // 后台静默连接（.catchError 忽略失败）
8. _state = unlocked → notifyListeners()
```

#### 同步流程 (`syncNow`)

```
1. syncService.syncNow()                       // 执行同步决策
2. if result.pulled:
   a. Future.delayed(500ms)                    // 等待文件系统刷盘
   b. secureStorageService.initialize()        // 重新打开被替换的数据库
   c. syncService.initialize()                 // 从新库读取版本号
   d. secureStorageService.loadAccounts()      // 获取真实账号数
   e. notifyListeners()                        // 触发 UI 刷新
   f. return SyncResult(pulled:true, accountCount:N)
3. if result.pushed or no-change:
   return SyncResult(..., accountCount: result.accountCount)
```

#### 锁定流程 (`lock`)

```
autoLockService.lock()
secureStorageService.close()
syncService.disconnect()
_currentDbPassword = null
_state = locked → notifyListeners()
```

#### 免密码模式

```dart
enableNoPasswordMode()  → secureStorage.write('no_password_mode', 'true') + unlockWithPassword('')
isNoPasswordMode()      → secureStorage.read('no_password_mode') == 'true'
```

#### 应用重置

```dart
resetApplication() → logout() + deleteDatabaseFile() + secureStorage.deleteAll()
```

#### 同步配置存储位置

| 配置项 | 存储位置 | 键名 | 原因 |
|--------|---------|------|------|
| 服务器地址 | SharedPreferences | `sync_server_url` | 防止被数据库同步覆盖 |
| 同步密钥 | SharedPreferences | `custom_sync_key` | 同上 |
| 自动锁定时长 | FlutterSecureStorage | `auto_lock_duration` | 安全存储 |
| 免密码模式 | FlutterSecureStorage | `no_password_mode` | 安全存储 |
| 生物识别状态 | FlutterSecureStorage | `biometric_enabled` | 安全存储 |
| 生物识别密码 | FlutterSecureStorage | `master_key_biometric_v1` | 安全存储 |

---

### 5.2 SecureStorageService

**文件**: `lib/services/secure_storage_service.dart`

#### 平台适配

```dart
bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
// 桌面: sqflite_common_ffi (databaseFactoryFfi)
// 移动: sqflite (openDatabase)
```

#### 数据库信息

| 属性 | 值 |
|------|------|
| 文件名 | `secret_roy_vault.db` |
| 路径 | `getApplicationDocumentsDirectory()` / `secret_roy_vault.db` |
| 版本 | 1 |
| 加密 | ❌ 无（明文 SQLite） |

#### 数据库 Schema

```sql
CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  template_id TEXT NOT NULL,
  data TEXT NOT NULL,              -- JSON 字符串
  created_at INTEGER NOT NULL,
  modified_at INTEGER NOT NULL,
  version INTEGER DEFAULT 1       -- 乐观锁（预留）
);
CREATE INDEX idx_accounts_template ON accounts(template_id);
CREATE INDEX idx_accounts_modified ON accounts(modified_at);

CREATE TABLE templates (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  subtitle TEXT,
  icon_code_point INTEGER,
  fields TEXT NOT NULL,            -- JSON 字符串
  is_custom INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL
);

CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at INTEGER NOT NULL
);

CREATE TABLE sync_metadata (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT,
  vector_clock TEXT,
  last_sync_at INTEGER,
  sync_enabled INTEGER DEFAULT 0
);
```

> **注意**: `sync_metadata` 表已创建但**未被代码积极使用**，同步版本号通过 `settings` 表中的 `sync_version` / `sync_dirty` 键存储。

#### 变更通知机制

```dart
StreamController<StorageChangeEvent> _changeController   // broadcast
Stream<StorageChangeEvent> get onChange                   // 外部订阅

// StorageChangeEvent:
//   type: StorageItemType (account/template/setting/syncMetadata)
//   action: StorageAction (save/batchSave/delete/clear)
//   id: String? (操作的记录 ID)
```

#### replaceDatabase 行为（同步拉取时调用）

```dart
1. _database?.close()     // 关闭当前连接
2. _database = null        // 置空 → isOpen 返回 false
3. 备份旧文件 → .bak
4. 写入新文件（flush: true）
// ⚠️ 调用方必须再调 initialize() 重新打开
```

---

### 5.3 SyncService

**文件**: `lib/sync/sync_service.dart`  
**依赖**: `EnhancedCryptoService`（未使用，保留接口）、`SecureStorageService`  
**父类**: `ChangeNotifier`

#### 状态 (SyncState)

| 状态 | 说明 |
|------|------|
| `offline` | 未连接或未配置 |
| `syncing` | 正在同步 |
| `synced` | 同步完成 |
| `error` | 同步失败 |

#### 持久化存储（settings 表）

| Key | 类型 | 说明 |
|-----|------|------|
| `sync_version` | int 字符串 | 本地版本号 |
| `sync_dirty` | "0"/"1" | 是否有未同步变更 |
| `sync_last_time` | ISO8601 | 上次同步时间 |

#### 服务器地址获取优先级

```
1. SharedPreferences → 'sync_server_url'
2. SecureStorageService.getSetting('sync_server_url')  ← 旧配置迁移
3. SyncConfig.serverUrl (构造参数，默认 'http://127.0.0.1:8080')
```

地址规范化：去尾部 `/`、`ws://` → `http://`、自动添加 `http://` 前缀

#### 核心逻辑 (`syncNow`)

```
fetchServerVersion → GET /sync/version → {version: N}

if isDirty:
    if localVersion <= serverVersion:
        localVersion = serverVersion + 1     // 冲突自动递增
    pushDatabase → PUT /sync/db?version=N    // 上传原始DB文件
    isDirty = false
    loadAccounts() → accountCount            // 此时DB仍打开，能正确读取

else if serverVersion > localVersion:
    pullDatabase → GET /sync/db              // 下载
    storageService.replaceDatabase(bytes)     //   ← DB连接关闭！
    loadAccounts() → []                      //   ← isOpen=false → 返回空
    // ⚠️ accountCount 在此层始终为 0（pull 时）
    // ServiceManager.syncNow() 负责重新 initialize 后获取正确数量

else:
    无需操作
```

#### SyncResult 类

```dart
class SyncResult {
  final bool success;
  final bool pushed;            // 是否执行了推送
  final bool pulled;            // 是否执行了拉取
  final String? error;          // 失败时的错误信息
  final int version;            // 同步后版本号
  final int accountCount;       // 账号总数
  final bool hasMetadata;       // 是否包含元数据（当前未使用，恒 false）
}
```

#### markDirty 行为

```dart
if (!_isDirty) {
  _localVersion++            // 版本号立即自增
  _isDirty = true
  持久化 sync_version 和 sync_dirty 到 settings 表
  notifyListeners()
}
```

由 `ServiceManager.saveAccount()` / `deleteAccount()` / `saveTemplate()` / `deleteTemplate()` 调用。

#### 定时同步

```dart
Timer.periodic(_config.syncInterval, (_) => syncNow())
// 默认 5 分钟间隔，由 connect() 成功后启动
```

---

### 5.4 EnhancedCryptoService

**文件**: `lib/services/enhanced_crypto_service.dart`  
**当前状态**: ⚠️ 所有加密/解密方法是**明文透传占位符**

| 方法 | 实际行为 |
|------|---------|
| `initMasterKey(password)` | 设置 `_isUnlocked=true`，返回 `true` |
| `verifyPassword(password)` | 返回 `true` |
| `encryptData(plainText)` | 原样返回 `plainText` |
| `decryptData(data)` | 原样返回 `data` |
| `deriveSubKey(purpose)` | 返回全零字节列表 |
| `logout()` | 设置 `_isUnlocked=false` |

保留了 `KdfVersion` 枚举和 `DerivedKeyMetadata` 类（含 JSON 序列化），为未来加密层重设计做接口预留。

#### 密码工具方法（可用）

```dart
static String generatePassword({length, includeUppercase, includeLowercase, includeNumbers, includeSpecial})
static int calculatePasswordStrength(String password)  // 0-100 分
static String getPasswordStrengthLevel(int score)       // "极弱"/"弱"/"中等"/"强"/"极强"
```

---

### 5.5 AutoLockService

**文件**: `lib/services/auto_lock_service.dart`  
**依赖**: `EnhancedCryptoService`、`FlutterSecureStorage`  
**父类**: `ChangeNotifier`

#### 锁定时间选项 (AutoLockDuration)

| 枚举值 | 显示名 | Duration |
|--------|--------|----------|
| `immediately` | 立即 | 0 秒 |
| `fiveSeconds` | 5秒 | 5 秒 |
| `thirtySeconds` | 30秒 | 30 秒 |
| `oneMinute` | 1分钟 | 60 秒 |
| `fiveMinutes` | 5分钟 | 300 秒 |
| `tenMinutes` | 10分钟 | 600 秒 |
| `never` | 永不 | 365 天 |

默认值：`oneMinute`

#### 生命周期联动

通过 `AutoLockObserver`（`WidgetsBindingObserver`）监听应用状态：

- `paused` / `inactive` / `hidden` → 记录 `_backgroundTime`，启动后台计时器（5秒轮询）
- `resumed` → 检查超时，如超过则调用 `lock()`
- `detached` → 保存最后活动时间

`lock()` 时调用 `_cryptoService.logout()` 清除解锁标记。

---

### 5.6 BiometricAuthService

**文件**: `lib/services/biometric_auth_service.dart`  
**依赖**: `local_auth`、`FlutterSecureStorage`

#### 状态 (BiometricAuthStatus)

| 状态 | 判断条件 |
|------|---------|
| `notSupported` | `localAuth.isDeviceSupported() == false` |
| `notEnrolled` | 无可用生物识别录入 |
| `available` | 设备支持但未在 App 中启用 |
| `enabled` | FlutterSecureStorage 中 `biometric_enabled == 'true'` |

#### 启用流程 (`enableBiometric`)

1. 检查设备支持状态
2. 调用 `localAuth.authenticate()` 验证身份
3. 将主密码明文存入 `FlutterSecureStorage`（键 `master_key_biometric_v1`）
4. 标记启用状态

#### 解锁流程 (`unlockWithBiometric`)

1. 检查启用状态
2. `localAuth.authenticate()`
3. 从 `FlutterSecureStorage` 读取主密码
4. 返回密码给 `ServiceManager.unlockWithBiometric()` → 走 `unlockWithPassword(password)` 流程

---

## 6. 状态管理层

### EnhancedAppProvider

**文件**: `lib/providers/enhanced_app_provider.dart`  
**父类**: `ChangeNotifier`  
**构造参数**: `SecureStorageService`、`ServiceManager`

#### 数据缓存

```dart
List<AccountItem> _accounts = []           // 全部账号
List<AccountTemplate> _customTemplates = [] // 自定义模板
String _searchQuery = ''                    // 搜索关键词
Set<String> _selectedTags = {}             // 选中的模板 ID 筛选
bool _isLoading = false
```

#### 关键属性

| 属性 | 说明 |
|------|------|
| `allTemplates` | `basicAccountTemplates + _customTemplates` |
| `accounts` | 应用搜索和标签筛选后的列表 |
| `allAccounts` | 未筛选的完整列表 |

#### 自动刷新机制

```dart
// 监听 ServiceManager 状态变化
_serviceManager.addListener(_onServiceManagerStateChanged)

void _onServiceManagerStateChanged() {
  if (_serviceManager.isUnlocked) {
    refresh()                           // 从 DB 重新加载
    重新订阅 _storageService.onChange   // DB 可能被替换
  } else {
    清空 _accounts 和 _customTemplates
  }
}
```

`refresh()` 方法先清空数据再重新加载（"激进刷新"），确保 UI 一定会重绘。

---

## 7. UI 层

### 7.1 页面列表

| 页面 | 文件 | Widget 类型 | 说明 |
|------|------|------------|------|
| UnlockView | `unlock_view.dart` | StatefulWidget | 解锁/创建密库/免密登录/重置应用 |
| HomeView | `home_view.dart` | StatefulWidget | 底部导航（3 Tab：账号/模板/设置） |
| AccountListView | `accounts/account_list_view.dart` | StatelessWidget | 搜索+标签筛选+账号列表 |
| AccountEditView | `accounts/account_edit_view.dart` | StatefulWidget | 账号新建/编辑（动态字段） |
| TemplateListView | `templates/template_list_view.dart` | StatelessWidget | 模板列表（内置+自定义） |
| TemplateEditView | `templates/template_edit_view.dart` | StatefulWidget | 模板编辑（动态字段管理） |
| SettingsView | `settings_view.dart` | StatelessWidget | 设置入口（跳转安全设置/关于） |
| SecuritySettingsView | `security_settings_view.dart` | StatefulWidget | 自动锁定/生物识别/同步配置 |

### 7.2 页面导航

```
UnlockView （ServiceManager.state != unlocked 时显示）
  │
  └── 解锁成功 → HomeView
        ├── Tab 0: AccountListView
        │     ├── FloatingActionButton → AccountEditView (新建)
        │     ├── ListTile.trailing → AccountEditView (编辑)
        │     └── ListTile.onLongPress → 删除确认对话框
        ├── Tab 1: TemplateListView
        │     ├── FloatingActionButton → TemplateEditView (新建)
        │     └── ListTile.trailing (isCustom) → TemplateEditView (编辑)
        └── Tab 2: SettingsView
              ├── 安全设置 → SecuritySettingsView
              │     ├── 自动锁定时间（RadioListTile）
              │     ├── 生物识别开关（SwitchListTile）
              │     ├── 密码生成器（AlertDialog）
              │     └── 同步 → showModalBottomSheet
              │           ├── 立即同步（加载对话框 → syncNow）
              │           └── 服务器配置 → showDialog
              ├── 数据同步 → SecuritySettingsView（同一页面）
              └── 关于 → showAboutDialog
```

### 7.3 主题

| 项目 | 值 |
|------|------|
| 种子颜色 | `Colors.deepPurple` |
| Material 版本 | Material 3 |
| 亮色/暗色 | 跟随系统 (`ThemeMode.system`) |
| 卡片圆角 | 12px |
| 输入框风格 | 圆角 12px，filled，deepPurple 聚焦边框 |

### 7.4 路由

```dart
// main.dart 中注册的命名路由
'/unlock'  → UnlockView
'/home'    → HomeView
'/security' → SecuritySettingsView
```

实际导航主要使用 `Navigator.push(MaterialPageRoute(...))` 方式。

---

## 8. 同步服务器

**文件**: `sync_server/index.js`  
**框架**: Express.js + CORS  
**端口**: `process.env.PORT || 8080`

### API 接口

| 方法 | 路径 | 请求体 | 响应 |
|------|------|--------|------|
| `GET` | `/sync/version` | — | `{ version: int, updatedAt: ISO8601 }` |
| `GET` | `/sync/db` | — | 二进制文件（`vault.db.enc`） |
| `PUT` | `/sync/db?version=N` | `application/octet-stream`（最大 50MB） | 成功 `{ success: true, serverVersion: N }`，冲突 `409 { error, serverVersion }` |

### 冲突策略

```javascript
if (clientVersion <= serverVersion) {
  return 409 Conflict     // 拒绝低版本推送
} else {
  写入文件，更新版本号
}
```

### 数据存储

```
sync_server/data/
├── vault.db.enc        # 接收的数据库文件（实际为明文 SQLite）
└── sync_version.json   # { "version": N, "updatedAt": "..." }
```

### 日志

所有请求通过中间件打印：`[HH:MM:SS] METHOD URL`

---

## 9. 关键数据流

### 账号保存

```
UI: AccountEditView._save()
  → Navigator.pop(item)
  → AccountListView: context.read<EnhancedAppProvider>().addAccount(item)
  → EnhancedAppProvider.addAccount()
    → ServiceManager.saveAccount(item)
      → SecureStorageService.saveAccount(item)         // INSERT OR REPLACE
      → SyncService.markDirty()                        // localVersion++, isDirty=true
    → _accounts.insert(0, item)
    → notifyListeners()
```

### 同步拉取（完整流程）

```
UI: SecuritySettingsView → "立即同步" onTap
  → Navigator.of(sheetContext).pop()                   // 关闭底部弹窗
  → outerNavigator.push(DialogRoute)                   // 显示加载框
  → ServiceManager.syncNow()
    → SyncService.syncNow()
      → GET /sync/version                             // 获取服务器版本
      → serverVersion > localVersion
      → GET /sync/db                                  // 下载数据库
      → StorageService.replaceDatabase(bytes)          // 写入文件，DB关闭
      → return SyncResult(pulled:true, accountCount:0) // ← DB已关闭
    → Future.delayed(500ms)                            // 等待刷盘
    → StorageService.initialize()                      // 重新打开 DB
    → SyncService.initialize()                         // 从新库读版本号
    → StorageService.loadAccounts()                    // 获取真实账号数
    → notifyListeners()
      → EnhancedAppProvider._onServiceManagerStateChanged()
      → EnhancedAppProvider.refresh()                  // 重新加载账号列表
    → return SyncResult(pulled:true, accountCount:N)
  → outerNavigator.maybePop()                          // 关闭加载框
  → outerScaffoldMsg.showSnackBar("拉取成功 账号:N")
```

---

## 10. 已知技术债

| 优先级 | 问题 | 位置 | 说明 |
|--------|------|------|------|
| 🔴 高 | 数据明文存储 | `secure_storage_service.dart` | SQLite 文件无加密，`data` 字段含密码明文 |
| 🔴 高 | 同步传输明文 | `sync_service.dart` / `index.js` | HTTP 未加密，数据库文件原始传输 |
| 🔴 高 | 服务器无认证 | `index.js` | 任何能访问 IP 的人可读写数据库 |
| 🔴 高 | 生物识别密码明文存储 | `biometric_auth_service.dart:117` | 主密码直接写入 FlutterSecureStorage |
| 🟠 中 | `sync_metadata` 表未使用 | `secure_storage_service.dart:198` | 已创建但无 CRUD 代码调用 |
| 🟠 中 | `core/` 目录空 | `lib/core/` | 可清理或填充 |
| 🟡 低 | `EnhancedCryptoService` 被 `SyncService` 接收但未使用 | `sync_service.dart:39` | 构造参数存在但无调用 |
| 🟡 低 | 数据库文件后缀名 `.enc` 但实际未加密 | `sync_server/data/vault.db.enc` | 仅约定命名，内容为明文 SQLite |
| 🟡 低 | `_getSyncKey()` 方法返回空字符串 | `sync_service.dart:161` | 同步密钥功能预留但未实现 |
| 🟡 低 | `hasMetadata` 字段恒为 `false` | `sync_service.dart:390` | SyncResult 参数从未被设为 true |

---

## 11. 依赖包清单

### 运行时依赖

| 包名 | 版本 | 用途 |
|------|------|------|
| `provider` | ^6.1.5 | 状态管理 |
| `shared_preferences` | ^2.0.15 | 同步配置存储 |
| `flutter_secure_storage` | ^10.0.0 | 密钥/密码安全存储 |
| `sqflite` | ^2.2.0 | 移动端 SQLite |
| `sqflite_common_ffi` | ^2.3.5 | 桌面端 SQLite |
| `path` | ^1.9.0 | 文件路径拼接 |
| `path_provider` | ^2.1.4 | 获取文档目录 |
| `http` | ^1.2.0 | HTTP 同步传输 |
| `local_auth` | ^2.3.0 | 生物识别认证 |
| `local_auth_windows` | ^1.0.11 | Windows 生物识别 |
| `intl` | any | 国际化 |
| `flutter_localizations` | SDK | 国际化 |
| `material_symbols_icons` | ^4.2892.0 | 图标（未在代码中直接引用） |
| `json_annotation` | ^4.9.0 | JSON 注解（预留） |
| `cupertino_icons` | ^1.0.8 | iOS 风格图标 |
| `uuid` | ^4.5.1 | UUID 生成（未在代码中直接引用） |

### 开发依赖

| 包名 | 版本 | 用途 |
|------|------|------|
| `flutter_test` | SDK | 测试 |
| `build_runner` | ^2.4.8 | 代码生成 |
| `json_serializable` | ^6.8.0 | JSON 序列化（预留） |
| `flutter_lints` | ^6.0.0 | 代码规范 |
