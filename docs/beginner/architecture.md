# 架构分层说明

SecretRoy 是一个 Flutter 本地保险库应用。它的核心结构可以先理解成四层：

```text
UI 层
↓
状态管理层
↓
业务层
↓
数据层
```

更贴近本项目的图是：

```text
lib/views + lib/widgets
↓
lib/providers + ChangeNotifier
↓
lib/services + lib/sync
↓
lib/models + SecureStorageService(SQLite) + SyncService HTTP
```

## 1. UI 层：负责展示和接收用户操作

项目里的 UI 层主要在：

- `lib/views/`
- `lib/widgets/`

虽然用户需求里常见说法是 `pages/widgets`，这个项目把页面目录命名为 `views`。可以把 `views` 理解成 pages。

### views：完整页面

典型页面：

- `lib/views/unlock_view.dart`：解锁页。
- `lib/views/home/home_view.dart`：主框架页。
- `lib/views/home/home_search_view.dart`：主页搜索。
- `lib/views/accounts/account_list_view.dart`：账号列表。
- `lib/views/accounts/account_edit_view.dart`：账号编辑。
- `lib/views/settings_view.dart`：设置中心。
- `lib/views/templates/template_list_view.dart`：模板列表。
- `lib/views/sync_settings_view.dart`：同步设置。

页面的职责是：

```text
显示数据
↓
响应点击、输入、保存
↓
调用 Provider 或 Service
↓
根据状态重新 build
```

项目中的例子：

`AccountListView` 展示账号列表。它不会自己直接写数据库，而是调用 `EnhancedAppProvider`：

```dart
final provider = context.read<EnhancedAppProvider>();
await provider.addAccount(result);
```

### widgets：可复用小组件

典型组件：

- `lib/widgets/account_list_tile.dart`：账号列表中的单条账号卡片。
- `lib/widgets/green_add_button.dart`：新增按钮。
- `lib/widgets/adaptive_page.dart`：桌面和移动端布局约束。
- `lib/widgets/password_generator_sheet.dart`：密码生成弹窗。
- `lib/widgets/account_edit_widgets.dart`：账号编辑页的局部组件。

组件的职责是：

```text
把一小块 UI 画好
↓
通过参数接收数据
↓
通过回调把用户操作交回页面
```

例如 `AccountListTile` 接收 `account`、`template`、`onEdit`、`onDelete`，自己负责展示卡片、展开详情、复制字段。

## 2. 状态管理层：负责把数据送到 UI

本项目使用的是 `Provider + ChangeNotifier`。

核心文件：

- `lib/providers/enhanced_app_provider.dart`
- `lib/providers/theme_provider.dart`
- `lib/services/service_manager.dart`

在 `lib/main.dart` 中注册：

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: _serviceManager),
    ChangeNotifierProvider(
      create: (_) => EnhancedAppProvider(
        ServiceManager.instance.storageService,
        ServiceManager.instance,
      ),
    ),
    ChangeNotifierProvider(create: (_) => AppThemeProvider(widget.prefs)),
  ],
)
```

### EnhancedAppProvider：账号和模板状态

`EnhancedAppProvider` 保存 UI 最常用的数据：

- `_accounts`：账号列表。
- `_customTemplates`：用户自定义模板。
- `_searchQuery`：搜索词。
- `_selectedTags`：筛选条件。
- `_isLoading`：加载状态。
- `_conflictCount`：同步冲突数量。

它对 UI 暴露 getter：

```dart
List<AccountItem> get allAccounts => _accounts;
List<AccountTemplate> get customTemplates => _customTemplates;
bool get isLoading => _isLoading;
int get conflictCount => _conflictCount;
```

UI 读取它：

```dart
final provider = context.watch<EnhancedAppProvider>();
```

数据变化后，它调用：

```dart
notifyListeners();
```

然后使用 `watch` 的页面会自动重新 build。

### ServiceManager：全局服务状态

`ServiceManager` 也是 `ChangeNotifier`。它保存 App 是否解锁：

```dart
enum ServiceManagerState {
  uninitialized,
  locked,
  unlocking,
  unlocked,
  error,
}
```

`SecretRoyApp` 监听它：

```dart
home: serviceManager.state == ServiceManagerState.unlocked
    ? const HomeView()
    : const UnlockView(),
```

所以解锁成功后，不需要页面手动跳转，`ServiceManager` 发通知即可。

### AppThemeProvider：主题状态

`AppThemeProvider` 管主题：

- `themeMode`：跟随系统、浅色、深色。
- `colorSeed`：主题色。
- `trueBlack`：纯黑模式。

它把设置写入 `SharedPreferences`，然后 `notifyListeners()`，`MaterialApp` 重新 build 后主题就更新。

## 3. 业务层：负责把一个操作做完整

项目里的业务层主要在：

- `lib/services/`
- `lib/sync/`
- `lib/system/service_manager/`

业务层不是直接画界面，而是处理“一个功能应该怎么完成”。

### ServiceManager：业务门面

`ServiceManager` 是最重要的业务入口。UI 和 Provider 尽量通过它做关键操作。

例子：保存账号。

```dart
Future<void> saveAccount(AccountItem account) async {
  if (!isUnlocked) return;
  await _secureStorageService.saveAccount(account);
  await _syncService.markDirty();
  unawaited(_syncService.syncNow());
}
```

这段代码把“保存账号”拆成三个业务动作：

```text
确认保险库已解锁
↓
保存到本地加密数据库
↓
标记同步脏数据
↓
后台尝试同步
```

UI 不需要知道 SQLite 怎么写，也不需要知道同步怎么发 HTTP。

### 其他 services

常见服务：

- `SecureStorageService`：打开、读取、写入加密数据库。
- `EnhancedCryptoService`：主密码、数据库文件密钥。
- `BiometricAuthService`：生物识别。
- `AutoLockService`：自动锁定。
- `IdentityService`：设备 ID、保险库 ID、同步密钥。
- `VaultPairingService`、`LanPairingService`：设备配对。

### sync 目录

同步逻辑在：

- `lib/sync/sync_service.dart`
- `lib/sync/sync_payload_codec.dart`
- `lib/sync/crdt_merge_engine.dart`

`SyncService` 负责：

```text
读取本地待同步数据
↓
加密并签名 payload
↓
HTTP 推送到同步服务器
↓
拉取远端变更
↓
合并账号和模板
↓
记录冲突日志
```

对于新手，先记住：同步不是 UI 层做的，而是由 `ServiceManager` 和 `SyncService` 在后台完成。

## 4. 数据层：负责数据形状、存储和外部接口

项目的数据层包括三类东西。

### models：数据长什么样

目录：

- `lib/models/account_item.dart`
- `lib/models/account_template.dart`
- `lib/models/hlc.dart`

`AccountItem` 表示一条账号：

```dart
class AccountItem {
  final String id;
  final String name;
  final String email;
  final String templateId;
  final Map<String, String> data;
  final int createdAt;

  final Hlc nameHlc;
  final Hlc emailHlc;
  final Map<String, Hlc> dataHlc;
  final int serverVersion;
  final SyncStatus syncStatus;
  final bool isDeleted;
}
```

普通理解：

- `name`：账号名称。
- `email`：邮箱或登录名。
- `templateId`：这条账号使用哪个模板。
- `data`：模板字段里的具体内容，比如密码、API Key、恢复码。
- `syncStatus`：是否已经同步。
- `Hlc` 字段：同步冲突合并时用的时间戳。

`AccountTemplate` 表示账号模板：

```text
模板
↓
定义账号需要哪些字段
↓
编辑页根据模板自动生成输入项
```

当前内置模板是 `websiteTemplate`，也就是“网站模板”。

### 本地存储：SecureStorageService

核心文件：

- `lib/services/secure_storage_service.dart`

它使用 SQLite 保存数据，但不是直接把明文数据库长期放在用户目录。

流程：

```text
保险库未解锁
↓
磁盘上只有加密文件 secret_roy_vault.db.enc

用户解锁
↓
EnhancedCryptoService 解开数据库密钥
↓
SecureStorageService 把加密文件解成临时运行数据库
↓
App 使用 SQLite 读写

数据变化或关闭
↓
运行数据库重新加密
↓
写回 secret_roy_vault.db.enc
```

数据表包括：

- `accounts`：账号。
- `templates`：自定义模板。
- `conflict_logs`：同步冲突记录。
- `settings`：同步版本、脏标记等设置。

### API：同步 HTTP 在 SyncService 中

本项目没有单独的 `api/` 目录。同步 API 请求集中在 `lib/sync/sync_service.dart`。

拉取远端变更：

```dart
final response = await http.get(
  Uri.parse('$serverUrl/vaults/$vaultId/sync?since=$since'),
);
```

推送本地变更：

```dart
final response = await http.post(
  Uri.parse('$serverUrl/vaults/$vaultId/sync'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'pushes': pushPayloads}),
);
```

业务上可以理解为：

```text
本地数据库
↓
SyncService 找到待同步账号/模板
↓
SyncPayloadCodec 加密 payload
↓
HTTP POST 推送
↓
HTTP GET 拉取远端变更
↓
CrdtMergeEngine 合并
↓
写回本地数据库
```

## 5. 层与层之间如何交互

以“新增账号”为例：

```text
UI 层
AccountListView / AccountEditView
↓
状态管理层
EnhancedAppProvider.addAccount()
↓
业务层
ServiceManager.saveAccount()
↓
数据层
SecureStorageService.saveAccount()
↓
本地 SQLite + 加密文件
```

保存完成后反向通知：

```text
SecureStorageService 发 StorageChangeEvent
↓
EnhancedAppProvider 重新 loadAccounts()
↓
EnhancedAppProvider.notifyListeners()
↓
AccountListView 重新 build
↓
用户看到新账号
```

## 6. 数据流总图

读取账号列表：

```text
SecureStorageService.loadAccounts()
↓
EnhancedAppProvider._loadData()
↓
_accounts
↓
notifyListeners()
↓
AccountListView context.watch()
↓
_buildGroups(provider)
↓
AccountListTile
```

保存账号：

```text
AccountEditView._save()
↓
Navigator.pop(AccountItem)
↓
AccountListView._openEditor() 收到 result
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
UI 刷新
```

解锁进入首页：

```text
UnlockView._unlockWithPassword()
↓
ServiceManager.unlockWithPassword()
↓
IdentityService + CryptoService + SecureStorageService + SyncService
↓
ServiceManagerState.unlocked
↓
SecretRoyApp Consumer2 重新 build
↓
HomeView
↓
EnhancedAppProvider.refresh()
↓
账号和模板展示
```

## 7. 新手读代码时怎么判断自己在哪一层

看到 `Scaffold`、`TextField`、`ListView`、`IconButton`，通常在 UI 层。

看到 `context.watch`、`context.read`、`notifyListeners`，通常在状态管理层。

看到 `ServiceManager.saveAccount`、`unlockWithPassword`、`syncNow`，通常在业务层。

看到 `AccountItem`、`AccountTemplate`、`db.insert`、`http.get`、`http.post`，通常在数据层。

这个判断方法足够支撑你读懂本项目大部分代码。
