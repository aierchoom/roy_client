# 2FA / TOTP 功能计划

**最后更新**: 2026-04-30
**当前状态**: 第一阶段已完成

| 文档 | 用途 |
|---|---|
| [feasibility-and-implementation-plan.md](feasibility-and-implementation-plan.md) | 2FA/TOTP 的可行性分析、边界、实现路线和测试计划 |

## 功能定位

本轮 2FA 计划先聚焦“账户内置 TOTP 验证器”：

```text
用户在账号里保存网站的 2FA 密钥
-> SecretRoy 本地生成动态验证码
-> 验证码可查看、复制，并随账号密文同步到可信设备
```

已落地能力：

- 网站模板内置可选 `totp_secret` 字段。
- 支持 Base32 secret、`otpauth://totp` URI 和结构化 JSON。
- 保存时规范化为结构化 JSON，便于后续稳定解析和迁移。
- 账号页显示当前验证码、倒计时和复制验证码按钮。
- TOTP secret 默认隐藏、不参与搜索、不在服务端明文出现。
- 修改 TOTP secret 继续进入 outbox 审阅；批准后通过现有 AEAD payload 同步。
- 多设备同步后，各可信设备从同一 secret 生成同一验证码。
- 并发修改 `totp_secret` 时进入现有 `data.totp_secret` 冲突日志。

本轮不做：

- 不做 SecretRoy 解锁时的登录 MFA。
- 不接入短信、邮箱、推送或云端 MFA。
- 不让服务端参与验证码生成或读取 TOTP 密钥。
- 不做 QR 扫码、二维码导出、WebAuthn/passkey 或剪贴板自动清理。
