# SecretRoy 文档中心

**版本**: v1.1.0
**更新日期**: 2026-04-28

---

## 📚 企业级 Wiki

> 完整的项目文档，适合开发者和用户阅读。

| 文档 | 说明 |
|------|------|
| [wiki/Home.md](wiki/Home.md) | **Wiki 首页** — 项目概览与导航 |
| [wiki/User_Manual.md](wiki/User_Manual.md) | **用户手册** — 完整的软件使用指南 |
| [wiki/Quick_Start_Guide.md](wiki/Quick_Start_Guide.md) | **快速入门** — 5 分钟上手指南 |
| [wiki/Architecture_Overview.md](wiki/Architecture_Overview.md) | **架构概览** — 系统架构与技术选型 |
| [wiki/Code_Analysis.md](wiki/Code_Analysis.md) | **代码详细解读** — 核心代码逐行分析 |
| [wiki/Development_Setup.md](wiki/Development_Setup.md) | **开发环境** — 环境搭建与项目构建 |
| [wiki/Data_Models.md](wiki/Data_Models.md) | **数据模型** — 数据结构定义与 JSON 格式 |
| [wiki/API_Reference.md](wiki/API_Reference.md) | **API 参考** — 核心 API 文档 |
| [wiki/Testing_Guide.md](wiki/Testing_Guide.md) | **测试指南** — 测试策略与用例编写 |
| [wiki/Troubleshooting.md](wiki/Troubleshooting.md) | **故障排除** — 问题诊断与解决 |

---

## 📌 当前代码文档

| 文档 | 说明 |
|------|------|
| [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md) | **技术参考文档** — 基于全量代码扫描编写 |
| [AI_HANDOVER_NOTES.md](AI_HANDOVER_NOTES.md) | **AI 开发交接手册** — 硬性约束、常见陷阱 |
| [SECRETROY_ARCHITECTURE_DEEP_DIVE.md](SECRETROY_ARCHITECTURE_DEEP_DIVE.md) | **架构深度解析** — 单文件完整版 |
| [architecture_review/README.md](architecture_review/README.md) | **架构评审文档集入口** |

---

## 🔧 质量收敛文档

| 文档 | 说明 |
|------|------|
| [quality_convergence/README.md](quality_convergence/README.md) | **质量收敛索引** |
| [quality_convergence/01_Execution_Report.md](quality_convergence/01_Execution_Report.md) | **执行报告** — 代码质量改进记录 |
| [quality_convergence/02_Convergence_Plan.md](quality_convergence/02_Convergence_Plan.md) | **收敛计划** — 目标设定与风险评估 |

---

## 📋 设计文档

### 核心设计

| 文档 | 说明 |
|------|------|
| [secret_roy_whitepaper.md](secret_roy_whitepaper.md) | **白皮书** — 产品愿景与技术理念 |
| [secret_roy_sync_protocol.md](secret_roy_sync_protocol.md) | **同步协议** — 同步机制详解 |
| [06_Vault_Linking_Design.md](06_Vault_Linking_Design.md) | **Vault 链接设计** — 多设备配对机制 |
| [07_Key_Sync_Implementation.md](07_Key_Sync_Implementation.md) | **密钥同步实现** — 安全链接码、服务器配对与 LAN 配对 |
| [08_Local_Database_Encryption.md](08_Local_Database_Encryption.md) | **本地数据库加密** — `secret_roy_vault.db.enc` 二进制 AES-GCM-256 文件信封 |

### 模板系统

| 文档 | 说明 |
|------|------|
| [ACCOUNT_TEMPLATE_BUSINESS_ANALYSIS.md](ACCOUNT_TEMPLATE_BUSINESS_ANALYSIS.md) | **模板业务分析** — 功能设计与用例 |
| [ACCOUNT_TEMPLATE_IMPLEMENTATION_PLAN.md](ACCOUNT_TEMPLATE_IMPLEMENTATION_PLAN.md) | **模板实现计划** — 技术实现方案 |

### 架构演进

| 文档 | 说明 |
|------|------|
| [00_Executive_Summary.md](00_Executive_Summary.md) | 执行总结 |
| [01_System_Architecture.md](01_System_Architecture.md) | 系统架构 |
| [02_Runtime_and_Sync.md](02_Runtime_and_Sync.md) | 运行时与同步 |
| [03_Risks_and_Roadmap.md](03_Risks_and_Roadmap.md) | 风险与路线图 |
| [04_Enterprise_Improvement_Plan.md](04_Enterprise_Improvement_Plan.md) | 企业级改进计划 |
| [05_Distributed_System_Implementation_Backlog.md](05_Distributed_System_Implementation_Backlog.md) | 分布式实现待办 |

---

## 📝 变更日志

| 文档 | 说明 |
|------|------|
| [dev_log/sync_account_count_fix.md](dev_log/sync_account_count_fix.md) | 同步账号数量修复 |
| [dev_log/sync_fix_and_platform_adaptation.md](dev_log/sync_fix_and_platform_adaptation.md) | 同步修复与平台适配 |
| [DOCS_AUDIT_2026_04_28.md](DOCS_AUDIT_2026_04_28.md) | 2026-04-28 全量文档扫描与更新记录 |

---

## 🎯 Beta 发布文档

| 文档 | 说明 |
|------|------|
| [BETA_RISK_REGISTER.md](BETA_RISK_REGISTER.md) | Beta 风险登记 |
| [BETA_TECHNICAL_DELIVERY.md](BETA_TECHNICAL_DELIVERY.md) | Beta 技术交付 |

---

## 📖 教程

| 文档 | 说明 |
|------|------|
| [FLUTTER_NODE_BEGINNER_TUTORIAL.md](FLUTTER_NODE_BEGINNER_TUTORIAL.md) | Flutter + Node.js 入门教程 |

---

## 文档结构

```
docs/
├── wiki/                          # 企业级 Wiki
│   ├── Home.md                    # Wiki 首页
│   ├── User_Manual.md             # 用户手册
│   ├── Quick_Start_Guide.md       # 快速入门
│   ├── Architecture_Overview.md   # 架构概览
│   ├── Development_Setup.md       # 开发环境
│   ├── Data_Models.md             # 数据模型
│   ├── API_Reference.md           # API 参考
│   ├── Testing_Guide.md           # 测试指南
│   └── Troubleshooting.md         # 故障排除
│
├── quality_convergence/           # 质量收敛
│   ├── README.md
│   ├── 01_Execution_Report.md
│   └── 02_Convergence_Plan.md
│
├── architecture_review/           # 架构评审
│   └── ...
│
├── dev_log/                       # 开发日志
│   └── ...
│
└── (其他设计文档)
```

---

## 快速导航

| 角色 | 推荐阅读 |
|------|----------|
| 👤 **用户** | [用户手册](wiki/User_Manual.md) → [快速入门](wiki/Quick_Start_Guide.md) |
| 👨‍💻 **开发者** | [开发环境](wiki/Development_Setup.md) → [代码解读](wiki/Code_Analysis.md) → [API 参考](wiki/API_Reference.md) |
| 🏗️ **架构师** | [架构深度解析](SECRETROY_ARCHITECTURE_DEEP_DIVE.md) → [同步协议](secret_roy_sync_protocol.md) |
| 🧪 **测试人员** | [测试指南](wiki/Testing_Guide.md) → [故障排除](wiki/Troubleshooting.md) |

---

**文档版本**: v1.1.0
**最后更新**: 2026-04-28
