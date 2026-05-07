# 安全大笔记集成计划

> 基于现有架构的增量集成方案，复用 AccountItem/AccountTemplate/同步协议，只新增 UI 层和字段类型。

## 核心决策

1. **数据模型复用**：安全笔记 = `AccountItem` + `TemplateCategory.note` 模板
2. **导航不变**：底部导航保持 4 项，列表页内增加 [全部/账号/安全笔记] SegmentedButton 切换
3. **字段扩展**：新增 `AccountFieldType.longText`（多行文本）和 `list`（字符串列表）
4. **新建流程**：FAB 点击弹出 [新建账号] [新建安全笔记] 选择

## 实施步骤

### Phase 1：数据模型（~30 min）
- `AccountFieldType` 新增 `longText`, `list`
- `TemplateCategory` 新增 `note`
- `templateCategoryIcon` / `inferTemplateCategory` 适配
- 新增 3 个内置模板：`secure_note_generic`, `secure_note_mnemonic`, `api_service`
- `field_presets.dart` 新增安全笔记预设

### Phase 2：Provider（~20 min）
- `EnhancedAppProvider` 新增 `vaultItems`（全部）、`accountItems`（排除 note）、`secureNoteItems`（仅 note）
- 保留 `allAccounts` 兼容，新增按 category 过滤能力

### Phase 3：列表页（~40 min）
- `AccountListView` 顶部增加 `SegmentedButton`：[全部] [账号] [安全笔记]
- 安全笔记列表项差异化展示（标题 + 摘要，不显示字段详情）
- FAB 改为弹出选择菜单

### Phase 4：编辑页（~60 min）
- `account_edit_view.dart` `_buildFieldCard` 增加 `longText` / `list` 分支
- `longText`：多行文本框 + 折叠/展开 + 等宽字体
- `list`：可增删的字符串列表，每项可复制
- 助记词特殊交互：粘贴整段自动分词、网格显示、BIP39 温和校验

### Phase 5：搜索（~20 min）
- `HomeSearchView` 搜索范围覆盖安全笔记内容

### Phase 6：测试（~30 min）
- `dart analyze lib test`
- `flutter test`
- 手动验证：新建安全笔记、编辑、列表切换、搜索

## 兼容性

- 存储：完全复用 `AccountItem.data`，无新表
- 同步：完全复用 AEAD payload，无新协议
- CRDT：字符串级 merge，现有逻辑直接支持
- 旧数据：`TemplateCategory.custom` 的账号不受影响
