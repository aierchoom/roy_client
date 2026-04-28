# Flutter 基础速通

本文只讲 SecretRoy 这个项目里马上会遇到的 Flutter 概念。读完后，你不需要完整掌握 Flutter，只要能看懂页面代码大概在做什么。

## 1. Widget 是什么

在 Flutter 里，几乎所有界面元素都叫 Widget。你可以先把 Widget 理解成“界面零件”。

在本项目中：

- `SecretRoyApp` 是整个应用的根 Widget，负责创建 `MaterialApp`、主题、语言和首页。
- `HomeView` 是解锁后的主界面 Widget。
- `AccountListView` 是账号列表页面 Widget。
- `AccountListTile` 是列表里每一条账号卡片 Widget。
- `GreenAddButton` 是右下角绿色新增按钮 Widget。

一个页面通常不是一个大 Widget 写到底，而是很多小 Widget 拼起来：

```text
SecretRoyApp
↓
MaterialApp
↓
HomeView
↓
AccountListView / HomeSearchView / SettingsView
↓
AccountListTile / GreenAddButton / 各种按钮和输入框
```

项目中的例子：

`lib/views/accounts/account_list_view.dart` 里的 `AccountListView` 负责展示账号库。它内部又会创建统计卡片、模板筛选按钮、账号分组列表和新增按钮。

```dart
class AccountListView extends StatefulWidget {
  const AccountListView({super.key});

  @override
  State<AccountListView> createState() => _AccountListViewState();
}
```

这段代码的意思是：`AccountListView` 是一个页面零件，它需要保存一些页面内部状态，所以它是 `StatefulWidget`。

## 2. StatelessWidget vs StatefulWidget

新手可以先这样理解：

- `StatelessWidget`：自己不保存会变化的数据，只根据外部传进来的数据画界面。
- `StatefulWidget`：自己保存会变化的数据，比如当前选中的 tab、输入框内容、加载中状态、展开/收起状态。

### StatelessWidget：只负责展示

项目中的例子是 `SettingsView`：

```dart
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    // 读取 Provider 中的数据，然后画设置列表
  }
}
```

`SettingsView` 本身没有“当前正在编辑的值”这种内部状态。它主要展示设置入口，例如外观、安全、同步、模板管理。

另一个例子是 `HomeViewMobile` 和 `HomeViewDesktop`。它们不自己决定当前选中的页面，而是接收 `selectedIndex` 和 `onDestinationSelected`：

```dart
class HomeViewMobile extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> pages;
}
```

这类 Widget 像一个显示器：别人告诉它当前选中哪个 tab，它就把对应样式画出来。

### StatefulWidget：页面里有会变的东西

项目中的例子是 `HomeView`：

```dart
class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 1;

  void _onItemTapped(int idx) {
    setState(() => _selectedIndex = idx);
  }
}
```

`HomeView` 需要记住当前选中的页面：

- `0`：账号列表
- `1`：主页搜索
- `2`：设置

用户点击底部导航或桌面左侧导航时，`_selectedIndex` 会变，所以它需要 `StatefulWidget`。

项目中的另一个例子是 `AccountListTile`。每条账号卡片可以展开和收起：

```dart
class _AccountListTileState extends State<AccountListTile> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
  }
}
```

这里的 `_isExpanded` 只影响这一条卡片，不影响全局账号数据。

## 3. build 方法的作用

`build` 方法就是“把当前数据画成界面”的地方。

你可以把它理解成一个函数：

```text
当前状态 + 当前数据
↓
build()
↓
新的界面结构
```

项目中的例子：

`lib/main.dart` 里的 `SecretRoyApp.build()` 会决定整个 App 长什么样：

```dart
@override
Widget build(BuildContext context) {
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
}
```

这段代码做了两件重要的事：

1. 用 `MultiProvider` 把全局状态放到页面树里。
2. 根据 `serviceManager.state` 决定显示 `HomeView` 还是 `UnlockView`。

也就是说，App 解锁前显示解锁页；解锁成功后，状态变成 `unlocked`，`build` 重新执行，首页就显示出来。

再看 `AccountListView.build()`：

```dart
@override
Widget build(BuildContext context) {
  final provider = context.watch<EnhancedAppProvider>();

  return LayoutBuilder(
    builder: (context, constraints) {
      return Stack(
        children: [
          // 账号统计、账号列表
          // 右下角新增按钮
        ],
      );
    },
  );
}
```

`context.watch<EnhancedAppProvider>()` 的意思是：这个页面关心账号数据。只要 `EnhancedAppProvider` 发出通知，这个 `build` 就会重新执行，页面会拿到最新账号列表。

## 4. UI 是如何刷新的

本项目里主要有两种刷新方式。

### 方式一：setState 刷新局部页面

适合“只影响当前页面内部的小状态”。

项目中的例子：

`HomeView` 切换 tab：

```dart
void _onItemTapped(int idx) {
  setState(() => _selectedIndex = idx);
}
```

流程：

```text
用户点击导航按钮
↓
调用 _onItemTapped
↓
修改 _selectedIndex
↓
setState 通知 Flutter
↓
HomeView.build 重新执行
↓
IndexedStack 显示新的页面
```

`AccountListTile` 展开详情也是同样方式：

```text
用户点击展开按钮
↓
_isExpanded 变成 true/false
↓
当前账号卡片重新 build
↓
详情区域显示或隐藏
```

### 方式二：notifyListeners 刷新共享数据页面

适合“很多页面都可能关心的数据”，例如账号列表、模板列表、解锁状态、主题设置。

项目使用 `Provider + ChangeNotifier`。核心文件是：

- `lib/providers/enhanced_app_provider.dart`
- `lib/providers/theme_provider.dart`
- `lib/services/service_manager.dart`

以账号列表为例：

```dart
Future<void> addAccount(AccountItem item) async {
  _setLoading(true);

  try {
    await _serviceManager.saveAccount(item);
    _accounts.insert(0, item);
    notifyListeners();
  } finally {
    _setLoading(false);
  }
}
```

流程：

```text
保存账号
↓
EnhancedAppProvider.addAccount
↓
账号写入本地加密数据库
↓
_accounts 列表加入新账号
↓
notifyListeners()
↓
使用 context.watch 的页面自动重新 build
↓
新账号出现在 AccountListView
```

### 本项目里什么时候用哪种方式

`setState` 用在当前 Widget 自己的小变化：

- `HomeView` 的当前 tab。
- `UnlockView` 的加载中、错误提示。
- `AccountListTile` 的展开/收起。
- `AccountEditView` 的输入框、字段可见性、编辑模式。

`notifyListeners` 用在全局或共享数据变化：

- `ServiceManager` 的锁定/解锁状态。
- `EnhancedAppProvider` 的账号列表、模板列表、冲突数量。
- `AppThemeProvider` 的主题模式、主题色。

## 5. 新手看页面代码的顺序

第一次读这个项目，不建议从所有 Widget 开始看。按这个顺序会更顺：

```text
lib/main.dart
↓
lib/views/unlock_view.dart
↓
lib/views/home/home_view.dart
↓
lib/views/accounts/account_list_view.dart
↓
lib/providers/enhanced_app_provider.dart
↓
lib/services/service_manager.dart
```

这样你会先看到 App 如何启动，再看到页面如何切换，最后看到数据从哪里来。
