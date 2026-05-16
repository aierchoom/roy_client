[stage] runner_started
[stage] agent_built
[stage] context_restored
[stage] context_ready
[stage] run_soul_start
[tool] Glob
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
[tool] Grep
[tool_result] success
[tool_result] success
[tool] Grep
[tool] Shell
[tool_result] success
[tool_result] success
[tool] Grep
[tool_result] success
[tool] Grep
[tool_result] success
Now I have all the data needed. Let me compile the comprehensive component library catalog.

---

# 《SecretRoy 组件库目录》

> 扫描范围：`lib/widgets/`（25 个 Dart 文件）  
> 测试对比：`test/widgets/`（9 个测试文件）  
> 统计时间：2026-05-16

---

## 一、组件总览表

| 分类 | 数量 | 组件清单 |
|---|---|---|
| **布局组件** | 3 | `AdaptivePage`, `AdaptiveSection`, `AppLayoutBuilder` |
| **基础组件** | 18 | `AppHeroCard`, `AppPageHeader`, `SectionCard`, `AppSettingsGroup`, `AppSettingsTile`, `AppOptionTile`, `SelectionIndicator`, `GreenAddButton`, `ToneChip`, `SectionHeader`, `EmptyStatePlaceholder`, `InboxEmptyState`, `MetricChip`, `SyncInfoChip`, `AppNavBar`, `AppNavRail`, `NavBadgeIcon`, `AppNavDestination`, `AppSelectableScrollable` |
| **业务组件** | 16 | `AccountListTile`, `AccountFieldRow`, `AccountFieldRowBody`, `PasswordGeneratorSheet`, `LanSyncConflictSheet`, `LanSyncConflictOverlay`, `LanPairingCodeDialog`, `VaultLinkCodeDialog`, `SyncServerDialog`, `FieldEditorDialog`, `FieldPresetPreviewDialog`, `EditorMetric`, `EditMetadataRow`, `ActionSummaryCard`, `ActionItemCard`, `InboxFilterBar`, `InboxHeroMetrics` |
| **模型/数据类** | 4 | `AccountFieldDisplayData`, `PasswordGeneratorResult`, `PasswordGeneratorOptions`, `FieldEditorResult`, `MetricData`, `InboxSeverity`, `InboxAction`, `InboxItem` |

> 注：25 个文件中包含多个 `class` / 顶层函数，实际可复用单元约 40+ 个。

---

## 二、每个组件的详细说明

### 布局组件

#### `AdaptivePage` / `AdaptiveSection`
- **文件**：`lib/widgets/adaptive_page.dart`
- **功能**：响应式页面容器，根据屏幕宽度限制最大内容宽度（tablet ≤ 820, desktop ≤ 1240）
- **参数**：
  - `child: Widget`（必需）
  - `padding: EdgeInsetsGeometry`（默认 `horizontal: 8`）
  - `tabletMaxWidth: double`（默认 820）
  - `desktopMaxWidth: double`（默认 1240）
- **使用场景**：所有需要居中受限宽度的页面根容器
- **Dartdoc**：❌ 无

#### `AppLayoutBuilder`
- **文件**：`lib/widgets/app_layout_builder.dart`
- **功能**：三档断点（compact / medium / expanded）布局构建器，自动向后降级
- **参数**：
  - `compactBuilder: WidgetBuilder`（必需）
  - `mediumBuilder: WidgetBuilder?`
  - `expandedBuilder: WidgetBuilder?`
- **使用场景**：替代旧版 `PlatformBuilder`，实现移动端/桌面端差异化布局
- **Dartdoc**：✅ 有（6 行）

---

### 基础组件

#### `AppHeroCard`
- **文件**：`lib/widgets/app_hero_card.dart`
- **功能**：页面顶部 Hero 视觉焦点卡片，支持渐变背景、指标 chips、尾部操作区
- **参数**：
  - `icon: IconData`, `title: String`（必需）
  - `subtitle: String?`, `metrics: List<Widget>?`, `trailing: Widget?`
  - `gradientColors: List<Color>?`, `padding: EdgeInsetsGeometry?`
- **使用场景**：首页、统计页顶部 Hero 区域
- **Dartdoc**：✅ 有（4 行）
- **测试**：✅ `app_hero_card_test.dart`

#### `AppPageHeader`
- **文件**：`lib/widgets/app_page_header.dart`
- **功能**：标准页面头部，左侧图标容器 + 标题/副标题 + 可选尾部 widget + 指标 Wrap
- **参数**：
  - `icon: IconData`, `title: String`, `subtitle: String`（必需）
  - `metrics: List<Widget>`（默认空列表）, `trailing: Widget?`
- **使用场景**：设置页、列表页等非 Hero 页面头部
- **Dartdoc**：❌ 无
- **测试**：❌ 无

#### `SectionCard`
- **文件**：`lib/widgets/section_card.dart`
- **功能**：带标题和副标题的分区卡片，可选 outlined border 或 Material Card
- **参数**：
  - `title: String`, `child: Widget`（必需）
  - `subtitle: String?`, `padding: EdgeInsetsGeometry`（默认 `AppSpacing.xl2`）
  - `childGap: double`（默认 `AppSpacing.lg`）, `useOutlinedBorder: bool`（默认 false）
- **使用场景**：表单分区、信息分组展示
- **Dartdoc**：✅ 有（1 行）
- **测试**：✅ `section_card_test.dart`

#### `AppSettingsGroup` / `AppSettingsTile`
- **文件**：`lib/widgets/app_settings_group.dart`, `lib/widgets/app_settings_tile.dart`
- **功能**：设置页列表组容器（自动插入 Divider）+ 单个设置项（支持桌面端悬停反馈）
- **参数（Group）**：`children: List<Widget>`, `padding: EdgeInsetsGeometry?`
- **参数（Tile）**：`icon: IconData`, `title: String`, `subtitle: String?`, `onTap: VoidCallback?`, `showChevron: bool`（默认 true）, `trailing: Widget?`
- **使用场景**：所有设置页面
- **Dartdoc**：✅ 均有
- **测试**：✅ `app_settings_test.dart`（覆盖两者）

#### `AppOptionTile`
- **文件**：`lib/widgets/app_option_tile.dart`
- **功能**：单选/多选选项列表项，带圆形选中指示器动画
- **参数**：`icon: IconData`, `title: String`, `subtitle: String?`, `selected: bool`, `onTap: VoidCallback?`
- **使用场景**：主题选择、语言选择等单选列表
- **Dartdoc**：✅ 有
- **测试**：✅ `app_option_tile_test.dart`

#### `SelectionIndicator`
- **文件**：`lib/widgets/selection_indicator.dart`
- **功能**：带动画的圆形选中指示器（勾选图标）
- **参数**：`selected: bool`, `size: double`（默认 22）, `duration: Duration`（默认 160ms）
- **使用场景**：多选列表、批量操作状态指示
- **Dartdoc**：✅ 有（1 行）
- **测试**：❌ 无

#### `GreenAddButton`
- **文件**：`lib/widgets/green_add_button.dart`
- **功能**：固定绿色的圆形 FloatingActionButton（大/小两种尺寸）
- **参数**：`onPressed: VoidCallback?`, `tooltip: String`, `heroTag: Object?`, `small: bool`（默认 false）, `icon: IconData`（默认 `Icons.add`）
- **使用场景**：各列表页的添加按钮
- **Dartdoc**：❌ 无
- **测试**：❌ 无

#### `AppNavBar` / `AppNavRail` / `NavBadgeIcon` / `AppNavDestination`
- **文件**：`lib/widgets/app_nav_bar.dart`, `lib/widgets/app_nav_rail.dart`
- **功能**：移动端底部导航栏 + 桌面端侧边 NavRail + 带数字角标的图标 + 导航目的地数据类
- **参数（NavBar/NavRail）**：`selectedIndex: int`, `onDestinationSelected: ValueChanged<int>`, `destinations: List<AppNavDestination>`, `header/footer: Widget?`（仅 Rail）
- **使用场景**：应用主框架导航
- **Dartdoc**：✅ 均有
- **测试**：✅ `app_nav_test.dart`

#### `AppSelectableScrollable`
- **文件**：`lib/widgets/app_selectable_scrollable.dart`
- **功能**：桌面端/Web 自动包裹 `Scrollbar` + `SelectionArea`，触摸设备保持原生行为
- **参数**：`child: Widget`, `showScrollbar: bool`（默认 true）, `selectable: bool`（默认 true）, `controller: ScrollController?`
- **使用场景**：所有包含滚动列表的页面
- **Dartdoc**：✅ 有（9 行）
- **测试**：✅ `app_selectable_scrollable_test.dart`

#### `ToneChip` / `SectionHeader` / `EmptyStatePlaceholder`
- **文件**：`lib/widgets/account_edit_widgets.dart`
- **功能**：样式化标签芯片 / 分区标题（带图标+操作按钮）/ 空状态占位图
- **参数**：
  - `ToneChip`: `icon: IconData`, `label: String`, `tint: Color?`
  - `SectionHeader`: `icon: IconData`, `title: String`, `subtitle: String?`, `actionLabel: String?`, `onAction: VoidCallback?`, `accent: Color?`
  - `EmptyStatePlaceholder`: `icon: IconData`, `title: String`, `subtitle: String?`, `actionLabel: String?`, `onAction: VoidCallback?`
- **使用场景**：账号编辑页、通用空状态
- **Dartdoc**：✅ 均有
- **测试**：❌ 无

#### `MetricChip` / `SyncInfoChip`
- **文件**：`lib/widgets/inbox/inbox_hero_metrics.dart`, `lib/widgets/sync_settings_dialogs.dart`
- **功能**：指标 chip（值+标签）/ 同步状态信息 chip
- **参数（MetricChip）**：`value: String`, `label: String`, `color: Color`
- **参数（SyncInfoChip）**：`label: String`
- **使用场景**：Hero 指标区、同步设置页状态标签
- **Dartdoc**：✅ 均有

---

### 业务组件

#### `AccountListTile`
- **文件**：`lib/widgets/account_list_tile.dart`
- **功能**：核心账号列表项，支持展开/折叠动画、字段复制、敏感信息掩码、长按菜单、TOTP 徽章、同步状态指示
- **参数**：
  - `account: AccountItem`, `template: AccountTemplate?`, `onEdit: VoidCallback`, `onDelete: VoidCallback`（必需）
  - `hasMissingTemplate: bool`, `legacyFieldCount: int`, `linkedTotpCredentialCount: int`（默认 0）
  - `density: AccountListTileDensity`（默认 `library`）
  - `onTogglePin: VoidCallback?`, `localeText: String Function(...)`, `resolveAccountName: String? Function(String)?`
  - `highlightedFieldKeys: List<String>`（默认空）
- **内部子组件**：`_FieldCountTag`, `_TinyBadge`, `_IconButtonCompact`, `_SectionLabel`, `_FieldRow`, `_FieldActionButton`, `_ActionBar`, `_ActionButton`, `AccountFieldRow`（legacy public）, `AccountFieldRowBody`（legacy public）
- **使用场景**：账号库列表、搜索结果列表
- **Dartdoc**：⚠️ 公共类无注释，仅 3 个私有方法有 `///`
- **测试**：✅ `account_list_tile_test.dart`

#### `PasswordGeneratorSheet`
- **文件**：`lib/widgets/password_generator_sheet.dart`
- **功能**：底部弹出的密码生成器，支持长度滑块、字符类型开关、强度评分、复制/应用
- **参数**：
  - `initialOptions: PasswordGeneratorOptions`, `minLength: int`, `maxLength: int`（必需）
  - `title: String?`, `subtitle: String?`, `applyLabel: String?`, `showApplyAction: bool`（默认 true）
- **辅助 API**：`showPasswordGeneratorSheet()` 便捷函数，`PasswordGeneratorResult`, `PasswordGeneratorOptions`
- **内部子组件**：`_OptionTile`
- **使用场景**：账号编辑页密码字段、密码工具页
- **Dartdoc**：❌ 公共类无注释
- **测试**：✅ `password_generator_sheet_test.dart`

#### `LanSyncConflictSheet` / `LanSyncConflictOverlay`
- **文件**：`lib/widgets/lan_sync_conflict_sheet.dart`
- **功能**：LAN 同步冲突处理 BottomSheet + 自动监听并弹出的 Overlay Widget
- **参数（Sheet）**：`coordinator: LanSyncCoordinator`, `onConfirm: VoidCallback?`, `onCancel: VoidCallback?`
- **参数（Overlay）**：无（从 `ServiceManager` 自动获取 coordinator）
- **使用场景**：LAN 同步过程中自动弹出冲突确认
- **Dartdoc**：✅ 均有（9 行）
- **测试**：❌ 无

#### `LanPairingCodeDialog` / `VaultLinkCodeDialog` / `SyncServerDialog`
- **文件**：`lib/widgets/sync_settings_dialogs.dart`
- **功能**：8 位配对码输入对话框 / 保险库恢复码输入对话框 / 同步服务器 URL 配置对话框
- **参数**：均为标准 AlertDialog 参数（title, subtitle, confirmLabel, cancelLabel 等）
- **使用场景**：同步设置页、设备配对流程
- **Dartdoc**：✅ 均有
- **测试**：❌ 无

#### `FieldEditorDialog` / `FieldPresetPreviewDialog` / `EditorMetric`
- **文件**：`lib/widgets/template_edit_widgets.dart`
- **功能**：模板字段编辑器对话框 / 字段预设预览选择对话框 / 编辑器指标小部件
- **参数（FieldEditor）**：`initial: AccountField?`, `originallyPersisted: bool`, `fieldTypeLabelBuilder: String Function(AccountFieldType)`
- **参数（PresetPreview）**：`preset: FieldPreset`
- **辅助 API**：`fieldTypeLabel()`, `fieldTypeIcon()`, `FieldEditorResult`
- **使用场景**：模板编辑页
- **Dartdoc**：✅ 均有（7 行）
- **测试**：❌ 无

#### `EditMetadataRow`
- **文件**：`lib/widgets/edit_metadata_row.dart`
- **功能**：显示编辑时间/设备别名，长按显示绝对时间和完整 deviceId
- **参数**：`editedAt: int?`, `editedBy: String?`
- **使用场景**：账号编辑页底部元数据
- **Dartdoc**：❌ 无
- **测试**：❌ 无

#### `ActionSummaryCard` / `ActionItemCard`
- **文件**：`lib/widgets/inbox/inbox_action_card.dart`
- **功能**：收件箱大类摘要卡片（带数字高亮）/ 单个收件箱项卡片（带严重级别图标）
- **参数（Summary）**：`icon: IconData?`, `iconColor: Color?`, `backgroundColor: Color?`, `title: String`, `subtitle: String`, `onTap: VoidCallback?`, `leading: Widget?`
- **参数（Item）**：`severity: InboxSeverity`, `title: String`, `subtitle: String`, `meta: String?`, `showChevron: bool`, `onTap: VoidCallback?`, `trailing: Widget?`
- **内部子组件**：`_IconContainer`
- **使用场景**：通知中心/冲突收件箱
- **Dartdoc**：✅ 均有（9 行）
- **测试**：✅ `inbox_action_card_test.dart`

#### `InboxFilterBar<T>`
- **文件**：`lib/widgets/inbox/inbox_filter_bar.dart`
- **功能**：通用分类过滤栏（`ChoiceChip` 实现），支持泛型类别值
- **参数**：`categories: List<(T, String, String)>`, `selected: T`, `onSelected: ValueChanged<T>`
- **使用场景**：收件箱按类别过滤
- **Dartdoc**：✅ 有
- **测试**：❌ 无

#### `InboxHeroMetrics`
- **文件**：`lib/widgets/inbox/inbox_hero_metrics.dart`
- **功能**：收件箱 Hero 区域，包装 `AppPageHeader` 并映射 `MetricData` → `MetricChip`
- **参数**：`icon: IconData`, `title: String`, `subtitle: String`, `metrics: List<MetricData>`, `trailing: Widget?`
- **使用场景**：通知中心顶部
- **Dartdoc**：✅ 有
- **测试**：❌ 无

---

### 模型/数据类

| 名称 | 文件 | 说明 |
|---|---|---|
| `AccountFieldDisplayData` | `account_list_tile.dart` | 账号字段展示数据（label, value, isSecret, icon 等） |
| `AccountListTileDensity` | `account_list_tile.dart` | 密度枚举：`library`, `search` |
| `AppNavDestination` | `app_nav_rail.dart` | 导航目的地描述（icon, selectedIcon, label, badgeCount 等） |
| `PasswordGeneratorResult` | `password_generator_sheet.dart` | 密码生成结果（password + options） |
| `PasswordGeneratorOptions` | `password_generator_sheet.dart` | 密码生成选项（length, 四种字符类型开关） |
| `FieldEditorResult` | `template_edit_widgets.dart` | 字段编辑器返回结果（label, rawKey, description, attributes） |
| `MetricData` | `inbox_hero_metrics.dart` | 单一指标数据（value, label, color） |
| `InboxSeverity` | `inbox/inbox_models.dart` | 严重级别枚举：`critical`, `warning`, `info`, `success` |
| `InboxAction` | `inbox/inbox_models.dart` | 收件箱项动作描述（targetId / targetIds / onTap） |
| `InboxItem` | `inbox/inbox_models.dart` | 收件箱项抽象接口（id, severity, title, subtitle 等） |

---

## 三、组件依赖图

```
┌─────────────────────────────────────────────────────────────┐
│                     跨文件依赖（极轻）                        │
├─────────────────────────────────────────────────────────────┤
│  inbox_hero_metrics.dart ──import──► app_page_header.dart   │
│  app_nav_bar.dart        ──import──► app_nav_rail.dart      │
│         (导出 AppNavDestination)                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     文件内部子组件                            │
├─────────────────────────────────────────────────────────────┤
│  account_list_tile.dart                                     │
│    ├── _FieldCountTag                                       │
│    ├── _TinyBadge                                           │
│    ├── _IconButtonCompact                                   │
│    ├── _SectionLabel                                        │
│    ├── _FieldRow  (Stateful, 秘密掩码/复制/高亮)              │
│    ├── _FieldActionButton                                   │
│    ├── _ActionBar                                           │
│    ├── _ActionButton                                        │
│    └── AccountFieldRow / AccountFieldRowBody (legacy公开)    │
├─────────────────────────────────────────────────────────────┤
│  app_nav_bar.dart                                           │
│    └── _NavItem                                             │
├─────────────────────────────────────────────────────────────┤
│  app_nav_rail.dart                                          │
│    ├── NavBadgeIcon  (公开，被 NavBar 复用)                   │
│    └── _NavItem                                             │
├─────────────────────────────────────────────────────────────┤
│  inbox_action_card.dart                                     │
│    └── _IconContainer                                       │
├─────────────────────────────────────────────────────────────┤
│  password_generator_sheet.dart                              │
│    └── _OptionTile                                          │
└─────────────────────────────────────────────────────────────┘
```

**设计特点**：组件库高度解耦，几乎无跨文件 widget 依赖，每个文件自包含。唯一跨文件依赖是 `InboxHeroMetrics` 复用 `AppPageHeader`，以及 `AppNavBar` 复用 `AppNavRail` 导出的 `AppNavDestination` 数据类。

---

## 四、测试覆盖缺口

### 已有测试（9 个测试文件）

| 测试文件 | 覆盖的组件 |
|---|---|
| `test/widgets/account_list_tile_test.dart` | `AccountListTile` |
| `test/widgets/app_hero_card_test.dart` | `AppHeroCard` |
| `test/widgets/app_nav_test.dart` | `AppNavBar`, `AppNavRail` |
| `test/widgets/app_option_tile_test.dart` | `AppOptionTile` |
| `test/widgets/app_selectable_scrollable_test.dart` | `AppSelectableScrollable` |
| `test/widgets/app_settings_test.dart` | `AppSettingsGroup`, `AppSettingsTile` |
| `test/widgets/inbox_action_card_test.dart` | `ActionSummaryCard`, `ActionItemCard` |
| `test/widgets/password_generator_sheet_test.dart` | `PasswordGeneratorSheet` |
| `test/widgets/section_card_test.dart` | `SectionCard` |

### 缺少测试的组件（14 个文件）

| 文件 | 组件 | 优先级建议 |
|---|---|---|
| `lib/widgets/account_edit_widgets.dart` | `ToneChip`, `SectionHeader`, `EmptyStatePlaceholder` | 中 |
| `lib/widgets/adaptive_page.dart` | `AdaptivePage`, `AdaptiveSection` | 低 |
| `lib/widgets/app_layout_builder.dart` | `AppLayoutBuilder` | 低 |
| `lib/widgets/app_page_header.dart` | `AppPageHeader` | 中 |
| `lib/widgets/edit_metadata_row.dart` | `EditMetadataRow` | 中（依赖 ServiceManager） |
| `lib/widgets/green_add_button.dart` | `GreenAddButton` | 低 |
| `lib/widgets/lan_sync_conflict_sheet.dart` | `LanSyncConflictSheet`, `LanSyncConflictOverlay` | 高（业务复杂） |
| `lib/widgets/selection_indicator.dart` | `SelectionIndicator` | 低 |
| `lib/widgets/sync_settings_dialogs.dart` | `SyncInfoChip`, `LanPairingCodeDialog`, `VaultLinkCodeDialog`, `SyncServerDialog` | 中 |
| `lib/widgets/template_edit_widgets.dart` | `FieldEditorDialog`, `FieldPresetPreviewDialog`, `EditorMetric` | 高（业务复杂） |
| `lib/widgets/inbox/inbox_empty_state.dart` | `InboxEmptyState` | 低 |
| `lib/widgets/inbox/inbox_filter_bar.dart` | `InboxFilterBar` | 低 |
| `lib/widgets/inbox/inbox_hero_metrics.dart` | `InboxHeroMetrics`, `MetricChip` | 低 |
| `lib/widgets/inbox/inbox_models.dart` | `InboxSeverity`, `InboxAction`, `InboxItem` | 低（纯数据接口） |

> 测试覆盖率：约 **44%** 的 widget 文件有对应测试（9/25），按组件数量计算更低。

---

## 五、TODO / FIXME / HACK 清单

```
扫描结果：lib/widgets/ 目录下未发现任何 TODO / FIXME / HACK / XXX 注释。
```

> 该目录代码债务控制良好，无显式待办标记。

---

## 六、Dartdoc 覆盖情况

| 状态 | 文件数 | 文件清单 |
|---|---|---|
| **有 Dartdoc** | 20 | `app_hero_card`, `app_layout_builder`, `app_nav_bar`, `app_nav_rail`, `app_option_tile`, `app_selectable_scrollable`, `app_settings_group`, `app_settings_tile`, `section_card`, `account_edit_widgets`, `account_list_tile`(仅私有方法), `lan_sync_conflict_sheet`, `sync_settings_dialogs`, `template_edit_widgets`, `inbox_action_card`, `inbox_empty_state`, `inbox_filter_bar`, `inbox_hero_metrics`, `inbox_models`, `selection_indicator` |
| **无 Dartdoc** | 5 | `adaptive_page.dart`, `app_page_header.dart`, `edit_metadata_row.dart`, `green_add_button.dart`, `password_generator_sheet.dart` |

**重点缺口**：`AccountListTile`（核心组件，1321 行）公共类本身无类级 dartdoc，仅 2 个私有方法有注释；`PasswordGeneratorSheet`（587 行）公共类完全无 dartdoc。

---

## 七、关键发现与建议

1. **单文件多组件模式**：`account_list_tile.dart`（1321 行，含 10 个 class）、`password_generator_sheet.dart`（587 行）、`template_edit_widgets.dart`（527 行）文件过长，子组件未拆分到独立文件，维护成本随功能增长而上升。
2. **Legacy 兼容层**：`account_list_tile.dart` 底部保留了 `AccountFieldRow` / `AccountFieldRowBody` 公开兼容类，标注为 "Legacy public exports for backward compatibility"，建议评估是否已可移除。
3. **硬编码颜色**：`green_add_button.dart` 中 `kGreenAddButtonColor = Color(0xFF1FA463)` 是唯一硬编码品牌色，未走 Design Token 体系。
4. **Style Token 红线**：`account_list_tile.dart` 第 467 行存在 `BorderRadius.circular(AppRadii.card)` 的合规使用，但第 552 行 `BoxDecoration(color: accent.withAlpha(100))` 等存在大量硬编码 alpha 值。根据 `AGENTS.md`，`lib/widgets/` 被排除在 `check_style_tokens.py` 扫描之外，因此允许。
5. **测试缺口集中区**：对话框类（`FieldEditorDialog`, `LanPairingCodeDialog`, `VaultLinkCodeDialog`, `SyncServerDialog`）和 Sheet 类（`LanSyncConflictSheet`, `PasswordGeneratorSheet` 已有测试）是交互最复杂的组件，其中对话框类全部无测，建议优先补充。[stage] run_soul_finished

[summary]
Now I have all the data needed. Let me compile the comprehensive component library catalog.

---

# 《SecretRoy 组件库目录》

> 扫描范围：`lib/widgets/`（25 个 Dart 文件）  
> 测试对比：`test/widgets/`（9 个测试文件）  
> 统计时间：2026-05-16

---

## 一、组件总览表

| 分类 | 数量 | 组件清单 |
|---|---|---|
| **布局组件** | 3 | `AdaptivePage`, `AdaptiveSection`, `AppLayoutBuilder` |
| **基础组件** | 18 | `AppHeroCard`, `AppPageHeader`, `SectionCard`, `AppSettingsGroup`, `AppSettingsTile`, `AppOptionTile`, `SelectionIndicator`, `GreenAddButton`, `ToneChip`, `SectionHeader`, `EmptyStatePlaceholder`, `InboxEmptyState`, `MetricChip`, `SyncInfoChip`, `AppNavBar`, `AppNavRail`, `NavBadgeIcon`, `AppNavDestination`, `AppSelectableScrollable` |
| **业务组件** | 16 | `AccountListTile`, `AccountFieldRow`, `AccountFieldRowBody`, `PasswordGeneratorSheet`, `LanSyncConflictSheet`, `LanSyncConflictOverlay`, `LanPairingCodeDialog`, `VaultLinkCodeDialog`, `SyncServerDialog`, `FieldEditorDialog`, `FieldPresetPreviewDialog`, `EditorMetric`, `EditMetadataRow`, `ActionSummaryCard`, `ActionItemCard`, `InboxFilterBar`, `InboxHeroMetrics` |
| **模型/数据类** | 4 | `AccountFieldDisplayData`, `PasswordGeneratorResult`, `PasswordGeneratorOptions`, `FieldEditorResult`, `MetricData`, `InboxSeverity`, `InboxAction`, `InboxItem` |

> 注：25 个文件中包含多个 `class` / 顶层函数，实际可复用单元约 40+ 个。

---

## 二、每个组件的详细说明

### 布局组件

#### `AdaptivePage` / `AdaptiveSection`
- **文件**：`lib/widgets/adaptive_page.dart`
- **功能**：响应式页面容器，根据屏幕宽度限制最大内容宽度（tablet ≤ 820, desktop ≤ 1240）
- **参数**：
  - `child: Widget`（必需）
  - `padding: EdgeInsetsGeometry`（默认 `horizontal: 8`）
  - `tabletMaxWidth: double`（默认 820）
  - `desktopMaxWidth: double`（默认 1240）
- **使用场景**：所有需要居中受限宽度的页面根容器
- **Dartdoc**：❌ 无

#### `AppLayoutBuilder`
- **文件**：`lib/widgets/app_layout_builder.dart`
- **功能**：三档断点（compact / medium / expanded）布局构建器，自动向后降级
- **参数**：
  - `compactBuilder: WidgetBuilder`（必需）
  - `mediumBuilder: WidgetBuilder?`
  - `expandedBuilder: WidgetBuilder?`
- **使用场景**：替代旧版 `PlatformBuilder`，实现移动端/桌面端差异化布局
- **Dartdoc**：✅ 有（6 行）

---

### 基础组件

#### `AppHeroCard`
- **文件**：`lib/widgets/app_hero_card.dart`
- **功能**：页面顶部 Hero 视觉焦点卡片，支持渐变背景、指标 chips、尾部操作区
- **参数**：
  - `icon: IconData`, `title: String`（必需）
  - `subtitle: String?`, `metrics: List<Widget>?`, `trailing: Widget?`
  - `gradientColors: List<Color>?`, `padding: EdgeInsetsGeometry?`
- **使用场景**：首页、统计页顶部 Hero 区域
- **Dartdoc**：✅ 有（4 行）
- **测试**：✅ `app_hero_card_test.dart`

#### `AppPageHeader`
- **文件**：`lib/widgets/app_page_header.dart`
- **功能**：标准页面头部，左侧图标容器 + 标题/副标题 + 可选尾部 widget + 指标 Wrap
- **参数**：
  - `icon: IconData`, `title: String`, `subtitle: String`（必需）
  - `metrics: List<Widget>`（默认空列表）, `trailing: Widget?`
- **使用场景**：设置页、列表页等非 Hero 页面头部
- **Dartdoc**：❌ 无
- **测试**：❌ 无

#### `SectionCard`
- **文件**：`lib/widgets/section_card.dart`
- **功能**：带标题和副标题的分区卡片，可选 outlined border 或 Material Card
- **参数**：
  - `title: String`, `child: Widget`（必需）
  - `subtitle: String?`, `padding: EdgeInsetsGeometry`（默认 `AppSpacing.xl2`）
  - `childGap: double`（默认 `AppSpacing.lg`）, `useOutlinedBorder: bool`（默认 false）
- **使用场景**：表单分区、信息分组展示
- **Dartdoc**：✅ 有（1 行）
- **测试**：✅ `section_card_test.dart`

#### `AppSettingsGroup` / `AppSettingsTile`
- **文件**：`lib/widgets/app_settings_group.dart`, `lib/widgets/app_settings_tile.dart`
- **功能**：设置页列表组容器（自动插入 Divider）+ 单个设置项（支持桌面端悬停反馈）
- **参数（Group）**：`children: List<Widget>`, `padding: EdgeInsetsGeometry?`
- **参数（Tile）**：`icon: IconData`, `title: String`, `subtitle: String?`, `onTap: VoidCallback?`, `showChevron: bool`（默认 true）, `trailing: Widget?`
- **使用场景**：所有设置页面
- **Dartdoc**：✅ 均有
- **测试**：✅ `app_settings_test.dart`（覆盖两者）

#### `AppOptionTile`
- **文件**：`lib/widgets/app_option_tile.dart`
- **功能**：单选/多选选项列表项，带圆形选中指示器动画
- **参数**：`icon: IconData`, `title: String`, `subtitle: String?`, `selected: bool`, `onTap: VoidCallback?`
- **使用场景**：主题选择、语言选择等单选列表
- **Dartdoc**：✅ 有
- **测试**：✅ `app_option_tile_test.dart`

#### `SelectionIndicator`
- **文件**：`lib/widgets/selection_indicator.dart`
- **功能**：带动画的圆形选中指示器（勾选图标）
- **参数**：`selected: bool`, `size: double`（默认 22）, `duration: Duration`（默认 160ms）
- **使用场景**：多选列表、批量操作状态指示
- **Dartdoc**：✅ 有（1 行）
- **测试**：❌ 无

#### `GreenAddButton`
- **文件**：`lib/widgets/green_add_button.dart`
- **功能**：固定绿色的圆形 FloatingActionButton（大/小两种尺寸）
- **参数**：`onPressed: VoidCallback?`, `tooltip: String`, `heroTag: Object?`, `small: bool`（默认 false）, `icon: IconData`（默认 `Icons.add`）
- **使用场景**：各列表页的添加按钮
- **Dartdoc**：❌ 无
- **测试**：❌ 无

#### `AppNavBar` / `AppNavRail` / `NavBadgeIcon` / `AppNavDestination`
- **文件**：`lib/widgets/app_nav_bar.dart`, `lib/widgets/app_nav_rail.dart`
- **功能**：移动端底部导航栏 + 桌面端侧边 NavRail + 带数字角标的图标 + 导航目的地数据类
- **参数（NavBar/NavRail）**：`selectedIndex: int`, `onDestinationSelected: ValueChanged<int>`, `destinations: List<AppNavDestination>`, `header/footer: Widget?`（仅 Rail）
- **使用场景**：应用主框架导航
- **Dartdoc**：✅ 均有
- **测试**：✅ `app_nav_test.dart`

#### `AppSelectableScrollable`
- **文件**：`lib/widgets/app_selectable_scrollable.dart`
- **功能**：桌面端/Web 自动包裹 `Scrollbar` + `SelectionArea`，触摸设备保持原生行为
- **参数**：`child: Widget`, `showScrollbar: bool`（默认 true）, `selectable: bool`（默认 true）, `controller: ScrollController?`
- **使用场景**：所有包含滚动列表的页面
- **Dartdoc**：✅ 有（9 行）
- **测试**：✅ `app_selectable_scrollable_test.dart`

#### `ToneChip` / `SectionHeader` / `EmptyStatePlaceholder`
- **文件**：`lib/widgets/account_edit_widgets.dart`
- **功能**：样式化标签芯片 / 分区标题（带图标+操作按钮）/ 空状态占位图
- **参数**：
  - `ToneChip`: `icon: IconData`, `label: String`, `tint: Color?`
  - `SectionHeader`: `icon: IconData`, `title: String`, `subtitle: String?`, `actionLabel: String?`, `onAction: VoidCallback?`, `accent: Color?`
  - `EmptyStatePlaceholder`: `icon: IconData`, `title: String`, `subtitle: String?`, `actionLabel: String?`, `onAction: VoidCallback?`
- **使用场景**：账号编辑页、通用空状态
- **Dartdoc**：✅ 均有
- **测试**：❌ 无

#### `MetricChip` / `SyncInfoChip`
- **文件**：`lib/widgets/inbox/inbox_hero_metrics.dart`, `lib/widgets/sync_settings_dialogs.dart`
- **功能**：指标 chip（值+标签）/ 同步状态信息 chip
- **参数（MetricChip）**：`value: String`, `label: String`, `color: Color`
- **参数（SyncInfoChip）**：`label: String`
- **使用场景**：Hero 指标区、同步设置页状态标签
- **Dartdoc**：✅ 均有

---

### 业务组件

#### `AccountListTile`
- **文件**：`lib/widgets/account_list_tile.dart`
- **功能**：核心账号列表项，支持展开/折叠动画、字段复制、敏感信息掩码、长按菜单、TOTP 徽章、同步状态指示
- **参数**：
  - `account: AccountItem`, `template: AccountTemplate?`, `onEdit: VoidCallback`, `onDelete: VoidCallback`（必需）
  - `hasMissingTemplate: bool`, `legacyFieldCount: int`, `linkedTotpCredentialCount: int`（默认 0）
  - `density: AccountListTileDensity`（默认 `library`）
  - `onTogglePin: VoidCallback?`, `localeText: String Function(...)`, `resolveAccountName: String? Function(String)?`
  - `highlightedFieldKeys: List<String>`（默认空）
- **内部子组件**：`_FieldCountTag`, `_TinyBadge`, `_IconButtonCompact`, `_SectionLabel`, `_FieldRow`, `_FieldActionButton`, `_ActionBar`, `_ActionButton`, `AccountFieldRow`（legacy public）, `AccountFieldRowBody`（legacy public）
- **使用场景**：账号库列表、搜索结果列表
- **Dartdoc**：⚠️ 公共类无注释，仅 3 个私有方法有 `///`
- **测试**：✅ `account_list_tile_test.dart`

#### `PasswordGeneratorSheet`
- **文件**：`lib/widgets/password_generator_sheet.dart`
- **功能**：底部弹出的密码生成器，支持长度滑块、字符类型开关、强度评分、复制/应用
- **参数**：
  - `initialOptions: PasswordGeneratorOptions`, `minLength: int`, `maxLength: int`（必需）
  - `title: String?`, `subtitle: String?`, `applyLabel: String?`, `showApplyAction: bool`（默认 true）
- **辅助 API**：`showPasswordGeneratorSheet()` 便捷函数，`PasswordGeneratorResult`, `PasswordGeneratorOptions`
- **内部子组件**：`_OptionTile`
- **使用场景**：账号编辑页密码字段、密码工具页
- **Dartdoc**：❌ 公共类无注释
- **测试**：✅ `password_generator_sheet_test.dart`

#### `LanSyncConflictSheet` / `LanSyncConflictOverlay`
- **文件**：`lib/widgets/lan_sync_conflict_sheet.dart`
- **功能**：LAN 同步冲突处理 BottomSheet + 自动监听并弹出的 Overlay Widget
- **参数（Sheet）**：`coordinator: LanSyncCoordinator`, `onConfirm: VoidCallback?`, `onCancel: VoidCallback?`
- **参数（Overlay）**：无（从 `ServiceManager` 自动获取 coordinator）
- **使用场景**：LAN 同步过程中自动弹出冲突确认
- **Dartdoc**：✅ 均有（9 行）
- **测试**：❌ 无

#### `LanPairingCodeDialog` / `VaultLinkCodeDialog` / `SyncServerDialog`
- **文件**：`lib/widgets/sync_settings_dialogs.dart`
- **功能**：8 位配对码输入对话框 / 保险库恢复码输入对话框 / 同步服务器 URL 配置对话框
- **参数**：均为标准 AlertDialog 参数（title, subtitle, confirmLabel, cancelLabel 等）
- **使用场景**：同步设置页、设备配对流程
- **Dartdoc**：✅ 均有
- **测试**：❌ 无

#### `FieldEditorDialog` / `FieldPresetPreviewDialog` / `EditorMetric`
- **文件**：`lib/widgets/template_edit_widgets.dart`
- **功能**：模板字段编辑器对话框 / 字段预设预览选择对话框 / 编辑器指标小部件
- **参数（FieldEditor）**：`initial: AccountField?`, `originallyPersisted: bool`, `fieldTypeLabelBuilder: String Function(AccountFieldType)`
- **参数（PresetPreview）**：`preset: FieldPreset`
- **辅助 API**：`fieldTypeLabel()`, `fieldTypeIcon()`, `FieldEditorResult`
- **使用场景**：模板编辑页
- **Dartdoc**：✅ 均有（7 行）
- **测试**：❌ 无

#### `EditMetadataRow`
- **文件**：`lib/widgets/edit_metadata_row.dart`
- **功能**：显示编辑时间/设备别名，长按显示绝对时间和完整 deviceId
- **参数**：`editedAt: int?`, `editedBy: String?`
- **使用场景**：账号编辑页底部元数据
- **Dartdoc**：❌ 无
- **测试**：❌ 无

#### `ActionSummaryCard` / `ActionItemCard`
- **文件**：`lib/widgets/inbox/inbox_action_card.dart`
- **功能**：收件箱大类摘要卡片（带数字高亮）/ 单个收件箱项卡片（带严重级别图标）
- **参数（Summary）**：`icon: IconData?`, `iconColor: Color?`, `backgroundColor: Color?`, `title: String`, `subtitle: String`, `onTap: VoidCallback?`, `leading: Widget?`
- **参数（Item）**：`severity: InboxSeverity`, `title: String`, `subtitle: String`, `meta: String?`, `showChevron: bool`, `onTap: VoidCallback?`, `trailing: Widget?`
- **内部子组件**：`_IconContainer`
- **使用场景**：通知中心/冲突收件箱
- **Dartdoc**：✅ 均有（9 行）
- **测试**：✅ `inbox_action_card_test.dart`

#### `InboxFilterBar<T>`
- **文件**：`lib/widgets/inbox/inbox_filter_bar.dart`
- **功能**：通用分类过滤栏（`ChoiceChip` 实现），支持泛型类别值
- **参数**：`categories: List<(T, String, String)>`, `selected: T`, `onSelected: ValueChanged<T>`
- **使用场景**：收件箱按类别过滤
- **Dartdoc**：✅ 有
- **测试**：❌ 无

#### `InboxHeroMetrics`
- **文件**：`lib/widgets/inbox/inbox_hero_metrics.dart`
- **功能**：收件箱 Hero 区域，包装 `AppPageHeader` 并映射 `MetricData` → `MetricChip`
- **参数**：`icon: IconData`, `title: String`, `subtitle: String`, `metrics: List<MetricData>`, `trailing: Widget?`
- **使用场景**：通知中心顶部
- **Dartdoc**：✅ 有
- **测试**：❌ 无

---

### 模型/数据类

| 名称 | 文件 | 说明 |
|---|---|---|
| `AccountFieldDisplayData` | `account_list_tile.dart` | 账号字段展示数据（label, value, isSecret, icon 等） |
| `AccountListTileDensity` | `account_list_tile.dart` | 密度枚举：`library`, `search` |
| `AppNavDestination` | `app_nav_rail.dart` | 导航目的地描述（icon, selectedIcon, label, badgeCount 等） |
| `PasswordGeneratorResult` | `password_generator_sheet.dart` | 密码生成结果（password + options） |
| `PasswordGeneratorOptions` | `password_generator_sheet.dart` | 密码生成选项（length, 四种字符类型开关） |
| `FieldEditorResult` | `template_edit_widgets.dart` | 字段编辑器返回结果（label, rawKey, description, attributes） |
| `MetricData` | `inbox_hero_metrics.dart` | 单一指标数据（value, label, color） |
| `InboxSeverity` | `inbox/inbox_models.dart` | 严重级别枚举：`critical`, `warning`, `info`, `success` |
| `InboxAction` | `inbox/inbox_models.dart` | 收件箱项动作描述（targetId / targetIds / onTap） |
| `InboxItem` | `inbox/inbox_models.dart` | 收件箱项抽象接口（id, severity, title, subtitle 等） |

---

## 三、组件依赖图

```
┌─────────────────────────────────────────────────────────────┐
│                     跨文件依赖（极轻）                        │
├─────────────────────────────────────────────────────────────┤
│  inbox_hero_metrics.dart ──import──► app_page_header.dart   │
│  app_nav_bar.dart        ──import──► app_nav_rail.dart      │
│         (导出 AppNavDestination)                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     文件内部子组件                            │
├─────────────────────────────────────────────────────────────┤
│  account_list_tile.dart                                     │
│    ├── _FieldCountTag                                       │
│    ├── _TinyBadge                                           │
│    ├── _IconButtonCompact                                   │
│    ├── _SectionLabel                                        │
│    ├── _FieldRow  (Stateful, 秘密掩码/复制/高亮)              │
│    ├── _FieldActionButton                                   │
│    ├── _ActionBar                                           │
│    ├── _ActionButton                                        │
│    └── AccountFieldRow / AccountFieldRowBody (legacy公开)    │
├─────────────────────────────────────────────────────────────┤
│  app_nav_bar.dart                                           │
│    └── _NavItem                                             │
├─────────────────────────────────────────────────────────────┤
│  app_nav_rail.dart                                          │
│    ├── NavBadgeIcon  (公开，被 NavBar 复用)                   │
│    └── _NavItem                                             │
├─────────────────────────────────────────────────────────────┤
│  inbox_action_card.dart                                     │
│    └── _IconContainer                                       │
├─────────────────────────────────────────────────────────────┤
│  password_generator_sheet.dart                              │
│    └── _OptionTile                                          │
└─────────────────────────────────────────────────────────────┘
```

**设计特点**：组件库高度解耦，几乎无跨文件 widget 依赖，每个文件自包含。唯一跨文件依赖是 `InboxHeroMetrics` 复用 `AppPageHeader`，以及 `AppNavBar` 复用 `AppNavRail` 导出的 `AppNavDestination` 数据类。

---

## 四、测试覆盖缺口

### 已有测试（9 个测试文件）

| 测试文件 | 覆盖的组件 |
|---|---|
| `test/widgets/account_list_tile_test.dart` | `AccountListTile` |
| `test/widgets/app_hero_card_test.dart` | `AppHeroCard` |
| `test/widgets/app_nav_test.dart` | `AppNavBar`, `AppNavRail` |
| `test/widgets/app_option_tile_test.dart` | `AppOptionTile` |
| `test/widgets/app_selectable_scrollable_test.dart` | `AppSelectableScrollable` |
| `test/widgets/app_settings_test.dart` | `AppSettingsGroup`, `AppSettingsTile` |
| `test/widgets/inbox_action_card_test.dart` | `ActionSummaryCard`, `ActionItemCard` |
| `test/widgets/password_generator_sheet_test.dart` | `PasswordGeneratorSheet` |
| `test/widgets/section_card_test.dart` | `SectionCard` |

### 缺少测试的组件（14 个文件）

| 文件 | 组件 | 优先级建议 |
|---|---|---|
| `lib/widgets/account_edit_widgets.dart` | `ToneChip`, `SectionHeader`, `EmptyStatePlaceholder` | 中 |
| `lib/widgets/adaptive_page.dart` | `AdaptivePage`, `AdaptiveSection` | 低 |
| `lib/widgets/app_layout_builder.dart` | `AppLayoutBuilder` | 低 |
| `lib/widgets/app_page_header.dart` | `AppPageHeader` | 中 |
| `lib/widgets/edit_metadata_row.dart` | `EditMetadataRow` | 中（依赖 ServiceManager） |
| `lib/widgets/green_add_button.dart` | `GreenAddButton` | 低 |
| `lib/widgets/lan_sync_conflict_sheet.dart` | `LanSyncConflictSheet`, `LanSyncConflictOverlay` | 高（业务复杂） |
| `lib/widgets/selection_indicator.dart` | `SelectionIndicator` | 低 |
| `lib/widgets/sync_settings_dialogs.dart` | `SyncInfoChip`, `LanPairingCodeDialog`, `VaultLinkCodeDialog`, `SyncServerDialog` | 中 |
| `lib/widgets/template_edit_widgets.dart` | `FieldEditorDialog`, `FieldPresetPreviewDialog`, `EditorMetric` | 高（业务复杂） |
| `lib/widgets/inbox/inbox_empty_state.dart` | `InboxEmptyState` | 低 |
| `lib/widgets/inbox/inbox_filter_bar.dart` | `InboxFilterBar` | 低 |
| `lib/widgets/inbox/inbox_hero_metrics.dart` | `InboxHeroMetrics`, `MetricChip` | 低 |
| `lib/widgets/inbox/inbox_models.dart` | `InboxSeverity`, `InboxAction`, `InboxItem` | 低（纯数据接口） |

> 测试覆盖率：约 **44%** 的 widget 文件有对应测试（9/25），按组件数量计算更低。

---

## 五、TODO / FIXME / HACK 清单

```
扫描结果：lib/widgets/ 目录下未发现任何 TODO / FIXME / HACK / XXX 注释。
```

> 该目录代码债务控制良好，无显式待办标记。

---

## 六、Dartdoc 覆盖情况

| 状态 | 文件数 | 文件清单 |
|---|---|---|
| **有 Dartdoc** | 20 | `app_hero_card`, `app_layout_builder`, `app_nav_bar`, `app_nav_rail`, `app_option_tile`, `app_selectable_scrollable`, `app_settings_group`, `app_settings_tile`, `section_card`, `account_edit_widgets`, `account_list_tile`(仅私有方法), `lan_sync_conflict_sheet`, `sync_settings_dialogs`, `template_edit_widgets`, `inbox_action_card`, `inbox_empty_state`, `inbox_filter_bar`, `inbox_hero_metrics`, `inbox_models`, `selection_indicator` |
| **无 Dartdoc** | 5 | `adaptive_page.dart`, `app_page_header.dart`, `edit_metadata_row.dart`, `green_add_button.dart`, `password_generator_sheet.dart` |

**重点缺口**：`AccountListTile`（核心组件，1321 行）公共类本身无类级 dartdoc，仅 2 个私有方法有注释；`PasswordGeneratorSheet`（587 行）公共类完全无 dartdoc。

---

## 七、关键发现与建议

1. **单文件多组件模式**：`account_list_tile.dart`（1321 行，含 10 个 class）、`password_generator_sheet.dart`（587 行）、`template_edit_widgets.dart`（527 行）文件过长，子组件未拆分到独立文件，维护成本随功能增长而上升。
2. **Legacy 兼容层**：`account_list_tile.dart` 底部保留了 `AccountFieldRow` / `AccountFieldRowBody` 公开兼容类，标注为 "Legacy public exports for backward compatibility"，建议评估是否已可移除。
3. **硬编码颜色**：`green_add_button.dart` 中 `kGreenAddButtonColor = Color(0xFF1FA463)` 是唯一硬编码品牌色，未走 Design Token 体系。
4. **Style Token 红线**：`account_list_tile.dart` 第 467 行存在 `BorderRadius.circular(AppRadii.card)` 的合规使用，但第 552 行 `BoxDecoration(color: accent.withAlpha(100))` 等存在大量硬编码 alpha 值。根据 `AGENTS.md`，`lib/widgets/` 被排除在 `check_style_tokens.py` 扫描之外，因此允许。
5. **测试缺口集中区**：对话框类（`FieldEditorDialog`, `LanPairingCodeDialog`, `VaultLinkCodeDialog`, `SyncServerDialog`）和 Sheet 类（`LanSyncConflictSheet`, `PasswordGeneratorSheet` 已有测试）是交互最复杂的组件，其中对话框类全部无测，建议优先补充。
