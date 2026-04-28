# 安全文档

**更新日期**：2026-04-29

| 文档 | 用途 |
|---|---|
| [security-features.md](security-features.md) | 当前已实现的客户端安全能力 |
| [local-database-encryption.md](local-database-encryption.md) | 本地 SQLite 二进制文件信封加密与 DB 数据密钥包裹 |
| [key-sync-implementation.md](key-sync-implementation.md) | 面对面链接、远程配对、离线恢复码与密钥同步加固 |
| [../sync/vault-recovery-routes.md](../sync/vault-recovery-routes.md) | 每条密钥恢复路线的风险等级、适用场景和验收方式 |
| [beta-risk-register.md](beta-risk-register.md) | Beta 安全风险清单与剩余阻塞项 |

当前本地数据库模型：

- 长期文件：`secret_roy_vault.db.enc`
- 文件信封：Dart AES-GCM-256 二进制信封
- DB 数据密钥：随机 32 字节 key
- 主密码职责：派生包裹密钥，用于保护 DB 数据密钥信封
