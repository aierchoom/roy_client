# LAN 同步实施过程中发现的问题

| 日期 | 2026-05-10 |
|---|---|
| 发现者 | 实施阶段 |
| 状态 | 待解决 |

---

## 问题 1：SecureStorageService 缺少 approved 状态 LocalSyncChange 的创建方法

### 描述

`LanSyncHostHandler._commitToDatabase()` 需要为每条 `syncStatus == pendingPush` 的记录自动创建一条 `LocalSyncStatus.approved` 的 `LocalSyncChange`，以确保后续服务器 Push 能识别这些记录。

但 `SecureStorageService` 中现有的 `recordLocalSyncChange()` 方法总是创建 `LocalSyncStatus.pendingReview` 状态的记录。

### 影响

LAN 同步完成后，如果接收方（B）的某记录变成 `pendingPush`，但 `local_sync_changes` 表中没有对应的 approved 记录，那么 B 后续与服务器同步时，`_runPushPhase` 通过 `approvedChangeKeys` 过滤会跳过该记录，导致修改永远推不到服务器。

### 建议方案

在 `SecureStorageService` 中新增方法：

```dart
Future<void> createApprovedLocalSyncChange({
  required String vaultId,
  required LocalSyncEntityType entityType,
  required String entityId,
  required String title,
  int baseServerVersion = 0,
});
```

或者修改 `recordLocalSyncChange` 增加可选参数 `status = LocalSyncStatus.pendingReview`。

---

## 问题 2：SecureStorageService 未暴露 SQLite transaction/batch

### 描述

`LanSyncHostHandler.commit()` 和 `LanSyncClient._commitLocal()` 需要将多条记录在一个 SQLite 事务中写入，以确保原子性。

但 `SecureStorageService` 的 `_database` 是私有的，没有暴露 `transaction()` 或 `batch()` 方法。当前实现只能逐条调用 `saveAccount()`、`saveTemplate()`、`saveTotpCredential()`，每条调用内部还有额外的查询逻辑（如 `isSyncMerge=false` 时的 HLC stamping）。

### 影响

- **性能**：100 条记录需要 100 次异步调用，每次内部有 1~2 次数据库查询
- **原子性**：逐条调用之间如果崩溃，部分记录已写入、部分未写入，破坏了"中断即未完成"的语义

### 建议方案

方案 A（推荐）：在 `SecureStorageService` 中新增：

```dart
Future<void> commitLanSyncBatch({
  required List<AccountItem> accounts,
  required List<AccountTemplate> templates,
  required List<TotpCredential> totps,
  required List<ConflictLog> conflictLogs,
  required String vaultId,
});
```

该方法内部使用 `Batch` 一次性写入所有数据，并在同一批次中补录 approved LocalSyncChange。

方案 B：暴露一个简化的事务回调：

```dart
Future<void> transaction(Future<void> Function(Batch batch) action);
```

---

## 问题 3：`AccountItem.fromJson` 反序列化时 `_type` 字段干扰

### 描述

`SyncPayloadCodec.encodeAccount()` 在序列化时会在 JSON 中注入 `_type: 'account'` 字段。`AccountItem.fromJson()` 可能不认识这个字段，导致反序列化时丢失数据或报错。

需要验证 `AccountItem.fromJson()` 是否能安全忽略未知字段。

### 建议方案

检查 `AccountItem.fromJson()` 实现，确保它对 JSON 中未定义的字段做静默忽略（而非抛出异常）。如果当前实现会报错，需要在 `LanSyncHostHandler` / `LanSyncClient` 的 `_payloadToItem` 方法中先删除 `_type` 字段再调用 `fromJson`。

---

## 问题 4：`SyncService.isSyncing` 的可见性

### 描述

`LanSyncClient` 需要检查 `SyncService.isSyncing` 来实现双通道互斥。但 `SyncService` 中 `isSyncing` 是公共 getter，没有 `@visibleForTesting` 限制，可以直接访问。

**这不是问题**，只是确认依赖关系。

---

## 问题 5：`TotpCredentialMergeEngine` 的返回值类型

### 描述

`CrdtMergeEngine.merge()` 返回 `MergeResult`（包含 `mergedItem` 和 `conflictLogs`）。

但 `TotpCredentialMergeEngine.merge()` 返回 `TotpCredential`（单个对象，不包含 conflictLogs）。

在 `LanSyncHostHandler._runMerge()` 中，处理 totp 时无法收集冲突日志。

### 建议方案

- 方案 A：扩展 `TotpCredentialMergeEngine.merge()` 返回一个包含 conflictLogs 的结果类型
- 方案 B：在 `LanSyncHostHandler` 中 totp 处理暂时不收集冲突（因为 TOTP 字段较少，冲突概率低）

当前代码采用方案 B（暂不收集 TOTP 冲突日志）。

---

## 问题 6：Host 端 `_loadHostItems()` 加载全部数据 vs 只加载 changed 数据

### 描述

当前 `LanSyncHostHandler.handlePull()` 在返回 mergedItems 之外，还会调用 `_loadHostItems()` 加载 Host 的全部数据推给 B。

这意味着：
- 如果 Host 有 1000 条账号，B 只修改了 1 条，Pull 时仍然要传输 1000 条
- 传输量巨大，浪费带宽和时间

### 建议方案

在 `handlePull` 时只传输：
1. mergedItems（A 和 B 有冲突/差异的记录）
2. Host 有但 B 没有的新增记录

需要一种方式让 Host 知道 B 有哪些记录。可以在 `/lan-sync/start` 时让 B 发送自己的 record ID 列表，Host 据此计算差集。

当前代码采用全量传输（简化实现），后续优化。

---

## 当前决策

| 问题 | 决策 | 优先级 |
|---|---|---|
| 问题 1：approved LocalSyncChange | 在 `SecureStorageService` 中新增 `createApprovedLocalSyncChange` | **P0** |
| 问题 2：transaction/batch 暴露 | 在 `SecureStorageService` 中新增 `commitLanSyncBatch` | **P0** |
| 问题 3：`_type` 字段干扰 | 在 `_payloadToItem` 中删除 `_type` 后再 fromJson | P1 |
| 问题 5：TOTP 冲突日志 | 暂不收集，后续统一 MergeResult 类型 | P2 |
| 问题 6：全量传输 | 当前全量传输，后续优化为增量 | P2 |
