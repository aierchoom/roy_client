# SecretRoy 样式与跨平台布局优化计划

> 编制日期：2026-05-06  
> 范围：Flutter 客户端 UI / 主题系统 / 跨平台排版与布局 / 可复用组件库  
> 目标平台：Android · iOS · Windows · macOS · Linux · Web

---

## 一、现状诊断

### 1.1 已有的良好基础

| 模块 | 状态 | 说明 |
|------|------|------|
| `ThemeData` 构建 | ✅ 较完善 | `main.dart` 中 `_buildLightTheme` / `_buildDarkTheme` 已覆盖 M3 组件主题 |
| `ColorScheme` | ✅ 完善 | 基于 `ColorScheme.fromSeed` + 用户可选种子色，支持 True Black (OLED) |
| `AppDesignTokens` | ⚠️ 半成 | 有 `AppRadii`、`AppSpacing`、`AppShadows`、`AppSurfaces`、`AppVisualTokens`，但**缺少 Typography Scale** |
| `AppBreakpoints` | ⚠️ 基础 | 720px (tablet) / 1080px (desktop) 断点存在，但**PlatformBuilder 只分 mobile/desktop，没有 tablet 独立布局** |
| 响应式容器 | ⚠️ 零散 | `AdaptivePage` / `AdaptiveSection` 已有，但**各视图使用不一致** |
| 可复用 Widget | ⚠️ 零散 | 已有 `AppPageHeader`、`SectionCard`、`AdaptivePage`，但各视图仍在重复造轮子 |
| 桌面端交互 | ❌ 严重不足 | 全项目仅 **1 处 `MouseRegion`**、**3 处 `SelectionArea`**、**无显式 `Scrollbar`**、无键盘导航 |

### 1.2 核心问题

#### 问题 A：排版系统缺失（最高优先级）

项目里**没有任何 Typography Scale**。所有视图中字体样式都是现场 `copyWith`：

```dart
// 在 20 个视图文件中重复出现 130+ 次
style: theme.textTheme.titleMedium?.copyWith(
  fontWeight: FontWeight.w700,
  color: theme.colorScheme.onPrimaryContainer,
)
```

**跨平台影响**：
- 桌面端（Windows/macOS/Web）屏幕更大、观看距离更远，需要更大的基准字号和更宽松的行高
- 移动端屏幕小、密度高，需要更紧凑的排版
- 当前所有平台共用同一套 `textTheme`，没有密度区分

#### 问题 B：跨平台布局适配粗糙

**B1. 断点系统未充分利用**
- `PlatformBuilder` 仅二分为 mobile/desktop，**缺少 tablet（720px~1080px）的独立布局策略**
- 很多页面在平板横屏下仍是手机布局，左右空间浪费

**B2. 桌面端交互缺失**
- 无全局 `Scrollbar`：桌面端用户无法直观判断滚动位置
- 几乎无 `MouseRegion`：缺少悬停反馈（hover effects）
- 几乎无 `SelectionArea`：桌面端/Web 用户无法选中文本复制
- 无键盘导航：`Tab` 顺序、`Enter` 确认、`Esc` 返回等未处理

**B3. 内容布局未适配宽屏**
- `AccountListView`、`TemplateListView` 在桌面端仍是单列 `ListView`，大量水平空间浪费
- 设置页在宽屏下内容过度拉伸或过于集中，没有合理的最大宽度约束
- `AdaptivePage` 部分页面使用、部分未使用

**B4. SafeArea 与平台内边距**
- `HomeViewMobile` 手动计算 `bottomInset` / `bottomPadding`，但桌面端不需要这些逻辑
- 部分页面没有考虑 Windows/macOS 的窗口标题栏区域（尤其是非全屏窗口）

#### 问题 C：样式逻辑下沉到视图层

以 `account_edit_view.dart` 为例（2231 行），内含大量**纯样式方法**：

- `_softCardShadows()` —— 卡片阴影算法
- `_softSurface()` —— Surface 色调混合（**`template_list_view.dart` 里又重复实现了一次**）
- `_fieldAccentColor()` —— 字段强调色规则
- `_buildOverviewCard()` —— 复杂的 Hero Card 装饰

这些方法本应在 `theme/` 或 `widgets/` 中统一维护。

#### 问题 D：魔法数字泛滥

在 `lib/views` 中检索到 **542 处** 硬编码的样式值：

| 类型 | 典型值 | 分布文件数 |
|------|--------|-----------|
| `withAlpha(...)` | `withAlpha(100)`、`withAlpha(120)`、`withAlpha(88)` | 20 |
| `BorderRadius.circular(...)` | `10`、`12`、`16`、`18`、`20`、`24`、`26` | 20 |
| `EdgeInsets` | `EdgeInsets.all(18)`、`EdgeInsets.all(20)` 等 | 20 |

虽然 `AppRadii` 和 `AppSpacing` 已定义，但**大量视图没有使用它们**。

#### 问题 E：组件重复实现

同一概念在多处被重复实现：

| 概念 | 已有官方组件 | 重复实现位置 |
|------|-------------|-------------|
| Section Card | `widgets/section_card.dart` | `appearance_settings_view.dart` 内嵌 `_SectionCard` |
| Settings Tile | 无 | `settings_view.dart` 内嵌 `_SettingsTile` |
| Hero Card | 无 | `account_edit_view.dart` 的 `_buildOverviewCard`、`appearance_settings_view.dart` 的 `_AppearanceHeroCard` |
| 带图标的选项行 | 无 | `appearance_settings_view.dart` 的 `_ModeOptionTile` |
| Soft Surface | 无 | `account_edit_view.dart`、**`template_list_view.dart`** 各自实现 `_softSurface` |

#### 问题 F：文件命名与职责错位

- `lib/theme/template_theme.dart` 实际处理**模板图标/分类推断逻辑**，与主题系统无关，应迁移到 `models/` 或 `utils/`。

---

## 二、优化目标

### 2.1 排版目标
1. **建立跨平台 Typography Scale**：移动端（Compact）与桌面端（Comfortable）两套密度，自动根据屏幕尺寸/平台切换
2. **统一字体语义层级**：将 130+ 处字体样式收敛到 `AppTextStyles`
3. **桌面端文本可选**：关键内容页包裹 `SelectionArea`

### 2.2 布局目标
1. **三档断点布局**：Compact（<720px）、Medium（720~1080px）、Expanded（>1080px）
2. **桌面端体验升级**：悬停反馈、显式滚动条、键盘导航、合理的最大内容宽度
3. **宽屏内容适配**：列表页在 Medium/Expanded 下支持多列/网格布局
4. **消灭布局魔法数字**：`AppRadii`、`AppSpacing`、`AppLayout` 覆盖 90% 以上

### 2.3 架构目标
1. **提取通用 Widget**：将散落在视图内的卡片、列表项、Hero 区域提取到 `widgets/`
2. **沉淀样式工具**：`_softSurface`、`_softCardShadows` 提升到 `theme/`
3. **修正文件职责**：迁移 `template_theme.dart`

---

## 三、分阶段执行方案

### 阶段 1：跨平台 Typography & Token 系统（低风险，高回报）✅ 已完成

**目标**：建立真正跨平台的排版系统，消灭字体硬编码；补齐 Surface/Shadow 工具。

**任务清单**：

1. **新建 `lib/theme/app_text_styles.dart`**
   - 定义 `AppTextScale` 枚举：`compact`（移动端）、`comfortable`（桌面端/Web）
   - 定义 `AppTextStyles` 静态类，提供语义化样式：
     - `heroTitle` / `heroSubtitle`
     - `headlineLarge` / `headlineMedium` / `headlineSmall`
     - `titleLarge` / `titleMedium` / `titleSmall`
     - `bodyLarge` / `bodyMedium` / `bodySmall`
     - `labelLarge` / `labelMedium` / `labelSmall`
     - `chipLabel`、`metricValue`、`caption`
   - 每个样式根据 `AppTextScale` 返回不同的 `fontSize`、`height`、`letterSpacing`
   - 提供 `AppTextStyles.of(BuildContext)` 快捷获取（自动根据断点推断 scale）
   - **中文排版优化**：`height` 在中文内容下适当增大（1.5~1.6），避免行距过紧

2. **改造 `main.dart` 的 `TextTheme` 构建**
   - 当前只在 `textTheme.copyWith` 里覆盖了 `titleLarge/Medium/Small`。
   - 改为由 `AppTextStyles` 生成完整的 `TextTheme`，确保所有 Material3 层级都有 Noto Sans SC + 统一字重 + 跨平台字号。
   - 桌面端基准字号比移动端大 1~2pt，行高增加 0.1~0.2。

3. **沉淀 Surface / Shadow / Border 工具**
   - 从 `account_edit_view.dart` 和 `template_list_view.dart` 提取 `_softSurface` → `AppSurfaces.soft(...)`
   - 从 `account_edit_view.dart` 提取 `_softCardShadows` → `AppShadows.card(...)` / `AppShadows.hero(...)`
   - 新增 `AppBorders`：封装常用的 `Border.all(color: ...withAlpha(...))` 模式，消灭 `withAlpha` 魔法数字

4. **新增 `lib/theme/app_layout.dart`**
   - `AppLayout.of(BuildContext)` 返回当前布局档位：`compact` / `medium` / `expanded`
   - `AppLayout.contentMaxWidth`：根据档位返回合理的最大内容宽度（compact=∞, medium=820, expanded=1080）
   - `AppLayout.horizontalPadding`：根据档位返回页面水平内边距（compact=16, medium=24, expanded=32）
   - `AppLayout.isPointerDevice` / `isTouchDevice`：判断当前平台交互方式（影响悬停、点击区域大小）

**验收标准**：
- `flutter analyze` 无错误。
- `AppTextStyles` 至少替换 3 个视图中的 `FontWeight` / `fontSize` 硬编码。
- `account_edit_view.dart` 和 `template_list_view.dart` 的 `_softSurface` 被替换为 `AppSurfaces.soft`。
- `main.dart` 中 Light/Dark ThemeData 的 `textTheme` 由 `AppTextStyles` 统一生成。

---

### 阶段 2：通用组件提取与跨平台增强（中风险，中回报）✅ 已完成

**目标**：将散落在视图内的可复用 UI 模式提取为官方 Widget，并注入跨平台适配能力。

**任务清单**：

1. **提取 `AppHeroCard`**
   - 合并 `account_edit_view.dart` 的 `_buildOverviewCard` 和 `appearance_settings_view.dart` 的 `_AppearanceHeroCard`。
   - 参数：`icon`、`title`、`subtitle`、`gradientColors`、`metrics`、`trailing`
   - 根据 `AppLayout` 自动调整内边距和字号（compact 20px / comfortable 28px）
   - 放入 `widgets/app_hero_card.dart`

2. **提取 `AppSettingsTile` + `AppSettingsGroup`**
   - 将 `settings_view.dart` 的 `_SettingsTile` 提取为 `widgets/app_settings_tile.dart`
   - 支持 `leading`、`title`、`subtitle`、`trailing`、`onTap`、`showChevron`
   - **桌面端增强**：增加 `MouseRegion` 悬停反馈（背景色微变），增大点击区域
   - 新增 `AppSettingsGroup`：自动处理 `Divider` 和 Card 包装，避免每个设置页重复写 `Column` + `Divider`

3. **提取 `AppOptionTile`**
   - 将 `appearance_settings_view.dart` 的 `_ModeOptionTile` 泛化为 `widgets/app_option_tile.dart`
   - 支持单选/多选、图标、标题、副标题、选中状态动画
   - 桌面端支持键盘 `Enter` / `Space` 切换选中

4. **统一 `SectionCard` 并增强**
   - 将 `appearance_settings_view.dart` 的内嵌 `_SectionCard` 替换为官方 `SectionCard`
   - 补充缺失特性（如 `useOutlinedBorder`、`gradientHeader` 等）
   - 根据 `AppLayout` 自适应内边距

5. **提取 `AppSelectableListView`**
   - 针对桌面端/Web 的列表，统一包裹 `Scrollbar` + `SelectionArea`
   - 在桌面端自动显示滚动条，移动端保持原生滚动感
   - 用于替换 `AccountListView`、`TemplateListView` 等页面的裸 `ListView`

6. **提取 `AppNavRail` / `AppNavBar`**
   - 将 `home_view_desktop.dart` 的 `_DesktopDock` 提取为可复用的 `AppNavRail`
   - 将 `home_view_mobile.dart` 的 `_NavItem` / BottomBar 提取为 `AppNavBar`
   - `AppNavRail` 支持 `compact`（仅图标）和 `expanded`（图标+文字+描述）两种模式
   - 桌面端支持 `MouseRegion` 悬停反馈和 Tooltip

**验收标准**：
- 至少 6 个新的/增强的通用 Widget 进入 `widgets/`。
- `settings_view.dart`、`appearance_settings_view.dart`、`account_edit_view.dart` 的内嵌组件被替换。
- 桌面端各页面有显式 `Scrollbar` 和 `SelectionArea`。
- 无功能回退（通过手动跑关键页面验证）。

---

### 阶段 3：跨平台布局重构（中风险，高回报）🟡 部分完成

**目标**：让布局真正适配三档断点，桌面端体验达到生产力工具水准。

**任务清单**：

1. **重构 `PlatformBuilder` → `AppLayoutBuilder`**
   - 替换现有的 `PlatformBuilder`（或在其基础上扩展）
   - 提供三档构建器：`compactBuilder`、`mediumBuilder`、`expandedBuilder`
   - 向后兼容：如果未提供 `mediumBuilder`，降级到 `compactBuilder`
   - 内部使用 `AppLayout.of(context)` 判断

2. **列表页宽屏适配**
   - `AccountListView`：在 `expanded` 档位下，从单列 `ListView` 改为**双列网格**（左侧账户列表 + 右侧快速预览/编辑），或至少改为 `Wrap` 网格布局
   - `TemplateListView`：在 `medium` / `expanded` 下改为网格布局（2~3 列）
   - `HomeSearchView`：搜索结果在宽屏下使用多列卡片网格
   - 使用 `LayoutBuilder` + `AppLayout` 判断，不要硬编码宽度阈值

3. **增强 `AdaptivePage` 统一接入**
   - 所有独立页面（`settings_view.dart`、`security_settings_view.dart`、`sync_settings_view.dart` 等）统一包裹 `AdaptivePage`
   - `AdaptivePage` 内部根据 `AppLayout` 自动调整：
     - `compact`：全宽 + 16px 水平内边距
     - `medium`：maxWidth 820 + 24px 内边距
     - `expanded`：maxWidth 1080 + 32px 内边距
   - 支持 `showScrollbar` 参数（桌面端默认 true）

4. **键盘导航与快捷键（桌面端专属）**
   - `UnlockView`：密码框支持 `Enter` 提交、`Esc` 清空
   - `AccountEditView`：支持 `Ctrl+S` 保存、`Esc` 返回
   - `HomeSearchView`：`Ctrl+F` 聚焦搜索框、`Esc` 清空搜索
   - 使用 `Shortcuts` + `Actions` 实现，仅在非移动端生效

5. **Web / 桌面端特定优化**
   - 全局 `SelectionArea`：在 `MaterialApp` 层级或各页面根节点包裹（排除敏感字段如密码）
   - 鼠标悬停反馈：所有可点击卡片、列表项在桌面端增加 `MouseRegion` + `AnimatedContainer` 背景色变化
   - 右键菜单：桌面端列表项支持右键弹出快捷菜单（复制、编辑、删除）
   - 拖拽支持（可选增强）：桌面端支持拖拽排序模板/账户

6. **平台内边距规范化**
   - 统一处理 `SafeArea`：桌面端窗口不需要底部 SafeArea，移动端需要
   - 使用 `AppLayout.isTouchDevice` 条件判断，不要在桌面端代码里硬编码 mobile 的 bottom padding 逻辑
   - `HomeViewMobile` 的 `bottomInset` 计算只在移动端执行

**验收标准**：
- `AccountListView`、`TemplateListView`、`HomeSearchView` 在 1200px 以上宽度显示为多列/网格。
- 所有设置页统一使用 `AdaptivePage`，内容不再过度拉伸。
- 桌面端至少 3 个页面支持键盘快捷键。
- 桌面端所有可滚动区域有显式 `Scrollbar`。
- 无移动端功能回退。

---

### 阶段 4：魔法数字清理与文件重组（低风险）🟡 部分完成

**任务清单**：

1. **逐个视图扫描 `lib/views`**
   - 替换硬编码的圆角为 `AppRadii.*`
   - 替换硬编码的间距为 `AppSpacing.*`
   - 替换硬编码的 `withAlpha` 为 `AppBorders` 或 `AppSurfaces` 封装方法
   - 优先清理高频页面：`account_edit_view.dart`、`account_list_view.dart`、`home_search_view.dart`、`settings_view.dart`

2. **迁移 `lib/theme/template_theme.dart`**
   - 迁移到 `lib/utils/template_icons.dart`（或 `lib/models/`）
   - 同步更新所有 import

3. **新建 `lib/theme/theme.dart` Barrel 文件**
   - 统一导出 `app_design_tokens.dart`、`app_text_styles.dart`、`app_layout.dart`
   - 各视图只需 `import '../theme/theme.dart'`

4. **更新 `AGENTS.md`**
   - 补充 `lib/theme/app_text_styles.dart`、`lib/theme/app_layout.dart`、新增 widgets 到项目结构速查表

**验收标准**：
- `lib/views` 中硬编码 `BorderRadius.circular` 减少 50% 以上。
- `lib/views` 中 `withAlpha` 减少 30% 以上。
- `flutter analyze` 无错误，所有 import 更新完毕。

---

## 四、执行顺序与依赖关系

```
阶段 1 (Typography & Token & AppLayout)
    │
    ├── 产出：AppTextStyles、AppSurfaces、AppShadows、AppBorders、AppLayout
    ▼
阶段 2 (通用组件提取)
    │
    ├── 依赖阶段1的 Token 和 AppLayout 做跨平台适配
    ├── 产出：AppHeroCard、AppSettingsTile、AppOptionTile、AppNavRail、AppSelectableListView
    ▼
阶段 3 (跨平台布局重构)
    │
    ├── 依赖阶段1的 AppLayout 和阶段2的组件
    ├── 产出：三档断点布局、键盘导航、宽屏网格、Scrollbar/SelectionArea
    ▼
阶段 4 (魔法数字清理 & 文件重组)
    │
    ├── 可随时进行，建议放在最后做全局清理
    └── 产出：干净一致的代码、更新的 AGENTS.md
```

**建议**：
- 若时间有限，**优先做阶段 1 + 阶段 4**，即可让代码质量和可维护性提升一个台阶。
- 阶段 2 和 3 可逐步进行，每完成一个视图就验证一次，降低风险。

---

## 五、跨平台适配检查清单

在阶段 2~3 中，每新增/修改一个组件或页面时，对照以下清单自检：

| 检查项 | Compact (<720px) | Medium (720~1080px) | Expanded (>1080px) |
|--------|------------------|---------------------|--------------------|
| 字号密度 | Compact | Comfortable | Comfortable |
| 内容最大宽度 | 100% | 820px | 1080px |
| 水平内边距 | 16px | 24px | 32px |
| 列表布局 | 单列 ListView | 可选双列 | 网格/多列/侧边栏 |
| 滚动条 | 隐藏 | 显式 Scrollbar | 显式 Scrollbar |
| 文本可选 | 否（除输入框） | 是 | 是 |
| 悬停反馈 | 无 | MouseRegion | MouseRegion |
| 键盘导航 | 原生 | Shortcuts+Actions | Shortcuts+Actions |
| 右键菜单 | 无 | 可选 | 可选 |
| 底部导航 | BottomNav | BottomNav/NavRail | NavRail |

---

## 六、预期收益

| 指标 | 优化前 | 优化后（预估） |
|------|--------|---------------|
| 字体样式硬编码点 | 130+ | < 20（仅限特殊场景） |
| 视图内嵌组件重复 | 8+ 处 | 0（全部提取到 widgets/） |
| `withAlpha` 魔法数字 | 200+ | < 50（封装到 Token） |
| 新增页面跨平台适配成本 | 改 N 个文件 | 调用 `AppLayout` + 官方 Widget，一次到位 |
| 桌面端可用性 | 仅是放大的手机 App | 有滚动条、键盘导航、悬停反馈、宽屏网格 |
| 主题色/字号全局切换成本 | 改 N 个文件 | 改 `AppVisualTokens` / `AppTextStyles` 一处 |

---

## 七、风险与注意事项

1. **视觉回归风险**：
   - 清理魔法数字时，可能误改 Alpha 值导致颜色变深/变浅。
   - **缓解措施**：每改完一个视图，在 Light / Dark / TrueBlack 三模式下截图对比；移动端和桌面端都验证。

2. **跨平台行为差异**：
   - `SelectionArea` 包裹后，某些手势（如长按复制）可能与现有逻辑冲突。
   - **缓解措施**：敏感字段（密码、密钥）显式使用 `SelectionContainer.disabled` 阻止选中。

3. **键盘快捷键冲突**：
   - `Ctrl+S` 在 Web 上可能被浏览器拦截。
   - **缓解措施**：Web 端使用 `Meta+S` 或 `Alt+S` 作为备选；在 `Shortcuts` 中做好平台判断。

4. **性能风险**：
   - `LayoutBuilder` 嵌套过多可能导致过度重建。
   - **缓解措施**：`AppLayout` 使用 `MediaQuery` 的静态方法（`MediaQuery.sizeOf`）而非 `LayoutBuilder` 做断点判断；`AppLayoutBuilder` 只在页面顶层使用一次。

5. **Widget 测试**：
   - 当前 Widget 测试极少（仅 `account_list_tile_test.dart`）。
   - **缓解措施**：提取通用组件时，**为新的通用 Widget 编写单元/Widget 测试**，尤其是 `AppSettingsTile`、`AppOptionTile`、`AppLayout` 这种带状态判断的组件。

6. **AGENTS.md 同步**：
   - 新增 `lib/theme/app_text_styles.dart`、`lib/theme/app_layout.dart`、新增 widgets 后，需更新 `AGENTS.md` 的项目结构和常用路径速查表。
