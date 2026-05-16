# SecretRoy 企业级 Wiki

**版本**: v1.1.0
**最后更新**: 2026-05-16

---

## 项目概览

SecretRoy 是一款**分布式密码管理器**，采用端到端加密和 CRDT（无冲突复制数据类型）同步技术，支持多设备安全同步。

### 核心特性

| 特性 | 描述 |
|------|------|
| 🔐 端到端安全 | PBKDF2 主密码校验、AES-GCM 离线恢复码、同步载荷完整性保护 |
| 🔄 CRDT 同步 | 无冲突复制，支持离线编辑和多设备合并 |
| 🌐 多种同步方式 | 云服务器同步、面对面链接、远程配对、离线恢复码 |
| 📱 跨平台 | Android、iOS、Windows、macOS、Linux |
| 🎨 模板系统 | 可自定义账户模板，灵活管理不同类型密码 |
| ⚡ 本地优先 | 所有数据本地存储，无需联网即可使用 |

---

## Wiki 导航

### 📖 用户文档

| 文档 | 描述 |
|------|------|
| [用户手册](user-manual.md) | 完整的软件使用指南 |
| [快速入门](quick-start-guide.md) | 5 分钟快速上手 |
| [故障排除](troubleshooting.md) | 常见问题与问题诊断 |

### 🛠️ 开发者文档

| 文档 | 描述 |
|------|------|
| [开发环境搭建](development-setup.md) | 环境配置与项目构建 |
| [代码走读](code-walkthrough.md) | 按用户旅程的代码走读与功能速查 |
| [API 参考](api-reference.md) | 核心 API 文档 |
| [数据模型](data-models.md) | 数据结构定义 |

### 🧪 测试与质量

| 文档 | 描述 |
|------|------|
| [测试指南](testing-guide.md) | 测试策略与用例编写 |
| [执行报告](../reports/execution/README.md) | 功能开发与质量收敛记录 |

### 🚀 运维与部署

| 文档 | 描述 |
|------|------|
| [故障排除](troubleshooting.md) | 问题诊断与解决 |

### 📚 设计文档

| 文档 | 描述 |
|------|------|
| [Vault 链接设计](../sync/vault-linking-design.md) | 多设备配对机制 |
| [密钥恢复路线](../sync/vault-recovery-routes.md) | 面对面链接、远程配对、离线恢复码、内部兼容码 |
| [密钥同步实现](../security/key-sync-implementation.md) | 面对面链接、远程配对与离线恢复码实现 |
| [本地数据库加密](../security/local-database-encryption.md) | 加密技术分析 |
| [模板系统设计](../features/account-templates/business-analysis.md) | 模板功能设计 |

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 前端框架 | Flutter 3.x |
| 状态管理 | Provider |
| 本地存储 | SharedPreferences + FlutterSecureStorage |
| 加密与密钥同步 | PBKDF2 主密码校验 + AES-GCM 离线恢复码 |
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
│   │   ├── account_item.dart
│   │   ├── account_template.dart
│   │   ├── totp_credential.dart
│   │   └── template_conflict_log.dart
│   ├── services/                 # 业务服务
│   │   ├── secure_storage_service.dart
│   │   ├── enhanced_crypto_service.dart
│   │   ├── identity_service.dart
│   │   ├── notification_service.dart
│   │   └── auto_lock_service.dart
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

- [架构深度解析](../architecture/architecture-deep-dive.md)
- [技术文档](../guides/technical-documentation.md)
- [业务规格](../product/business-specification.md)

---

## 联系与支持

- **问题反馈**: GitHub Issues
- **功能建议**: GitHub Discussions
- **安全漏洞**: 安全团队邮箱

---

*本文档由 SecretRoy 团队维护*
