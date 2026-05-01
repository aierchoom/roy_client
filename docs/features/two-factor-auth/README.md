# 2FA / TOTP 功能说明

- **最后更新**: 2026-05-01
- **当前状态**: 2FA 是独立功能；账号信息只维护和 2FA 项的关联关系。

| 文档 | 用途 |
|---|---|
| [feasibility-and-implementation-plan.md](feasibility-and-implementation-plan.md) | 2FA/TOTP 的可行性、架构边界、实现路线和测试计划 |

## 功能定位

2FA/TOTP 在 SecretRoy 中是独立的保密对象；账号模板可以声明一个 2FA 关联字段，但该字段只作为快捷入口，不保存 TOTP secret。

```text
用户在 2FA 页面创建或导入 TOTP 项
-> SecretRoy 本地生成动态验证码
-> TOTP 项可以关联到一个或多个账号
-> 同步时作为独立 encrypted payload 进入既有 outbox
```

## 已落地能力

- 新增独立 `TotpCredential` 模型，保存 TOTP 配置、显示名称和 `linkedAccountIds`。
- 新增 `totp_credentials` 本地加密存储表，带 HLC、`serverVersion`、`syncStatus` 和 tombstone 字段。
- 同步层新增 `LocalSyncEntityType.totpCredential` 与 `_type = "totp_credential"` AEAD payload。
- `2FA` 页面展示独立 2FA 项，支持新增、编辑、删除、复制当前验证码和关联账号。
- 账号编辑页在模板声明 2FA 字段时展示“关联 2FA”区域，可选择已有 2FA，也可现场新建独立 2FA 项。
- 内置网站模板包含 `2FA` 关联字段，但不包含 `totp_secret` 字段。
- 移动端支持扫码导入；桌面端支持用户主动粘贴二维码图片，不依赖读取剪切板。
- TOTP secret 不进入搜索摘要、账号列表明文、服务端明文或未加密同步体。

## 边界

- 不做 SecretRoy 解锁时的 MFA。
- 不做短信、邮箱、推送或云端 MFA。
- 不兼容旧账号字段式 TOTP 数据。项目尚未生产发布，当前方案直接移除旧 `totp_secret` secret 字段路线。
- 服务端只保存加密 payload，不参与验证码生成、校验或解析。
