# SecretRoy 企业级 Wiki

**版本**: v1.1.0
**最后更新**: 2026-04-28

---

## 项目概览

SecretRoy 是一款**分布式密码管理器**，采用端到端加密和 CRDT（无冲突复制数据类型）同步技术，支持多设备安全同步。

### 核心特性

| 特性 | 描述 |
|------|------|
| 🔐 端到端安全 | PBKDF2 主密码校验、AES-GCM 安全链接码、同步载荷完整性保护 |
| 🔄 CRDT 同步 | 无冲突复制，支持离线编辑和多设备合并 |
| 🌐 多种同步方式 | 云服务器同步、局域网配对、Vault 链接码 |
| 📱 跨平台 | Android、iOS、Windows、macOS、Linux |
| 🎨 模板系统 | 可自定义账户模板，灵活管理不同类型密码 |
| ⚡ 本地优先 | 所有数据本地存储，无需联网即可使用 |

---

## Wiki 导航

### 📖 用户文档

| 文档 | 描述 |
|------|------|
| [用户手册](./User_Manual.md) | 完整的软件使用指南 |
| [快速入门](./Quick_Start_Guide.md) | 5 分钟快速上手 |
| [常见问题](./FAQ.md) | 常见问题解答 |

### 🛠️ 开发者文档

| 文档 | 描述 |
|------|------|
| [开发环境搭建](./Development_Setup.md) | 环境配置与项目构建 |
| [架构概览](./Architecture_Overview.md) | 系统架构与技术选型 |
| [代码详细解读](./Code_Analysis.md) | 核心代码逐行分析 |
| [API 参考](./API_Reference.md) | 核心 API 文档 |
| [数据模型](./Data_Models.md) | 数据结构定义 |

### 🧪 测试与质量

| 文档 | 描述 |
|------|------|
| [测试指南](./Testing_Guide.md) | 测试策略与用例编写 |
| [质量收敛报告](../quality_convergence/README.md) | 代码质量改进记录 |

### 🚀 运维与部署

| 文档 | 描述 |
|------|------|
| [部署指南](./Deployment_Guide.md) | 生产环境部署 |
| [故障排除](./Troubleshooting.md) | 问题诊断与解决 |

### 📚 设计文档

| 文档 | 描述 |
|------|------|
| [Vault 链接设计](../06_Vault_Linking_Design.md) | 多设备配对机制 |
| [密钥同步实现](../07_Key_Sync_Implementation.md) | 安全链接码、服务器配对与 LAN 直连配对 |
| [加密方案评估](./Encryption_Assessment.md) | 加密技术分析 |
| [模板系统设计](../ACCOUNT_TEMPLATE_BUSINESS_ANALYSIS.md) | 模板功能设计 |

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 前端框架 | Flutter 3.x |
| 状态管理 | Provider |
| 本地存储 | SharedPreferences + FlutterSecureStorage |
| 加密与密钥同步 | PBKDF2 主密码校验 + AES-GCM 安全链接码 |
| 同步引擎 | CRDT + HLC (Hybrid Logical Clock) |
| 后端服务 | Node.js + Express (可选云同步) |
| 协议 | HTTPS + 自定义同步协议 |

---

## 项目结构

```
roy_client/
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── models/                   # 数据模型
│   │   ├── account.dart
│   │   ├── account_template.dart
│   │   └── vault.dart
│   ├── services/                 # 业务服务
│   │   ├── secure_storage_service.dart
│   │   ├── enhanced_crypto_service.dart
│   │   ├── sync_service.dart
│   │   ├── crdt_merge_engine.dart
│   │   └── lan_pairing_service.dart
│   ├── providers/                # 状态管理
│   │   └── enhanced_app_provider.dart
│   ├── views/                    # 视图层
│   │   ├── accounts/
│   │   ├── templates/
│   │   └── sync_settings_view.dart
│   ├── widgets/                  # 可复用组件
│   ├── l10n/                     # 国际化
│   └── utils/                    # 工具类
├── test/                         # 测试
├── docs/                         # 文档
└── pubspec.yaml                  # 依赖配置
```

---

## 快速链接

- [架构深度解析](../SECRETROY_ARCHITECTURE_DEEP_DIVE.md)
- [技术实现指南](../TECHNICAL_IMPLEMENTATION_GUIDE.md)
- [白皮书](../secret_roy_whitepaper.md)
- [变更日志](../../CHANGELOG.md)

---

## 联系与支持

- **问题反馈**: GitHub Issues
- **功能建议**: GitHub Discussions
- **安全漏洞**: 安全团队邮箱

---

*本文档由 SecretRoy 团队维护*
