# AI Developer Handover Notes (AI 开发交接手册)

> Current delta (2026-04-28): this handover was originally based on the 2026-04-18 code scan. Since then, `EnhancedCryptoService` has been upgraded to store `master_password_v2` PBKDF2-HMAC-SHA256 verifiers and migrate legacy `master_password_v1` after successful verification. Secure vault link export/import now uses `sroy-secure-v2:` with PBKDF2-HMAC-SHA256 plus AES-GCM-256, and LAN pairing uses 8 readable characters. Treat `docs/07_Key_Sync_Implementation.md` as the canonical key-sync reference.

> **致未来的 AI 助手：**
> 本文档基于 2026-04-18 对所有源代码的全面扫描编写。
> 如果代码已有更新，请以代码为准。

## 1. 核心硬性约束

### 1.1 数据库必须是明文 SQLite

- **事实**：数据库驱动为 `sqflite`（移动端）和 `sqflite_common_ffi`（桌面端），**不使用 SQLCipher**。
- 数据库文件 `secret_roy_vault.db` 为标准明文 SQLite 格式。
- `EnhancedCryptoService` 当前负责主密码 PBKDF2 校验与遗留主密码迁移；本地 SQLite 账号数据仍未接入 SQLCipher 或逐字段静态加密。
- 同步服务器上的文件名为 `vault.db.enc`，但内容实际上也是明文 SQLite。

### 1.2 同步后的 500ms 延迟不可删除

- 在 `ServiceManager.syncNow()` 的 pull 路径中，`replaceDatabase()` 会关闭 DB 连接并写入新文件。
- 必须 `await Future.delayed(500ms)` 才能重新 `initialize()`。
- 原因：文件系统存在写入缓冲区刷盘延迟（尤其是 Android）。

### 1.3 replaceDatabase 后必须重新 initialize

- `replaceDatabase()` 内部会将 `_database = null`，此后 `isOpen == false`。
- 任何 `loadAccounts()` 调用都会返回空列表。
- **调用方（ServiceManager）必须在替换后显式调用 `initialize()` 重新打开数据库。**

### 1.4 同步配置存储在 SharedPreferences

- 同步服务器地址（`sync_server_url`）和自定义密钥（`custom_sync_key`）存储在 `SharedPreferences` 中。
- **不要把它们改存到数据库的 settings 表**——因为数据库会被同步覆盖，会丢失本设备的配置。

## 2. 关键业务路径

### 同步链路（已验证可用）

```
SyncService.syncNow() → 决策推/拉 → 执行
ServiceManager.syncNow() → 如果是 pull:
  1. 等 500ms
  2. storageService.initialize()      // 重新打开 DB
  3. syncService.initialize()         // 从新 DB 读版本号
  4. storageService.loadAccounts()    // 获取真实账号数
  5. notifyListeners()                // 触发 EnhancedAppProvider.refresh()
  6. return SyncResult(accountCount:N) // 正确数量
```

### 数据刷新

- `EnhancedAppProvider` 监听 `ServiceManager` 的 `notifyListeners()`。
- 在 `isUnlocked` 状态下收到通知会自动调用 `refresh()`。
- `refresh()` 采用"激进刷新"策略：先清空列表再加载。

### 数据变更标记脏

- `ServiceManager.saveAccount()` / `deleteAccount()` / `saveTemplate()` / `deleteTemplate()` 都会调用 `SyncService.markDirty()`。
- `markDirty()` 会立即递增 `_localVersion` 并持久化到 settings 表。

## 3. 常见陷阱

### Flutter Context 使用

- **不要在 `await` 之后直接使用 `BuildContext`**——widget 可能已 deactivate。
- 在 `await` 前保存 `ScaffoldMessenger.of(context)` / `Navigator.of(context)` 到局部变量。
- `showModalBottomSheet` 和 `showDialog` 的 `builder:(context)` 参数会**遮蔽外层 context**。必须重命名为 `sheetContext` / `dialogContext`。

### 不要删除 `notifyListeners()` 调用

- 同步链路依赖 `ServiceManager → EnhancedAppProvider` 的通知传导。
- 删除任何一处 `notifyListeners()` 都可能导致 UI 不刷新。

### SyncService.syncNow() 中的 accountCount

- Pull 路径中，`loadAccounts()` 在 `replaceDatabase()` 之后调用，此时 DB 已关闭，**返回值始终为 0**。
- 正确的做法是由 `ServiceManager.syncNow()` 在 `initialize()` 之后重新查询。
- 不要试图在 `SyncService` 层面修复这个问题——这是架构设计的分层边界。

### 未使用的代码

| 代码 | 说明 |
|------|------|
| `SyncService._cryptoService` | 构造时接收但未调用任何方法 |
| `SyncService._getSyncKey()` | 恒返回空字符串 |
| `SyncResult.hasMetadata` | 恒为 false |
| `sync_metadata` 表 | Schema 中创建但无 CRUD 代码 |
| `uuid` 依赖包 | pubspec 中声明但代码中未 import |
| `json_serializable` / `build_runner` | dev 依赖但未配置 build.yaml |

---
*整理人：Antigravity (Google DeepMind Agent)*
*更新日期：2026-04-18*
*基于对所有源码文件的全量扫描*
