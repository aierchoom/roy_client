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

- [ARCHITECTURE_DOCS_INDEX.md](ARCHITECTURE_DOCS_INDEX.md)

推荐阅读顺序：

1. [00_Executive_Summary.md](00_Executive_Summary.md)
2. [01_System_Architecture.md](01_System_Architecture.md)
3. [02_Runtime_and_Sync.md](02_Runtime_and_Sync.md)
4. [03_Risks_and_Roadmap.md](03_Risks_and_Roadmap.md)

如果你更偏好单文件全集版本，请阅读：

- [SECRETROY_ARCHITECTURE_DEEP_DIVE.md](SECRETROY_ARCHITECTURE_DEEP_DIVE.md)

如果你是初学者，希望从教学视角理解项目，请阅读：

- [FLUTTER_NODE_BEGINNER_TUTORIAL.md](FLUTTER_NODE_BEGINNER_TUTORIAL.md)

## 2. Related Client Docs

当前已提交到 `roy_client/docs/` 的相关材料包括：

- [../TECHNICAL_DOCUMENTATION.md](../TECHNICAL_DOCUMENTATION.md)
- [../AI_HANDOVER_NOTES.md](../AI_HANDOVER_NOTES.md)
- [../ACCOUNT_TEMPLATE_BUSINESS_ANALYSIS.md](../ACCOUNT_TEMPLATE_BUSINESS_ANALYSIS.md)

注意：

- 本子目录只收录这次整理后的“当前代码导向”解读文档集。
- 仓库根目录里如果还有其他白皮书、协议草案或交付材料，应把它们视为补充背景，而不是这里这套文档的 source of truth。

## 3. Reading Guidance

如果你的目标是：

- 快速决策：先读 `00_Executive_Summary.md`
- 看整体结构：再读 `01_System_Architecture.md`
- 看启动/同步/冲突：读 `02_Runtime_and_Sync.md`
- 看风险和路线：读 `03_Risks_and_Roadmap.md`

