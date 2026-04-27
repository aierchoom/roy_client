# AI Developer Handover Notes (AI 开发交接手册)

> Current delta (2026-04-28): this handover was originally based on the 2026-04-18 code scan. Since then, `EnhancedCryptoService` has been upgraded to store `master_password_v2` PBKDF2-HMAC-SHA256 verifiers, unwrap a random local DB data key after unlock, and migrate legacy `master_password_v1` after successful verification. Secure vault link export/import now uses `sroy-secure-v2:` with PBKDF2-HMAC-SHA256 plus AES-GCM-256, LAN pairing uses 8 readable characters, and local SQLite now persists as `secret_roy_vault.db.enc` through a Dart AES-GCM-256 binary file envelope. Treat `docs/security/key-sync-implementation.md` and `docs/security/local-database-encryption.md` as the canonical security references.

> **致未来的 AI 助手：**
> 本文档基于 2026-04-18 对所有源代码的全面扫描编写。
> 如果代码已有更新，请以代码为准。

## 1. 核心硬性约束

### 1.1 数据库长期落盘必须是加密文件信封

- **事实**：数据库运行时仍使用 `sqflite`（移动端）和 `sqflite_common_ffi`（桌面端），**不使用 SQLCipher**。
- 长期落盘文件为 `secret_roy_vault.db.enc`，由 Dart 层 `DatabaseFileCipher` 以 AES-GCM-256 二进制信封加密。
- 解锁顺序必须是：先由 `EnhancedCryptoService.initMasterKey()` 校验/建立主密码并解开随机 DB 数据密钥，再调用 `SecureStorageService.setDatabaseCipher()` 和 `initialize()` 打开 SQLite。
- 解锁期间会在临时目录生成 `secret_roy_vault.runtime.db` 作为 SQLite 工作库，`close()` / 锁定时会重新封装并删除运行时文件。
- 不再兼容旧中间版本的 `secret_roy_vault.db` 明文库；初始化和重置路径可以清理它，不需要导入迁移。
- 同步层当前走记录级 CRDT payload，不再依赖服务端保存整库明文快照。

### 1.2 同步后的刷新延迟暂时保留

- 当前同步主路径是记录级 `/vaults/<vaultId>/sync`，pull 会将远端 `encrypted_signed_payload` 解封后合并到本地 runtime SQLite，再持久化 `.db.enc`。
- `ServiceManager.syncNow()` 在 pulled 后仍保留 `await Future.delayed(500ms)`，然后重新 `initialize()` storage/sync，作为刷盘和状态重读保护。
- 这不再是旧整库 `replaceDatabase()` 的必须补丁，而是保守刷新策略；要删除需要先补同步回归测试。

### 1.3 replaceDatabase 是备用整库替换入口

- 当前 `SyncService` 不再调用 `replaceDatabase()` 做主同步。
- 如果后续导入/恢复流程使用 `replaceDatabase()`，它会关闭当前连接、把传入 SQLite bytes 封装为 `secret_roy_vault.db.enc`，并删除 runtime/旧明文库。
- **调用方必须在替换后显式调用 `initialize()` 重新解封并打开数据库。**

### 1.4 同步配置存储在 SharedPreferences

- 同步服务器地址（`sync_server_url`）和自定义密钥（`custom_sync_key`）存储在 `SharedPreferences` 中。
- **不要把它们改存到数据库的 settings 表**——因为数据库会被同步覆盖，会丢失本设备的配置。

## 2. 关键业务路径

### 同步链路（已验证可用）

```
SyncService.syncNow() → 决策推/拉 → 执行
ServiceManager.syncNow() → 如果是 pull:
  1. 等 500ms
  2. storageService.initialize()      // 重新解封/刷新 runtime 状态
  3. syncService.initialize()         // 从 settings 读版本号/dirty 状态
  4. notifyListeners()                // 触发 EnhancedAppProvider.refresh()
  5. return SyncResult(version/conflictCount/notice)
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

### SyncService.syncNow() 的 pulled 刷新边界

- Pull 路径现在走记录级 merge，不再通过下载整库导致 DB 关闭。
- `ServiceManager.syncNow()` 仍在 pulled 后重新初始化 storage/sync 并通知 UI，这是当前的保守刷新边界。
- 不要把本机 sync server URL / custom sync key 放入会被 vault 同步覆盖的 settings 表；这些本机配置仍应留在 `SharedPreferences`。

---
*整理人：Antigravity (Google DeepMind Agent)*
*更新日期：2026-04-18*
*基于对所有源码文件的全量扫描*
