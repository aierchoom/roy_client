# SecretRoy 架构文档集

| Item | Value |
|---|---|
| Document Type | Architecture Docs Index |
| Audience | Engineers, reviewers, stakeholders |
| Scope | Architecture review document set |
| Owner | Repository maintainers (formal owner TBD) |
| Review Status | Working draft |
| Last Updated | 2026-04-20 |

> Source of truth: this document set describes the current code snapshot first, not the aspirational security/product target.

| Document | Purpose |
|---|---|
| [00_Executive_Summary.md](00_Executive_Summary.md) | 面向管理、评审和决策者的一页式摘要、评分卡与 90 天建议。 |
| [01_System_Architecture.md](01_System_Architecture.md) | 仓库拓扑、系统边界、客户端/服务端容器结构、依赖方向与模块边界。 |
| [02_Runtime_and_Sync.md](02_Runtime_and_Sync.md) | 启动链路、解锁链路、本地保存、同步编排、冲突合并与关键时序。 |
| [03_Risks_and_Roadmap.md](03_Risks_and_Roadmap.md) | 技术债、质量属性、运行就绪度、开放问题、迁移路线与风险登记。 |
| [SECRETROY_ARCHITECTURE_DEEP_DIVE.md](SECRETROY_ARCHITECTURE_DEEP_DIVE.md) | 原始总文档，适合作为单文件全集参考。 |

## 使用建议

如果你要快速判断项目状态，先读：

1. `00_Executive_Summary.md`
2. `03_Risks_and_Roadmap.md`

如果你要读系统结构，按这个顺序：

1. `01_System_Architecture.md`
2. `02_Runtime_and_Sync.md`

如果你要保留一份完整长文版本，则继续使用：

- `SECRETROY_ARCHITECTURE_DEEP_DIVE.md`

