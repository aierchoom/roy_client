# 2FA / TOTP 功能计划

**最后更新**: 2026-04-30

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

本轮不做：

- 不做 SecretRoy 解锁时的登录 MFA。
- 不接入短信、邮箱、推送或云端 MFA。
- 不让服务端参与验证码生成或读取 TOTP 密钥。
