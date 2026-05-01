# 2FA / TOTP 可行性分析与实现计划

- **功能点**: 独立 2FA/TOTP 管理与账号关联
- **适用项目**: `roy_client`
- **最后更新**: 2026-05-01
- **状态**: 已实施并通过 analyzer、2FA 回归测试和全量 Flutter 测试。

## 1. 结论

2FA 应作为独立保密对象存在，而不是账号信息字段。

```text
TotpCredential
  - id
  - label
  - config(secret/issuer/account/algorithm/digits/period)
  - linkedAccountIds
  - HLC + serverVersion + syncStatus + tombstone

AccountItem
  - 不保存 TOTP secret
  - 账号页面只展示和维护关联关系
```

收益：

- 2FA 页面可以独立新增、编辑、删除和复制验证码。
- 一个 2FA 项可以不关联账号，也可以关联多个账号。
- 账号模板只承载 2FA 关联入口，不承载第二因素凭据，避免“账号信息”和“验证器密钥”混在一起。
- 同步复用既有 AEAD payload、outbox 审阅和服务端密文存储，不新增服务端明文能力。

## 2. 数据与同步设计

### 2.1 本地模型

```dart
class TotpCredential {
  String id;
  String label;
  TotpConfig config;
  List<String> linkedAccountIds;
  Hlc labelHlc;
  Hlc configHlc;
  Hlc linksHlc;
  int serverVersion;
  SyncStatus syncStatus;
  bool isDeleted;
  Hlc? deleteHlc;
}
```

`linkedAccountIds` 由 2FA 对象持有，因此账号数据不需要写入 TOTP secret。模板里的 `AccountFieldType.totp` 只表示“这里需要一个 2FA 关联控件”，不对应 `AccountItem.data` 字段。

### 2.2 本地存储

新增加密表：

```text
totp_credentials
```

该表随 vault DB 一起落盘，字段包含 TOTP config JSON、关联账号 id 列表、HLC、同步版本、同步状态和删除 tombstone。

### 2.3 同步协议

新增本地同步实体：

```dart
LocalSyncEntityType.totpCredential
```

同步 payload 类型：

```json
{ "_type": "totp_credential" }
```

服务端仍只接收 `encrypted_signed_payload`，不理解 TOTP secret，也不参与验证码生成。

## 3. UI 设计

### 3.1 独立 2FA 页面

- 主导航保留 `2FA` 入口。
- 页面展示独立 2FA 项，而不是“拥有 TOTP 字段的账号列表”。
- 每个 2FA 项显示名称、当前验证码、倒计时、复制、编辑和删除入口。
- 新增/编辑页支持手动输入 Base32 secret、`otpauth://totp` URI、扫码和主动粘贴二维码图片。

### 3.2 账号信息页

- 账号编辑页在模板包含 2FA 字段时展示“关联 2FA”区域。
- 用户可以选择关联或取消关联已有独立 2FA 项。
- 用户也可以在账号编辑页现场新建 2FA；新建结果写入独立 2FA 模块，并关联到当前账号。
- 账号字段区域不保存 TOTP secret，也不内嵌验证码密钥输入框。

### 3.3 模板边界

- 内置网站模板包含 `2FA` 关联字段，但不包含 `totp_secret` 字段。
- `AccountFieldType.totp` 保留为模板关联控件类型；它不再表示账号数据里的 TOTP secret。
- `AccountFieldAttributes.totpDefaults` 和旧 secret 字段默认值已下线。
- 自定义模板编辑入口提供 2FA 字段类型，保存时会强制关闭 secret/search/copy/primary 等账号数据属性。

## 4. 不兼容旧数据

项目尚未生产发布，本轮不保留旧数据兼容层：

- 不扫描账号历史字段里的 `totp_secret`。
- 不提供旧账号字段导入到 `TotpCredential` 的迁移入口。
- 不把旧 `AccountFieldType.totp` secret 字段作为只读兼容数据保留；新的 `AccountFieldType.totp` 仅用于关联控件。
- 如本地开发数据仍有旧 TOTP 字段，按普通历史字段处理或直接重建测试数据。

## 5. 已实施任务

- [x] 新增 `TotpCredential` 模型。
- [x] 新增 `totp_credentials` 加密存储表和 CRUD。
- [x] 新增 `LocalSyncEntityType.totpCredential`。
- [x] 新增 TOTP credential AEAD sync payload 编解码。
- [x] 同步 push/pull 支持独立 2FA 项。
- [x] Provider 和 ServiceManager 暴露 2FA CRUD。
- [x] 2FA 页面改为独立 2FA 项列表。
- [x] 账号编辑页在模板 2FA 字段处展示 2FA 关联面板。
- [x] 内置网站模板提供 2FA 关联字段，但不再提供 `totp_secret` secret 字段。
- [x] 模板编辑器支持新增 2FA 关联字段。
- [x] 移除旧 TOTP 账号字段兼容服务和测试。
- [x] 补充模型、导入、同步 payload 和多设备同步测试。

## 6. 验证计划

- `dart analyze lib test`
- `flutter test`

## 7. 后续收敛

- 为账号编辑页的 2FA 关联面板补 widget test。
- 为 `totp_credentials` 增加真实 SQLite schema migration 覆盖。
- 评估验证码复制是否需要纳入全局敏感剪切板策略。
