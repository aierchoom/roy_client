# 2FA / TOTP 可行性分析与实现计划

**功能点**: 账户内置 2FA/TOTP 验证器
**适用项目**: `roy_client`
**最后更新**: 2026-04-30
**状态**: 第一阶段已完成，后续增强待规划

## 1. 结论

可行，且适合优先做成客户端本地能力。

推荐第一阶段实现范围：

```text
TOTP 手动密钥 / otpauth:// URI 导入
-> 账号字段保存 TOTP secret
-> 本地生成当前验证码和倒计时
-> 复制验证码
-> 随账号数据走现有端到端加密同步
```

不推荐第一阶段就做 QR 扫码、服务端 MFA、登录 SecretRoy 时的第二因素校验。它们会引入相机权限、平台插件、恢复流程和锁屏安全语义，应该在 TOTP 核心闭环稳定后再扩展。

同步策略结论：

```text
2FA/TOTP 不引入独立同步协议。
TOTP secret 和配置属于账号保密数据。
它们跟随 AccountItem.data 走现有本地加密、AEAD sync payload、outbox 审阅、CRDT merge 和 conflict inbox。
服务端仍只保存密文，不参与验证码生成、校验或冲突判断。
```

## 2. 当前代码适配性

| 方向 | 当前基础 | 可行性 |
|---|---|---|
| 数据模型 | `AccountTemplate` 已有字段类型、`isSecret`、`isCopyable`、`data` map | 可新增 `AccountFieldType.totp`，或先用 secret text 字段承载 |
| 本地加密 | `SecureStorageService` 已将 SQLite 明文工作库加密落盘 | TOTP secret 可按普通敏感字段保存 |
| 同步安全 | `SyncPayloadCodec` 已用 AEAD envelope 加密账号 payload | TOTP secret 不需要服务端明文参与 |
| 多设备冲突 | `dataHlc`、CRDT merge、conflict log 已覆盖 data 字段 | TOTP 字段可作为普通 `data.<fieldKey>` 合并 |
| 出站审阅 | 本机编辑先进入 `local_sync_changes` | 添加或修改 2FA secret 不会自动扩散 |
| UI 基础 | 账号编辑已有 secret 字段显示/隐藏和复制动作 | 可复用隐藏、复制、生成类交互模式 |
| 依赖基础 | `crypto` 已在依赖中 | 可直接实现 HMAC-SHA1/SHA256/SHA512 TOTP，无需新增核心依赖 |

## 3. 功能边界

### 3.1 第一阶段目标

- 支持 Base32 TOTP secret。
- 支持 `otpauth://totp/...` URI 粘贴解析。
- 支持 issuer、account label、digits、period、algorithm。
- 默认参数：SHA1、6 位、30 秒。
- 在账号查看/编辑页显示当前验证码和剩余秒数。
- 支持复制当前验证码。
- TOTP secret 默认隐藏，不参与搜索。
- 同步和导入仍沿用现有账号密文链路。
- 多设备同步后，各可信设备用本地系统时间从同一 TOTP secret 生成验证码。

### 3.2 第一阶段非目标

- 不做 QR 扫码导入。
- 不做二维码导出。
- 不做 SecretRoy 解锁 2FA。
- 不做服务器侧验证码校验。
- 不做 WebAuthn/passkey。
- 不做云端备份恢复策略变更。

## 4. 推荐设计

### 4.1 数据表示

新增字段类型：

```dart
enum AccountFieldType {
  text,
  password,
  number,
  email,
  phone,
  url,
  time,
  totp,
  custom,
}
```

推荐字段 key：

```text
totp_secret
```

字段属性：

```text
type = totp
isSecret = true
isSearchable = false
isCopyable = true
isRequired = false
```

存储值建议优先保存规范化后的 `otpauth://` URI 或结构化 JSON 字符串。第一阶段更推荐结构化 JSON，因为后续可稳定支持 algorithm、period、digits、issuer：

```json
{
  "secret": "JBSWY3DPEHPK3PXP",
  "issuer": "Example",
  "account": "alice@example.com",
  "algorithm": "SHA1",
  "digits": 6,
  "period": 30
}
```

如果用户只输入 Base32 secret，则保存为同一结构，缺省字段由客户端补齐。

### 4.2 TOTP 引擎

新增纯 Dart 服务：

```text
lib/services/totp_service.dart
```

核心能力：

- Base32 解码。
- `otpauth://` URI 解析。
- HOTP 计数器计算。
- TOTP 当前码计算。
- 当前周期剩余秒数计算。
- 配置校验和错误分类。

建议不把 TOTP 算法放进 UI，也不把 `AccountItem` 模型变成算法容器。UI 只消费：

```dart
TotpConfig config
TotpCode code
```

### 4.3 UI 入口

账号编辑页：

- TOTP 字段显示为专用控件，不直接展示完整 secret。
- 支持粘贴 Base32 secret。
- 支持粘贴 `otpauth://totp/...`。
- 支持“显示/隐藏密钥”。
- 支持“测试生成验证码”。

账号查看页：

- 显示 6 位验证码。
- 显示倒计时。
- 提供复制按钮。
- 验证码不进入搜索结果。

模板编辑页：

- 字段类型下拉新增“2FA 验证码”。
- 选择该类型时自动勾选保密字段，默认不搜索。

### 4.4 内置模板

推荐把内置网站模板增加一个可选 TOTP 字段：

```text
字段名称: 2FA 密钥
字段标识: totp_secret
字段类型: totp
是否必填: 否
```

兼容性影响可控：

- 旧账号没有该字段时，视为空。
- `AccountItem.data` 是 map，不需要数据库迁移。
- 需要更新 `account_template_test.dart` 中的网站模板字段断言。

## 5. 安全分析

| 风险 | 处理 |
|---|---|
| TOTP secret 泄漏等价于第二因素泄漏 | secret 按保密字段处理，默认隐藏，不搜索 |
| 复制验证码进入系统剪贴板 | 只复制短验证码，不默认复制 secret；后续可加剪贴板自动清理 |
| 服务端读取风险 | 继续使用现有 AEAD sync payload，服务端只见密文 |
| 多设备时间漂移 | 第一阶段使用系统时间；UI 可提示设备时间不准会导致验证码失败 |
| otpauth URI 解析错误 | 明确错误文案，不静默保存不可用配置 |
| 冲突覆盖 TOTP secret | 复用 CRDT data 字段和 conflict inbox，冲突时不静默覆盖 |

## 6. 实现步骤

### T11.1 TOTP 算法与解析

- [x] 新增 `TotpConfig`、`TotpCode`、`TotpService`。
- [x] 实现 Base32 decoder。
- [x] 实现 `otpauth://totp` parser。
- [x] 实现 SHA1/SHA256/SHA512 HOTP/TOTP。
- [x] 增加 RFC 6238 测试向量和 URI 解析测试。

验收：

- [x] 固定时间戳生成结果稳定。
- [x] 非法 secret、非法 digits、非法 period 有明确错误。

完成记录：

- `lib/services/totp_service.dart` 已落地纯 Dart 算法层，不依赖 UI 或账号模型。
- `test/services/totp_service_test.dart` 覆盖 RFC 6238 SHA1/SHA256/SHA512 向量、Base32 输入规整、JSON/URI 解析、倒计时和错误输入。
- 已通过 `flutter test test\services\totp_service_test.dart` 与 `dart analyze lib test`。
- T11.3 已将 TOTP 字段从普通保密输入升级为专用录入/查看控件。

### T11.2 模型与模板接入

- [x] 新增 `AccountFieldType.totp`。
- [x] 模板编辑字段类型增加“2FA 验证码”。
- [x] 内置网站模板增加 `totp_secret` 可选字段。
- [x] 更新模板序列化和回归测试。

验收：

- [x] 旧模板 JSON 仍能 fallback。
- [x] 新字段不会破坏现有账号。

完成记录：

- `AccountFieldAttributes.totpDefaults` 统一 TOTP 字段默认值：保密、不可搜索、可复制。
- `websiteTemplate` 已增加可选 `totp_secret` 字段。
- 模板编辑器已显示 TOTP 字段类型、图标和样例值。
- 已通过 `flutter test test\models\account_template_test.dart` 与 `dart analyze lib test`。

### T11.3 账号编辑与查看体验

- [x] 为 TOTP 字段新增专用输入控件。
- [x] 支持 Base32 secret 和 `otpauth://` 粘贴。
- [x] 显示当前验证码、倒计时、复制按钮。
- [x] 密钥默认隐藏。

验收：

- [x] 用户能从常见网站提供的 TOTP secret 完成录入。
- [x] 复制的是当前验证码，不是 secret。

完成记录：

- `AccountEditView` 对 `AccountFieldType.totp` 显示验证码面板，包含当前验证码、剩余秒数、配置元信息和复制按钮。
- TOTP 输入支持 Base32 secret、`otpauth://totp` URI 和结构化 JSON；保存时通过 `TotpService.encodeConfig()` 规范化。
- 无效 TOTP 配置会在字段内展示错误，并在保存时阻止写入。
- “复制全部信息”和 TOTP 字段复制动作只复制当前验证码，不复制 secret。
- 已通过 `flutter test test\services\totp_service_test.dart`、`flutter test test\models\account_template_test.dart` 与 `dart analyze lib test`。

### T11.4 同步、冲突和 outbox 回归

- [x] 确认 TOTP 字段作为 `AccountItem.data` 的普通保密字段进入现有同步机制。
- [x] 确认修改 TOTP 字段进入本地待审队列。
- [x] 确认未批准时不会 push。
- [x] 确认批准后密文同步到另一设备并可生成同一验证码。
- [x] 确认并发修改 TOTP secret 进入冲突处理。
- [x] 确认不新增服务端 TOTP route、metadata key 或独立同步状态。

验收：

- [x] `sync_state_machine_test.dart` 增加 TOTP 字段未审阅不 push。
- [x] `multi_device_sync_test.dart` 增加 TOTP secret 多设备一致性。

完成记录：

- `sync_state_machine_test.dart` 覆盖未审阅 TOTP 修改不 push，以及批准后请求体只包含 `encrypted_signed_payload`，不泄露 `totp_secret`、Base32 secret 或 `otpauth://`。
- `multi_device_sync_test.dart` 覆盖可信设备同步同一 TOTP secret 后生成同一验证码。
- `multi_device_sync_test.dart` 覆盖并发修改 `totp_secret` 进入 `data.totp_secret` 冲突日志。
- 已通过 `flutter test test\sync\sync_state_machine_test.dart`、`flutter test test\sync\multi_device_sync_test.dart`、`flutter test test\sync\sync_conflict_recovery_test.dart` 与 `dart analyze lib test`。

### T11.5 文档与质量收敛

- [x] 更新 `application-characteristics.md`。
- [x] 新增执行报告。
- [x] 补充手工验收清单。
- [x] 全量 `dart analyze lib test` 和定向 Flutter 测试。

完成记录：

- 新增 `docs/reports/execution/2026-04-30-totp-ui-sync-closure.md`。
- `docs/product/application-characteristics.md` 已补充 2FA/TOTP 功能点、同步边界和测试维护点。
- `flutter test` 全量通过，结果为 97 passed, 1 skipped。
- `git diff --check` 通过，仅有 CRLF 提示。

## 7. 测试计划

| 测试文件 | 覆盖 |
|---|---|
| `test/services/totp_service_test.dart` | Base32、otpauth URI、RFC 6238 向量、错误分类 |
| `test/models/account_template_test.dart` | 新字段类型和内置模板兼容 |
| `test/sync/sync_state_machine_test.dart` | 未审阅 TOTP secret 不 push |
| `test/sync/multi_device_sync_test.dart` | 多设备同步后验证码一致 |
| `test/sync/sync_conflict_recovery_test.dart` | TOTP secret 并发修改进入冲突箱 |

## 8. 开放问题

1. 2FA secret 是保存为结构化 JSON，还是保存原始 `otpauth://` URI？
   - 推荐结构化 JSON，利于稳定解析和字段级迁移。
2. 是否第一阶段就加入 QR 扫码？
   - 不推荐。扫码会引入相机权限和平台插件，适合第二阶段。
3. 是否允许自定义模板添加多个 TOTP 字段？
   - 推荐允许，企业账号可能同时有登录、恢复或管理员入口的不同 2FA。
4. 是否显示验证码在列表页？
   - 不推荐。列表页只提示“已配置 2FA”，验证码只在账号详情页显示。
5. 是否在复制验证码后自动清理剪贴板？
   - 推荐作为 P1 增强，第一阶段可以先做复制动作和文案提示。

## 9. 初步排期建议

| 顺序 | 任务 | 结果 |
|---|---|---|
| 1 | TOTP service + tests | 算法可信、无 UI 依赖 |
| 2 | 模型/模板字段接入 | 2FA 成为正式字段类型 |
| 3 | 账号编辑/查看 UI | 用户可录入、查看、复制验证码 |
| 4 | 同步与冲突回归 | 多设备和 outbox 语义稳定 |
| 5 | 文档和执行报告 | 可提交、可维护 |
