# SecretRoy 教学级源码教程

> 如果你想看“架构评审/专业解读”风格，而不是初学者教程，请直接阅读：`docs/architecture/architecture-deep-dive.md`

这不是一份“5 分钟看懂 Flutter”的速成笔记。

这是一份把 `roy` 当作教学项目来拆解的深入教程，目标是让一个：

- 懂 Node.js
- 懂服务、接口、数据库、状态、组件化
- 但不懂 Flutter

的人，能够真正读懂这个项目的设计与实现。

这份教程会尽量做到 4 件事：

1. 先帮你建立 Flutter 的心智模型，而不是直接灌术语。
2. 按真实代码拆模块，讲“为什么这么设计”。
3. 不只讲表面功能，还讲调用链、状态流、数据流和边界。
4. 明确指出这个项目哪些地方是可学习的设计，哪些地方只是原型阶段的占位实现。

---

## 0. 教程怎么用

如果你第一次接触这个仓库，不要从头到尾硬读。

建议这样使用这份教程：

1. 先看第 1 章到第 4 章，建立整体图景。
2. 再跑一遍项目。
3. 然后按“模块”阅读第 5 章以后。
4. 每读完一章，就打开对应源码文件跟一遍。

你可以把这份教程当成一门小课，它的主题是：

“一个 Flutter 本地优先密码库原型，是如何组织 UI、状态、存储、同步和服务端的。”

---

## 1. 项目定位：它到底是什么

这个仓库本质上是一个“小型全栈同步应用”。

### 1.1 仓库结构

```text
roy/
  docs/
  roy_client/
  roy_server/
```

真正的主角只有两个：

- `roy_client/`：Flutter 客户端
- `roy_server/`：Node.js 同步服务

### 1.2 用 Node.js 视角理解它

可以先粗暴类比成：

- `roy_client` = “React App + 本地 SQLite + 原生能力 + 同步引擎”
- `roy_server` = “一个轻量的 Express 同步 API”

这个类比不完全准确，但足够帮你理解结构。

### 1.3 这个项目解决什么问题

从产品角度，它试图解决：

- 本地保存账号/密码/模板化字段
- 多端同步
- 自动锁定
- 生物识别解锁
- 冲突管理

从工程角度，它试图演示：

- Flutter 客户端如何组织复杂业务
- 本地优先架构怎么落到 SQLite
- 同步状态如何进入数据模型
- 一个很轻的 Node 服务端如何为同步提供支撑

### 1.4 它不是一个“安全已完成”的产品

这一点一定要先讲清楚。

这个项目有明显的“原型性”和“教学性”：

- 加密并不是真正的端到端加密
- 服务端保存的是明文可恢复的 base64 JSON
- 身份系统是 mock
- 一些说明文案写的是未来目标，不是现状

所以你应该把它理解成：

“一个非常适合教学和架构学习的原型项目”，而不是“已经可以放心商用的密码管理器”。

---

## 1.5 项目文件结构说明

这一节专门讲“地图”。

很多初学者不是卡在某一行 Flutter 语法，而是卡在：

- 这个仓库到底该先看哪里？
- 哪些目录是核心？
- 哪些目录是 Flutter 自动生成的平台壳？
- `lib/` 下面这么多目录分别负责什么？

所以这里我专门补一份“项目文件结构说明”。

### 1.5.1 仓库顶层结构

根目录可以先理解成：

```text
roy/
  docs/
  roy_client/
  roy_server/
```

这三个目录分别代表：

- `docs/`：仓库级文档，偏总体说明、架构、方案、交付记录
- `roy_client/`：Flutter 客户端，是前端与本地业务核心
- `roy_server/`：Node.js 同步服务，是后端核心

如果你的目标是“先读懂项目代码”，优先级通常是：

1. `roy_client/`
2. `roy_server/`
3. 根目录 `docs/`

### 1.5.2 根目录 `docs/` 是做什么的

根级 `docs/` 不是 Flutter 客户端源码的一部分，而更像仓库的“说明区”。

你会看到类似目录：

- `architecture/`
- `guides/`
- `reports/execution/`
- `security/`
- `sync/`
- `wiki/`

可以把它理解为：

- 架构文档区
- 交付说明区
- 背景资料区

如果你是第一次读代码，这里不是第一优先级；但当你读完源码后，再回来看这些文档，会更容易理解作者想把系统发展成什么样。

---

### 1.5.3 `roy_client/`：Flutter 客户端目录

这是整个项目里最重要的目录。

结构大致可以理解为：

```text
roy_client/
  android/
  ios/
  linux/
  macos/
  web/
  windows/
  lib/
  test/
  docs/
  pubspec.yaml
  pubspec.lock
  README.md
  analysis_options.yaml
```

你可以先记住一句话：

- 真正最重要的是 `lib/`
- 第二重要的是 `test/`
- 各平台目录先知道存在即可，不必第一时间深挖

#### `pubspec.yaml`

这是 Flutter 项目的依赖与配置清单。

它相当于：

- Node.js 里的 `package.json`

它定义了：

- 项目名
- Dart SDK 版本
- 依赖库
- Flutter 配置项

如果你会 Node.js，那么读 Flutter 项目时优先看 `pubspec.yaml` 是完全正确的。

#### `pubspec.lock`

它相当于：

- `package-lock.json`

用于锁定依赖版本。

#### `analysis_options.yaml`

它可以类比为：

- ESLint/TypeScript 静态检查规则配置

#### `README.md`

通常用于写：

- 项目简介
- 本地运行方式
- 开发注意事项

---

### 1.5.4 Flutter 各平台目录为什么会存在

这些目录：

- `android/`
- `ios/`
- `linux/`
- `macos/`
- `windows/`
- `web/`

它们不是你日常要写业务逻辑的地方。

它们更多代表：

- Flutter 在不同平台上的宿主工程
- 构建配置
- 原生启动配置
- 平台权限与打包信息

可以把它们理解成：

- Flutter 业务代码的“原生外壳”

对初学者来说：

- 第一阶段先别把时间花在这些目录
- 除非你正在解决平台启动、权限、打包、原生插件问题

---

### 1.5.5 `roy_client/lib/`：真正的业务核心

这是最重要的目录。

当前大致结构如下：

```text
lib/
  main.dart
  l10n/
  models/
  providers/
  services/
  sync/
  views/
  widgets/
```

下面逐个解释。

#### `main.dart`

作用：

- 应用入口
- 初始化运行时
- 挂载 `MaterialApp`
- 注入 Provider

它相当于：

- `main.ts`
- `index.tsx`

如果你要从一个 Flutter 项目开始读，通常先读 `main.dart`。

#### `l10n/`

作用：

- 国际化资源
- 多语言文案
- 本地化代码生成产物

你会看到：

- `app_en.arb`
- `app_zh.arb`
- 自动生成的 `app_localizations.dart`

这可以类比为：

- `locales/` + i18n 代码生成结果

#### `models/`

作用：

- 定义核心数据模型

例如：

- `account_item.dart`
- `account_template.dart`
- `hlc.dart`

这一层非常重要，因为它决定了：

- 这个系统到底在处理哪些对象
- 每个对象包含哪些业务字段与同步字段

你可以把它理解成：

- TypeScript interface/class
- 领域模型层

#### `providers/`

作用：

- 管理共享状态
- 给页面提供可观察数据

主要包括：

- `enhanced_app_provider.dart`
- `theme_provider.dart`

你可以类比成：

- React Context + store

#### `services/`

作用：

- 放底层服务和门面层

例如：

- `service_manager.dart`
- `secure_storage_service.dart`
- `enhanced_crypto_service.dart`
- `biometric_auth_service.dart`
- `auto_lock_service.dart`
- `identity_service.dart`

这一层可以类比成：

- Node 项目里的 service/repository/runtime 组合层

#### `sync/`

作用：

- 专门承载同步逻辑

例如：

- `sync_service.dart`
- `crdt_merge_engine.dart`

这个目录是本项目区别于普通 CRUD 项目的关键之一。

你可以把它理解成：

- 分布式同步子系统

#### `views/`

作用：

- 页面级组件
- 路由级视图

比如：

- `unlock_view.dart`
- `settings_view.dart`
- `sync_settings_view.dart`
- `security_settings_view.dart`
- `conflict_inbox_view.dart`
- `accounts/`
- `templates/`
- `home/`

可以类比成：

- 页面容器组件目录

#### `widgets/`

作用：

- 通用组件
- 页面级以外的可复用 UI 零件

例如：

- `adaptive_page.dart`
- `platform_builder.dart`
- `account_list_tile.dart`
- `password_generator_sheet.dart`

可以类比成：

- shared components

---

### 1.5.6 `views/` 目录内部怎么理解

`views/` 又按业务继续分组。

可以大致理解为：

```text
views/
  accounts/
  home/
  templates/
  appearance_settings_view.dart
  conflict_inbox_view.dart
  password_tools_view.dart
  release_note_view.dart
  security_settings_view.dart
  settings_view.dart
  sync_settings_view.dart
  unlock_view.dart
```

#### `views/accounts/`

职责：

- 账号列表
- 账号编辑

这里是最适合初学者跟业务链路的地方，因为它包含：

- 展示
- 编辑
- 保存
- 删除

#### `views/home/`

职责：

- 应用主壳
- 搜索主页
- 桌面端/移动端布局拆分

这里很适合学习：

- 同一业务如何适配不同设备布局

#### `views/templates/`

职责：

- 模板列表
- 模板编辑

这里很适合学习：

- 动态表单 schema 如何被创建与维护

#### 单页设置类视图

这些单独页面各自负责一个功能中心：

- `unlock_view.dart`：应用安全入口
- `settings_view.dart`：设置入口页
- `sync_settings_view.dart`：同步配置与诊断
- `security_settings_view.dart`：安全设置
- `appearance_settings_view.dart`：主题设置
- `conflict_inbox_view.dart`：冲突收件箱
- `password_tools_view.dart`：密码工具

---

### 1.5.7 `widgets/` 目录内部怎么理解

这个目录比 `views/` 更偏底层复用。

#### `adaptive_page.dart`

职责：

- 提供页面最大宽度与断点约束

适合学习：

- Flutter 的响应式布局容器

#### `platform_builder.dart`

职责：

- 在移动端和桌面端布局之间切换

适合学习：

- 多端布局分发

#### `account_list_tile.dart`

职责：

- 封装账号卡片展示与交互

它不是纯视觉组件，而是“带业务语义的复用组件”。

#### `password_generator_sheet.dart`

职责：

- 封装密码生成弹层

适合学习：

- 复杂组件如何从页面中独立出来

#### `green_add_button.dart`

职责：

- 统一项目里的浮动添加/确认按钮样式

这是偏视觉复用的组件。

---

### 1.5.8 `roy_client/test/`

这是客户端测试目录。

当前重点测试文件是：

- `test/sync/crdt_merge_engine_test.dart`

这说明当前测试策略更关注：

- 同步合并正确性

而不是大规模的 UI 测试。

从教学角度这是合理的，因为真正高风险的是数据一致性，而不是界面颜色。

---

### 1.5.9 `roy_client/docs/`

客户端自己也有一个 `docs/` 目录。

它和仓库根目录 `docs/` 不一样。

这里更偏：

- 客户端自身的实现说明
- 调查记录
- 开发日志
- 设计草案

你可以把它理解成：

- 客户端子系统的工程文档区

如果你只是先学源码，可以把这里放到第二阶段再读。

---

### 1.5.10 `roy_server/`：Node.js 服务端目录

服务端结构相对简单：

```text
roy_server/
  data/
  test/
  index.js
  package.json
  package-lock.json
```

#### `index.js`

这是服务端入口，也是当前服务端的主实现文件。

和很多正式后端项目不同，它没有拆成：

- controller
- service
- repository

而是集中在一个文件里。

对教学项目来说，这样做的好处是：

- 更容易一眼看懂完整请求流

#### `data/`

职责：

- 保存运行时写出的 vault JSON 文件

它更像：

- 轻量文件型数据库目录

注意它不是源码，而是运行数据。

#### `test/`

职责：

- 服务端测试

重点文件：

- `test/index.test.js`

它主要覆盖：

- path 安全性
- vault 持久化
- push 校验

#### `package.json`

职责：

- 声明服务端依赖
- 提供 `start`、`dev`、`test` 等脚本

它就是服务端的依赖清单与脚本入口。

---

### 1.5.11 初学者第一次应该按什么顺序点目录

如果你第一次打开项目，我建议按这个顺序：

1. `roy_client/pubspec.yaml`
2. `roy_client/lib/main.dart`
3. `roy_client/lib/services/`
4. `roy_client/lib/providers/`
5. `roy_client/lib/models/`
6. `roy_client/lib/views/accounts/`
7. `roy_client/lib/sync/`
8. `roy_server/index.js`

如果你想用一句话记住整个仓库结构，可以这样记：

- `models` 讲系统处理什么数据
- `services` 讲系统靠什么能力运行
- `providers` 讲状态怎么共享
- `views` 讲页面怎么组织
- `widgets` 讲可复用组件
- `sync` 讲这个项目最特别的同步能力
- `roy_server` 讲最小后端如何配合客户端

---

## 2. 先跑起来：理解应用从静态代码到运行时的过程

先跑起来，是理解项目最重要的一步。

### 2.1 先启动服务端

```bash
cd roy_server
npm install
npm start
```

默认监听端口是：

- `8080`

服务端入口文件是：

- `roy_server/index.js`

### 2.2 再启动客户端

```bash
cd roy_client
flutter pub get
flutter run
```

如果你在 Windows 桌面运行，客户端默认同步地址会走：

- `http://127.0.0.1:8080`

这个默认值定义在：

- `roy_client/lib/services/service_manager.dart`

### 2.3 第一次运行时你会看到什么

应用不会直接进首页，而是先进入 `UnlockView`。

原因不是“路由还没配好”，而是这个应用在设计上有一个顶层状态机：

- 未初始化
- 已锁定
- 解锁中
- 已解锁
- 错误

客户端只有进入“已解锁”状态后，才会展示真正的业务页面。

这说明这个项目的第一层导航，不是 URL 导航，而是“应用状态导航”。

---

## 3. Flutter 的最小心智模型：给 Node.js 开发者看的版本

这一章是为了让你后面读源码时不那么别扭。

### 3.1 Flutter 不是 HTML + CSS + JS

在 Web 世界里，你通常分成：

- HTML 负责结构
- CSS 负责样式
- JS 负责逻辑

Flutter 不是这个拆法。

Flutter 更像：

- 用 Dart 直接描述 UI 树
- 组件、布局、样式、事件、状态都在 Dart 中
- Flutter 负责渲染这棵树

所以你看到 Flutter 代码会感觉：

- “为什么 UI 都写在代码里？”
- “为什么一层一层全是 Widget？”

答案就是：Flutter 的核心工作方式就是这样。

### 3.2 Widget 先理解成组件

最重要的一句翻译是：

- `Widget = 组件`

你可以先这样记：

- `MaterialApp` = 应用根组件
- `Scaffold` = 页面骨架
- `Column`/`Row` = flex 布局
- `Text`/`Icon`/`Container` = 基础 UI 组件

### 3.3 StatefulWidget 可以先类比 useState 组件

如果你看到：

- `StatelessWidget`
- `StatefulWidget`

可以先粗暴理解为：

- `StatelessWidget` = 纯展示组件
- `StatefulWidget` = 有本地状态的组件

比如 `HomeView` 维护一个 `_selectedIndex`，它就很像 React 里的：

```js
const [selectedIndex, setSelectedIndex] = useState(1)
```

### 3.4 build 方法就是“当前应该长成什么样”

Flutter 组件常见结构是：

```dart
@override
Widget build(BuildContext context) {
  ...
}
```

你可以把它理解为：

- “根据当前状态，重新计算界面”

它很像 React 组件函数的返回值。

### 3.5 BuildContext 是组件树上下文

Flutter 里会大量出现：

- `Theme.of(context)`
- `Navigator.of(context)`
- `context.watch<T>()`
- `context.read<T>()`

你可以先理解为：

- “当前组件在这棵 UI 树里的上下文入口”

它承担了很多 React 中 Context、Router、Theme access 的角色。

---

## 4. 先建立一张总图：这个应用的架构分层

先看结构，再看细节。

### 4.1 客户端总体分层

可以把 `roy_client` 理解成下面这几层：

```text
View / Widget 层
  -> Provider 状态层
  -> ServiceManager 门面层
  -> 各类 Service（存储、同步、身份、自动锁、生物识别、主题）
  -> SQLite / Secure Storage / HTTP
```

### 4.2 对应目录

- `lib/views/`：页面
- `lib/widgets/`：可复用组件
- `lib/providers/`：业务状态与主题状态
- `lib/services/`：底层服务和门面
- `lib/models/`：数据模型
- `lib/sync/`：同步与冲突合并

### 4.3 一个最重要的调用链

把它记住，后面会一直用到：

```text
用户点击保存
  -> View 收集表单数据
  -> Provider 调用业务动作
  -> ServiceManager 调度
  -> SecureStorageService 写 SQLite
  -> SyncService 标记 dirty 并同步
  -> Node 服务端收 push / 回 pull
  -> 本地 merge
  -> Provider 刷新页面
```

这条链路，就是整个项目的主线。

---

## 5. 模块一：应用入口与根容器

关键文件：

- `roy_client/lib/main.dart`

这一层负责解决的问题是：

- 应用怎么启动
- 根部注入哪些共享对象
- 顶层路由如何决定
- 主题与本地化如何挂进去

### 5.1 `main()` 做了哪些事

`main()` 做了四件关键工作：

1. `WidgetsFlutterBinding.ensureInitialized()`
2. 读取 `SharedPreferences`
3. 初始化 `ServiceManager`
4. `runApp(SecretRoyApp(...))`

这在 Node/前端世界里很像：

1. 先准备运行时
2. 读本地配置
3. 初始化全局服务
4. 启动应用

### 5.2 为什么 `ServiceManager` 要在 `runApp` 之前初始化

因为应用一启动就要知道：

- 当前是不是锁定状态
- 自动锁设置是什么
- 是否需要先显示 `UnlockView`

也就是说，顶层 UI 依赖运行前状态。

这是一种典型的“先初始化运行时，再渲染根界面”的设计。

### 5.3 `SecretRoyApp` 的职责

`SecretRoyApp` 是根 Widget，它主要负责：

- 设置 `MultiProvider`
- 构建 `MaterialApp`
- 注入主题、本地化、路由
- 根据锁定状态切换首页

### 5.4 `MultiProvider` 的设计意义

注入了 3 个核心对象：

- `ServiceManager`
- `EnhancedAppProvider`
- `AppThemeProvider`

这其实就是“应用级依赖注入”。

如果你会 React，可以把它理解为：

- 根部挂多个 Context Provider

但和很多 Web 项目不同，这里注入的不只是“状态”，还包括“服务门面”。

### 5.5 `MaterialApp` 是真正的根壳

这里统一配置了：

- `title`
- 本地化委托
- `supportedLocales`
- `theme`
- `darkTheme`
- `themeMode`
- `home`
- `routes`

也就是说，它既是 UI 根节点，也是“全局运行环境配置中心”。

### 5.6 顶层路由设计

最关键的一段逻辑是：

- 如果 `serviceManager.state == unlocked`，进入 `HomeView`
- 否则进入 `UnlockView`

这个设计体现了本项目的核心思想：

- 业务页面永远建立在“已解锁”的前提上

这比“业务页自己判断是否有权限”更干净。

### 5.7 主题设计

`main.dart` 中除了业务逻辑，还定义了较完整的 light/dark 主题。

这说明项目作者把主题设计放在了根部统一管理，而不是零散写在页面里。

好处：

- 视觉统一
- 页面组件更轻
- 后续主题切换成本低

---

## 6. 模块二：`ServiceManager`，整个客户端的总调度中心

关键文件：

- `roy_client/lib/services/service_manager.dart`

如果你只选一个文件读透，我最推荐先读这个。

### 6.1 这个类的角色是什么

它不是单纯的“某个服务”。

它更像三种角色的组合：

- 服务定位器
- 应用状态机
- 门面层

一句话概括：

- 它把多个底层服务组装起来，对页面和 Provider 提供一个统一入口。

### 6.2 为什么要有这样一个类

如果没有 `ServiceManager`，页面层将不得不直接知道：

- 如何解锁
- 如何操作 SQLite
- 如何连接同步服务
- 如何处理自动锁
- 如何调用生物识别

这会导致 UI 和底层实现强耦合。

而有了 `ServiceManager` 之后，页面只需要知道：

- `unlockWithPassword`
- `saveAccount`
- `deleteAccount`
- `syncNow`

这就是典型的“门面模式”收益。

### 6.3 它内部组合了哪些服务

构造时初始化了这些核心对象：

- `EnhancedCryptoService`
- `BiometricAuthService`
- `AutoLockService`
- `IdentityService`
- `SecureStorageService`
- `SyncService`

可以这样理解它们的职责：

- `EnhancedCryptoService`：主密码相关逻辑
- `BiometricAuthService`：指纹/面容能力接入
- `AutoLockService`：后台锁定逻辑
- `IdentityService`：设备和 vault 身份
- `SecureStorageService`：SQLite 数据库
- `SyncService`：同步引擎

### 6.4 状态机设计

`ServiceManagerState` 有 5 个状态：

- `uninitialized`
- `locked`
- `unlocking`
- `unlocked`
- `error`

这比多个布尔值更清晰，因为它把“应用当前处于什么阶段”变成了显式状态。

### 6.5 初始化流程

`initialize()` 做的事情很少，但意义很大：

- 初始化自动锁服务
- 根据自动锁逻辑决定当前应处于 locked 还是 unlocked

这说明项目作者把“进入应用之前先判断锁状态”当成顶层能力，而不是某个页面自己的判断。

### 6.6 生命周期观察

`setupLifecycleObserver()` 会：

- 注册一个 `WidgetsBindingObserver`
- 监听应用前后台切换
- 当自动锁服务判断需要锁定时，把全局状态切回 `locked`

这是一种很典型的 Flutter 原生应用设计。

Web 前端一般不太会有“应用切后台要锁定”的强场景，但移动/桌面应用里很常见。

### 6.7 解锁链路：项目最重要的流程之一

`unlockWithPassword()` 最终会走 `_completeUnlock()`。

完整流程大致是：

1. 初始化 `IdentityService`
2. 用 `deviceId` 初始化 `SecureStorageService`
3. 用密码初始化主密钥
4. 如果密码不正确，关闭数据库、断开同步，恢复为 `locked`
5. 自动锁服务切换到 unlocked
6. 初始化 `SyncService`
7. 尝试异步连接同步服务器
8. 全局状态切换为 `unlocked`

这个流程的设计很值得学：

- 身份、存储、解锁、同步是串行启动的
- 每一步失败都能让状态回退
- UI 不需要知道这些细节

### 6.8 保存账号链路

`saveAccount(account)` 做的是：

1. 先写本地 SQLite
2. 标记同步 dirty
3. 异步触发一次同步

它不是“直接先调后端，再回写本地”，而是典型的：

- Local-first

这也是本项目最值得学习的架构倾向之一。

### 6.9 为什么 `saveTemplate`、`deleteTemplate` 也走同样模式

因为模板也是同步域的一部分。

也就是说，在作者心里，“模板不是纯前端配置”，而是 vault 数据模型的一部分。

这个设计会让模板能力更一致，但同时也要求同步逻辑考虑模板数据。

### 6.10 这个类的优点

- 页面接口非常简洁
- 状态流清楚
- 多服务组合集中管理
- 解锁、锁定、同步的入口统一

### 6.11 这个类的代价

它有一点“过于中心化”的趋势：

- 权责很多
- 容易变成大总管

对教学来说，这样很易懂；对大型项目来说，未来可能需要继续拆。

---

## 7. 模块三：Provider 状态层

关键文件：

- `roy_client/lib/providers/enhanced_app_provider.dart`
- `roy_client/lib/providers/theme_provider.dart`

这两个 Provider 很适合教学，因为它们分别代表两种常见状态：

- 业务状态
- UI 偏好状态

### 7.1 `EnhancedAppProvider` 的定位

它不是底层 service，也不是页面。

它是一个：

- 面向页面的业务状态聚合器

它维护的状态包括：

- 账号列表
- 自定义模板列表
- 搜索关键字
- 标签筛选
- loading
- 冲突数量

### 7.2 它为什么依赖 `SecureStorageService` 和 `ServiceManager`

构造函数注入了：

- `_storageService`
- `_serviceManager`

这说明它既需要：

- 直接感知数据库变化

也需要：

- 通过门面完成写入、删除、同步动作

这是一种折中设计：

- 读路径偏向存储层
- 写路径偏向门面层

### 7.3 初始化设计

`_init()` 做两件事：

1. 首次加载数据
2. 订阅存储层变更流

这个思路很像：

- store 初始化时先加载一次 state
- 再监听 repository 的变化事件

### 7.4 为什么要监听数据库变化流

`SecureStorageService` 暴露了 `onChange`。

Provider 订阅后，就能在底层数据变化时自动刷新。

这让页面不必自己在每次保存后手动全量重载。

也就是说：

- SQLite 变更 -> Provider 感知 -> `notifyListeners()` -> 页面更新

### 7.5 `accounts` 这个 getter 的意义

Provider 内部保存的是 `_accounts` 原始列表，但对外暴露的 `accounts` 会：

- 根据搜索词过滤
- 根据标签过滤

这代表一种很常见的前端状态设计：

- 原始数据和派生视图分开

### 7.6 新增、修改、删除账号的方法

例如 `addAccount()`：

1. 设置 loading
2. 调用 `ServiceManager.saveAccount`
3. 本地内存列表先更新
4. 通知 UI
5. 关闭 loading

这说明它既做：

- 业务动作分发

也做：

- 前端内存态维护

### 7.7 `syncNow()` 为什么不自己实现

Provider 没有直接写同步逻辑，而是把同步委托给 `ServiceManager`。

这非常合理，因为：

- Provider 应该管页面状态
- 真正的同步编排应该在 service 层

### 7.8 `AppThemeProvider`

`AppThemeProvider` 很简单，但设计很标准。

它负责：

- 读取 `SharedPreferences`
- 维护 `themeMode`
- 维护主色 `colorSeed`
- 维护 `trueBlack`

这是典型的“UI 偏好设置状态”。

它和 `EnhancedAppProvider` 的区别在于：

- 它不管业务数据
- 它只管体验层配置

### 7.9 这一层的教学价值

这两个 Provider 能很好地让初学者理解：

- 什么状态该放在页面本地
- 什么状态该提升到共享层
- 什么状态属于业务
- 什么状态属于界面偏好

---

## 8. 模块四：领域模型层

关键文件：

- `lib/models/account_item.dart`
- `lib/models/account_template.dart`
- `lib/models/hlc.dart`
- `lib/sync/crdt_merge_engine.dart` 中的 `ConflictLog`

这一层解决的问题是：

- 应用里到底有哪些“核心数据对象”
- 每个对象携带哪些业务信息和同步信息

### 8.1 `AccountItem`：主业务实体

它代表一条账号记录。

分成两类字段最好理解。

第一类，业务字段：

- `id`
- `name`
- `email`
- `templateId`
- `data`
- `createdAt`

第二类，同步字段：

- `nameHlc`
- `emailHlc`
- `dataHlc`
- `serverVersion`
- `syncStatus`
- `isDeleted`
- `deleteHlc`

### 8.2 这个模型的设计特点

它不是“单纯的表单数据”。

它是：

- 一条业务记录
- 再加上一套同步元数据

这说明从建模层面开始，作者就把“同步”当成核心领域能力，而不是后补功能。

### 8.3 `SyncStatus`

状态有：

- `synchronized`
- `pendingPush`
- `conflict`

这非常关键，因为它让每条记录本身就知道：

- 自己是否已经同步
- 是否有本地未上推变更
- 是否进入冲突状态

### 8.4 `AccountTemplate`：动态表单模板

这个模型特别适合教学。

它不是简单保存一个“模板名称”，而是完整描述：

- 模板 ID
- 标题、副标题
- 类别
- 字段列表
- 是否为自定义模板

### 8.5 `AccountField` 与 `AccountFieldAttributes`

模板中的每个字段，又继续拆成：

- 字段结构
- 字段属性

属性里包含：

- 字段类型
- 是否主字段
- 是否必填
- 是否保密
- 是否可编辑
- 是否可搜索
- 是否可复制
- 时间格式等

这说明表单渲染不是写死在 UI 里，而是由数据驱动。

### 8.6 为什么这种建模很值得学

因为它让“表单结构”本身也变成可保存、可同步、可编辑的数据。

在 React/Node 世界里，这很像：

- 用 schema 驱动表单
- 用配置决定输入控件行为

### 8.7 `Hlc`

虽然这里没有完整展开所有 HLC 源码，但从使用方式可以知道：

- 每个字段都带一个混合逻辑时钟
- 合并时不是整条记录比时间，而是逐字段比较

这比“最后修改时间覆盖全记录”精细得多。

### 8.8 `ConflictLog`

冲突日志记录：

- 哪个账号
- 哪个字段冲突
- 被覆盖值是什么
- 对应 HLC
- 保存时间

这说明冲突不是“直接吞掉”，而是进入可查看、可恢复的冲突箱。

这是一个很好的产品意识和工程意识结合点。

---

## 9. 模块五：本地存储层 `SecureStorageService`

关键文件：

- `roy_client/lib/services/secure_storage_service.dart`

这是客户端最重要的基础设施之一。

### 9.1 它要解决什么问题

它负责：

- 管理 SQLite 数据库连接
- 建表和升级
- 读写账号
- 读写模板
- 读写设置
- 保存冲突日志
- 发出数据变化事件

如果用 Node.js 类比，它像：

- 一个 repository 层
- 再加一点数据库生命周期管理

### 9.2 为什么桌面和移动端用不同打开方式

代码里有 `_isDesktop` 判断。

在桌面端使用：

- `sqflite_common_ffi`

在移动端使用：

- `sqflite`

这说明 Flutter “一套业务代码多端跑”的前提下，底层数据库接入仍然会有平台差异。

作者把这个差异包在一个 service 里，是对的。

### 9.3 数据库 schema

它建了 4 张核心表：

- `accounts`
- `conflict_logs`
- `templates`
- `settings`

#### `accounts`

职责：

- 保存账号主数据
- 保存字段级时钟
- 保存同步版本和软删除信息

#### `conflict_logs`

职责：

- 保存冲突历史
- 供冲突收件箱页面恢复使用

#### `templates`

职责：

- 保存自定义模板
- 与内置模板一起组成总模板池

#### `settings`

职责：

- 保存同步版本
- 保存上次同步时间
- 保存 dirty 状态
- 保存其他应用配置

### 9.4 为什么 `settings` 表值得注意

很多初学者会忽略这个设计。

同步系统除了主业务数据，还需要很多“元数据”：

- 本地版本号
- 上次同步时间
- 是否有未同步变更

把这些状态单独存在 `settings` 表，是很合理的做法。

### 9.5 `saveAccount()` 的设计

这个方法不是“直接 replace 一条记录”那么简单。

当不是同步合并写入时，它会：

1. 查询旧数据
2. 比较哪些字段真的变了
3. 给变更字段打新的 HLC
4. 把 `syncStatus` 标成 `pendingPush`
5. 保留旧的 `serverVersion`
6. 最后写入数据库

这说明本地保存时就已经在做“同步语义补全”。

### 9.6 软删除设计

`deleteAccount()` 不是物理删除，而是：

- `is_deleted = 1`
- 写入 `delete_hlc`
- 标记 `pendingPush`

这在同步系统里非常关键，因为：

- 其他设备需要知道“它被删了”
- 如果物理删除，远端无法感知删除事件

### 9.7 数据迁移设计

`_onUpgrade()` 中可以看到从旧版本升级到新版本的过程。

例如：

- 为旧数据补 HLC 字段
- 增加 `server_version`
- 增加 `sync_status`
- 创建 `conflict_logs`

这说明同步能力是后来逐步加入的，不是一开始就有。

从教学角度看，这很好，因为你能看到“项目如何从普通 CRUD 演进到带同步元数据的系统”。

### 9.8 变化事件流

`_changeController` 暴露了 `onChange` stream。

每当：

- 保存账号
- 删除账号
- 保存模板
- 删除模板
- 更新 setting

都会发出一个事件。

这就是 Provider 自动刷新的基础。

### 9.9 这一层的优点

- 数据库细节集中
- 事件驱动刷新页面
- 同步元数据与业务数据紧密结合
- schema 设计和业务目标一致

### 9.10 当前限制

虽然名字叫 `SecureStorageService`，但它管理的主体其实是：

- 本地 SQLite 数据库

严格说它不是“完整安全存储服务”，只是带有安全语义的本地存储层。

这个命名有一点“理想先行”的味道。

---

## 10. 模块六：同步系统 `SyncService`

关键文件：

- `roy_client/lib/sync/sync_service.dart`

这是整个项目技术含量最高的一层之一。

### 10.1 它要解决的问题

它负责：

- 管理同步连接状态
- 读取本地同步元数据
- 定时同步
- 手动同步
- pull 远端变化
- push 本地变化
- 处理冲突
- 更新本地同步版本

### 10.2 状态模型

同步状态包括：

- `offline`
- `syncing`
- `synced`
- `error`
- `conflictRecovery`

这说明同步不是一个简单布尔值，而是一个有阶段的过程。

### 10.3 初始化设计

`initialize()` 会从 `settings` 表读取：

- `sync_version_<vaultId>`
- `sync_last_time_<vaultId>`
- `sync_dirty`

这非常合理，因为同步系统必须先恢复自己上次的状态。

### 10.4 `connect()` 的设计

`connect()` 会：

1. 读取同步地址
2. 判断是否已经有身份
3. 设置状态为 `synced`
4. 开启定时器
5. 异步立即发起一次 `syncNow()`

注意这里的“connected”不是 WebSocket 连接，而是：

- 应用认为“同步系统可用了”

这是一种轻连接的设计。

### 10.5 `syncNow()` 是真正入口

它会先做一堆保护性检查：

- 地址有没有配
- 身份有没有建立
- 移动端是不是误用了 `localhost`
- 是否已有同步在进行中

这些检查很值得学，因为同步系统最怕重入和坏配置。

### 10.6 整体同步流程

`_runSyncLoop()` 的主流程是：

1. 进入 syncing
2. pull
3. push
4. 更新最后同步时间
5. 清理 dirty
6. 进入 synced

如果出现冲突：

1. 捕获 `_ConflictException`
2. 执行 `_handleConflict()`
3. 进入 `conflictRecovery`
4. 延迟后重试

### 10.7 为什么先 pull 再 push

这是经典设计。

先 pull 的好处：

- 先拿到服务端最新状态
- 本地 merge 后再决定该 push 什么
- 减少盲推导致的版本冲突

### 10.8 Pull 阶段在做什么

`_runPullPhase()` 会：

1. 请求服务端 `since = 本地版本号`
2. 获取远端变化列表
3. 对每个远端 item 解码为 `AccountItem`
4. 读取本地同 ID 记录
5. 根据本地状态决定：
   - 直接保存
   - 进行 merge
   - 或直接覆盖
6. 全部成功后推进本地版本号

这里最精彩的点在于：

- 本地不是无脑覆盖远端
- 而是基于本地同步状态决定合并策略

### 10.9 Push 阶段在做什么

`_runPushPhase()` 会：

1. 读取所有 `pendingPush` 数据
2. 序列化并“加密签名”
3. 发送到服务端 `/vaults/:vaultId/sync`
4. 如果成功，读取服务端确认的版本号
5. 把本地记录标为 `synchronized`
6. 更新本地 version

### 10.10 当前所谓“加密”的真实情况

这里必须非常明确：

`_encryptAndSign()` 实际上只是：

- `jsonEncode`
- `utf8`
- `base64Encode`

这不是安全加密。

也就是说，当前同步层的“加密”是占位实现。

教学上要学的是：

- 同步协议结构
- 状态推进逻辑
- 合并策略

不是当前这个“加密”本身。

### 10.11 冲突恢复

当服务端返回 `409` 后，客户端会进入冲突恢复流程。

一个特别值得注意的场景是：

- 本地有记录
- 服务端说这条远端记录不存在

代码里用 `record.remote_missing` 这个特殊冲突项来表示这种情况，并把它放入冲突收件箱。

这是一种很实用的产品化设计：

- 不强行自动决策
- 让用户看到并决定是否覆盖远端

### 10.12 同步系统的优点

- 不是简单全量覆盖
- 有 pull/push 分阶段
- 有 dirty 标记
- 有重入保护
- 有冲突恢复
- 有本地版本元数据管理

### 10.13 同步系统的局限

- 没有真正端到端加密
- 没有真正签名校验
- 没有复杂的断网重放队列
- 定时同步较基础
- 某些错误处理仍偏原型阶段

---

## 11. 模块七：字段级合并引擎 `CrdtMergeEngine`

关键文件：

- `roy_client/lib/sync/crdt_merge_engine.dart`

这一层是同步系统的“大脑”。

### 11.1 它解决什么问题

假设两个设备同时修改同一条记录：

- 设备 A 改了 name
- 设备 B 改了 password

如果你用整条记录覆盖，必然丢数据。

这个引擎要解决的是：

- 如何尽量按字段合并
- 如何决定删除优先级
- 如何保留被覆盖值

### 11.2 它不是完整 CRDT 论文实现

从工程上更准确地说，它是：

- 基于 HLC 的字段级 LWW 合并器
- 再加 tombstone 优先级和冲突日志

也就是说：

- 它有 CRDT 风格
- 但你不必把它当成一篇学术级 CRDT 实现

### 11.3 Tombstone 逻辑

“删除”在同步系统里是最难的操作之一。

这里的原则是：

- 删除不是立刻消失
- 删除有自己的 HLC
- 删除可能压过普通字段修改

代码中优先判断：

- 双方都删除
- 只有远端删除
- 只有本地删除

这个顺序很合理，因为删除本质上是记录级状态变更，优先级高于普通字段比较。

### 11.4 字段级合并

在未触发 tombstone 胜出时，会比较：

- `nameHlc`
- `emailHlc`
- `data[key]` 的 HLC

谁的 HLC 更大，谁赢。

但输掉的值不会直接丢弃，而是会写入 `ConflictLog`。

### 11.5 为什么冲突日志很关键

因为“自动合并成功”不等于“用户一定满意”。

例如：

- 远端值赢了
- 但本地用户想保留自己输入的旧值

有了冲突日志，就能在 UI 上提供：

- 查看被覆盖值
- 一键恢复

这大幅提升了系统可解释性。

### 11.6 合并后 `syncStatus` 如何决定

这是非常精彩的一段设计。

它不是简单地“合并后就 synchronized”。

它会判断：

- 是纯 fast-forward
- 还是交错合并
- 本地之前是否已有 pendingPush

最终可能得到：

- `synchronized`
- `pendingPush`
- `conflict`

这意味着合并结果本身也会影响后续同步策略。

### 11.7 这一层的教学价值

它非常适合帮助初学者理解：

- 数据同步不是只有接口请求
- 真正难的是状态与冲突语义
- 领域模型必须携带同步信息

---

## 12. 模块八：解锁与安全子系统

关键文件：

- `lib/views/unlock_view.dart`
- `lib/services/enhanced_crypto_service.dart`
- `lib/services/biometric_auth_service.dart`
- `lib/services/auto_lock_service.dart`
- `lib/services/identity_service.dart`

这一块从产品体验上很关键，从工程上也很有教学价值。

---

### 12.1 `UnlockView`：安全入口 UI

它负责：

- 判断是否首次运行
- 判断是否开启无密码模式
- 判断是否支持并已启用生物识别
- 展示密码输入与解锁入口
- 支持清空本地库

#### 设计亮点

- 首次运行和普通解锁复用同一个页面
- 自动尝试生物识别解锁
- 把“忘记密码 -> 重置本机”作为明确流程

#### 设计含义

页面不是只做静态展示，而是承担“应用启动分流器”的角色。

这也是为什么它会在 `initState()` 里立刻检查：

- 数据库是否存在
- 是否无密码模式
- 生物识别状态

---

### 12.2 `EnhancedCryptoService`：当前是“伪加密服务”

这个类负责：

- 初始化主密码
- 验证主密码
- 生成随机密码
- 计算密码强度

但它的“主密码存储”方式目前是：

- 直接写入 `FlutterSecureStorage`

所以要非常诚实地说：

- 这不是完整的密码学实现
- 它更像原型阶段的 master password gate

#### 可学习点

- 服务边界划分是对的
- 页面不直接碰安全存储
- 密码生成器与强度评估工具被收敛在同一个领域服务中

#### 当前局限

- 没有 KDF
- 没有真实密钥派生
- 没有真实数据加密

---

### 12.3 `BiometricAuthService`

它接入了：

- `local_auth`
- `flutter_secure_storage`

它负责：

- 判断设备是否支持生物识别
- 判断是否已录入
- 开启生物识别解锁
- 生物识别解锁时取回主密码

#### 设计思路

它不是自己做解锁，而是：

1. 通过系统生物识别认证
2. 认证成功后，从安全存储中拿回主密码
3. 再交回 `ServiceManager` 做完整解锁流程

也就是说：

- 生物识别只是获取“解锁凭据”的快捷方式
- 真正的应用解锁仍由统一流程完成

#### 这是好设计吗

从分层来说，是好的。

从安全实现来说，目前仍是原型：

- 因为主密码以明文形式存于安全存储键值中

---

### 12.4 `AutoLockService`

这是一个很适合教学的服务。

它负责：

- 保存自动锁定时长
- 监听应用进入后台
- 记录最后活跃时间
- 在超时后锁定应用

#### 状态

- `unlocked`
- `locked`
- `backgroundTimer`

#### 设计思路

它结合了两种机制：

1. 应用切后台时记时间
2. 启动定时器轮询是否超时

恢复前台时再次判断：

- 如果超时，锁定
- 如果没超时，恢复 unlocked

#### 为什么这种设计适合 Flutter

因为 Flutter 应用是有明显生命周期的：

- resumed
- inactive
- paused
- hidden

这和纯 Web 页面的生命周期复杂度不一样。

---

### 12.5 `IdentityService`

这个类负责：

- 设备 ID
- vault ID
- mock private key
- mock symmetric key

#### 设计意图

从意图上看，作者想表达：

- 每个设备有设备身份
- 每个 vault 有 vault 身份
- 后续可能扩展真实密钥体系

#### 当前实现的真实状态

这层明显还是原型阶段：

- key 是 mock 生成
- `vaultId` getter 直接返回固定常量 `pub_test_global_vault_001`
- 同时内部又有 `_vaultId` 的初始化逻辑

这说明：

- 当前身份系统是半占位状态
- 还没完全演进到真实实现

这也是一个很好的教学点：

- 你可以看到一个系统在“目标架构”和“当前可跑原型”之间的过渡状态

---

## 13. 模块九：账号模块，UI 与业务链路最完整的一块

关键文件：

- `lib/views/accounts/account_list_view.dart`
- `lib/views/accounts/account_edit_view.dart`
- `lib/widgets/account_list_tile.dart`

这是最值得跟的一条用户路径：

- 列表 -> 新增/编辑 -> 保存 -> 同步 -> 回刷页面

---

### 13.1 `AccountListView`

它的职责是：

- 展示账号列表
- 按模板分组
- 执行新增和删除入口
- 展示 Hero 区和统计信息

#### 设计亮点

- 列表不是简单平铺，而是按模板分组
- 页面头部有概览信息
- 模板过滤器做成独立交互组件

#### 为什么这对教学有价值

它能让你看到 Flutter 页面不仅是“摆控件”，而是：

- 页面状态
- 过滤逻辑
- 视图分组
- 导航返回结果

一起组织起来的。

### 13.2 新增账号调用链

这条链一定要记住。

1. 列表页点击 FAB
2. `_openEditor()` 用 `Navigator.push` 打开 `AccountEditView`
3. 编辑页保存时 `Navigator.pop(item)`
4. 列表页拿到 `AccountItem`
5. 调 `provider.addAccount`
6. `ServiceManager.saveAccount`
7. `SecureStorageService.saveAccount`
8. `SyncService.markDirty + syncNow`

这是一条完整的“从 UI 到本地数据再到同步”的黄金路径。

---

### 13.3 `AccountEditView`

这是客户端最复杂的页面之一。

它负责：

- 展示和编辑账号基础信息
- 根据模板动态生成字段
- 管理 legacy fields
- 管理历史冲突恢复
- 集成密码生成器
- 管理时间字段输入

#### 这页为什么复杂

因为它不是“静态表单”。

它同时承担了：

- 动态 schema 表单
- 历史字段兼容
- 冲突日志恢复
- 时间控件特殊交互
- 敏感字段密码生成

#### 模板驱动字段生成

核心思路是：

1. 根据 `templateId` 找到 `AccountTemplate`
2. 为模板字段创建 `TextEditingController`
3. 把 `draftData` 映射到这些字段
4. 保存时再从 controller 回写到 `AccountItem.data`

这就是典型的“schema 驱动表单”。

#### 为什么要保留 `legacy fields`

因为模板是会变的。

如果旧账号里有字段：

- 旧模板定义过
- 新模板不再定义

直接丢弃会导致用户数据悄悄消失。

作者的做法是：

- 这些字段继续保留在记录里
- 在 UI 上以 Historical Fields 展示
- 用户可手动确认是否删除

这是非常成熟的产品设计意识。

#### 模板切换保护

当编辑已有账号且切换模板时，会先弹确认框。

原因是：

- 新模板不会自动把旧字段无损映射过去

这也是很负责任的设计：

- 不假装智能
- 明确告诉用户会发生什么

#### 冲突日志恢复

页面会读取某账号的冲突日志，并允许：

- 把旧值重新填回表单
- 用户确认后保存

这种“先恢复为草稿，再由用户决定是否提交”的模式非常合理。

---

### 13.4 `AccountListTile`

它负责：

- 列表态展示账号摘要
- 展开更多字段
- 隐私字段遮罩/显示
- 复制字段值
- 风险标签展示

#### 设计亮点

它不是一张死卡片，而是一个小型交互单元。

它会根据账号状态展示：

- 冲突标签
- 模板缺失标签
- 历史字段数量

这说明数据模型中的同步语义和模板语义，已经成功进入 UI。

#### 摘要构建逻辑

卡片不会把所有字段都塞在标题下，而是根据：

- 主字段
- email
- 常见可展示字段

生成一条摘要。

这是一种很实用的信息密度控制方式。

---

## 14. 模块十：模板系统，为什么它是这个项目的第二主角

关键文件：

- `lib/views/templates/template_list_view.dart`
- `lib/views/templates/template_edit_view.dart`
- `lib/models/account_template.dart`

账号系统和模板系统是强耦合的。

可以说：

- 模板系统决定了编辑器怎么长
- 账号系统消费模板系统产生的 schema

---

### 14.1 `TemplateListView`

它负责：

- 展示内置模板
- 展示自定义模板
- 显示模板使用次数
- 删除模板
- 打开模板编辑器

#### 设计上的关键点

模板不是“静态常量列表”。

它有两种来源：

- 内置模板
- SQLite 中保存的自定义模板

Provider 会把它们合成 `allTemplates`。

#### 为什么删除模板时要检查 usageCount

因为模板和账号已经发生绑定。

如果某模板还被账号使用，直接删掉会带来数据语义问题。

因此删除前会：

- 先统计使用数
- 若仍被使用，则阻止删除

这体现了数据关系完整性的意识。

---

### 14.2 `TemplateEditView`

这是另一个很值得学习的页面。

它负责：

- 创建/修改模板元信息
- 增删改字段
- 调整字段顺序
- 编辑字段属性
- 预览字段在账号编辑页中的样子

#### 它本质上是“表单编辑器的编辑器”

这层比普通 CRUD 更有意思，因为它不是在编辑业务实体，而是在编辑：

- 未来业务表单的结构

这会自然带你理解“元模型”的概念。

#### 字段 key 设计

它会：

- 从 label 生成标准化 field key
- 自动保证 key 唯一
- 对已持久化字段锁定 key，不允许任意改

这个设计非常好。

原因是：

- `fieldKey` 实际上是数据存储键
- 一旦已有账号记录使用它，随便改会破坏历史数据

这是一条很成熟的 schema 演进原则。

#### 字段属性编辑

字段编辑器里可以设置：

- 类型
- 必填
- 保密
- 可编辑
- 可搜索
- 可复制
- 主字段
- 时间格式

这相当于在做一个小型 DSL。

#### 为什么它有预览区

因为模板的最终消费者是账号编辑器。

如果没有预览，模板作者会很难理解：

- 自己定义出来的字段，实际会如何呈现

所以这里的预览是很合理的 UX 投资。

---

## 15. 模块十一：搜索、首页和冲突箱

关键文件：

- `lib/views/home/home_view.dart`
- `lib/views/home/home_search_view.dart`
- `lib/views/conflict_inbox_view.dart`

这一组文件体现了：

- 业务导航壳
- 搜索与筛选体验
- 冲突处理 UX

---

### 15.1 `HomeView`

它维护一个简单的 `_selectedIndex`，决定显示：

- 账号页
- 首页搜索页
- 设置页

这个设计很像一个轻量壳页面。

### 15.2 `HomeSearchView`

它不是传统意义上的“首页仪表盘”，而更像：

- 搜索中心
- 模板筛选中心
- 冲突提醒入口

#### 设计点 1：SearchController

它用 `SearchController` 管理搜索输入，而不是单纯 TextField。

#### 设计点 2：结果构建

它会综合匹配：

- 账号名
- 邮箱
- 模板名
- `data` 中的字段值

这说明搜索不是对 UI 文本做模糊匹配，而是对领域数据做筛选。

#### 设计点 3：冲突提醒 banner

如果 Provider 中 `conflictCount > 0`，会展示一个显眼 banner 进入冲突箱。

这很关键，因为冲突如果只是埋在设置页，用户很可能根本发现不了。

---

### 15.3 `ConflictInboxView`

这页从产品和架构上都很有价值。

它把冲突从“后台逻辑”提升为“可管理的用户任务”。

#### 它做了什么

- 按账号聚合冲突日志
- 展示当前值与被覆盖值
- 允许忽略
- 允许恢复某个冲突值并重新排队 push

#### 核心思想

同步冲突不一定能完全自动解决。

所以系统提供：

- 自动合并
- 冲突留痕
- 用户介入恢复

这比很多“冲突直接覆盖”的原型要成熟很多。

---

## 16. 模块十二：设置系统与体验层

关键文件：

- `lib/views/settings_view.dart`
- `lib/views/appearance_settings_view.dart`
- `lib/views/security_settings_view.dart`
- `lib/views/sync_settings_view.dart`
- `lib/views/password_tools_view.dart`

设置系统不是单一页面，而是一个入口页 + 多个主题子页。

### 16.1 `SettingsView`

它本身只是设置中心入口。

职责：

- 聚合设置能力
- 导航到具体子页
- 显示自定义模板数量等摘要信息

这种设计很像 Web 后台里的：

- settings index page

### 16.2 `AppearanceSettingsView`

它负责：

- 主题模式
- 主色
- true black

这是典型的“偏好设置页”。

它直接消费 `AppThemeProvider`，而不需要经过复杂门面。

这是合理的，因为：

- 这类状态是纯 UI 偏好
- 不属于核心业务领域

### 16.3 `SecuritySettingsView`

它负责：

- 自动锁定时长
- 生物识别开关

这里的设计很好地体现了“设置页面只是操作入口，实际业务仍由 service 完成”。

比如：

- 开启生物识别时先弹主密码确认
- 最终实际动作还是调用 `ServiceManager.enableBiometric()`

### 16.4 `SyncSettingsView`

这个页面很值得学，因为它把“同步控制”和“技术诊断”结合在了一起。

它不仅能：

- 设置服务器地址
- 点击立即同步

还能展示：

- 当前版本号
- 是否有未同步更改
- 节点 ID
- vault ID
- 上次同步时间

这对教学非常好，因为你不需要猜同步系统在想什么。

#### 这个页面的一个现实意义

很多复杂系统的“可维护性”，其实不是来自代码本身，而是来自：

- 是否有可见诊断信息

这个页面就是很好的例子。

---

## 17. 模块十三：适配与通用 UI 组件

关键文件：

- `lib/widgets/adaptive_page.dart`
- `lib/widgets/platform_builder.dart`
- `lib/views/home/layouts/home_view_desktop.dart`
- `lib/views/home/layouts/home_view_mobile.dart`
- `lib/widgets/password_generator_sheet.dart`
- `lib/widgets/green_add_button.dart`

这一层的意义是：

- 把“跨端差异”和“通用交互”从业务页中抽走

### 17.1 `AdaptivePage`

它解决的是：

- 不同宽度设备上的内容最大宽度限制

这相当于 Web 里的：

- 响应式容器
- 页面最大宽度系统

### 17.2 `PlatformBuilder`

它根据断点决定：

- 走 desktopBuilder
- 还是走 mobileBuilder

这说明这个项目的多端策略不是“一套布局到处挤”，而是：

- 同一业务，不同布局

### 17.3 `HomeViewDesktop` 与 `HomeViewMobile`

这两个文件很适合作为“Flutter 响应式设计”教学示例。

相同点：

- 都消费相同 `selectedIndex`
- 都展示同样的 pages

不同点：

- 桌面端是侧边 Dock
- 移动端是底部导航

这正是良好的跨端设计方式：

- 共享状态和业务
- 分离交互承载形式

### 17.4 `PasswordGeneratorSheet`

这个组件很好地体现了“功能组件独立化”。

它封装了：

- 密码生成
- 选项切换
- 长度控制
- 强度显示
- 复制/应用动作

账号编辑器不需要自己实现这些逻辑，只需调用 bottom sheet。

这就是高内聚组件的价值。

---

## 18. 模块十四：服务端 `roy_server`

关键文件：

- `roy_server/index.js`
- `roy_server/test/index.test.js`

对 Node.js 开发者来说，这是全仓库最容易看懂的一块。

### 18.1 技术栈

当前服务端是：

- Express
- CORS
- 本地文件存储

它没有复杂框架，也没有数据库中间层。

### 18.2 它真正的职责

服务端不负责渲染，不负责业务页面，也不负责复杂 merge。

它只做这几件事：

- 接收同步请求
- 校验输入
- 加载 vault JSON
- 根据版本返回变化
- 校验乐观锁冲突
- 以新版本保存

换句话说，它像一个：

- dumb sync coordinator

### 18.3 数据文件组织

每个 vault 映射到一个 JSON 文件：

- `data/vault_<vaultId>.json`

文件内容包含：

- `currentVersion`
- `items`

每个 item 包含：

- `id`
- `version`
- `encrypted_signed_payload`
- `is_deleted`

### 18.4 `GET /vaults/:vaultId/sync`

功能：

- 按 `since` 返回增量变化

逻辑很直接：

1. 读 vault
2. 如果服务端当前版本 <= since，返回 `304`
3. 否则返回 version 更大的 items

这就是一个很典型的增量拉取接口。

### 18.5 `POST /vaults/:vaultId/sync`

功能：

- 接收客户端推送的一批变更

逻辑分两段：

第一段，校验：

- `pushes` 是否合法数组
- item id 是否安全
- `expected_base_version` 是否合法
- payload 大小是否合理
- 是否存在重复 id

第二段，提交：

- 检查每个 push 的 `expected_base_version` 是否等于服务器现有版本
- 如不等，直接返回 `409 Conflict`
- 如都等，按顺序为每个 item 递增版本号并写入

### 18.6 为什么服务端不做复杂 merge

因为当前设计把复杂合并下放到了客户端。

这背后有一个思路：

- 服务端只负责版本秩序
- 客户端负责领域级语义合并

这对原型来说很轻量，也和 local-first 架构一致。

### 18.7 `writeJsonAtomically`

这个函数非常值得学。

它的流程是：

1. 写临时文件
2. 备份旧文件
3. 把临时文件 rename 成正式文件
4. 成功后删除备份
5. 出错时尽可能恢复旧文件

这是一种经典的原子写入策略。

对于文件型服务端来说，这是非常重要的健壮性措施。

### 18.8 当前服务端局限

- 没有数据库
- 没有身份认证
- 没有真实签名验证
- 没有真实加密感知
- 没有租户隔离强保证

但它非常适合作为教学和原型同步服务。

---

## 19. 模块十五：测试体系

关键文件：

- `roy_client/test/sync/crdt_merge_engine_test.dart`
- `roy_server/test/index.test.js`

虽然测试规模不大，但选点很有代表性。

### 19.1 客户端测试：为什么测 merge

客户端测试重点不在 UI，而在：

- `CrdtMergeEngine`

这说明作者认为真正高风险的是：

- 并发编辑
- 删除与修改冲突
- 字段级合并

这和实际情况是匹配的。

因为同步系统里最容易出严重 bug 的，往往不是按钮没变色，而是：

- 数据被错误合并

### 19.2 服务端测试：为什么测 path 和 push 校验

服务端测试重点验证：

- unsafe vault id 拦截
- save/load 正常
- pushes 校验逻辑

这也是合理的，因为当前服务端的复杂度主要在：

- 输入校验
- 文件读写正确性

### 19.3 这个测试体系的启发

一个原型项目不一定要有超多测试，但应该优先覆盖：

- 最危险的逻辑
- 最可能造成数据损坏的逻辑

这里的选择基本是对的。

---

## 20. 从架构角度评价这个项目：哪些设计值得学

这一章不讲“它能干什么”，只讲“它为什么是个好教学项目”。

### 20.1 值得学的设计

#### 1. 顶层状态机清晰

解锁、锁定、解锁中、错误等状态不是散的，而是统一表达。

#### 2. UI、状态、服务、存储分层明确

页面不直接碰数据库和同步细节，这一点非常重要。

#### 3. Local-first 思路清楚

先写本地，再同步，而不是强依赖网络。

#### 4. 模板驱动表单设计成熟

字段结构由数据描述，不是靠 if/else 硬编码。

#### 5. 冲突不是黑盒

冲突有日志、有 inbox、有恢复入口。

#### 6. 多端适配不是“缩放 UI”，而是分布局

桌面和移动交互布局被明确区分。

### 20.2 当前技术债与原型特征

#### 1. 安全实现是占位级

- 主密码存储方式不是真正密码学方案
- 同步 payload 只是 base64

#### 2. 身份体系未完成

- `IdentityService` 仍有明显 mock 痕迹

#### 3. `ServiceManager` 略偏大

未来如果功能继续长，会成为进一步拆分目标。

#### 4. 客户端某些“技术说明文字”比真实实现超前

比如同步页里对安全能力的描述，更像未来目标。

#### 5. 模板同步与账号同步边界还可继续抽象

当前更多以账号记录为中心，模板同步建模还可以更完整。

---

## 21. 如果你要继续学，推荐按这个顺序重读源码

第一次阅读建议顺序：

1. `roy_server/index.js`
2. `roy_client/lib/main.dart`
3. `roy_client/lib/services/service_manager.dart`
4. `roy_client/lib/providers/enhanced_app_provider.dart`
5. `roy_client/lib/services/secure_storage_service.dart`
6. `roy_client/lib/sync/sync_service.dart`
7. `roy_client/lib/sync/crdt_merge_engine.dart`
8. `roy_client/lib/views/accounts/account_list_view.dart`
9. `roy_client/lib/views/accounts/account_edit_view.dart`
10. `roy_client/lib/views/templates/template_edit_view.dart`
11. `roy_client/lib/views/unlock_view.dart`
12. `roy_client/lib/views/conflict_inbox_view.dart`

这个顺序的好处是：

- 先抓主干
- 再抓数据
- 最后再抓复杂页面

---

## 22. 适合把这个项目当教学项目做的练习

下面这些练习都很值得做。

### 练习 1：给网站模板新增一个字段

目标：

- 给 `web_account` 增加“二步验证说明”

你会学到：

- 模板如何驱动账号编辑器
- `AccountTemplate` 和 `AccountEditView` 如何配合

### 练习 2：给账号列表加一个“未同步”提示

目标：

- 当 `syncStatus == pendingPush` 时，在 `AccountListTile` 增加提示

你会学到：

- 领域状态如何进入 UI 呈现

### 练习 3：让同步页显示更细的错误分类

目标：

- 区分离线、冲突、配置错误、HTTP 错误

你会学到：

- `SyncResult`
- `SyncState`
- 错误传播与 UI 反馈

### 练习 4：为服务端加一个 `/debug/vaults` 调试接口

目标：

- 仅开发环境展示当前 vault 列表和版本

你会学到：

- 服务端文件组织
- 如何观察同步过程

### 练习 5：把“伪加密”替换成真正加密方案的设计稿

目标：

- 不一定立刻实现，但先写设计

你会学到：

- 从原型到真实产品，中间缺了哪些关键能力

---

## 23. 作为初学者，你现在最该抓住什么

你现在不需要一口气掌握所有 Flutter API。

你真正应该抓住的是这 6 件事：

1. `main.dart` 如何启动应用
2. `ServiceManager` 如何串起各服务
3. Provider 如何把数据送到页面
4. SQLite 如何保存账号和同步元数据
5. 同步系统如何 pull、push、merge
6. 模板如何驱动动态表单

如果你把这 6 件事吃透，这个项目就已经不再是“一个陌生 Flutter 仓库”，而会变成：

- 一个你能讲清楚结构
- 能独立定位问题
- 能自己改小功能

的学习项目。

---

## 24. 最后给你的学习建议

如果你是懂 Node.js 但刚接触 Flutter，我建议你这样学：

第一阶段：

- 不纠结 Flutter 语法细节
- 先把系统结构走通

第二阶段：

- 跟一条完整业务链
- 推荐“新增账号 -> 同步 -> 冲突处理”

第三阶段：

- 自己改一个小功能
- 再回来看哪些类该拆、哪些能力还是原型

真正的学习不是“把教程看完”，而是：

- 你能不能把某个模块讲给别人听
- 你能不能自己改动一小块并且不破坏整体

当你做到这两点时，这个项目就真的成了你的教学项目。
