# SecretRoy Risks and Roadmap

Navigation:
[Docs Home](README.md) |
[Architecture Index](ARCHITECTURE_DOCS_INDEX.md) |
Prev: [02_Runtime_and_Sync.md](02_Runtime_and_Sync.md) |
Related: [SECRETROY_ARCHITECTURE_DEEP_DIVE.md](SECRETROY_ARCHITECTURE_DEEP_DIVE.md)

| Item | Value |
|---|---|
| Doc ID | SR-ARCH-03 |
| Document Type | Risks and Roadmap |
| Audience | Leads, maintainers, reviewers |
| Scope | Maturity, risks, readiness, migration and next-stage planning |
| Owner | Repository maintainers (formal owner TBD) |
| Review Status | Draft - Unapproved |
| Last Updated | 2026-04-20 |

## 1. Maturity Assessment

### Already Strong

- 客户端分层清晰
- 本地优先设计明确
- 模板系统具备扩展性
- 同步与冲突模型相对成熟

### Partially Mature

- `ServiceManager` 门面设计
- 同步状态与 dirty 元数据管理
- 客户端对风险状态的可视化反馈

### Still Prototype-Level

- 安全能力
- 身份与密钥体系
- 服务端持久化与认证
- 观测与恢复能力
- 系统级测试矩阵

## 2. Quality Attributes

| Attribute | Current View |
|---|---|
| Offline Capability | 强 |
| Consistency | 中等偏强 |
| Security | 架构方向合理，实现偏弱 |
| Modifiability | 较强 |
| Observability | 偏弱 |
| Testability | 中等 |

### Commentary

- 离线与本地优先是当前系统最强的属性之一。
- 一致性设计比普通原型好，但缺少更高强度验证。
- 安全能力是当前最大短板。

## 3. Operational Readiness

### Current State

- 适合开发、演示、研究
- 不适合正式生产部署

### Primary Gaps

- 缺少结构化日志
- 缺少恢复与备份机制
- 缺少部署治理模型
- 缺少系统级错误分类

## 4. Open Questions

### OQ-01. Vault identity 最终如何建模

仍需明确：

- 用户、vault、device 的最终关系

### OQ-02. 加密边界最终落在哪里

仍需明确：

- 本地库加密
- payload 加密
- 签名验证边界

### OQ-03. 模板是否成为正式同步对象

仍需明确：

- 模板版本化
- 模板删除语义
- 模板与历史账号兼容规则

### OQ-04. 服务端是快照系统还是日志系统

仍需明确：

- 是否引入 operation log
- 是否保留快照主模型

## 5. Risk Register

### R-01. 安全认知风险

问题：

- 命名和文案可能让人高估当前安全能力

建议：

- 全面校正文档、UI 文案与命名

### R-02. `ServiceManager` 膨胀风险

问题：

- 运行时编排高度集中

建议：

- 继续增长前规划拆分边界

### R-03. 本地数据库单点风险

问题：

- SQLite 是主存储，损坏会直接影响系统可用性

建议：

- 增强完整性校验、备份、恢复与导出能力

### R-04. 服务端存储扩展性不足

问题：

- JSON 文件存储不适合中长期演进

建议：

- 中期迁移到正式数据库

### R-05. 测试覆盖不足

问题：

- 缺少多设备、多场景、多故障验证

建议：

- 建立系统级同步回归集

## 6. Migration Strategy

### Security Migration

建议顺序：

1. 正式主密钥派生
2. 本地数据库进入保护边界
3. 同步 payload 正式加密/认证
4. 生物识别与密钥持有关系重构

### Backend Migration

建议顺序：

1. JSON 文件持久化迁移到数据库
2. 尽量保留 API 兼容壳
3. 再逐步引入更细的版本/日志模型

### Sync Migration

建议顺序：

1. 先稳住现有同步编排
2. 再补错误分类与恢复
3. 再考虑更复杂的日志型同步

## 7. Recommended Next 90 Days

### Days 1-30

- 统一系统真实定位
- 补最关键同步回归
- 梳理 `ServiceManager` 边界

### Days 31-60

- 设计正式安全底座
- 制定服务端迁移目标模型

### Days 61-90

- 建立结构化诊断能力
- 补备份/恢复最小闭环
- 建多设备同步回归基线

## 8. Glossary

### Vault

逻辑上的数据保险库。

### Local-first

本地状态与本地持久化优先，网络同步是后置协调动作。

### HLC

Hybrid Logical Clock，混合逻辑时钟。

### Tombstone

软删除标记，用于删除状态传播。

### Conflict Inbox

供用户查看和恢复冲突值的 UI 入口。

### Thin Sync Backend

只承担同步协调与版本秩序的薄后端。

---

Navigation:
[Docs Home](README.md) |
[Architecture Index](ARCHITECTURE_DOCS_INDEX.md) |
Prev: [02_Runtime_and_Sync.md](02_Runtime_and_Sync.md) |
Related: [SECRETROY_ARCHITECTURE_DEEP_DIVE.md](SECRETROY_ARCHITECTURE_DEEP_DIVE.md)

