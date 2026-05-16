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
  - 网格布局正确渲染。
- **涉及页面和组件**：`TemplateListBody`、`_TemplateCard`、`AppSelectableScrollable`
- **平台限制**：无
- **测试覆盖状态**：🟡 `test/views/template_list_view_test.dart` 存在但实际覆盖率仅 **0.2%**（598行命中1行）

### US-TPL-02 新建/编辑模板
- **故事描述**：作为用户，我想要自定义字段、排序和图标，以便创建符合个人需求的模板。
- **前置条件**：保险库已解锁。
- **测试步骤**：
  1. 进入 `TemplateEditView`（新建或编辑）。
  2. 添加字段 → 选择字段预设（如「银行卡」「身份证号」）。
  3. 拖拽排序字段。
  4. 选择图标（57个 Material outlined 图标）。
  5. 观察徽章联动（标题自动生成两字缩写）。
  6. 实时预览模板效果。
  7. 保存后回到列表验证。
- **预期结果**：
  - 字段增删改排序即时反映在预览区。
  - 预设字段 key 唯一，重复添加同一 preset 有处理策略。
  - 保存后模板可用，账号创建时可选。
- **涉及页面和组件**：`TemplateEditView`、`FieldEditorDialog`、`TemplateEditWidgets`、`GreenAddButton`
- **平台限制**：无
- **测试覆盖状态**：✅ `test/views/template_edit_view_test.dart`

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
