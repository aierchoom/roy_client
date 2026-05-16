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
[tool] Glob
[tool_result] success
[tool] Glob
[tool_result] success
[tool] Glob
[tool_result] success
[tool] Glob
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
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool_result] success
[tool] Grep
[tool] Grep
[tool_result] success
[tool] Grep
[tool_result] success
[tool] Grep
[tool_result] success
[tool_result] success
[tool] Grep
[tool_result] success
[tool] Grep
[tool_result] success
# SecretRoy 基础设施速查手册

> 扫描范围：`lib/core/`、`lib/theme/`、`lib/utils/`、`lib/system/`、`lib/providers/`、`lib/l10n/`、`lib/main.dart`

---

## 一、基础设施总览

| 目录 | 文件数 | 核心职责 |
|------|--------|----------|
| `lib/core/` | 2 | 最底层共享工具：日志、密码学随机数 |
| `lib/theme/` | 4 | 设计Token、跨平台排版、三档布局断点、主题Barrel |
| `lib/utils/` | 4 | 字段预设、模板图标、相对时间格式化、文本高亮 |
| `lib/system/` | 10 | ServiceManager拆分出的协调器（解锁、同步、导入导出、配对、数据仓库等） |
| `lib/providers/` | 3 | ChangeNotifier状态层（业务数据、通知、主题） |
| `lib/l10n/` | 4 | ARB生成的本地化类 + 双语辅助扩展 |
| `lib/main.dart` | 1 | 应用入口、全局Provider注入、动态主题构建 |

---

## 二、核心类/工具清单

### 2.1 `lib/core/`
| 类 | 职责 |
|----|------|
| `AppLogger` | 轻量日志。`d()`/`w()`仅在debug模式输出；`e()`在release也输出，用于同步失败、数据损坏等关键问题 |
| `CryptoRandom` | 全局密码学随机字节生成器，所有服务应复用而非自建 `_randomBytes` |

### 2.2 `lib/theme/`
| 类 | 职责 |
|----|------|
| `AppBrandColors` | 品牌种子色 + 11个预设调色板 |
| `AppRadii` | 圆角Token：`chip`(6)、`sm`(8)、`control`(10)、`button/card`(12)、`panel`(16)、`dialog/sheet/nav`(20)、`xl`(24)、`xxl`(28)、`pill`(999) |
| `AppSpacing` | 间距Token：4~24共11档 |
| `AppSurfaces` | 按亮/暗模式计算背景色、输入框色、卡片色；`soft()`提供柔和混合 |
| `AppAlphas` | 透明度Token：18(tint)~232(surface)共12档 |
| `AppBorders` | 语义化边框辅助：`subtle`/`medium`/`strong`/`primary`/`tint` |
| `AppShadows` | 阴影系统：`low()`/`card()`/`hero()`；仅在浅色模式生效 |
| `AppVisualTokens` | `ThemeExtension`，扩展 success/warning/info 语义色及其容器色 |
| `AppLayoutType` | 三档枚举：`compact`(<720px)、`medium`(720~1080px)、`expanded`(>1080px) |
| `AppLayoutData` | 当前布局快照：类型、屏宽、内容最大宽度、水平内边距、是否触摸设备 |
| `AppLayout` | 布局工具类：`of(context)`返回快照；`typeOf`/`isCompact`/`isExpanded`等静态方法 |
| `AppTextDensity` | 两档文本密度：`compact`(<720px)、`comfortable`(>=720px) |
| `AppTextStyles` | 跨平台排版系统。按密度生成完整Material3 TextTheme；额外提供 `heroTitle`/`heroSubtitle`/`chipLabel`/`metricValue`/`caption` |

### 2.3 `lib/utils/`
| 类/工具 | 职责 |
|---------|------|
| `FieldPreset` / `kFieldPresets` | 10组内置字段预设（安全笔记、助记词、API Key、银行卡、身份证、WiFi、服务器、社交媒体、软件授权） |
| `generateUniqueFieldKey` | 基于现有key集合生成唯一fieldKey |
| `instantiatePresetFields` | 复制preset字段并分配唯一key |
| `RelativeTimeFormatter` | 相对时间格式化（刚刚、N分钟前、今天、昨天、周内、年内、跨年），支持zh/en格式差异 |
| `kTemplateIconOptions` | 57个模板可选图标（Material outlined） |
| `templateIconFromStorageValue` | 从codePoint反查IconData（仅匹配预设列表，未知则null） |
| `templateIconStorageValue` | IconData → codePoint |
| `templateBadgeText` | 根据标题生成两字缩写badge |
| `iconForBuiltinTemplate` | 内置模板默认图标映射 |
| `highlightNumbers` | 将文本中的数字高亮为指定颜色 |

### 2.4 `lib/system/service_manager/`
> 所有协调器遵循同一设计目标：将 `ServiceManager` 的职责拆分到 `lib/system/`，保持 facade 只做状态管理与通知。

| 类 | 职责 |
|----|------|
| `VaultUnlockCoordinator` | 解锁/锁定/登出、无密码模式、主密码修改、生物识别启停 |
| `VaultDataRepository` | Account/Template/TOTP的持久化 + 同步变更箱记录（create/update/delete/togglePin） |
| `SyncCoordinator` | 封装 `SyncService` 的连接/断开/同步拉取 + 服务器URL读写 |
| `SyncServerUrlStore` | 基于 `SharedPreferences` 的同步服务器URL持久化，支持vault级隔离与legacy迁移 |
| `VaultDumpCoordinator` | 加密导出（备份包）与验证导入；区分备份包和配对转存的生命周期 |
| `VaultImportExportCoordinator` | 备份包、安全链接码、导入预览与执行的统一协调 |
| `VaultPairingCoordinator` | Vault配对（服务器中继）与LAN配对（直连）完整流程 |
| `ServiceManagerPasswordTools` | 密码生成与强度计算 facade（代理到 `EnhancedCryptoService`） |
| `defaultSyncServerUrlForCurrentPlatform` | 桌面默认 `http://127.0.0.1:8080`，移动端/Web为空 |

### 2.5 `lib/providers/`
| 类 | 职责 | 依赖 |
|----|------|------|
| `EnhancedAppProvider` | 业务数据持有者：accounts、templates、totp、syncChanges、conflictLogs、搜索/标签过滤 | `SecureStorageService`, `ServiceManager` |
| `NotificationProvider` | 通知中心状态：加载、已读/未读、删除、密码过期阈值、推送开关 | `SecureStorageService`, `NotificationService` |
| `AppThemeProvider` | 主题状态：`ThemeMode`、种子色、`trueBlack`；持久化到SharedPreferences | `SharedPreferences` |

---

## 三、主题系统详细说明

### 3.1 设计Token体系

```
AppBrandColors (种子色) ──┬──> ColorScheme.fromSeed ──> Material3 ColorScheme
                        │
AppRadii     (圆角)     ├──> CardTheme / DialogTheme / InputDecorationTheme ...
AppSpacing   (间距)     ├──> Padding / contentPadding
AppAlphas    (透明度)   ├──> withAlpha() 统一入口
AppBorders   (边框)     ├──> BorderSide
AppShadows   (阴影)     ├──> BoxShadow
AppSurfaces  (表面色)   ├──> scaffoldBackgroundColor / cardColor / fillColor
AppVisualTokens(语义色) ├──> ThemeExtension<AppVisualTokens>
```

### 3.2 布局断点（AppLayout）

| 档位 | 宽度阈值 | 内容最大宽度 | 水平内边距 | 设备类型 |
|------|----------|--------------|------------|----------|
| `compact` | < 720 | ∞ | 16 | 触摸优先 |
| `medium` | 720~1080 | 820 | 24 | 混合 |
| `expanded` | > 1080 | 1080 | 32 | 指针优先 |

使用方式：
```dart
final layout = AppLayout.of(context);
if (layout.isExpanded) { ... }

// 或直接用静态方法
AppLayout.isCompact(context);
```

遗留兼容：`AppLayout.isTablet` / `AppLayout.isDesktop` 仍保留，但 `AppBreakpoints.isDesktop` 已被标记为 legacy。

### 3.3 排版系统（AppTextStyles）

- **自动密度切换**：以 720px 为界，`compact` 用更小字号与更紧凑行高，`comfortable` 更宽松。
- **中文字体优化**：所有行高 1.3~1.6，避免过紧；`letterSpacing: 0`、`leadingDistribution: even`。
- **字体栈**：`GoogleFonts.notoSansScTextTheme(baseTextTheme)` 包裹生成的 TextTheme。

使用方式：
```dart
// 获取完整 TextTheme
final textTheme = AppTextStyles.theme(context);

// 获取单个语义样式
AppTextStyles.titleMedium(context);
AppTextStyles.heroTitle(context);
AppTextStyles.metricValue(context);
```

### 3.4 动态主题构建（main.dart）

`SecretRoyApp` 根据 `AppThemeProvider` 的状态在 `build` 中实时构建 `ThemeData`：

1. **Light Theme**: `ColorScheme.fromSeed` + `AppSurfaces.lightBackground` + `AppVisualTokens.fromBrightness(light)`
2. **Dark Theme**: 对蓝种子色自动提升饱和度（避免暗色发灰）+ `AppSurfaces.darkBackground/darkCard/darkInput` + `trueBlack` 支持纯黑背景
3. **共享配置**: `PageTransitionsTheme`（Android/Windows用Zoom，iOS用Cupertino）、各类按钮/卡片/输入框/导航栏主题

---

## 四、状态管理拓扑图

```
┌─────────────────────────────────────────────────────────────┐
│                        main.dart                              │
│  MultiProvider                                                │
│    ├── ChangeNotifierProvider.value(ServiceManager.instance) │
│    ├── ChangeNotifierProvider(EnhancedAppProvider)           │
│    ├── ChangeNotifierProvider(NotificationProvider)          │
│    └── ChangeNotifierProvider(AppThemeProvider)              │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐   ┌─────────────────┐   ┌─────────────────┐
│ ServiceManager│   │EnhancedAppProvider│  │AppThemeProvider │
│ (全局单例)     │   │ (业务数据层)      │   │ (主题状态)       │
│ ChangeNotifier│   │ ChangeNotifier   │   │ ChangeNotifier  │
└───────────────┘   └─────────────────┘   └─────────────────┘
        │                     │
        │    ┌────────────────┘
        │    │
        ▼    ▼
  ┌──────────────┐         ┌──────────────────┐
  │ VaultUnlock  │         │ SecureStorage    │
  │ Coordinator  │         │ Service          │
  │ (解锁/锁定)   │         │ (数据持久化)      │
  └──────────────┘         └──────────────────┘
        │
        ├──> VaultDataRepository (数据操作)
        ├──> SyncCoordinator (同步控制)
        ├──> VaultImportExportCoordinator (导入导出)
        ├──> VaultPairingCoordinator (设备配对)
        └──> VaultDumpCoordinator (备份包)

EnhancedAppProvider 数据流：
1. 构造函数 -> _init() -> _loadData()
2. 监听 _storageService.onChange -> _loadData()
3. 监听 _serviceManager (解锁时refresh；锁定时清空数据)
4. 所有写操作（add/update/delete）先调ServiceManager，再本地更新列表并notify
```

### 关键数据流向

- **解锁**: `VaultUnlockCoordinator.initializeAndUnlock()` → `ServiceManager` 状态变为 `unlocked` → `EnhancedAppProvider` 收到监听 → `refresh()` 加载全部数据
- **锁定/登出**: `lock()` / `logout()` → `ServiceManager` 状态变为 `locked` → Provider 清空内存数据
- **数据变更**: 用户操作 → `ServiceManager` / `VaultDataRepository` → `SecureStorageService` 触发 `onChange` → `EnhancedAppProvider` 自动重新加载
- **主题变更**: 用户设置 → `AppThemeProvider` notify → `Consumer2` 重建 `MaterialApp` → 新 ThemeData 生效

---

## 五、国际化配置

### 5.1 支持Locale
| 语言 | 代码 | 模板文件 | 说明 |
|------|------|----------|------|
| 中文 | `zh` | `lib/l10n/app_zh.arb` | 默认模板语言 |
| 英文 | `en` | `lib/l10n/app_en.arb` | 英文翻译 |

`MaterialApp` 中强制固定 `locale: const Locale('zh')`，但 `supportedLocales` 包含 `zh` 和 `en`。

### 5.2 关键API

```dart
// 标准用法
final l10n = AppLocalizations.of(context)!;
l10n.tabAccounts;
l10n.fillRequiredField('用户名');

// 双语辅助扩展（非ARB，用于少量硬编码双语场景）
extension AppTextExtension on BuildContext {
  String text(String zh, String en) => ...;
}
context.text('中文', 'English');
```

### 5.3 生成文件
- `app_localizations.dart` — 抽象基类 + Delegate
- `app_localizations_zh.dart` — 中文实现
- `app_localizations_en.dart` — 英文实现
- `app_text_extension.dart` — 辅助扩展

---

## 六、启动流程说明（main.dart）

```dart
void main() async {
  // 1. 确保Flutter绑定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 加载SharedPreferences（主题Provider需要）
  final prefs = await SharedPreferences.getInstance();

  // 3. 初始化ServiceManager全局单例（检测数据库存在、准备服务）
  await ServiceManager.instance.initialize();

  // 4. 初始化本地通知服务
  final notificationService = NotificationService(ServiceManager.instance.storageService);
  await notificationService.init();

  // 5. 启动应用
  runApp(SecretRoyApp(prefs: prefs, notificationService: notificationService));
}
```

`SecretRoyApp` 状态生命周期：
1. `initState()` → `_serviceManager.setupLifecycleObserver()`（监听App前后台，自动锁）
2. `build()` → `MultiProvider` 注入4个Provider
3. `Consumer2<ServiceManager, AppThemeProvider>` 重建：
   - 根据 `themeMode` / `colorSeed` / `trueBlack` 构建 Light/Dark `ThemeData`
   - 根据 `ServiceManager.state` 决定首页：`unlocked` → `HomeView`，否则 → `UnlockView`
4. `dispose()` → `_serviceManager.disposeLifecycleObserver()`

---

## 七、样式债务标记

> 根据 `tool/check_style_tokens.py` 扫描规则（CI红线）：
> - 禁止 `BorderRadius.circular(<数字>)`（应使用 `AppRadii.*`）
> - 禁止 `.withAlpha(<数字>)`（应使用 `AppAlphas.*`）
> - 禁止 `AppBreakpoints.isDesktop`（legacy，应使用 `AppLayout`）
> - `lib/theme/` 和 `lib/widgets/` 被排除

### 7.1 硬编码 `BorderRadius.circular`（违规）

| 位置 | 代码 | 建议 |
|------|------|------|
| `widgets/account_list_tile.dart:550` | `BorderRadius.circular(1)` | 替换为 `BorderRadius.zero` 或定义语义Token |
| `widgets/account_list_tile.dart:961` | `BorderRadius.circular(7)` | 使用 `AppRadii.control`(10) 或新增 `AppRadii.sm2`(6) |
| `widgets/inbox/inbox_action_card.dart:212` | `BorderRadius.circular(size > 36 ? 12 : 10)` | 提取为条件变量或统一为 `AppRadii.button`(12) / `AppRadii.control`(10) |

### 7.2 遗留 `AppBreakpoints.isDesktop`（违规）

| 位置 | 代码 |
|------|------|
| `views/accounts/account_edit_view.dart:2537` | `final isDesktop = AppBreakpoints.isDesktop(context);` |

应替换为 `AppLayout.isExpanded(context)` 或 `AppLayout.of(context).isExpanded`。

### 7.3 硬编码 `.withAlpha`（在 `lib/views/` 和 `lib/main.dart` 中）

以下文件包含大量**非 `AppAlphas.*` 的硬编码 `withAlpha`**（`lib/theme/` 和 `lib/widgets/` 已被排除在CI扫描外）：

- `lib/main.dart` — `withAlpha(120)`（light divider）、`withAlpha(110)`（dark divider）
- `lib/views/accounts/account_edit_view.dart` — 大量 `withAlpha(42)`、`withAlpha(24)`、`withAlpha(18)`、`withAlpha(38)`、`withAlpha(34)`、`withAlpha(88)`、`withAlpha(90)`、`withAlpha(92)`、`withAlpha(72)`、`withAlpha(44)`、`withAlpha(60)`、`withAlpha(70)`、`withAlpha(230)`、`withAlpha(214)`、`withAlpha(236)`、`withAlpha(232)`、`withAlpha(120)`、`withAlpha(180)`、`withAlpha(160)`、`withAlpha(190)`、`withAlpha(255)`、`withAlpha(100)`、`withAlpha(70)`、`withAlpha(16)`、`withAlpha(20)`、`withAlpha(30)`、`withAlpha(50)`、`withAlpha(0)`、`withAlpha(12)`、`withAlpha(14)`、`withAlpha(15)` 等
- `lib/views/accounts/account_list_view.dart` — `withAlpha(60)`、`withAlpha(150)`、`withAlpha(180)`、`withAlpha(100)`、`withAlpha(30)`、`withAlpha(50)`、`withAlpha(0)`、`withAlpha(180)`、`withAlpha(200)`、`withAlpha(32)`、`withAlpha(48)` 等
- `lib/views/accounts/account_subset_view.dart` — `withAlpha(18)`、`withAlpha(168)`、`withAlpha(230)` 等
- `lib/views/templates/template_edit_view.dart` — `withAlpha(42)`、`withAlpha(22)`、`withAlpha(16)`、`withAlpha(36)`、`withAlpha(34)`、`withAlpha(44)`、`withAlpha(90)`、`withAlpha(255)`、`withAlpha(100)`、`withAlpha(70)` 等
- `lib/views/templates/template_list_view.dart` — `withAlpha(10)`、`withAlpha(30)`、`withAlpha(34)`、`withAlpha(18)`、`withAlpha(14)`、`withAlpha(255)`、`withAlpha(100)`、`withAlpha(70)` 等
- `lib/views/sync_settings_view.dart` — `withAlpha(16)`、`withAlpha(20)`、`withAlpha(70)`、`withAlpha(95)`、`withAlpha(110)`、`withAlpha(140)` 等
- `lib/views/conflict_inbox_view.dart`、`password_tools_view.dart`、`security_settings_view.dart`、`unlock_view.dart`、`home_search_view.dart`、`notification_center_view.dart`、`release_note_view.dart`、`local_sync_queue_view.dart`、`notification_settings_view.dart`、`totp_credential_edit_view.dart`、`totp_qr_scanner_view.dart` 等也散布硬编码

> **结论**：`lib/views/` 目录是样式Token违规的**重灾区**。建议批量引入 `AppAlphas` 中缺失的中间档位（如 14、16、20、22、30、34、36、38、42、44、50、70、72、88、90、92、95、100、110、140、150、160、168、180、190、200、214、230、236）或允许视图层按语义场景使用少量硬编码。

---

## 八、TODO清单

在本次扫描的基础设施层文件中，**未发现任何工程性 `TODO` / `FIXME` / `HACK` / `XXX` 注释**。代码维护状态良好。

---

## 九、速查速用

### 常用主题API
```dart
// 布局
final layout = AppLayout.of(context);
layout.isExpanded ? 1080 : 820;

// 文本
AppTextStyles.titleMedium(context);
AppTextStyles.heroTitle(context);

// Token
AppRadii.card, AppRadii.button, AppRadii.panel
AppSpacing.md, AppSpacing.lg
AppAlphas.tint, AppAlphas.low, AppAlphas.medium
AppSurfaces.lightBackground(colorScheme)
AppShadows.card(theme, depth: 1.0)
```

### 常用状态API
```dart
// 读取业务数据
context.watch<EnhancedAppProvider>().accounts;
context.watch<EnhancedAppProvider>().syncState;

// 主题
context.watch<AppThemeProvider>().themeMode;
context.read<AppThemeProvider>().setColorSeed(seed);

// 本地化
AppLocalizations.of(context)!.tabAccounts;
```

### 启动顺序记忆
```
ensureInitialized → SharedPreferences → ServiceManager.initialize
→ NotificationService.init → runApp → setupLifecycleObserver
→ MultiProvider → Consumer2重建Theme + 路由决策
```[stage] run_soul_finished

[summary]
# SecretRoy 基础设施速查手册

> 扫描范围：`lib/core/`、`lib/theme/`、`lib/utils/`、`lib/system/`、`lib/providers/`、`lib/l10n/`、`lib/main.dart`

---

## 一、基础设施总览

| 目录 | 文件数 | 核心职责 |
|------|--------|----------|
| `lib/core/` | 2 | 最底层共享工具：日志、密码学随机数 |
| `lib/theme/` | 4 | 设计Token、跨平台排版、三档布局断点、主题Barrel |
| `lib/utils/` | 4 | 字段预设、模板图标、相对时间格式化、文本高亮 |
| `lib/system/` | 10 | ServiceManager拆分出的协调器（解锁、同步、导入导出、配对、数据仓库等） |
| `lib/providers/` | 3 | ChangeNotifier状态层（业务数据、通知、主题） |
| `lib/l10n/` | 4 | ARB生成的本地化类 + 双语辅助扩展 |
| `lib/main.dart` | 1 | 应用入口、全局Provider注入、动态主题构建 |

---

## 二、核心类/工具清单

### 2.1 `lib/core/`
| 类 | 职责 |
|----|------|
| `AppLogger` | 轻量日志。`d()`/`w()`仅在debug模式输出；`e()`在release也输出，用于同步失败、数据损坏等关键问题 |
| `CryptoRandom` | 全局密码学随机字节生成器，所有服务应复用而非自建 `_randomBytes` |

### 2.2 `lib/theme/`
| 类 | 职责 |
|----|------|
| `AppBrandColors` | 品牌种子色 + 11个预设调色板 |
| `AppRadii` | 圆角Token：`chip`(6)、`sm`(8)、`control`(10)、`button/card`(12)、`panel`(16)、`dialog/sheet/nav`(20)、`xl`(24)、`xxl`(28)、`pill`(999) |
| `AppSpacing` | 间距Token：4~24共11档 |
| `AppSurfaces` | 按亮/暗模式计算背景色、输入框色、卡片色；`soft()`提供柔和混合 |
| `AppAlphas` | 透明度Token：18(tint)~232(surface)共12档 |
| `AppBorders` | 语义化边框辅助：`subtle`/`medium`/`strong`/`primary`/`tint` |
| `AppShadows` | 阴影系统：`low()`/`card()`/`hero()`；仅在浅色模式生效 |
| `AppVisualTokens` | `ThemeExtension`，扩展 success/warning/info 语义色及其容器色 |
| `AppLayoutType` | 三档枚举：`compact`(<720px)、`medium`(720~1080px)、`expanded`(>1080px) |
| `AppLayoutData` | 当前布局快照：类型、屏宽、内容最大宽度、水平内边距、是否触摸设备 |
| `AppLayout` | 布局工具类：`of(context)`返回快照；`typeOf`/`isCompact`/`isExpanded`等静态方法 |
| `AppTextDensity` | 两档文本密度：`compact`(<720px)、`comfortable`(>=720px) |
| `AppTextStyles` | 跨平台排版系统。按密度生成完整Material3 TextTheme；额外提供 `heroTitle`/`heroSubtitle`/`chipLabel`/`metricValue`/`caption` |

### 2.3 `lib/utils/`
| 类/工具 | 职责 |
|---------|------|
| `FieldPreset` / `kFieldPresets` | 10组内置字段预设（安全笔记、助记词、API Key、银行卡、身份证、WiFi、服务器、社交媒体、软件授权） |
| `generateUniqueFieldKey` | 基于现有key集合生成唯一fieldKey |
| `instantiatePresetFields` | 复制preset字段并分配唯一key |
| `RelativeTimeFormatter` | 相对时间格式化（刚刚、N分钟前、今天、昨天、周内、年内、跨年），支持zh/en格式差异 |
| `kTemplateIconOptions` | 57个模板可选图标（Material outlined） |
| `templateIconFromStorageValue` | 从codePoint反查IconData（仅匹配预设列表，未知则null） |
| `templateIconStorageValue` | IconData → codePoint |
| `templateBadgeText` | 根据标题生成两字缩写badge |
| `iconForBuiltinTemplate` | 内置模板默认图标映射 |
| `highlightNumbers` | 将文本中的数字高亮为指定颜色 |

### 2.4 `lib/system/service_manager/`
> 所有协调器遵循同一设计目标：将 `ServiceManager` 的职责拆分到 `lib/system/`，保持 facade 只做状态管理与通知。

| 类 | 职责 |
|----|------|
| `VaultUnlockCoordinator` | 解锁/锁定/登出、无密码模式、主密码修改、生物识别启停 |
| `VaultDataRepository` | Account/Template/TOTP的持久化 + 同步变更箱记录（create/update/delete/togglePin） |
| `SyncCoordinator` | 封装 `SyncService` 的连接/断开/同步拉取 + 服务器URL读写 |
| `SyncServerUrlStore` | 基于 `SharedPreferences` 的同步服务器URL持久化，支持vault级隔离与legacy迁移 |
| `VaultDumpCoordinator` | 加密导出（备份包）与验证导入；区分备份包和配对转存的生命周期 |
| `VaultImportExportCoordinator` | 备份包、安全链接码、导入预览与执行的统一协调 |
| `VaultPairingCoordinator` | Vault配对（服务器中继）与LAN配对（直连）完整流程 |
| `ServiceManagerPasswordTools` | 密码生成与强度计算 facade（代理到 `EnhancedCryptoService`） |
| `defaultSyncServerUrlForCurrentPlatform` | 桌面默认 `http://127.0.0.1:8080`，移动端/Web为空 |

### 2.5 `lib/providers/`
| 类 | 职责 | 依赖 |
|----|------|------|
| `EnhancedAppProvider` | 业务数据持有者：accounts、templates、totp、syncChanges、conflictLogs、搜索/标签过滤 | `SecureStorageService`, `ServiceManager` |
| `NotificationProvider` | 通知中心状态：加载、已读/未读、删除、密码过期阈值、推送开关 | `SecureStorageService`, `NotificationService` |
| `AppThemeProvider` | 主题状态：`ThemeMode`、种子色、`trueBlack`；持久化到SharedPreferences | `SharedPreferences` |

---

## 三、主题系统详细说明

### 3.1 设计Token体系

```
AppBrandColors (种子色) ──┬──> ColorScheme.fromSeed ──> Material3 ColorScheme
                        │
AppRadii     (圆角)     ├──> CardTheme / DialogTheme / InputDecorationTheme ...
AppSpacing   (间距)     ├──> Padding / contentPadding
AppAlphas    (透明度)   ├──> withAlpha() 统一入口
AppBorders   (边框)     ├──> BorderSide
AppShadows   (阴影)     ├──> BoxShadow
AppSurfaces  (表面色)   ├──> scaffoldBackgroundColor / cardColor / fillColor
AppVisualTokens(语义色) ├──> ThemeExtension<AppVisualTokens>
```

### 3.2 布局断点（AppLayout）

| 档位 | 宽度阈值 | 内容最大宽度 | 水平内边距 | 设备类型 |
|------|----------|--------------|------------|----------|
| `compact` | < 720 | ∞ | 16 | 触摸优先 |
| `medium` | 720~1080 | 820 | 24 | 混合 |
| `expanded` | > 1080 | 1080 | 32 | 指针优先 |

使用方式：
```dart
final layout = AppLayout.of(context);
if (layout.isExpanded) { ... }

// 或直接用静态方法
AppLayout.isCompact(context);
```

遗留兼容：`AppLayout.isTablet` / `AppLayout.isDesktop` 仍保留，但 `AppBreakpoints.isDesktop` 已被标记为 legacy。

### 3.3 排版系统（AppTextStyles）

- **自动密度切换**：以 720px 为界，`compact` 用更小字号与更紧凑行高，`comfortable` 更宽松。
- **中文字体优化**：所有行高 1.3~1.6，避免过紧；`letterSpacing: 0`、`leadingDistribution: even`。
- **字体栈**：`GoogleFonts.notoSansScTextTheme(baseTextTheme)` 包裹生成的 TextTheme。

使用方式：
```dart
// 获取完整 TextTheme
final textTheme = AppTextStyles.theme(context);

// 获取单个语义样式
AppTextStyles.titleMedium(context);
AppTextStyles.heroTitle(context);
AppTextStyles.metricValue(context);
```

### 3.4 动态主题构建（main.dart）

`SecretRoyApp` 根据 `AppThemeProvider` 的状态在 `build` 中实时构建 `ThemeData`：

1. **Light Theme**: `ColorScheme.fromSeed` + `AppSurfaces.lightBackground` + `AppVisualTokens.fromBrightness(light)`
2. **Dark Theme**: 对蓝种子色自动提升饱和度（避免暗色发灰）+ `AppSurfaces.darkBackground/darkCard/darkInput` + `trueBlack` 支持纯黑背景
3. **共享配置**: `PageTransitionsTheme`（Android/Windows用Zoom，iOS用Cupertino）、各类按钮/卡片/输入框/导航栏主题

---

## 四、状态管理拓扑图

```
┌─────────────────────────────────────────────────────────────┐
│                        main.dart                              │
│  MultiProvider                                                │
│    ├── ChangeNotifierProvider.value(ServiceManager.instance) │
│    ├── ChangeNotifierProvider(EnhancedAppProvider)           │
│    ├── ChangeNotifierProvider(NotificationProvider)          │
│    └── ChangeNotifierProvider(AppThemeProvider)              │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐   ┌─────────────────┐   ┌─────────────────┐
│ ServiceManager│   │EnhancedAppProvider│  │AppThemeProvider │
│ (全局单例)     │   │ (业务数据层)      │   │ (主题状态)       │
│ ChangeNotifier│   │ ChangeNotifier   │   │ ChangeNotifier  │
└───────────────┘   └─────────────────┘   └─────────────────┘
        │                     │
        │    ┌────────────────┘
        │    │
        ▼    ▼
  ┌──────────────┐         ┌──────────────────┐
  │ VaultUnlock  │         │ SecureStorage    │
  │ Coordinator  │         │ Service          │
  │ (解锁/锁定)   │         │ (数据持久化)      │
  └──────────────┘         └──────────────────┘
        │
        ├──> VaultDataRepository (数据操作)
        ├──> SyncCoordinator (同步控制)
        ├──> VaultImportExportCoordinator (导入导出)
        ├──> VaultPairingCoordinator (设备配对)
        └──> VaultDumpCoordinator (备份包)

EnhancedAppProvider 数据流：
1. 构造函数 -> _init() -> _loadData()
2. 监听 _storageService.onChange -> _loadData()
3. 监听 _serviceManager (解锁时refresh；锁定时清空数据)
4. 所有写操作（add/update/delete）先调ServiceManager，再本地更新列表并notify
```

### 关键数据流向

- **解锁**: `VaultUnlockCoordinator.initializeAndUnlock()` → `ServiceManager` 状态变为 `unlocked` → `EnhancedAppProvider` 收到监听 → `refresh()` 加载全部数据
- **锁定/登出**: `lock()` / `logout()` → `ServiceManager` 状态变为 `locked` → Provider 清空内存数据
- **数据变更**: 用户操作 → `ServiceManager` / `VaultDataRepository` → `SecureStorageService` 触发 `onChange` → `EnhancedAppProvider` 自动重新加载
- **主题变更**: 用户设置 → `AppThemeProvider` notify → `Consumer2` 重建 `MaterialApp` → 新 ThemeData 生效

---

## 五、国际化配置

### 5.1 支持Locale
| 语言 | 代码 | 模板文件 | 说明 |
|------|------|----------|------|
| 中文 | `zh` | `lib/l10n/app_zh.arb` | 默认模板语言 |
| 英文 | `en` | `lib/l10n/app_en.arb` | 英文翻译 |

`MaterialApp` 中强制固定 `locale: const Locale('zh')`，但 `supportedLocales` 包含 `zh` 和 `en`。

### 5.2 关键API

```dart
// 标准用法
final l10n = AppLocalizations.of(context)!;
l10n.tabAccounts;
l10n.fillRequiredField('用户名');

// 双语辅助扩展（非ARB，用于少量硬编码双语场景）
extension AppTextExtension on BuildContext {
  String text(String zh, String en) => ...;
}
context.text('中文', 'English');
```

### 5.3 生成文件
- `app_localizations.dart` — 抽象基类 + Delegate
- `app_localizations_zh.dart` — 中文实现
- `app_localizations_en.dart` — 英文实现
- `app_text_extension.dart` — 辅助扩展

---

## 六、启动流程说明（main.dart）

```dart
void main() async {
  // 1. 确保Flutter绑定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 加载SharedPreferences（主题Provider需要）
  final prefs = await SharedPreferences.getInstance();

  // 3. 初始化ServiceManager全局单例（检测数据库存在、准备服务）
  await ServiceManager.instance.initialize();

  // 4. 初始化本地通知服务
  final notificationService = NotificationService(ServiceManager.instance.storageService);
  await notificationService.init();

  // 5. 启动应用
  runApp(SecretRoyApp(prefs: prefs, notificationService: notificationService));
}
```

`SecretRoyApp` 状态生命周期：
1. `initState()` → `_serviceManager.setupLifecycleObserver()`（监听App前后台，自动锁）
2. `build()` → `MultiProvider` 注入4个Provider
3. `Consumer2<ServiceManager, AppThemeProvider>` 重建：
   - 根据 `themeMode` / `colorSeed` / `trueBlack` 构建 Light/Dark `ThemeData`
   - 根据 `ServiceManager.state` 决定首页：`unlocked` → `HomeView`，否则 → `UnlockView`
4. `dispose()` → `_serviceManager.disposeLifecycleObserver()`

---

## 七、样式债务标记

> 根据 `tool/check_style_tokens.py` 扫描规则（CI红线）：
> - 禁止 `BorderRadius.circular(<数字>)`（应使用 `AppRadii.*`）
> - 禁止 `.withAlpha(<数字>)`（应使用 `AppAlphas.*`）
> - 禁止 `AppBreakpoints.isDesktop`（legacy，应使用 `AppLayout`）
> - `lib/theme/` 和 `lib/widgets/` 被排除

### 7.1 硬编码 `BorderRadius.circular`（违规）

| 位置 | 代码 | 建议 |
|------|------|------|
| `widgets/account_list_tile.dart:550` | `BorderRadius.circular(1)` | 替换为 `BorderRadius.zero` 或定义语义Token |
| `widgets/account_list_tile.dart:961` | `BorderRadius.circular(7)` | 使用 `AppRadii.control`(10) 或新增 `AppRadii.sm2`(6) |
| `widgets/inbox/inbox_action_card.dart:212` | `BorderRadius.circular(size > 36 ? 12 : 10)` | 提取为条件变量或统一为 `AppRadii.button`(12) / `AppRadii.control`(10) |

### 7.2 遗留 `AppBreakpoints.isDesktop`（违规）

| 位置 | 代码 |
|------|------|
| `views/accounts/account_edit_view.dart:2537` | `final isDesktop = AppBreakpoints.isDesktop(context);` |

应替换为 `AppLayout.isExpanded(context)` 或 `AppLayout.of(context).isExpanded`。

### 7.3 硬编码 `.withAlpha`（在 `lib/views/` 和 `lib/main.dart` 中）

以下文件包含大量**非 `AppAlphas.*` 的硬编码 `withAlpha`**（`lib/theme/` 和 `lib/widgets/` 已被排除在CI扫描外）：

- `lib/main.dart` — `withAlpha(120)`（light divider）、`withAlpha(110)`（dark divider）
- `lib/views/accounts/account_edit_view.dart` — 大量 `withAlpha(42)`、`withAlpha(24)`、`withAlpha(18)`、`withAlpha(38)`、`withAlpha(34)`、`withAlpha(88)`、`withAlpha(90)`、`withAlpha(92)`、`withAlpha(72)`、`withAlpha(44)`、`withAlpha(60)`、`withAlpha(70)`、`withAlpha(230)`、`withAlpha(214)`、`withAlpha(236)`、`withAlpha(232)`、`withAlpha(120)`、`withAlpha(180)`、`withAlpha(160)`、`withAlpha(190)`、`withAlpha(255)`、`withAlpha(100)`、`withAlpha(70)`、`withAlpha(16)`、`withAlpha(20)`、`withAlpha(30)`、`withAlpha(50)`、`withAlpha(0)`、`withAlpha(12)`、`withAlpha(14)`、`withAlpha(15)` 等
- `lib/views/accounts/account_list_view.dart` — `withAlpha(60)`、`withAlpha(150)`、`withAlpha(180)`、`withAlpha(100)`、`withAlpha(30)`、`withAlpha(50)`、`withAlpha(0)`、`withAlpha(180)`、`withAlpha(200)`、`withAlpha(32)`、`withAlpha(48)` 等
- `lib/views/accounts/account_subset_view.dart` — `withAlpha(18)`、`withAlpha(168)`、`withAlpha(230)` 等
- `lib/views/templates/template_edit_view.dart` — `withAlpha(42)`、`withAlpha(22)`、`withAlpha(16)`、`withAlpha(36)`、`withAlpha(34)`、`withAlpha(44)`、`withAlpha(90)`、`withAlpha(255)`、`withAlpha(100)`、`withAlpha(70)` 等
- `lib/views/templates/template_list_view.dart` — `withAlpha(10)`、`withAlpha(30)`、`withAlpha(34)`、`withAlpha(18)`、`withAlpha(14)`、`withAlpha(255)`、`withAlpha(100)`、`withAlpha(70)` 等
- `lib/views/sync_settings_view.dart` — `withAlpha(16)`、`withAlpha(20)`、`withAlpha(70)`、`withAlpha(95)`、`withAlpha(110)`、`withAlpha(140)` 等
- `lib/views/conflict_inbox_view.dart`、`password_tools_view.dart`、`security_settings_view.dart`、`unlock_view.dart`、`home_search_view.dart`、`notification_center_view.dart`、`release_note_view.dart`、`local_sync_queue_view.dart`、`notification_settings_view.dart`、`totp_credential_edit_view.dart`、`totp_qr_scanner_view.dart` 等也散布硬编码

> **结论**：`lib/views/` 目录是样式Token违规的**重灾区**。建议批量引入 `AppAlphas` 中缺失的中间档位（如 14、16、20、22、30、34、36、38、42、44、50、70、72、88、90、92、95、100、110、140、150、160、168、180、190、200、214、230、236）或允许视图层按语义场景使用少量硬编码。

---

## 八、TODO清单

在本次扫描的基础设施层文件中，**未发现任何工程性 `TODO` / `FIXME` / `HACK` / `XXX` 注释**。代码维护状态良好。

---

## 九、速查速用

### 常用主题API
```dart
// 布局
final layout = AppLayout.of(context);
layout.isExpanded ? 1080 : 820;

// 文本
AppTextStyles.titleMedium(context);
AppTextStyles.heroTitle(context);

// Token
AppRadii.card, AppRadii.button, AppRadii.panel
AppSpacing.md, AppSpacing.lg
AppAlphas.tint, AppAlphas.low, AppAlphas.medium
AppSurfaces.lightBackground(colorScheme)
AppShadows.card(theme, depth: 1.0)
```

### 常用状态API
```dart
// 读取业务数据
context.watch<EnhancedAppProvider>().accounts;
context.watch<EnhancedAppProvider>().syncState;

// 主题
context.watch<AppThemeProvider>().themeMode;
context.read<AppThemeProvider>().setColorSeed(seed);

// 本地化
AppLocalizations.of(context)!.tabAccounts;
```

### 启动顺序记忆
```
ensureInitialized → SharedPreferences → ServiceManager.initialize
→ NotificationService.init → runApp → setupLifecycleObserver
→ MultiProvider → Consumer2重建Theme + 路由决策
```
