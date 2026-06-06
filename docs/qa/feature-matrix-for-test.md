# SecretRoy 功能测试矩阵（QA用）

> 面向对象：QA / 测试团队  
> 生成依据：功能清单 v1.0、平台能力矩阵、测试审计报告（540用例）、视图层扫描、质量缺口报告  
> 生成时间：2026-05-16  
> 标注说明：✅ 已有自动化测试（单元/Widget/集成）；🟡 部分自动化测试；❌ 建议补充（当前无/极低覆盖）

---

## 一、认证 / 解锁

### US-AUTH-01 首次创建保险库
- **故事描述**：作为新用户，我想要设置主密码并初始化保险库，以便安全存储我的账号数据。
- **前置条件**：应用为全新安装，本地无 `secret_roy_vault.db.enc` 文件。
- **测试步骤**：
  1. 冷启动应用，进入 `UnlockView`。
  2. 输入主密码（≥1位）。
  3. 确认密码（与步骤2一致）。
  4. 点击「创建保险库」。
  5. 等待初始化完成，观察是否自动进入 `HomeView`。
- **预期结果**：
  - 密码不一致时给出中文提示，不创建数据库。
  - 一致后数据库文件生成，身份（`deviceId` / `vaultId`）自动初始化。
  - 自动解锁并进入主页四栏布局。
- **涉及页面和组件**：`UnlockView`、`AdaptivePage`、`_HeroBadge`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/views/unlock_view_test.dart` + `test/services/enhanced_crypto_service_test.dart` + `test/services/database_file_cipher_test.dart`

### US-AUTH-02 主密码解锁
- **故事描述**：作为已有保险库的用户，我想要输入主密码解锁应用，以便访问我的数据。
- **前置条件**：保险库已创建，应用处于锁定状态（冷启动或后台超时）。
- **测试步骤**：
  1. 启动应用，进入 `UnlockView` 密码输入态。
  2. 输入正确主密码，点击解锁。
  3. 输入错误主密码，观察提示。
  4. 连续多次输入错误，观察是否崩溃或异常。
- **预期结果**：
  - 正确密码 → 解密成功 → 加载账号/模板 → 进入 `HomeView`。
  - 错误密码 → `invalidPassword` 提示，不解锁，不泄露数据。
  - 空密码/超长密码均 graceful 处理。
- **涉及页面和组件**：`UnlockView`、`ServiceManager`、`EnhancedCryptoService`
- **平台限制**：无
- **测试覆盖状态**：✅ `unlock_view_test.dart`、`enhanced_crypto_service_test.dart`、`database_file_key_manager_test.dart`

### US-AUTH-03 生物识别解锁
- **故事描述**：作为移动端用户，我想要通过 Face ID / 指纹快速解锁，以便无需输入主密码。
- **前置条件**：设备支持生物识别；已在 `SecuritySettingsView` 启用生物识别。
- **测试步骤**：
  1. 启用生物识别，主密码被加密存储到安全密钥库。
  2. 重新进入 `UnlockView`，观察是否出现生物识别入口。
  3. 触发生物识别（成功/取消/失败）。
  4. 在设置中禁用生物识别，再次进入解锁页。
- **预期结果**：
  - 启用后下次解锁显示生物识别图标/入口。
  - 认证成功 → 自动填充主密码 → 解锁。
  - 用户取消 → 回退到密码输入态。
  - 禁用后安全删除已存储的主密码，不再显示生物识别入口。
- **涉及页面和组件**：`UnlockView`、`BiometricAuthService`
- **平台限制**：❌ Linux 不支持；⚠️ Windows 依赖 Windows Hello 硬件与 `local_auth_windows` 行为可能不一致
- **测试覆盖状态**：✅ `test/services/biometric_auth_service_test.dart`

### US-AUTH-04 无密码模式
- **故事描述**：作为低安全需求场景的用户，我想要不设置主密码直接解锁，以便快速体验应用。
- **前置条件**：应用处于首次创建态或已在设置中启用无密码模式。
- **测试步骤**：
  1. 在 `UnlockView` 启用无密码模式。
  2. 观察解锁页是否直接显示「进入」按钮。
  3. 点击「进入」，验证是否成功解锁。
  4. 在设置中禁用无密码模式，恢复密码输入。
- **预期结果**：
  - 无密码模式下不显示密码输入框，显示「进入」按钮。
  - 数据库密钥仍通过随机密钥加密（非明文）。
  - 禁用后恢复主密码输入与验证流程。
- **涉及页面和组件**：`UnlockView`、`ServiceManager`、`VaultUnlockCoordinator`
- **平台限制**：⚠️ Web 端安全存储降级，不推荐启用
- **测试覆盖状态**：🟡 `test/services/service_manager_no_password_test.dart`（部分覆盖，缺专项边界测试）

### US-AUTH-05 自动锁定
- **故事描述**：作为安全意识强的用户，我想要应用在切后台或超时后自动锁定，以防他人窥探。
- **前置条件**：保险库已解锁，处于 `HomeView`。
- **测试步骤**：
  1. 设置自动锁定时长（5秒 / 1分钟 / 10分钟 / 永不）。
  2. 将应用切到后台，等待超过设定时长。
  3. 回到前台，观察是否回到 `UnlockView`。
  4. 测试「立即锁定」快捷入口/API。
  5. 测试「永不锁定」模式下切后台不触发锁定。
- **预期结果**：
  - 超时后密钥状态被清理，页面回到 `UnlockView`。
  - 切后台计时器暂停/恢复行为正确。
  - 永不锁定模式下切后台不触发。
- **涉及页面和组件**：`AutoLockService`、`AutoLockObserver`、`UnlockView`
- **平台限制**：⚠️ Web 端切后台行为受浏览器限制
- **测试覆盖状态**：✅ `test/services/auto_lock_service_test.dart`

### US-AUTH-06 修改主密码
- **故事描述**：作为用户，我想要定期更换主密码，以便提升保险库安全性。
- **前置条件**：保险库已解锁，当前主密码已知。
- **测试步骤**：
  1. 进入 `SecuritySettingsView` → 修改主密码。
  2. 输入旧密码 → 验证失败观察是否阻断。
  3. 输入正确旧密码 + 新密码 → 确认。
  4. 修改成功后退出，使用新密码解锁。
- **预期结果**：
  - 旧密码错误 → 不修改，提示错误。
  - 成功 → 数据库密钥 envelope 轮换，不解锁状态下不可用此功能。
  - 新密码可正常解锁，旧密码失效。
- **涉及页面和组件**：`SecuritySettingsView`、`EnhancedCryptoService`、`DatabaseFileKeyManager`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/services/database_file_key_manager_test.dart`

### US-AUTH-07 保险库销毁
- **故事描述**：作为用户，我想要彻底删除所有本地数据并重置应用，以便在弃用或转让设备时清除痕迹。
- **前置条件**：保险库已创建。
- **测试步骤**：
  1. 进入 `SecuritySettingsView` → 销毁保险库。
  2. 点击后观察二次确认对话框。
  3. 取消 → 数据保留；确认 → 等待清理完成。
  4. 观察是否回到根路由 `/`（`UnlockView`）。
  5. 再次启动应用，观察是否为新用户流程。
- **预期结果**：
  - 确认后删除所有加密文件、身份数据、安全存储内容。
  - 下次启动为首次创建保险库流程。
  - 取消后无任何数据丢失。
- **涉及页面和组件**：`SecuritySettingsView`、`ServiceManager`、`SecureStorageService`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/services/secure_storage_service_encryption_test.dart`（间接覆盖清理逻辑）

---

## 二、账号管理

### US-ACCT-01 账号列表浏览与排序
- **故事描述**：作为用户，我想要以网格或列表模式浏览所有账号，并按模板过滤和置顶排序，以便快速找到目标账号。
- **前置条件**：保险库已解锁，至少存在1个账号。
- **测试步骤**：
  1. 进入 `AccountListView`，观察默认布局模式。
  2. 切换网格/列表模式，观察展示变化。
  3. 使用模板下拉过滤，仅显示特定模板账号。
  4. 点击置顶按钮，观察排序变化。
  5. 验证 TOTP 徽章在列表中定时刷新。
- **预期结果**：
  - 网格/列表切换即时生效。
  - 置顶账号排在列表顶部，`isPinned` 持久化。
  - 模板过滤后仅显示匹配账号，清除后恢复全部。
- **涉及页面和组件**：`AccountListView`、`AccountListTile`、`AppPageHeader`、`TemplateListBody`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/views/account_list_view_test.dart` + `test/widgets/account_list_tile_test.dart`

### US-ACCT-02 新建/编辑账号
- **故事描述**：作为用户，我想要基于模板创建或编辑账号，并为字段生成密码，以便完整保存账号信息。
- **前置条件**：保险库已解锁，至少存在1个模板。
- **测试步骤**：
  1. 在 `AccountListView` 点击「+」进入 `AccountEditView`。
  2. 选择模板 → 填写各字段 → 对密码字段打开 `PasswordGeneratorSheet` 生成密码。
  3. 切换模板，观察旧字段保留与映射行为。
  4. 保存后回到列表，验证数据出现。
  5. 点击已有账号进入编辑，修改字段后保存。
- **预期结果**：
  - 新建后列表出现该账号，数据库 JSON 结构正确。
  - 编辑后字段更新，同步变更箱记录 update（如开启同步）。
  - 模板切换后旧字段保留在历史区，新字段按预设填充。
- **涉及页面和组件**：`AccountEditView`、`PasswordGeneratorSheet`、`AccountEditWidgets`、`EnhancedAppProvider`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/views/account_edit_view_test.dart`

### US-ACCT-03 账号删除与软删除
- **故事描述**：作为用户，我想要删除不再使用的账号，以便清理列表并保留同步标记。
- **前置条件**：保险库已解锁，至少存在1个账号。
- **测试步骤**：
  1. 在 `AccountListView` 长按账号 tile → 底部 Sheet 选择删除。
  2. 观察 AlertDialog 二次确认。
  3. 确认删除后观察列表变化。
  4. 验证数据库中该记录带有 `isDeleted` 标记。
  5. 重新打开数据库后验证软删除状态持久。
- **预期结果**：
  - 确认后账号从列表消失，数据库标记 `isDeleted`。
  - 同步变更箱记录 `delete` 变更（如开启同步）。
  - 取消后账号保留，无任何变更。
- **涉及页面和组件**：`AccountListView`、`AccountEditView`、`SecureStorageService`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/services/secure_storage_service_sync_outbox_test.dart`（create→update→delete 合并规则）

### US-ACCT-04 字段复制与安全剪贴板
- **故事描述**：作为用户，我想要复制账号字段值到剪贴板，并自动清理，以防敏感信息长期留存。
- **前置条件**：保险库已解锁，至少存在1个含字段值的账号。
- **测试步骤**：
  1. 在 `AccountListView` 或 `AccountEditView` 点击字段的「复制」按钮。
  2. 观察 SnackBar 复制成功提示。
  3. 立即粘贴验证剪贴板内容正确。
  4. 等待定时清理周期（或手动覆盖剪贴板），验证原内容被清空。
  5. 手动覆盖相同内容，验证 hash 匹配时不误删。
- **预期结果**：
  - 复制后剪贴板有值，显示 SnackBar 反馈。
  - 定时清理后剪贴板为空（或不再包含原内容）。
  - SHA-256 hash 比对确保仅清理自己复制的内容。
- **涉及页面和组件**：`AccountListView`、`AccountEditView`、`SensitiveClipboardService`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/services/sensitive_clipboard_service_test.dart`

### US-ACCT-05 敏感信息掩码
- **故事描述**：作为用户，我想要密码等敏感字段默认隐藏，点击后展开，以便在公共场合安全浏览。
- **前置条件**：保险库已解锁，至少存在1个含密码字段的账号。
- **测试步骤**：
  1. 进入 `AccountListView`，观察密码字段默认显示为掩码（如 `••••••`）。
  2. 点击展开图标，观察明文显示。
  3. 再次点击，恢复掩码。
- **预期结果**：
  - 默认掩码，不暴露明文。
  - 点击切换即时生效。
- **涉及页面和组件**：`AccountListView`、`AccountListTile`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/widgets/account_list_tile_test.dart`

### US-ACCT-06 TOTP 关联与解绑
- **故事描述**：作为用户，我想要将 2FA 凭证关联到账号，以便在列表中直接查看动态验证码。
- **前置条件**：保险库已解锁，已存在 TOTP 凭证。
- **测试步骤**：
  1. 进入 `AccountEditView`，找到 TOTP 关联区域。
  2. 选择已有 TOTP 凭证进行关联。
  3. 保存后回到 `AccountListView`，观察 tile 是否显示 TOTP 徽章。
  4. 再次编辑，取消关联，观察徽章消失。
- **预期结果**：
  - 关联后列表定时刷新并显示当前 TOTP 码。
  - 取消关联后徽章消失。
  - 关联不存在的凭证 graceful 处理。
- **涉及页面和组件**：`AccountEditView`、`TotpCredentialEditView`、`EnhancedAppProvider`
- **平台限制**：无
- **测试覆盖状态**：🟡 `TotpService` / `TotpImportService` 有单元测试，但视图层 `TotpCredentialEditView` ❌ 0% 覆盖

### US-ACCT-07 全局搜索
- **故事描述**：作为用户，我想要通过关键字快速搜索账号，并按模板进一步过滤，以便在大量账号中定位目标。
- **前置条件**：保险库已解锁，存在多个账号。
- **测试步骤**：
  1. 桌面端按 `Ctrl+F`（移动端点击搜索图标）唤起 `HomeSearchView`。
  2. 输入匹配关键字，观察实时过滤结果。
  3. 输入不存在的关键字，观察空状态。
  4. 使用模板多选过滤。
  5. 点击清除按钮，观察恢复全部。
  6. 按 `Esc` 关闭搜索页。
- **预期结果**：
  - 实时过滤结果正确，`AccountListTile` 复用展示。
  - 空关键字/清除后恢复全部账号。
  - 模板多选与关键字可组合过滤。
- **涉及页面和组件**：`HomeSearchView`、`SearchBar`、`AccountListTile`
- **平台限制**：⚠️ `Ctrl+F` / `Esc` 快捷键仅在桌面端注册
- **测试覆盖状态**：❌ `HomeSearchView` 无 Widget 测试；快捷键依赖集成测试

---

## 三、模板管理

### US-TPL-01 模板列表浏览
- **故事描述**：作为用户，我想要浏览所有内置和自定义模板，查看使用率统计，以便选择合适的模板创建账号。
- **前置条件**：保险库已解锁，首次启动后已自动创建内置模板。
- **测试步骤**：
  1. 在 `AccountListView` 切换 `showTemplates` 进入 `TemplateListBody`。
  2. 观察内置模板与自定义模板的分区展示。
  3. 观察各模板的使用率统计。
  4. 点击模板进入 `TemplateEditView`。
- **预期结果**：
  - 内置模板不可删除。
  - 使用率统计准确反映各模板关联的账号数量。
  - 继承模板的卡片上显示"继承 N"的标记 chip。
  - 网格布局正确渲染。
- **涉及页面和组件**：`TemplateListBody`、`_TemplateCard`、`_FieldPreviewTags`、`_InfoChip`、`AppSelectableScrollable`
- **平台限制**：无
- **测试覆盖状态**：🟡 `test/views/template_list_view_test.dart` 存在但实际覆盖率仅 **0.2%**（598行命中1行）

### US-TPL-02 新建/编辑模板
- **故事描述**：作为用户，我想要自定义字段、排序和图标，设置父模板继承，添加限定关联和嵌套子表单字段，以便创建符合个人需求的模板。
- **前置条件**：保险库已解锁。
- **测试步骤**：
  1. 进入 `TemplateEditView`（新建或编辑）。
  2. 添加字段 → 选择字段预设（如「银行卡」「身份证号」），或从 12 种字段类型中选择（文本/密码/数字/邮箱/电话/网址/时间/关联账户/模板关联/嵌套子表单/多行文本/列表）。
  3. 选择「模板关联」类型 → 在目标模板下拉中选择模板 → 保存字段后观察字段卡片中目标模板名+预览字段。
  4. 选择「嵌套子表单」类型 → 选择子表单模板 + 设置最大子项数 → 保存后观察字段卡片中子模板预览。
  5. 拖拽排序字段（继承字段不可排序，灰色显示）。
  6. 在「父模板继承」区域点击添加 → 弹出继承选择器（排除自身和会循环的模板）→ 多选 → 确定后观察继承字段在网格中以灰色渲染并显示来源。
  7. 保存后回到列表验证，观察继承模板卡片显示"继承 N"标记。
- **预期结果**：
  - 字段增删改排序即时反映在预览区。
  - 预设字段 key 唯一，重复添加同一 preset 有处理策略。
  - templateRef/subForm 字段卡片显示目标模板字段预览（前 5 个字段名+类型图标）。
  - 继承字段不可编辑/删除/重排，来源清晰标注。
  - 保存后模板可用，账号创建时可选。
- **涉及页面和组件**：`TemplateEditView`、`FieldEditorDialog`、`TemplateEditWidgets`、`GreenAddButton`、`_buildInheritanceSection`、`_getResolvedFields`、`_buildTargetTemplatePreview`、`TemplateInheritancePicker`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/views/template_edit_view_test.dart`（基础 CRUD，未覆盖新字段类型和继承）

### US-TPL-03 模板导入/导出
- **故事描述**：作为用户，我想要将模板导出为 JSON 或从 JSON 导入，以便备份或在设备间迁移模板。
- **前置条件**：保险库已解锁，存在自定义模板。
- **测试步骤**：
  1. 在 `TemplateListBody` 选择单条或批量导出。
  2. 验证导出 JSON 包含完整字段定义。
  3. 在其他设备/清数据后导入该 JSON。
  4. 验证导入后模板可用，无重复 ID 冲突。
- **预期结果**：
  - 导出 JSON 结构完整，包含字段、图标、徽章信息。
  - 导入后模板列表正确更新，与已有模板共存或覆盖策略正确。
- **涉及页面和组件**：`TemplateListBody`、`VaultImportExportCoordinator`
- **平台限制**：无
- **测试覆盖状态**：🟡 `test/system/vault_import_export_coordinator_test.dart` 存在但协调器覆盖率仅 **1.3%**

### US-TPL-04 模板删除
- **故事描述**：作为用户，我想要删除不再使用的自定义模板，但被使用时禁止删除，以防误删导致数据混乱。
- **前置条件**：保险库已解锁，存在自定义模板。
- **测试步骤**：
  1. 在 `TemplateListBody` 长按/点击删除自定义模板（未被任何账号使用）。
  2. 验证删除成功，列表更新。
  3. 尝试删除正在被账号引用的模板。
  4. 验证是否被阻止并给出提示。
- **预期结果**：
  - 未使用模板可软删除，数据库标记 `isDeleted`。
  - 使用中模板删除抛异常/被阻止，给出中文提示。
- **涉及页面和组件**：`TemplateListBody`、`TemplateEditView`、`SecureStorageService`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/views/template_list_view_test.dart` / `template_edit_view_test.dart`（间接覆盖）

### US-TPL-05 模板限定关联字段 (TemplateRef)
- **故事描述**：作为用户，我想要在自定义模板中添加一个限定目标模板的关联字段，以便在填写账户时只显示使用指定模板的账户列表。
- **前置条件**：保险库已解锁，存在至少 2 个不同模板以及基于它们创建的账户。
- **测试步骤**：
  1. 新建/编辑自定义模板，点击添加字段。
  2. 在「字段类型」下拉中选择「模板关联」。
  3. 观察是否自动勾选「关联字段」开关，且非关联属性（保密/可搜索/可复制）开关被隐藏。
  4. 在「目标模板」下拉中选择一个已有模板（如「服务器」）。
  5. 保存字段后，在字段网格中观察是否显示目标模板名和字段预览（目标模板的前 5 个字段名+类型图标）。
  6. 保存模板后，用该模板创建/编辑账户。
  7. 在账户编辑页中，观察模板关联区域标题是否显示"仅限 [目标模板名]"的筛选标记。
  8. 点击「选择账户」，观察弹窗列表是否仅显示使用目标模板的账户。
  9. 选择一个关联账户后，观察关联卡片是否显示账户名+模板名+前 3 个非保密字段值的摘要行（如 `192.168.1.100 · root · 22`）。
  10. 点击关联卡片，验证是否跳转到关联账户的编辑页。
  11. 点击「清除关联」，验证关联被移除且状态回到空。
  12. 删除被 templateRef 引用的模板，验证是否被阻止并提示"被字段 'XXX' 引用"。
- **预期结果**：
  - 字段编辑器正确显示目标模板下拉，排除自身模板。
  - 账户编辑页的账户选择器正确按模板过滤。
  - 关联卡片展示关键信息摘要。
  - 删除被引用的目标模板时被阻止，提示具体的引用字段和来源模板。
- **涉及页面和组件**：`TemplateEditView`、`FieldEditorDialog`、`AccountEditView._buildTemplateRefSection`、`_showAccountPicker`、`_buildLinkedAccountCard`、`SecureStorageService.deleteTemplate`
- **平台限制**：无
- **测试覆盖状态**：❌ 当前无专项自动化测试；建议补充 widget 测试覆盖字段编辑器下拉、账户选择器过滤逻辑。

### US-TPL-06 模板继承 (Template Inheritance)
- **故事描述**：作为用户，我想要自定义模板继承一个或多个父模板的全部字段，以便复用常用字段组合而无需重复定义。
- **前置条件**：保险库已解锁，存在至少 1 个自定义模板和 1 个父模板。
- **测试步骤**：
  1. 新建/编辑自定义模板，观察是否出现「父模板继承」卡片区域。
  2. 点击「添加父模板」，观察弹窗列表是否排除自身（和会造成循环的模板）。
  3. 选择一个父模板后点击确定，观察父模板是否以 Chip 形式出现在继承区。
  4. 观察是否实时显示"已解析字段：X 个（继承 Y + 自有 Z）"的预览文本。
  5. 在字段网格中观察继承字段：
     a. 是否以灰色样式渲染。
     b. 是否显示"继承自 'XXX'"标签。
     c. 编辑/上移/下移/删除按钮是否被隐藏。
  6. 添加一个与继承字段同 key 的自有字段，观察自有字段是否覆盖继承字段。
  7. 删除一个父模板 Chip，观察对应的继承字段是否从网格中消失。
  8. 点击「清除全部」，观察所有父模板被移除。
  9. 保存模板后，用该模板创建/编辑账户——验证字段表单是否包含继承字段。
  10. 在模板列表中观察继承模板卡片是否显示"继承 N"标记。
  11. 尝试添加会造成循环的父模板（如 A 继承 B，再让 B 继承 A），验证是否被阻塞并提示"会造成循环引用"。
  12. 删除被其他模板继承的父模板，验证是否被阻止并提示被子模板列表。
- **预期结果**：
  - 继承字段在编辑器中不可编辑/不可删除/不可重排，但正常显示在账户编辑页。
  - 字段计数、保存校验基于解析后的全部字段（继承+自有）。
  - 循环引用在父模板选择器中被实时阻止（灰显+提示），在 API 保存时再次校验。
  - 导入模板时，`parentTemplateIds` 中不存在的模板引用被自动剔除。
- **涉及页面和组件**：`TemplateEditView._buildInheritanceSection`、`_getResolvedFields`、`_buildFieldGrid`、`_buildFieldCard`、`TemplateInheritancePicker`、`TemplateReferenceValidator`、`SecureStorageService._validateTemplateReferences`、`parseTemplateExport`、`EnhancedAppProvider.resolveFields`
- **平台限制**：无
- **测试覆盖状态**：❌ 当前无专项自动化测试；建议补充 widget 测试覆盖继承选择器弹窗、字段解析去重、循环检测边界。

### US-TPL-07 嵌套子表单字段 (SubForm)
- **故事描述**：作为用户，我想要在模板中添加一个可重复的嵌套子表单字段，每个子项使用另一个模板的字段结构，以便在一个账户中管理多条结构化数据（如服务器的多个 SSH Key）。
- **前置条件**：保险库已解锁，存在至少 2 个模板（一个作为容器，一个作为子表单模板）。
- **测试步骤**：
  1. 新建/编辑自定义模板，点击添加字段。
  2. 在「字段类型」下拉中选择「嵌套子表单」。
  3. 在「子表单模板」下拉中选择目标模板（验证是否排除自身和会造成递归的模板）。
  4. 在「最大子项数」输入框中输入限制数字（或留空表示不限制）。
  5. 保存字段后，观察字段网格中是否显示目标模板名+字段预览（同 templateRef 的预览效果）。
  6. 保存模板后，用该模板创建/编辑账户。
  7. 在账户编辑页中观察子表单区域：
     a. 标题是否显示字段名+子模板名。
     b. 计数是否显示"已添加 X 个 / 最多 Y 个"。
  8. 点击「添加子项」，观察子项编辑器弹窗是否渲染子模板的全部字段（排除子模板自身的 subForm 字段以限制 1 层嵌套）。
  9. 填写字段后点击确定，观察子项卡片是否出现在列表中，摘要是否显示前 3 个非保密字段值。
  10. 点击子项卡片的展开箭头，观察是否展开显示全部非保密字段（字段名-字段值行），保密字段以计数方式显示。
  11. 在展开状态下点击「编辑」，观察是否弹出预填数据的编辑弹窗。
  12. 在展开状态下点击「删除」，确认后观察子项是否被移除。
  13. 在编辑模式下，拖拽子项卡片的拖拽手柄（`≡`），观察是否可以重排顺序，释放后列表是否按新顺序渲染。
  14. 当子项数达到最大限制时，观察「添加子项」按钮是否消失。
  15. 保存账户后重新打开，验证子项数据（JSON 数组）是否正确持久化。
  16. 删除被子表单引用的模板，验证是否被阻止并提示"被字段 'XXX' 的子表单引用"。
- **预期结果**：
  - 子项编辑器仅渲染非 subForm 字段，嵌套深度限制为 1 层。
  - 子项增删改即时反映在 `_draftData` 中，拖拽排序后 JSON 数组顺序正确。
  - 展开卡片的摘要和详情数据正确，保密字段不泄露。
  - 删除被子表单引用的模板时被阻止并给出明确提示。
  - 导入模板时，`subTemplateId` 引用不存在的模板被自动剔除。
- **涉及页面和组件**：`AccountEditView._buildSubFormSection`、`_ExpandableSubItem`、`_SubFieldRow`、`_addSubItem`、`_editSubItem`、`_showSubItemEditor`、`ReorderableListView`、`FieldEditorDialog`、`SecureStorageService._validateTemplateReferences`、`_countSubFormItemsByTemplate`
- **平台限制**：无
- **测试覆盖状态**：❌ 当前无专项自动化测试；建议补充 widget 测试覆盖子项增删改拖拽全流程、最大数量限制、嵌套深度限制。

### US-TPL-08 模板引用删除保护
- **故事描述**：作为用户，当我尝试删除一个模板时，系统应全面检查该模板是否被其他模板引用（继承/关联/子表单/子项数据），并根据引用类型给出明确的阻止提示。
- **前置条件**：保险库已解锁，存在模板间引用关系（某模板被另一个继承、被 templateRef 字段引用、被 subForm 字段引用、或有子项数据使用该模板）。
- **测试步骤**：
  1. **继承引用**：模板 A 被模板 B 继承。在列表删除 A，验证是否阻止并提示"继承: [B 的标题]"。
  2. **templateRef 引用**：模板 X 的字段引用了模板 Y 作为目标模板。删除 Y，验证是否阻止并提示"字段 '关联' 引用于模板 'X'"。
  3. **subForm 引用**：模板 P 的字段引用了模板 Q 作为子表单模板。删除 Q，验证是否阻止并提示"子表单项: 字段 'SSH Keys' of 模板 'P'"。
  4. **子项数据引用**：账户中已存在使用模板 S 的子项数据。删除 S，验证是否阻止并提示"子表单项: X 条记录仍在使用"。
  5. **无引用**：模板无任何引用关系且无账户使用。删除成功，模板被软删除（`isDeleted=1`）。
- **预期结果**：
  - 所有引用类型在删除前均被检查，不同引用类型给出不同错误提示。
  - 同步合并删除（`isSyncMerge=true`）同样执行引用检查，不留下悬空引用。
- **涉及页面和组件**：`SecureStorageService.deleteTemplate`、`_countSubFormItemsByTemplate`
- **平台限制**：无
- **测试覆盖状态**：❌ 当前无专项自动化测试；建议补充单元测试覆盖各引用类型的删除保护逻辑。

### US-TPL-09 模板导入引用清扫
- **故事描述**：作为用户，当我导入的模板 JSON 中包含不存在的 `parentTemplateIds`、`targetTemplateId` 或 `subTemplateId` 引用时，系统应自动剔除无效引用而非崩溃。
- **前置条件**：保险库已解锁，准备导入的 JSON 中含本地不存在的模板 ID 引用。
- **测试步骤**：
  1. 导出一个继承了父模板 P 的模板 A。在另一个不含 P 的保险库中导入 A 的 JSON。
  2. 验证导入后 A 的 `parentTemplateIds` 中是否已剔除 P 的 ID。
  3. 同法测试导入含无效 `targetTemplateId` 的模板——该字段的 `targetTemplateId` 被置空。
  4. 同法测试导入含无效 `subTemplateId` 的模板——该字段的 `subTemplateId` 被置空。
  5. 验证导入后模板功能正常，无效引用不影响模板的创建/编辑/使用。
- **预期结果**：
  - 导入不抛出异常，无效引用被静默剔除。
  - 剔除后模板可正常编辑——引用字段显示为"未选择目标模板/子表单模板"。
- **涉及页面和组件**：`parseTemplateExport`
- **平台限制**：无
- **测试覆盖状态**：❌ 当前无专项自动化测试；建议补充单元测试覆盖导入引用清扫逻辑。

---

## 四、TOTP / 2FA

### US-TOTP-01 TOTP 码生成
- **故事描述**：作为用户，我想要在账号列表中直接查看 TOTP 动态验证码，以便快速完成两步验证。
- **前置条件**：保险库已解锁，已存在至少1个有效的 TOTP 凭证并关联到账号。
- **测试步骤**：
  1. 进入 `AccountListView`，观察已关联 TOTP 的账号 tile。
  2. 验证显示的 6/8 位数字码与标准工具（如 `oathtool`）一致。
  3. 等待 30 秒周期，验证码自动刷新。
  4. 验证倒计时指示器（如有）同步递减。
- **预期结果**：
  - TOTP 码与 RFC 6238 标准向量一致。
  - SHA1/SHA256/SHA512 算法均正确。
  - 30s/60s 周期切换后码值正确。
- **涉及页面和组件**：`AccountListView`、`TotpService`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/services/totp_service_test.dart`（RFC 6238 标准向量验证）

### US-TOTP-02 TOTP 凭证手动创建/编辑
- **故事描述**：作为用户，我想要手动输入 TOTP 密钥或粘贴 otpauth URI，以便添加 2FA 凭证。
- **前置条件**：保险库已解锁。
- **测试步骤**：
  1. 进入 `TotpCredentialEditView`。
  2. 手动输入 secret、issuer、accountName。
  3. 粘贴完整 `otpauth://totp/...` URI，观察自动解析。
  4. 粘贴缺失参数的 URI，观察 graceful fallback。
  5. 粘贴非法 URI，观察报错提示。
  6. 保存后验证实时预览显示的 TOTP 码正确。
- **预期结果**：
  - 完整 URI 正确解析并填充各字段。
  - 缺失参数时使用合理默认值。
  - 非法 URI 给出用户可理解的中文错误提示，不崩溃。
- **涉及页面和组件**：`TotpCredentialEditView`、`TotpService`、`TotpImportService`
- **平台限制**：无
- **测试覆盖状态**：❌ `TotpCredentialEditView` 覆盖率 **0.0%**；服务层 `totp_import_service_test.dart` ✅

### US-TOTP-03 扫码导入 TOTP（移动端）
- **故事描述**：作为移动端用户，我想要通过相机扫描二维码快速导入 TOTP 凭证。
- **前置条件**：保险库已解锁；设备为 Android/iOS；已授予相机权限。
- **测试步骤**：
  1. 在 `TotpCredentialEditView` 点击「扫码」按钮。
  2. 进入 `TotpQrScannerView`，观察相机预览。
  3. 扫描有效的 TOTP QR 码。
  4. 扫描无效的 QR 码。
  5. 点击取消返回编辑页。
- **预期结果**：
  - 有效 QR 码 → 自动解析并回填字段。
  - 无效 QR 码 → 给出错误提示，不崩溃。
  - 取消 → 无数据变更，正常返回。
- **涉及页面和组件**：`TotpQrScannerView`、`MobileScanner`、`TotpImportService`
- **平台限制**：❌ 仅 Android / iOS 支持；桌面端/Web 不显示「扫码」按钮
- **测试覆盖状态**：❌ `TotpQrScannerView` 覆盖率 **0.0%**；重度依赖相机硬件，建议 mock `MobileScanner`

### US-TOTP-04 图片 QR 解码导入
- **故事描述**：作为桌面端用户，我想要从剪贴板图片或文件中解码 QR 码导入 TOTP，以便无需相机完成导入。
- **前置条件**：保险库已解锁；剪贴板中已有 QR 图片或已选择图片文件。
- **测试步骤**：
  1. 在 `TotpCredentialEditView` 点击「粘贴二维码」或选择图片文件。
  2. `TotpQrImageImportService` 解码图片中的 QR 码。
  3. 验证有效 QR 图片正确导入。
  4. 验证非 QR 图片给出错误提示。
  5. 验证剪贴板无图片时 graceful 处理。
- **预期结果**：
  - 有效 QR 图片正确解析 otpauth URI 并填充字段。
  - 非 QR 图片/无法解码时给出中文提示。
  - 纯 Dart 解码，不依赖平台原生库。
- **涉及页面和组件**：`TotpCredentialEditView`、`TotpQrImageImportService`
- **平台限制**：⚠️ Linux 剪贴板图片读取依赖桌面环境工具链
- **测试覆盖状态**：✅ `test/services/totp_qr_image_import_service_test.dart`

### US-TOTP-05 TOTP 关联账号多选
- **故事描述**：作为用户，我想要将一个 TOTP 凭证关联到多个账号，以便复用同一个 2FA 密钥。
- **前置条件**：保险库已解锁，存在多个账号和至少1个 TOTP 凭证。
- **测试步骤**：
  1. 在 `TotpCredentialEditView` 的关联区域多选账号。
  2. 保存后验证各关联账号的 tile 均显示 TOTP 徽章。
  3. 取消部分关联，保存后验证徽章消失。
  4. 删除账号后验证关联自动清理。
- **预期结果**：
  - 多选关联保存正确，列表实时更新。
  - 取消关联后对应账号不再显示 TOTP。
  - 删除账号后引用自动清理，无 dangling 关联。
- **涉及页面和组件**：`TotpCredentialEditView`、`EnhancedAppProvider`
- **平台限制**：无
- **测试覆盖状态**：🟡 模型与 Provider 有测试，但视图层 `TotpCredentialEditView` ❌ 0% 覆盖

---

## 五、同步

### US-SYNC-01 同步服务器配置
- **故事描述**：作为用户，我想要配置自托管的同步服务器地址，以便在多设备间同步数据。
- **前置条件**：保险库已解锁。
- **测试步骤**：
  1. 进入 `SyncSettingsView`，找到服务器 URL 输入框。
  2. 输入合法 URL（如 `https://roy.example.com`）。
  3. 移动端尝试输入 `127.0.0.1:8080` / `localhost`，观察是否被拒绝。
  4. 保存后退出应用，再次进入验证配置持久。
  5. 清空 URL，验证同步被禁用。
- **预期结果**：
  - 合法 URL 保存成功，下次启动仍有效。
  - 移动端 loopback URL 被拒绝并给出中文提示。
  - 空 URL 表示禁用同步。
- **涉及页面和组件**：`SyncSettingsView`、`SyncCoordinator`、`SyncServerUrlStore`
- **平台限制**：⚠️ 移动端禁止 loopback URL；桌面端默认 `127.0.0.1:8080`
- **测试覆盖状态**：❌ `SyncSettingsView` 无 Widget 测试；`SyncServerUrlStore` ✅ 100% 覆盖率

### US-SYNC-02 即时同步（Pull/Push）
- **故事描述**：作为用户，我想要手动触发与服务端的同步，以便拉取远程变更或推送本地修改。
- **前置条件**：保险库已解锁，已配置有效同步服务器，设备在线。
- **测试步骤**：
  1. 在 `SyncSettingsView` 或 `LocalSyncQueueView` 点击「即时同步」。
  2. 观察同步状态变化：`syncing` → `synced` / `error`。
  3. 在线时触发 Pull → 验证远程变更合并到本地。
  4. 在线时触发 Push → 验证本地变更推送到服务端。
  5. 断网时触发同步 → 验证进入 `error` 或 `offline` 状态。
- **预期结果**：
  - Pull 成功：远程变更合并，冲突时进入 `conflictRecovery`。
  - Push 成功：本地变更箱清空，服务端数据一致。
  - 网络错误：状态机进入 `error`，给出中文提示，不崩溃。
- **涉及页面和组件**：`SyncSettingsView`、`LocalSyncQueueView`、`SyncService`、`SyncCoordinator`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/sync/sync_state_machine_test.dart` + `multi_device_sync_test.dart`

### US-SYNC-03 本地同步变更箱
- **故事描述**：作为用户，我想要查看尚未推送的本地变更，并选择单条/批量推送或撤销，以便精确控制同步内容。
- **前置条件**：保险库已解锁，已存在未推送的 create/update/delete 变更（如编辑/删除账号后）。
- **测试步骤**：
  1. 进入 `LocalSyncQueueView`，观察待同步变更列表。
  2. 验证 create/update/delete 三种类型正确展示。
  3. 点击单条推送，验证推送成功后从列表移除。
  4. 点击批量推送，验证全部推送成功。
  5. 点击撤销，验证数据库回退到变更前状态。
- **预期结果**：
  - 三种变更类型正确记录与展示。
  - 推送成功后变更箱清除对应项。
  - 撤销后数据库状态回退，列表更新。
- **涉及页面和组件**：`LocalSyncQueueView`、`SyncService`、`SecureStorageService`、`InboxEmptyState`
- **平台限制**：无
- **测试覆盖状态**：❌ `LocalSyncQueueView` 无 Widget 测试；服务层 `secure_storage_service_sync_outbox_test.dart` ✅

### US-SYNC-04 CRDT 冲突合并
- **故事描述**：作为多设备用户，我想要不同设备上的编辑自动合并，以便冲突时数据不丢失。
- **前置条件**：多设备环境，或模拟多设备同步冲突场景。
- **测试步骤**：
  1. 设备 A 修改账号字段 X，设备 B 修改同一账号字段 Y。
  2. 触发同步，观察后台 `CRDTMergeEngine` 自动合并。
  3. 设备 A/B 同时修改同一字段，触发真正的字段级冲突。
  4. 验证 HLC 时钟递增，同一字段多设备编辑 deterministic。
- **预期结果**：
  - 不同字段同时编辑 → 自动合并，两端数据一致。
  - 同一字段冲突 → 按 HLC + LWW 策略确定胜者，或进入冲突收件箱。
  - 合并结果可复现（deterministic）。
- **涉及页面和组件**：`CRDTMergeEngine`、`SyncService`（后台）
- **平台限制**：无
- **测试覆盖状态**：✅ `test/sync/crdt_merge_engine_test.dart` + `crdt_merge_invariants_test.dart` + `sync_conflict_recovery_test.dart`

### US-SYNC-05 冲突收件箱
- **故事描述**：作为用户，我想要查看无法自动合并的字段级冲突，并选择接受本地版本或全部忽略，以便掌控数据归属。
- **前置条件**：保险库已解锁，同步过程中产生了冲突日志。
- **测试步骤**：
  1. 进入 `ConflictInboxView`，观察冲突列表。
  2. 点击单个冲突项，查看字段级差异详情。
  3. 点击「接受本地」，验证本地数据覆盖远程。
  4. 点击「全部忽略」，验证保留远程版本，冲突列表清空。
- **预期结果**：
  - 冲突正确展示为 inbox 项，包含字段级差异。
  - 接受本地后数据覆盖，同步状态恢复。
  - 全部忽略后保留远程，冲突列表为空。
- **涉及页面和组件**：`ConflictInboxView`、`InboxEmptyState`、`ServiceManager`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/views/conflict_inbox_view_test.dart`

### US-SYNC-06 离线恢复码导入/导出
- **故事描述**：作为用户，我想要导出加密恢复码，以便在没有网络或服务器不可用时迁移保险库身份。
- **前置条件**：保险库已解锁。
- **测试步骤**：
  1. 进入 `SyncSettingsView` → 导出离线恢复码。
  2. 设置导出密码，观察生成的 `sroy-recovery:` 前缀加密字符串。
  3. 在另一台设备/清数据后导入该恢复码。
  4. 输入正确密码导入，验证身份一致（`deviceId` / `vaultId` 匹配）。
  5. 输入错误密码，验证解密失败。
- **预期结果**：
  - 导出码加密不可读，不含明文密钥。
  - 正确密码解密成功，身份恢复。
  - 错误密码解密失败，给出中文提示。
- **涉及页面和组件**：`SyncSettingsView`、`IdentityService`、`VaultImportExportCoordinator`
- **平台限制**：⚠️ Web 端导出/导入行为可能受限（安全存储降级）
- **测试覆盖状态**：✅ `test/services/identity_service_test.dart` + `test/services/vault_pairing_crypto_test.dart`

### US-SYNC-07 备份包导出/验证
- **故事描述**：作为用户，我想要导出完整加密的备份包并验证完整性，以便定期备份保险库。
- **前置条件**：保险库已解锁，存在账号/模板数据。
- **测试步骤**：
  1. 进入 `SyncSettingsView` → 导出备份包。
  2. 设置备份密码，等待导出完成。
  3. 点击验证备份包，验证完整性通过。
  4. 故意损坏备份包文件，验证完整性失败。
  5. 导入备份包，验证数据一致。
- **预期结果**：
  - 导出包加密完整，含校验信息。
  - 验证通过表示包完好；验证失败给出提示。
  - 导入后数据与导出时一致。
- **涉及页面和组件**：`SyncSettingsView`、`VaultDumpCoordinator`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/system/vault_dump_coordinator_test.dart`

---

## 六、设备配对

### US-PAIR-01 LAN 面对面配对
- **故事描述**：作为用户，我想要在同一 WiFi 下与新设备快速配对传输数据，无需公网服务器。
- **前置条件**：两台设备在同一局域网；均为原生平台（非 Web）。
- **测试步骤**：
  1. 设备 A（主机）进入 `SyncSettingsView` → 启动 LAN 面对面链接。
  2. 设备 B（客户端）进入同一页面 → 搜索主机。
  3. 设备 B 发现主机后输入 8 位配对码。
  4. 验证配对码校验成功，claim 流程完成。
  5. 验证 X25519 密钥交换，加密传输 bundle。
  6. 设备 B 成功拉取数据并导入。
- **预期结果**：
  - UDP 广播发现可达，HTTP claim 成功。
  - 配对码错误时拒绝连接。
  - 传输过程 X25519 端到端加密，无中间明文。
- **涉及页面和组件**：`SyncSettingsView`、`LanPairingService`、`VaultPairingCrypto`
- **平台限制**：❌ Web 不支持（`dart:io` 的 `HttpServer` / `RawDatagramSocket` 不可用）
- **测试覆盖状态**：🟡 `test/sync/lan_pairing_service_test.dart` 存在，但端到端依赖手动验证；`vault_pairing_crypto_test.dart` ✅

### US-PAIR-02 服务端中继配对
- **故事描述**：作为不在同一局域网的远程用户，我想要通过自托管服务器创建配对会话并审批请求，以便安全传输数据。
- **前置条件**：保险库已解锁，已配置有效的 `roy_server` 地址。
- **测试步骤**：
  1. 设备 A 在 `SyncSettingsView` 创建配对会话，获取配对码。
  2. 设备 B 使用配对码加入会话。
  3. 设备 A 收到配对请求，点击审批。
  4. 设备 B 状态变更为已审批，拉取加密 bundle。
  5. 验证 bundle 解密后数据正确。
- **预期结果**：
  - 创建/加入会话成功，配对码有效。
  - 审批后状态正确变更。
  - 拉取的 bundle 解密后与源数据一致。
- **涉及页面和组件**：`SyncSettingsView`、`VaultPairingService`、`VaultPairingCoordinator`
- **平台限制**：无
- **测试覆盖状态**：🟡 `test/services/vault_pairing_service_test.dart` 无独立测试，覆盖率 **1.0%**；`test/system/vault_pairing_coordinator_test.dart` 存在但覆盖率仅 **5.3%**

### US-PAIR-03 设备别名
- **故事描述**：作为用户，我想要为设备设置易记的别名，以便在同步和配对时识别不同设备。
- **前置条件**：保险库已解锁。
- **测试步骤**：
  1. 在设置中为当前设备设置别名。
  2. 观察 `SyncSettingsView` 中设备列表的显示名称。
  3. 未设置别名时，观察是否回退到 `deviceId` 缩写。
  4. 验证别名持久化，重启后仍有效。
- **预期结果**：
  - 设置别名后即时显示。
  - 未设置时显示 `deviceId` 缩写或 l10n 回退文本。
  - 别名跨设备解析正确。
- **涉及页面和组件**：`SyncSettingsView`、`DeviceAliasService`
- **平台限制**：无
- **测试覆盖状态**：❌ `DeviceAliasService` 无独立测试，覆盖率 **33.3%**（间接触及）

---

## 七、保险库健康

### US-HLTH-01 健康评分计算
- **故事描述**：作为用户，我想要了解保险库的整体安全状况，以便识别弱密码、重复密码和过期记录。
- **前置条件**：保险库已解锁，存在多个账号（含弱密码、重复密码、过期记录、缺失 2FA 等场景）。
- **测试步骤**：
  1. 进入 `VaultHealthView`，观察健康评分（0–100）与等级（优/良/中/差）。
  2. 验证全健康场景下评分为满分。
  3. 添加弱密码账号，验证评分下降。
  4. 添加重复密码账号，验证重复项扣分。
  5. 设置过期记录，验证过期扣分。
  6. 缺失 2FA 的账号验证 2FA 项扣分。
- **预期结果**：
  - 评分计算正确，各维度扣分符合算法预期。
  - 等级阈值划分合理（如 ≥90 优，<60 差）。
- **涉及页面和组件**：`VaultHealthView`、`VaultHealthCalculator`
- **平台限制**：⚠️ Web 端受限
- **测试覆盖状态**：✅ `test/services/vault_health_calculator_test.dart`（服务层）；❌ `VaultHealthView` 无 Widget 测试

### US-HLTH-02 风险项展示与一键跳转
- **故事描述**：作为用户，我想要看到分类的风险卡片，并一键跳转到修复页面，以便快速处理安全问题。
- **前置条件**：保险库已解锁，`VaultHealthCalculator` 已识别至少1项风险。
- **测试步骤**：
  1. 进入 `VaultHealthView`，观察风险分类卡片（弱密码、重复密码、过期、不完整、缺失 2FA）。
  2. 点击「单账号风险」卡片，观察是否跳转到 `AccountEditView`。
  3. 点击「多账号风险」卡片，观察是否跳转到 `AccountSubsetView`。
  4. 点击「同步风险」卡片，观察是否跳转到 `LocalSyncQueueView` / `ConflictInboxView`。
  5. 点击「导出备份」引导，观察是否跳转到 `SyncSettingsView`。
- **预期结果**：
  - 各风险项正确分类展示，数量准确。
  - 点击后正确路由到对应修复页面。
  - 空风险项时显示空状态或隐藏卡片。
- **涉及页面和组件**：`VaultHealthView`、`InboxActionCard`、`InboxEmptyState`、`AccountEditView`、`AccountSubsetView`
- **平台限制**：无
- **测试覆盖状态**：❌ `VaultHealthView` 无 Widget 测试；❌ `AccountSubsetView` 无测试

### US-HLTH-03 体检通知生成
- **故事描述**：作为用户，我想要在体检完成后收到通知中心提醒，以便及时了解保险库安全动态。
- **前置条件**：保险库已解锁，通知权限已授予。
- **测试步骤**：
  1. 触发 Vault 体检（手动或自动调度）。
  2. 进入 `NotificationCenterView`，观察体检结果通知。
  3. 验证通知内容包含风险摘要。
  4. 修复风险后再次体检，验证旧通知是否自动清除/更新。
- **预期结果**：
  - 体检后生成对应通知，分类为「体检」类型。
  - 通知内容包含具体风险摘要。
  - 已修复后通知状态更新。
- **涉及页面和组件**：`NotificationCenterView`、`NotificationService`、`VaultHealthCalculator`
- **平台限制**：⚠️ Windows / Linux 不支持系统推送，应用内通知中心仍可用
- **测试覆盖状态**：🟡 `test/services/notification_service_test.dart` 存在；❌ `NotificationCenterView` 无测试

---

## 八、设置 / 个性化

### US-SET-01 主题模式切换与 OLED 极致黑
- **故事描述**：作为用户，我想要在浅色/深色/OLED 纯黑模式间切换，以便在不同光照和屏幕下舒适使用。
- **前置条件**：保险库已解锁。
- **测试步骤**：
  1. 进入 `AppearanceSettingsView`。
  2. 依次选择「跟随系统」「浅色」「深色」，观察全局主题实时变化。
  3. 在深色模式下开启 OLED 极致黑，观察背景是否为纯黑（`#000000`）。
  4. 重启应用，验证主题持久。
- **预期结果**：
  - 三种模式实时生效，不重启。
  - OLED 极致黑仅在深色模式下生效。
  - 重启后仍保持上次选择。
- **涉及页面和组件**：`AppearanceSettingsView`、`AppThemeProvider`、`AppHeroCard`、`AppOptionTile`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/views/appearance_settings_view_test.dart` + `test/theme/app_design_tokens_test.dart`

### US-SET-02 主题色预设
- **故事描述**：作为用户，我想要从多种品牌色中选择主题色，以便个性化应用外观。
- **前置条件**：保险库已解锁。
- **测试步骤**：
  1. 进入 `AppearanceSettingsView`。
  2. 依次点击 11 个主题色预设。
  3. 观察全局 `ColorScheme`（AppBar、按钮、FAB、开关等）实时更新。
  4. 重启应用，验证主题色持久。
  5. 验证未知/异常种子色 graceful 处理。
- **预期结果**：
  - 11 个预设色切换即时生效。
  - 重启后持久。
  - 异常值不崩溃，回退到默认色。
- **涉及页面和组件**：`AppearanceSettingsView`、`AppThemeProvider`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/views/appearance_settings_view_test.dart`

### US-SET-03 自动锁定时长
- **故事描述**：作为用户，我想要自定义自动锁定的时间间隔，以便在安全与便利间取舍。
- **前置条件**：保险库已解锁。
- **测试步骤**：
  1. 进入 `SecuritySettingsView` → 自动锁定。
  2. 依次选择「立即」「5秒」「1分钟」「10分钟」「永不」。
  3. 切后台，等待对应时长，验证锁定行为。
  4. 选择「永不」，验证切后台不触发锁定。
- **预期结果**：
  - 各档位切换后行为正确。
  - 立即锁定 API 即时生效。
  - 永不锁定模式下不触发后台锁定。
- **涉及页面和组件**：`SecuritySettingsView`、`AutoLockService`
- **平台限制**：⚠️ Web 端切后台行为受限
- **测试覆盖状态**：✅ `test/views/security_settings_view_test.dart` + `test/services/auto_lock_service_test.dart`

### US-SET-04 生物识别开关
- **故事描述**：作为用户，我想要随时启用或禁用生物识别解锁，以便掌控解锁方式。
- **前置条件**：保险库已解锁，设备支持生物识别。
- **测试步骤**：
  1. 进入 `SecuritySettingsView` → 生物识别。
  2. 启用生物识别，验证主密码被加密存储。
  3. 重新进入解锁页，验证出现生物识别入口。
  4. 禁用生物识别，验证安全存储中的主密码被删除。
  5. 重新进入解锁页，验证仅显示密码输入。
- **预期结果**：
  - 启用后主密码加密存储于安全密钥库。
  - 禁用后安全删除，不留残留。
  - 不支持生物识别的设备不显示该选项或显示「不支持」。
- **涉及页面和组件**：`SecuritySettingsView`、`BiometricAuthService`
- **平台限制**：❌ Linux 不支持；⚠️ Windows Hello 行为可能不稳定
- **测试覆盖状态**：✅ `test/views/security_settings_view_test.dart` + `test/services/biometric_auth_service_test.dart`

### US-SET-05 密码过期提醒天数
- **故事描述**：作为用户，我想要设置密码过期检查的阈值天数，以便按自己的节奏更换密码。
- **前置条件**：保险库已解锁。
- **测试步骤**：
  1. 进入 `NotificationSettingsView`。
  2. 设置密码过期提醒天数（如 30 天 / 90 天）。
  3. 创建/编辑账号，设置密码修改时间超过阈值。
  4. 等待后台扫描或手动触发体检，验证是否生成过期通知。
  5. 修改阈值后，验证通知重新扫描生成。
- **预期结果**：
  - 设置后持久保存。
  - 超过阈值的账号生成密码过期通知。
  - 修改阈值后按新阈值重新评估。
- **涉及页面和组件**：`NotificationSettingsView`、`NotificationProvider`、`NotificationService`
- **平台限制**：无
- **测试覆盖状态**：❌ `NotificationSettingsView` 无 Widget 测试；`notification_service_test.dart` 🟡 部分覆盖

### US-SET-06 通知中心聚合与未读
- **故事描述**：作为用户，我想要在一个页面查看所有通知（冲突/同步/体检/普通），并按类型分组，以便统一管理。
- **前置条件**：保险库已解锁，存在至少1条通知。
- **测试步骤**：
  1. 进入 `NotificationCenterView`。
  2. 观察通知按类型分组展示（冲突 / 同步 / 体检 / 普通）。
  3. 点击展开区块查看详情。
  4. 标记单条已读，观察未读红点变化。
  5. 标记全部已读，验证红点消失。
  6. 删除单条/全部通知，验证列表更新。
- **预期结果**：
  - 各类型通知正确分组，数量准确。
  - 未读标记（红点角标）实时更新。
  - 全部已读后红点消失。
- **涉及页面和组件**：`NotificationCenterView`、`NotificationProvider`、`InboxEmptyState`
- **平台限制**：无
- **测试覆盖状态**：❌ `NotificationCenterView` 无 Widget 测试；`test/providers/notification_provider_test.dart` ✅

---

## 附录：测试覆盖速查表

| 模块 | 用户故事数 | ✅ 已覆盖 | 🟡 部分覆盖 | ❌ 建议补充 |
|------|-----------|----------|------------|------------|
| 认证 / 解锁 | 7 | 6 | 1 | 0 |
| 账号管理 | 7 | 5 | 1 | 1（搜索） |
| 模板管理 | 4 | 2 | 2 | 0 |
| TOTP / 2FA | 5 | 2 | 1 | 2（TOTP编辑视图、扫码视图） |
| 同步 | 7 | 4 | 1 | 2（SyncSettingsView、LocalSyncQueueView） |
| 设备配对 | 3 | 1 | 1 | 1（DeviceAliasService） |
| 保险库健康 | 3 | 1 | 0 | 2（VaultHealthView、AccountSubsetView） |
| 设置 / 个性化 | 6 | 4 | 1 | 1（NotificationSettingsView + NotificationCenterView） |
| **合计** | **42** | **25** | **8** | **9** |

### 建议优先补充的自动化测试（按风险排序）

1. 🔴 `test/views/totp_credential_edit_view_test.dart` — TOTP 凭证编辑（0%，安全关键）
2. 🔴 `test/views/sync_settings_view_test.dart` — 同步设置（0%，含配对流程）
3. 🔴 `test/views/totp_qr_scanner_view_test.dart` — QR 扫码（0%，建议 mock MobileScanner）
4. 🟡 `test/views/notification_center_view_test.dart` — 通知中心聚合（0%，状态复杂）
5. 🟡 `test/views/home_search_view_test.dart` — 全局搜索（0%，高频用户路径）
6. 🟡 `test/views/local_sync_queue_view_test.dart` — 本地同步队列（0%）
7. 🟡 `test/views/vault_health_view_test.dart` — Vault 体检报告（0%）
8. 🟢 `test/services/device_alias_service_test.dart` — 设备别名（33.3%，间接触及）
9. 🟢 `test/views/notification_settings_view_test.dart` — 通知设置（0%，设置项少但易遗漏）
