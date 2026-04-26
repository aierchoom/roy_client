# SecretRoy Docs

| Item | Value |
|---|---|
| Document Type | Docs Home |
| Audience | All readers |
| Scope | `docs/` directory overview |
| Owner | Repository maintainers (formal owner TBD) |
| Review Status | Working draft |
| Last Updated | 2026-04-20 |

本目录包含两类文档：

- 架构/评审文档
- 其他仓库级参考材料

## Source-of-Truth Notice

本轮新增的架构文档集以当前工作区源码为准，重点依据：

- `roy_client/lib/main.dart`
- `roy_client/lib/services/service_manager.dart`
- `roy_client/lib/services/enhanced_crypto_service.dart`
- `roy_client/lib/services/identity_service.dart`
- `roy_client/lib/sync/sync_service.dart`
- `roy_server/index.js`

如果某些旧文档、命名或 UI 文案与上述实现不一致，应优先以代码现状为准，而不是以未来目标或产品化表述为准。

## 1. Architecture Review Set

如果你想以“正式架构文档集”的方式阅读，请从这里开始：

- [ARCHITECTURE_DOCS_INDEX.md](C:\Users\choom\Desktop\CodeRepo\roy\docs\ARCHITECTURE_DOCS_INDEX.md)

推荐阅读顺序：

1. [00_Executive_Summary.md](C:\Users\choom\Desktop\CodeRepo\roy\docs\00_Executive_Summary.md)
2. [01_System_Architecture.md](C:\Users\choom\Desktop\CodeRepo\roy\docs\01_System_Architecture.md)
3. [02_Runtime_and_Sync.md](C:\Users\choom\Desktop\CodeRepo\roy\docs\02_Runtime_and_Sync.md)
4. [03_Risks_and_Roadmap.md](C:\Users\choom\Desktop\CodeRepo\roy\docs\03_Risks_and_Roadmap.md)
5. [04_Distributed_System_Quality_Iteration_Plan.md](C:\Users\choom\Desktop\CodeRepo\roy\docs\04_Distributed_System_Quality_Iteration_Plan.md)
6. [05_Distributed_System_Implementation_Backlog.md](C:\Users\choom\Desktop\CodeRepo\roy\docs\05_Distributed_System_Implementation_Backlog.md)

如果你更偏好单文件全集版本，请阅读：

- [SECRETROY_ARCHITECTURE_DEEP_DIVE.md](C:\Users\choom\Desktop\CodeRepo\roy\docs\SECRETROY_ARCHITECTURE_DEEP_DIVE.md)

如果你是初学者，希望从教学视角理解项目，请阅读：

- [FLUTTER_NODE_BEGINNER_TUTORIAL.md](C:\Users\choom\Desktop\CodeRepo\roy\docs\FLUTTER_NODE_BEGINNER_TUTORIAL.md)

## 2. Other Repository-Level Documents

以下文档属于补充背景材料：

- [secret_roy_sync_protocol.md](C:\Users\choom\Desktop\CodeRepo\roy\docs\secret_roy_sync_protocol.md)
- [secret_roy_whitepaper.md](C:\Users\choom\Desktop\CodeRepo\roy\docs\secret_roy_whitepaper.md)
- [BETA_RISK_REGISTER.md](C:\Users\choom\Desktop\CodeRepo\roy\docs\BETA_RISK_REGISTER.md)
- [BETA_TECHNICAL_DELIVERY.md](C:\Users\choom\Desktop\CodeRepo\roy\docs\BETA_TECHNICAL_DELIVERY.md)

## 3. Reading Guidance

如果你的目标是：

- 快速决策：先读 `00_Executive_Summary.md`
- 看整体结构：再读 `01_System_Architecture.md`
- 看启动/同步/冲突：读 `02_Runtime_and_Sync.md`
- 看风险和路线：读 `03_Risks_and_Roadmap.md`
- 看分布式系统质量改造方向：读 `04_Distributed_System_Quality_Iteration_Plan.md`
- 直接排期和开工：读 `05_Distributed_System_Implementation_Backlog.md`
