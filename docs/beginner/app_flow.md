# 项目运行流程

本文从 `lib/main.dart` 开始，按 App 实际执行顺序讲 SecretRoy 是怎么跑起来的。

## 1. 先把项目跑起来

在项目根目录执行：

```bash
flutter pub get
flutter run
```

如果本机有多个设备，可以指定平台，例如 Windows 桌面端：

```bash
flutter run -d windows
```

项目的 Dart SDK 要求在 `pubspec.yaml` 里：

```yaml
environment:
  sdk: ^3.10.1
```

首次运行时，App 会进入 `UnlockView`。你可以创建主密码，也可以选择跳过主密码进入本地保险库。同步服务器不是基础启动必需项；没有配置同步地址时，本地账号管理仍然可以跑通。

## 2. 总体启动链路

先看整体流程：

```text
main.dart
↓
Flutter 引擎初始化
↓
读取 SharedPreferences
↓
初始化 ServiceManager
↓
runApp(SecretRoyApp)
↓
注册 Provider
↓
根据解锁状态决定首页
↓
未解锁：UnlockView
已解锁：HomeView
```

## 3. main.dart 做了什么

入口代码在 `lib/main.dart`：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await ServiceManager.instance.initialize();

  runApp(SecretRoyApp(prefs: prefs));
}
```

按步骤理解：

### 第一步：初始化 Flutter

```dart
WidgetsFlutterBinding.ensureInitialized();
```

这句是告诉 Flutter：“我要在 `runApp` 之前使用插件或平台能力，请先准备好 Flutter 和原生平台之间的通道。”

本项目马上会读取 `SharedPreferences`，还会初始化安全存储相关服务，所以需要这句。

### 第二步：读取本地偏好设置

```dart
final prefs = await SharedPreferences.getInstance();
```

`SharedPreferences` 用来保存轻量设置，比如主题模式、主题色、同步服务器地址等。

这里读取出来后，会传给 `SecretRoyApp`，再交给 `AppThemeProvider` 使用。

### 第三步：初始化服务总管

```dart
await ServiceManager.instance.initialize();
```

`ServiceManager` 是本项目的“服务入口”。它统一管理：

- 主密码和数据库密钥：`EnhancedCryptoService`
- 生物识别：`BiometricAuthService`
- 自动锁定：`AutoLockService`
- 本地身份：`IdentityService`
- 加密数据库：`SecureStorageService`
- 同步：`SyncService`
- 配对：`VaultPairingService`、`LanPairingService`

`initialize()` 当前主要做：

```text
初始化自动锁定服务
↓
把 ServiceManager 状态设置为 locked
↓
notifyListeners 通知关心它的 UI
```

注意：这一步还没有打开账号数据库。数据库需要用户输入主密码或走无密码模式后才会打开。

### 第四步：真正启动 App

```dart
runApp(SecretRoyApp(prefs: prefs));
```

从这里开始，Flutter 会创建第一棵 Widget 树。

## 4. SecretRoyApp 如何创建全局状态

`SecretRoyApp` 是一个 `StatefulWidget`。它在 `initState` 里注册生命周期监听：

```dart
@override
void initState() {
  super.initState();
  _serviceManager.setupLifecycleObserver();
}
```

这件事和自动锁定有关。App 进入后台或达到锁定条件时，`AutoLockService` 会触发锁定，`ServiceManager` 会关闭数据库并把状态改回 `locked`。

然后看 `build`：

```dart
return MultiProvider(
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
  child: Consumer2<ServiceManager, AppThemeProvider>(
    builder: (context, serviceManager, themeProvider, _) {
      return MaterialApp(
        home: serviceManager.state == ServiceManagerState.unlocked
            ? const HomeView()
            : const UnlockView(),
      );
    },
  ),
);
```

这里有三个全局对象：

- `ServiceManager`：控制锁定、解锁、服务生命周期。
- `EnhancedAppProvider`：给 UI 提供账号、模板、冲突数量等业务数据。
- `AppThemeProvider`：给 UI 提供主题模式、主题色等外观数据。

## 5. App 首屏是如何展示的

首页判断在 `MaterialApp.home`：

```dart
home: serviceManager.state == ServiceManagerState.unlocked
    ? const HomeView()
    : const UnlockView(),
```

流程是：

```text
ServiceManager.state 初始为 locked
↓
MaterialApp 显示 UnlockView
↓
用户输入主密码或选择无密码模式
↓
ServiceManager 解锁成功
↓
state 变成 unlocked
↓
notifyListeners
↓
Consumer2 重新 build
↓
MaterialApp.home 变成 HomeView
```

这就是为什么项目里没有在解锁成功后手动 `Navigator.push('/home')`。首页切换是由状态驱动的。

## 6. 解锁流程

`UnlockView` 是启动后的默认页面。它在 `initState` 中做两件事：

```text
检查是否为无密码模式 / 首次运行
↓
检查生物识别状态
```

用户输入主密码点击解锁后，流程如下：

```text
UnlockView
↓
_unlockWithPassword()
↓
ServiceManager.unlockWithPassword(password)
↓
ServiceManager._performUnlock(password)
↓
VaultUnlockCoordinator.initializeAndUnlock(password)
  (内部依次初始化 IdentityService、CryptoService、
   SecureStorageService、SyncService 等)
↓
ServiceManagerState.unlocked
↓
notifyListeners()
↓
SecretRoyApp 重新 build
↓
HomeView 展示
```

每一步的作用：

1. `IdentityService.initialize()`
   准备本机设备 ID、保险库 ID、同步用密钥。如果是第一次运行，会生成新的身份。

2. `EnhancedCryptoService.initMasterKey(password)`
   校验或创建主密码，并解开数据库文件密钥。

3. `VaultUnlockCoordinator.initializeAndUnlock(password)`
   委托协调器完成解锁后的完整初始化：校验主密码、打开加密数据库、初始化同步服务等。真实数据保存在 `secret_roy_vault.db.enc`，解锁后会临时解密成运行期 SQLite 文件。

4. 同步服务初始化
   在 `VaultUnlockCoordinator.initializeAndUnlock` 内部完成，读取本地同步版本、脏数据标记等同步状态。

5. `ServiceManagerState.unlocked`
   全局状态变为已解锁，UI 可以进入主界面。

## 7. HomeView 如何展示首页

`HomeView` 在 `lib/views/home/home_view.dart`：

```dart
class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 1;

  final List<Widget> _pages = const [
    AccountListView(),
    HomeSearchView(),
    SettingsView(),
  ];
}
```

默认 `_selectedIndex = 1`，所以解锁后首先显示的是 `HomeSearchView`。

页面结构：

```text
HomeView
↓
PlatformBuilder
↓
桌面端：HomeViewDesktop
移动端：HomeViewMobile
↓
IndexedStack
↓
AccountListView / HomeSearchView / SettingsView
```

`IndexedStack` 的作用是：三个页面都在栈里，但只显示当前选中的那个。切换 tab 时，页面不会每次都完全重建成空状态。

## 8. 页面跳转方式

本项目有两类页面跳转。

### 方式一：状态决定首页

解锁前后不是普通跳转，而是由 `ServiceManager.state` 决定：

```text
locked
↓
UnlockView

unlocked
↓
HomeView
```

这是主流程。

### 方式二：Navigator.push 打开子页面

项目里编辑账号、编辑模板、进入安全设置、进入同步设置等，使用 `Navigator.push`。

账号列表打开编辑页：

```dart
final result = await Navigator.push<AccountItem>(
  context,
  MaterialPageRoute(builder: (_) => AccountEditView(initial: initial)),
);
```

编辑页保存后：

```dart
Navigator.of(context).pop(item);
```

流程：

```text
AccountListView
↓
Navigator.push(AccountEditView)
↓
用户编辑并保存
↓
AccountEditView 创建 AccountItem
↓
Navigator.pop(item)
↓
AccountListView 收到 result
↓
调用 Provider 保存数据
```

设置页也是类似方式：

```text
SettingsView
↓
Navigator.push(SecuritySettingsView / SyncSettingsView / TemplateListView)
↓
进入具体设置页面
```

`MaterialApp.routes` 里也注册了命名路由：

```dart
routes: {
  '/unlock': (context) => const UnlockView(),
  '/home': (context) => const HomeView(),
  '/password-tools': (context) => const PasswordToolsView(),
  '/security': (context) => const SecuritySettingsView(),
  '/sync': (context) => const SyncSettingsView(),
}
```

不过当前主要页面更常用 `MaterialPageRoute` 直接跳转。

## 9. 数据请求和 UI 更新流程

本项目的数据来源主要是本地加密 SQLite。这里的“请求数据”不一定是 HTTP 请求，更多时候是从 `SecureStorageService` 读取本地数据库。

解锁后的数据加载流程：

```text
ServiceManager 解锁成功
↓
ServiceManager.notifyListeners()
↓
EnhancedAppProvider 监听到已解锁
↓
EnhancedAppProvider.refresh()
↓
SecureStorageService.loadAccounts()
↓
SecureStorageService.loadCustomTemplates()
↓
SecureStorageService.getConflictLogs()
↓
EnhancedAppProvider 保存到内存列表
↓
notifyListeners()
↓
AccountListView / HomeSearchView 重新 build
↓
账号列表、搜索页、统计数字更新
```

对应代码在 `EnhancedAppProvider`：

```dart
Future<void> _loadData() async {
  if (!_storageService.isOpen) return;

  _accounts = List<AccountItem>.of(await _storageService.loadAccounts());
  _customTemplates = List<AccountTemplate>.of(
    await _storageService.loadCustomTemplates(),
  );

  notifyListeners();
}
```

UI 页面通过 `watch` 订阅：

```dart
final provider = context.watch<EnhancedAppProvider>();
```

`watch` 的意思是：如果 `provider.notifyListeners()`，这个页面就重新执行 `build`。

## 10. 新增账号时的数据流

这是最典型的一条业务链路：

```text
用户点击新增按钮
↓
AccountListView._openEditor()
↓
Navigator.push(AccountEditView)
↓
用户填写表单并保存
↓
AccountEditView._save()
↓
Navigator.pop(AccountItem)
↓
AccountListView 收到 result
↓
EnhancedAppProvider.addAccount(result)
↓
ServiceManager.saveAccount(result)
↓
SecureStorageService.saveAccount(result)
↓
写入 SQLite 并加密落盘
↓
SyncService.markDirty()
↓
EnhancedAppProvider.notifyListeners()
↓
AccountListView 重新 build
↓
新账号出现在列表
```

这里有两个刷新来源：

1. `EnhancedAppProvider.addAccount()` 会先把新账号插入 `_accounts`，让 UI 立即更新。
2. `SecureStorageService.saveAccount()` 会发出 `StorageChangeEvent`，`EnhancedAppProvider` 监听到后重新从数据库加载一次，保证内存数据和数据库一致。

## 11. 一张完整脑图

把启动、解锁、加载数据连起来：

```text
main.dart
↓
WidgetsFlutterBinding.ensureInitialized()
↓
SharedPreferences.getInstance()
↓
ServiceManager.initialize()
↓
runApp(SecretRoyApp)
↓
MultiProvider 注册全局状态
↓
ServiceManager.state == locked
↓
显示 UnlockView
↓
用户输入主密码
↓
ServiceManager.unlockWithPassword()
↓
初始化身份、密码、数据库、同步
↓
ServiceManager.state == unlocked
↓
显示 HomeView
↓
EnhancedAppProvider.refresh()
↓
读取账号和模板
↓
notifyListeners()
↓
HomeSearchView / AccountListView 展示数据
```
