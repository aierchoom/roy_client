# SecretRoy 文档索引

**更新日期**: 2026-04-20

---

## 📌 当前代码文档（以代码为准）

| 文档 | 说明 |
|------|------|
| [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md) | **技术参考文档** — 基于全量代码扫描编写，涵盖架构、模块、数据模型、数据库 Schema、同步协议、依赖清单 |
| [AI_HANDOVER_NOTES.md](AI_HANDOVER_NOTES.md) | **AI 开发交接手册** — 硬性约束、常见陷阱、未使用代码清单 |
| [architecture_review/README.md](architecture_review/README.md) | **架构评审文档集入口** — 面向评审/学习的专业解读版，强调“以当前代码实现为准” |
| [architecture_review/00_Executive_Summary.md](architecture_review/00_Executive_Summary.md) | 一页式结论、评分卡、现实校准 |
| [architecture_review/SECRETROY_ARCHITECTURE_DEEP_DIVE.md](architecture_review/SECRETROY_ARCHITECTURE_DEEP_DIVE.md) | 单文件完整版架构深度解读 |

### 变更日志

| 文档 | 说明 |
|------|------|
| [dev_log/sync_account_count_fix.md](dev_log/sync_account_count_fix.md) | 同步账号数量 Bug 修复记录 |
| [dev_log/sync_fix_and_platform_adaptation.md](dev_log/sync_fix_and_platform_adaptation.md) | 同步功能修复与跨平台适配记录 |

---

## 📋 未来规划文档（设计提案，尚未实现）

> ⚠️ 以下文档是**未来架构升级的设计方案**。其中有些概念在当前代码中已经出现原型级雏形，例如字段级合并、冲突日志、local-first 同步；但文档里描述的是更正式、更完整的目标形态。  
> 请勿将这些文档直接视为对现有实现的精确描述。

| 文档 | 说明 |
|------|------|
| [EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md) | 执行总结 — 方案概览、成本估计、风险评估 |
| [STORAGE_AND_SYNC_ARCHITECTURE_REPORT.md](STORAGE_AND_SYNC_ARCHITECTURE_REPORT.md) | 存储与同步架构报告 — 现状分析、E2EE/CRDT/OT 方案对比 |
| [MICROSERVICES_IMPLEMENTATION_PLAN.md](MICROSERVICES_IMPLEMENTATION_PLAN.md) | 微服务实现计划 — 4 个服务的 API 设计、PostgreSQL Schema |
| [TECHNICAL_IMPLEMENTATION_GUIDE.md](TECHNICAL_IMPLEMENTATION_GUIDE.md) | 技术实现指南 — 客户端 Dart 代码参考（加密、向量时钟、CRDT） |

---

## 当前代码现状 vs 规划对比

| 能力 | 当前状态 | 规划目标 |
|------|---------|---------|
| 数据加密 | ⚠️ 主密码通过 secure storage 直接保存/比对；账号数据未形成正式数据库加密边界 | AES-256-GCM + 正式 KDF/密钥管理 |
| 传输安全 | ⚠️ 默认走 HTTP；同步 payload 当前只是 base64 包装 JSON，不是真正加密/签名 | HTTPS + 请求签名/正式 payload 保护 |
| 服务器认证 | ❌ 无 | JWT + 设备密钥 |
| 同步策略 | ✅ 客户端 `pull -> merge -> push`；服务端维护 per-item 版本号 | 更正式的日志型同步 / 更强协议治理 |
| 冲突处理 | ✅ 字段级 HLC 合并 + conflict log + inbox 恢复闭环 | 更严格的一致性验证与长期演进模型 |
| 离线支持 | ✅ local-first，可离线读写；恢复与回放能力仍偏基础 | 更完整的离线日志、恢复与重放 |
| 后端架构 | ⚠️ 单文件 Express + JSON vault 文件持久化 | 更稳健的数据库后端 / 可治理服务架构 |
