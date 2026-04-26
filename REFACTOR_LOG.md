# SecretRoy 重构日志 (April 2026 Refactor Log)

本项目在 2026 年 4 月经历了一次核心架构的彻底重构。以下是 AI 开发助手整理的重构纪实，用于帮助开发者理解代码现状的由来。

## 1. 重构背景
最初的 SecretRoy 在 Android 端使用 SQLCipher 物理层加密，而 Windows 端使用标准 SQLite + 字段级加密。这导致了**“同步死路”**：Android 创建的加密库在 Windows 上由于缺少解密元数据且文件格式不同而无法打开。

## 2. 三大核心改动

### 2.1 物理金库标准化 (Standardization)
- **动作**：移除了 Android 端 SQLCipher 的 `PRAGMA key` 物理锁。
- **现状**：全平台 `.db` 文件均为标准 SQLite 格式。
- **意义**：允许数据库文件像普通二进制流一样在多端自由流转。

### 2.2 解密元数据随库走 (Metadata-in-DB)
- **动作**：将 PBKDF2 的加密盐（Salt）和迭代次数（Iterations）从设备安全存储迁移到了数据库文件的 `settings` 表中。
- **现状**：数据库文件现在是“自包含（Self-contained）”的。
- **意义**：解决了“拉回数据但解不开”或“账号列表为空”的幽灵 Bug，实现了秒级跨端解密。

### 2.3 同步鲁棒性加固 (Sync Robustness)
- **动作**：引入了 500ms 重载延迟机制，解决了 Android 系统 IO 缓存导致的读脏数据问题。
- **动作**：重写了 `ServiceManager` 的 `syncNow` 链路，通过“激进刷新（Clear & Reload）”确保 UI 数据的一致性。
- **动作**：修复了 `Navigator.pop()` 在同步异常时的崩溃问题。

## 3. 历史变动清单 (Changeset Summary)
- `SecureStorageService`: 移除了数据库打开时的密码依赖。
- `EnhancedCryptoService`: 增加了 `initExistingKey` 方法以支持外挂 Salt 初始化。
- `ServiceManager`: 增加了 `_ensureMetadataInDb` 自动补全机制。
- `SyncService`: 重构了版本号逻辑，废弃了本地模拟版本号，完全信奉库内版本。

---
*整理人：Antigravity*
*状态：稳定，已交付测试。*
