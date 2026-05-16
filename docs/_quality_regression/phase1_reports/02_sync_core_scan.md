[stage] runner_started
[stage] agent_built
[stage] context_restored
[stage] context_ready
[stage] run_soul_start
[tool] Glob
[tool] Glob
[tool_result] success
[tool] Glob
[tool_result] success
[tool_result] success
[tool] ReadFile
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool_result] success
[tool] Grep
[tool] Grep
[tool_result] success
[tool] Grep
[tool_result] success
[tool_result] success
# 同步协议技术规范更新版（基于 `lib/sync/` 代码扫描）

> 扫描范围：`lib/sync/` 下 12 个 Dart 文件  
> 对比文档：`docs/sync/sync-protocol.md`、`docs/architecture/02-runtime-and-sync.md`

---

## 1. 同步架构总览

```
┌─────────────────────────────────────────────────────────────┐
│                        SyncService                          │
│  (ChangeNotifier, 核心状态机 + 编排器)                        │
├─────────────────────────────────────────────────────────────┤
│  Part: sync_service_pull.dart  ──► 拉取 + 解密 + 本地合并    │
│  Part: sync_service_push.dart  ──► 批准队列 + 加密 + 推送    │
│  Part: sync_service_conflict.dart ──► 冲突恢复策略           │
├─────────────────────────────────────────────────────────────┤
│  依赖:                                                       │
│    • CrdtMergeEngine          (账号/模板字段级 CRDT 合并)     │
│    • TotpCredentialMergeEngine (TOTP 凭证字段级合并)          │
│    • SyncPayloadCodec         (sroy-sync: AEAD 信封编解码)   │
│    • IdentityService          (vaultId, deviceId, keys)    │
│    • SecureStorageService     (本地 SQLite + outbox)        │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
   ┌─────────┐         ┌────────────┐         ┌─────────────┐
   │ LAN Sync │         │ HTTP Sync  │         │  Recovery   │
   │ Coordinator         │  Client    │         │  Marker     │
   │ (ChangeNotifier)    │  (Server)  │         │  (磁盘持久)  │
   └─────────┘         └────────────┘         └─────────────┘
        │
   ┌────┴────┐
   ▼         ▼
LanSyncClient   LanSyncHostHandler
(请求者B)       (宿主A)
```

**文件职责矩阵**

| 文件 | 职责 |
|---|---|
| `sync_service.dart` | 状态机、初始化、错误分类、recovery marker、定时器 |
| `sync_service_types.dart` | `SyncState`、`SyncConfig`、`SyncResult`、异常类 |
| `sync_service_pull.dart` | `GET /vaults/:id/sync`、分页拉取、解密、apply remote changes |
| `sync_service_push.dart` | `POST /vaults/:id/sync`、批准 outbox、加密、接受版本处理 |
| `sync_service_conflict.dart` | 5 种冲突类型的恢复策略 |
| `crdt_merge_engine.dart` | `AccountItem` 与 `AccountTemplate` 的字段级 LWW + tombstone 合并 |
| `totp_credential_merge_engine.dart` | `TotpCredential` 的字段级 LWW + tombstone 合并 |
| `sync_payload_codec.dart` | `sroy-sync:` 前缀 AES-256-GCM + HKDF 信封 |
| `lan_sync_coordinator.dart` | LAN 同步生命周期协调、角色管理 |
| `lan_sync_client.dart` | 请求者端：start → push → poll → pull → commit |
| `lan_sync_host_handler.dart` | 宿主端：start → receive → merge → pull → commit |
| `lan_sync_session.dart` | LAN 阶段枚举、会话状态、配置、异常常量 |

---

## 2. 状态机定义（状态和迁移）

### 2.1 同步状态枚举 (`SyncState`)

| 状态 | 类型 | 语义 |
|---|---|---|
| `offline` | 正常 | 未配置服务器或用户手动断开 |
| `connecting` | 正常 | 正在连接/握手 |
| `pulling` | 正常 | 正在拉取远端更新 |
| `pushing` | 正常 | 正在推送已批准的本地变更 |
| `idle` | 正常 | 同步完成 |
| `conflictRecovery` | 正常 | 冲突恢复中（自动重试循环内） |
| `networkUnreachable` | **错误** | 网络不可达（Socket/Timeout/ClientException） |
| `serverError` | **错误** | 服务端 5xx |
| `protocolError` | **错误** | 协议解析失败、payload 校验失败、cleartext HTTP、max retries |
| `authError` | **错误** | 身份未建立 |

### 2.2 状态迁移图

```
[任意状态] ──► reset()/disconnect() ──► offline

offline ──► connect() ──► [syncNow()]
              │
              ▼
        ┌───────────┐
        │ connecting │ ◄── 循环开始 / recovery 后重试
        └─────┬─────┘
              │
              ▼
        ┌───────────┐     无 recovery marker
        │  pulling   │ ◄──┘
        └─────┬─────┘
              │ 有 ConflictException
              ▼
        ┌───────────┐      无冲突
        │  pushing   │ ─────┐
        └─────┬─────┘      │
              │            ▼
              │       ┌─────────┐
              │       │  idle   │
              │       └─────────┘
              │
              ▼
        ┌─────────────────┐
        │ conflictRecovery │ ──► 延迟 500ms × retryCount ──► 回到 connecting
        └─────────────────┘      (最多 3 次)

错误迁移（任何时候发生未捕获异常）：
  • SocketException / TimeoutException ──► networkUnreachable
  • http.ClientException 含 "SocketException"/"Connection failed" ──► networkUnreachable
  • http.ClientException 含 "cleartext" ──► protocolError
  • SyncHttpException status >= 500 ──► serverError
  • SyncHttpException status < 500 ──► protocolError
  • SyncProtocolException ──► protocolError
  • SyncPayloadException ──► protocolError
  • 其他 ──► protocolError
```

### 2.3 Recovery Marker 持久化状态

SyncService 在磁盘保存 `SyncRecoveryMarker`，支持崩溃恢复：

| Phase | 写入时机 | 恢复行为 |
|---|---|---|
| `pull` | pull phase 开始前 | 从 marker.localVersion 重新 pull |
| `push` | push phase 开始前 | 执行完整快照 pull + merge |
| `conflictRecovery` | 捕获 ConflictException 后 | 进入冲突恢复循环 |

---

## 3. CRDT 合并算法详细说明

系统支持三种实体的合并：`AccountItem`、`AccountTemplate`、`TotpCredential`。核心共同模式：**字段级 LWW + Tombstone 优先**。

### 3.1 HLC 比较规则

代码位于 `models/hlc.dart`（未在本次扫描范围内，由调用侧推断）：

- 比较优先级：**物理时间戳 > 逻辑计数器 > 设备 ID 字典序**
- `Hlc.zero('local')` / `Hlc.zero('remote')` 作为缺失字段的默认值
- `isCorrupted` 属性：若远程 HLC 被判定损坏，本地无条件获胜

### 3.2 AccountItem 合并算法 (`CrdtMergeEngine.merge`)

**输入**：`local`, `remote`（必须同 `id`）  
**输出**：`MergeResult(AccountItem, List<ConflictLog>, isPureFastForward)`

**步骤**：

1. **远程 HLC 损坏检测**  
   若 `remote.nameHlc.isCorrupted || remote.emailHlc.isCorrupted || remote.dataHlc.values.any(...) || remote.pinHlc?.isCorrupted`，返回本地副本 + `syncStatus = pendingPush`，并生成一条 `hlc.corrupted_remote` 冲突日志。

2. **Tombstone Trumps All（墓碑拦截）**  
   - 双方都删除：取 `deleteHlc` 更大的一方，返回其副本 + `synchronized`
   - 仅远程删除：若 `remote.deleteHlc > max(local 所有字段 HLC)`，接受墓碑；否则本地在删除后又做了修改，**本地复活**
   - 仅本地删除：若 `local.deleteHlc > max(remote 所有字段 HLC)`，坚持墓碑；否则远程在删除后又做了修改，**接受远程**

3. **字段级 LWW 穿透合并**  
   对以下字段逐对比较 HLC：

   | 字段 | 本地 HLC | 远程 HLC | 胜者 |
   |---|---|---|---|
   | `name` | `local.nameHlc` | `remote.nameHlc` | HLC 大者 |
   | `email` | `local.emailHlc` | `remote.emailHlc` | HLC 大者 |
   | `data.<key>` | `local.dataHlc[key]` (缺省 zero) | `remote.dataHlc[key]` (缺省 zero) | HLC 大者 |
   | `isPinned` | `local.pinHlc` (缺省 zero) | `remote.pinHlc` (缺省 zero) | HLC 大者 |

   - 若 remote 胜且 `lVal != rVal`，记录本地旧值到 `ConflictLog`
   - 若 local 胜且 `rVal != lVal` 且 `rHlc.time > 0`，记录远程旧值到 `ConflictLog`
   - `null` 值被视为**字段删除**（不写入 mergedData）

4. **收敛状态分析 (`isPureFastForward`)**  
   检查合并结果的每个字段 HLC 是否**完全等于 remote 的对应字段 HLC**：
   - 若全部相等 → `isPureFastForward = true`
   - 若存在差异 → `isPureFastForward = false`

5. **最终 `syncStatus` 判定**  
   - `isPureFastForward == true` → `synchronized`（本地完全被远端覆盖）
   - `isPureFastForward == false` 且 `local.syncStatus == pendingPush` → `conflict`（本地原本就有未推送修改，合并后需人工核对）
   - `isPureFastForward == false` 且 `local.syncStatus != pendingPush` → `pendingPush`（本地之前是同步状态，合并产生了新缝合内容，需要推回服务端）

### 3.3 AccountTemplate 合并算法 (`CrdtMergeEngine.mergeTemplate`)

与 AccountItem 类似，但结构不同：

- **顶层 tombstone**：比较 `deleteHlc`
- **顶层 LWW**：若未删除，比较 `local.hlc` vs `remote.hlc`，胜者决定 `title`, `subTitle`, `iconCodePoint`, `category`
- **字段级 LWW**：对 `fields` 列表中的每个 `AccountField`，分别比较 `labelHlc`, `descriptionHlc`, `attributesHlc`, `orderHlc`
- **字段排序**：合并后的 `resolvedFields` 按 `order` 升序排列
- **fast-forward 判定**：要求顶层 remote 赢，且每个 field 的四维 HLC 完全等于 remote 对应 field

### 3.4 TotpCredential 合并算法 (`TotpCredentialMergeEngine.merge`)

简化版三字段 + 删除：

| 字段 | HLC 来源 |
|---|---|
| `label` | `labelHlc` |
| `config` | `configHlc` |
| `linkedAccountIds` | `linksHlc` |
| `isDeleted` | `deleteHlc`（`_remoteDeleteWins` 特殊逻辑） |

- 损坏检测逻辑与 AccountItem 一致
- 无 `conflictLog` 产出（代码层面静默合并）
- 删除逻辑：若仅一方有 `deleteHlc`，则直接比较；若双方都有，取 HLC 更大者

---

## 4. Payload 加密规范

### 4.1 算法参数 (`SyncPayloadCodec`)

| 参数 | 值 |
|---|---|
| 前缀 | `sroy-sync:` |
| 版本 | `1` |
| 算法标识 | `aes-256-gcm-hkdf-sha256` |
| Nonce 长度 | 12 bytes |
| Salt 长度 | 16 bytes |
| 派生密钥长度 | 32 bytes |

### 4.2 密钥派生 (`_derivePayloadKey`)

```dart
Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
  secretKey: SecretKey(utf8.encode(symmetricKey) + [0x00] + utf8.encode(privateKey)),
  nonce: salt,
  info: utf8.encode('sroy-sync-payload|aes-256-gcm-hkdf-sha256|$vaultId'),
)
```

- **IKM** = `symmetricKey || 0x00 || privateKey`（UTF-8 字节拼接）
- **Salt** = 随机 16 bytes
- **Info** = 固定字符串 `sroy-sync-payload|aes-256-gcm-hkdf-sha256|<vaultId>`

### 4.3 附加认证数据 (AAD)

```
v=1;alg=aes-256-gcm-hkdf-sha256;vault=<vaultId>;node=<nodeId>
```

### 4.4 信封 JSON 结构

```json
{
  "v": 1,
  "alg": "aes-256-gcm-hkdf-sha256",
  "vault_id": "<vaultId>",
  "node_id": "<nodeId>",
  "salt": "<base64url>",
  "nonce": "<base64url>",
  "ciphertext": "<base64url>",
  "mac": "<base64url>"
}
```

外层：前缀 + base64url(UTF-8(信封 JSON))，无 padding。

### 4.5 解码校验流程

1. 检查 `sroy-sync:` 前缀
2. 解析信封 JSON
3. 校验 `v == 1`、`alg` 匹配、`vault_id` 非空且等于 `expectedVaultId`、`node_id` 非空
4. 校验 salt/nonce/ciphertext/mac 存在且长度合规
5. 重新派生密钥，用 AAD 解密
6. 返回 `Map<String, dynamic>` payload

### 4.6 实体类型标记

编码时向 `toJson()` 结果注入 `_type` 字段：
- AccountItem → `"account"`
- AccountTemplate → `"template"`
- TotpCredential → `"totp_credential"`

解码时根据 `_type` 路由到对应模型。

---

## 5. LAN 同步流程

LAN 同步是与 HTTP Server 同步**互斥**的独立通道，由 `LanSyncCoordinator` 管理。

### 5.1 红线约束（代码注释明确声明）

1. **不读写 `_localVersion` / `serverVersion`** — LAN 同步不影响服务端同步版本号
2. **不写 `syncStatus = synchronized`** — LAN 同步只产生 `pendingPush`（以便后续服务端同步时推送）
3. **与 server sync 互斥** — `LanSyncCoordinator` 和 `LanSyncClient` 都会检查 `_syncService.isSyncing`，若 server sync 活跃则拒绝启动

### 5.2 LAN 同步阶段 (`LanSyncPhase`)

```
idle → connecting → receiving → merging → resolving → pushing → committing → completed
                                          ↓
                                    interrupted / failed
```

| 阶段 | 说明 |
|---|---|
| `connecting` | 建立会话，交换 record ID 列表 |
| `receiving` | 请求者推送本地加密数据，宿主接收 |
| `merging` | 宿主执行 CRDT 合并 |
| `resolving` | 宿主侧存在冲突，等待用户确认 |
| `pushing` | 请求者拉取合并结果；宿主准备响应 |
| `committing` | 双方写入本地数据库 |
| `completed` | 完成 |
| `interrupted` | 用户/异常中断 |
| `failed` | 处理失败 |

### 5.3 完整流程（Host A ↔ Requester B）

```
B (Requester)                          A (Host)
──────────────────────────────────────────────────────────────────
1. discoverHost() ──► 获取 A 的 IP:Port
2. POST /lan-sync/start
   {device_id, record_ids} ──►
                              ◄─── {session_id, ttl_seconds}
3. _pushLocalData()
   分页 POST /lan-sync/push
   {session_id, page, items:[cipher,...]} ──►
                              ◄─── {accepted, phase}
4.                          触发 triggerMerge(sessionId)
                            调用 CrdtMergeEngine.merge()
                            生成 conflictPreview（如有）
5. _pollUntilMerged()
   轮询 POST /lan-sync/result
   {session_id} ──►
                              ◄─── {phase, conflict_count, [conflict_preview]}
                            直到 phase == "pushing"
6. POST /lan-sync/pull
   {session_id} ──►
                              ◄─── {items:[cipher,...]}
                            含：合并结果 + Host 有但 B 没有的增量
7. _commitLocal()
   解密并写入本地 DB
   标记为 pendingPush
8.                          用户确认后 hostCommit()
                            写入 Host 本地 DB
                            标记为 pendingPush
```

### 5.4 关键机制

- **会话 TTL**：默认 3 分钟 (`LanSyncConfig.sessionTtl`)
- **分页大小**：默认 100 条 (`LanSyncConfig.pageSize`)
- **轮询上限**：180 次 × 500ms = 90 秒超时
- **增量传输**：Host 在 `handlePull` 时，会把 Host 有但 Requester 没有（通过 `peerRecordIds` 过滤）的记录一并推给 B
- **加密连续性**：LAN 同步复用与服务端同步完全相同的 `SyncPayloadCodec`，密钥材料来自 `IdentityService`

---

## 6. 公共 API 清单

### 6.1 `SyncService` (`sync_service.dart`)

| 成员 | 类型 | 说明 |
|---|---|---|
| `state` | `SyncState` | 当前状态 |
| `errorMessage` | `String?` | 错误日志（供调试） |
| `statusNote` | `String?` | 用户友好状态说明 |
| `lastSyncTime` | `DateTime?` | 上次成功同步时间 |
| `isConnected` | `bool` | 是否处于连接/活跃状态 |
| `isSyncing` | `bool` | 是否正在同步中 |
| `localVersion` | `int` | 本地同步版本号 |
| `isDirty` | `bool` | 是否有未推送变更 |
| `initialize()` | `Future<void>` | 从持久化恢复版本/时间/dirty 状态 |
| `markDirty()` | `Future<void>` | 标记本地有变更待同步 |
| `reconcileDirtyState()` | `Future<void>` | 根据 outbox 实际存在性校准 dirty |
| `reset()` / `disconnect()` | `Future<void>` | 断开并停止定时器 |
| `connect()` | `Future<bool>` | 执行一次同步并启动定时同步 |
| `syncNow()` | `Future<SyncResult>` | 立即执行完整同步循环 |
| `recoveryPhase` | `String?` | `@visibleForTesting` 读取 recovery 阶段 |

### 6.2 异常与结果类型 (`sync_service_types.dart`)

| 类/枚举 | 说明 |
|---|---|
| `SyncState` + `SyncStateExt.isError` | 10 状态枚举 |
| `SyncConfig` | `serverUrl`, `syncInterval`（默认 5 分钟） |
| `SyncRecoveryPhase` | `pull` / `push` / `conflictRecovery` |
| `SyncRecoveryMarker` | 磁盘持久化的恢复标记 |
| `SyncProtocolException` | JSON/协议格式错误 |
| `ConflictException` | 服务端 409 冲突，可解析 `conflict_type`/`item_id` 等 |
| `SyncHttpException` | HTTP 非 200 错误，含 `userMessage`/`logMessage` |
| `SyncResult` | `success`, `pulled`, `pushed`, `version`, `conflictCount`, `notice` |

### 6.3 `SyncPayloadCodec` (`sync_payload_codec.dart`)

| 方法 | 说明 |
|---|---|
| `encodeAccount(...)` | 编码 AccountItem |
| `encodeTemplate(...)` | 编码 AccountTemplate |
| `encodeTotpCredential(...)` | 编码 TotpCredential |
| `encodePayload(...)` | 通用编码入口 |
| `decodePayload(...)` | 通用解码入口（返回 Map） |
| `decode(...)` | 解码并强制要求 `_type == account` |

### 6.4 `CrdtMergeEngine` (`crdt_merge_engine.dart`)

| 方法 | 说明 |
|---|---|
| `merge(local, remote)` | `AccountItem` → `MergeResult` |
| `mergeTemplate(local, remote)` | `AccountTemplate` → `TemplateMergeResult` |

### 6.5 `TotpCredentialMergeEngine` (`totp_credential_merge_engine.dart`)

| 方法 | 说明 |
|---|---|
| `merge(local, remote)` | `TotpCredential` → `TotpCredential` |

### 6.6 LAN 同步组件

| 类 | 关键公共成员 |
|---|---|
| `LanSyncCoordinator` | `isBusy`, `currentSession`, `currentRole`, `currentConflictPreview`, `startAsHost()`, `startAndRunAsRequester()`, `hostTriggerMerge()`, `hostCommit()`, `abort()` |
| `LanSyncClient` | `isBusy`, `phase`, `sessionId`, `startSync(...)`, `abort()`, `reset()` |
| `LanSyncHostHandler` | `handleStart()`, `handlePush()`, `triggerMerge()`, `handleResultQuery()`, `handlePull()`, `commit()`, `handleAbort()`, `cleanup()`, `getSessionPhase()`, `getConflictPreview()` |
| `LanSyncSessionState` | `sessionId`, `phase`, `startedAt`, `expiresAt`, `copyWith()` |
| `LanSyncResult` | `success`, `pushedItems`, `pulledItems`, `conflictCount`, `error` |
| `LanSyncConfig` | `sessionTtl` (3min), `pageSize` (100) |

---

## 7. TODO 清单

在 `lib/sync/` 目录的全部 12 个 Dart 文件中，**未发现任何 `TODO`、`FIXME`、`HACK`、`XXX` 或 `BUG` 注释**。

> 注：`docs/architecture/architecture-deep-dive.md` 中有一处提及 "scattered layout hacks"，但与同步协议无关。

---

## 8. 与现有文档的差异（Diff）

### 8.1 `docs/sync/sync-protocol.md` — 过期/不一致项

| # | 文档描述 | 代码实际 | 严重程度 |
|---|---|---|---|
| 1 | **2.2 节** 描述数据模型使用 `SyncValue` 包装器：`{"name": {"v": "...", "hlc": "..."}}` | 实际代码为**扁平字段**：`name` + `nameHlc`、`email` + `emailHlc`、`data` + `dataHlc`。不存在 `SyncValue` 包装结构。 | **高** |
| 2 | **2.3 节** 伪代码使用 `fields[key]` 泛型字典遍历 | 实际 `CrdtMergeEngine.merge()` 是**硬编码字段逐一比较**（name, email, data keys, isPinned），非泛型 Map 迭代。 | **中** |
| 3 | **2.3 节** Tombstone 逻辑伪代码过于简化：`compare(deleteHlc) > 0` 即决定胜负 | 实际算法更精细：删除方必须证明 `deleteHlc > max(对方所有字段 HLC)` 才能生效；否则**被删除方后续的字段修改会导致复活**。 | **高** |
| 4 | **2.4 节** 宣称有 "人工仲裁复写引擎" 和 "使用此记录覆盖当前 (Restore)" | 同步层代码**未实现任何 restore/rewind 机制**。`ConflictLog` 仅记录被覆盖的旧值，无反向写入逻辑。 | **高** |
| 5 | 文档未提及 `serverGeneration` | 代码中存在 `serverGeneration` 头传递与 vault reset 检测（generation mismatch 时触发全量重推）。 | **中** |
| 6 | 文档称 `SyncPayloadCodec` 使用 "记录级 nonce/ciphertext/HMAC 信封" | 实际使用 **AES-256-GCM (AEAD) + HKDF-SHA256**，不是独立 HMAC。文档术语错误。 | **中** |
| 7 | 文档未提及 `SyncRecoveryPhase` 和 recovery marker | 代码实现了三阶段 recovery marker 磁盘持久化（pull/push/conflictRecovery），文档完全未覆盖。 | **中** |
| 8 | 文档未提及 **批准制推送** (`loadApprovedLocalSyncChanges`) | 实际 push phase 只推送用户**已批准**的 outbox 条目，而非所有 `PendingPush`。文档说 "读取所有 PendingPush" 不准确。 | **高** |
| 9 | 文档未提及 **LAN 同步** | `lib/sync/` 有 4 个 LAN 相关文件，文档完全空白。 | **高** |
| 10 | 文档未提及 **TotpCredential** 作为独立同步实体 | 同步协议实际支持三种实体（account/template/totp），文档只提 account。 | **中** |

### 8.2 `docs/architecture/02-runtime-and-sync.md` — 过期/不一致项

| # | 文档描述 | 代码实际 | 严重程度 |
|---|---|---|---|
| 1 | **7. Security Runtime Assessment** 称 payload "仍不是标准 AEAD/E2EE 终局方案"，描述为 "nonce/ciphertext/HMAC 信封，使用 vault/device 派生材料做混淆加密" | 实际 `SyncPayloadCodec` 已是**标准 AEAD**（AES-256-GCM with HKDF-SHA256、标准 AAD、版本校验、vault 隔离）。该段落已过时，低估了当前实现。 | **高** |
| 2 | 序列图只显示 `CrdtMergeEngine.merge()` | 实际 pull phase 按 `_type` 分三路：`CrdtMergeEngine.merge()`（account）、`CrdtMergeEngine.mergeTemplate()`（template）、`TotpCredentialMergeEngine.merge()`（totp）。 | **中** |
| 3 | 文档说 "读取所有处于 PendingPush 状态的行" | 实际是先 `loadApprovedLocalSyncChanges`，再与 `pendingPush` 条目取交集。未批准的不推送。 | **高** |
| 4 | 文档未提及 **409 Conflict 自动重试循环** | 代码中 `_runSyncLoop` 有 `while (retries < 3)` 的冲突恢复重试，每次延迟 500ms×retries。 | **中** |
| 5 | 文档日期 `Last Updated: 2026-04-28` | 代码在 2026-05 之后有大量演进（LAN 同步、TotpCredential 合并、批准制推送、generation 处理）。 | **低** |

---

## 9. 结论与建议

1. **`docs/sync/sync-protocol.md` 需要重写**：当前文档中的伪代码、数据模型描述、加密术语均与代码实现存在实质性偏差。建议以本报告中第 3、4 节为基准更新。
2. **`docs/architecture/02-runtime-and-sync.md` 安全评估段落需修正**：`SyncPayloadCodec` 已实现标准 AEAD，不应再被描述为 "原型级 / 非标准方案"。
3. **新增 LAN 同步文档**：`lib/sync/lan_*.dart` 4 个文件形成了完整的 LAN 同步子系统，目前无任何文档覆盖，建议单独撰写 `docs/sync/lan-sync-protocol.md`。
4. **文档中缺失的批准制推送流程**：这是用户可见的核心行为（本地变更需先进入 outbox 并被批准后才推送），应在架构文档中明确说明。[stage] run_soul_finished

[summary]
# 同步协议技术规范更新版（基于 `lib/sync/` 代码扫描）

> 扫描范围：`lib/sync/` 下 12 个 Dart 文件  
> 对比文档：`docs/sync/sync-protocol.md`、`docs/architecture/02-runtime-and-sync.md`

---

## 1. 同步架构总览

```
┌─────────────────────────────────────────────────────────────┐
│                        SyncService                          │
│  (ChangeNotifier, 核心状态机 + 编排器)                        │
├─────────────────────────────────────────────────────────────┤
│  Part: sync_service_pull.dart  ──► 拉取 + 解密 + 本地合并    │
│  Part: sync_service_push.dart  ──► 批准队列 + 加密 + 推送    │
│  Part: sync_service_conflict.dart ──► 冲突恢复策略           │
├─────────────────────────────────────────────────────────────┤
│  依赖:                                                       │
│    • CrdtMergeEngine          (账号/模板字段级 CRDT 合并)     │
│    • TotpCredentialMergeEngine (TOTP 凭证字段级合并)          │
│    • SyncPayloadCodec         (sroy-sync: AEAD 信封编解码)   │
│    • IdentityService          (vaultId, deviceId, keys)    │
│    • SecureStorageService     (本地 SQLite + outbox)        │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
   ┌─────────┐         ┌────────────┐         ┌─────────────┐
   │ LAN Sync │         │ HTTP Sync  │         │  Recovery   │
   │ Coordinator         │  Client    │         │  Marker     │
   │ (ChangeNotifier)    │  (Server)  │         │  (磁盘持久)  │
   └─────────┘         └────────────┘         └─────────────┘
        │
   ┌────┴────┐
   ▼         ▼
LanSyncClient   LanSyncHostHandler
(请求者B)       (宿主A)
```

**文件职责矩阵**

| 文件 | 职责 |
|---|---|
| `sync_service.dart` | 状态机、初始化、错误分类、recovery marker、定时器 |
| `sync_service_types.dart` | `SyncState`、`SyncConfig`、`SyncResult`、异常类 |
| `sync_service_pull.dart` | `GET /vaults/:id/sync`、分页拉取、解密、apply remote changes |
| `sync_service_push.dart` | `POST /vaults/:id/sync`、批准 outbox、加密、接受版本处理 |
| `sync_service_conflict.dart` | 5 种冲突类型的恢复策略 |
| `crdt_merge_engine.dart` | `AccountItem` 与 `AccountTemplate` 的字段级 LWW + tombstone 合并 |
| `totp_credential_merge_engine.dart` | `TotpCredential` 的字段级 LWW + tombstone 合并 |
| `sync_payload_codec.dart` | `sroy-sync:` 前缀 AES-256-GCM + HKDF 信封 |
| `lan_sync_coordinator.dart` | LAN 同步生命周期协调、角色管理 |
| `lan_sync_client.dart` | 请求者端：start → push → poll → pull → commit |
| `lan_sync_host_handler.dart` | 宿主端：start → receive → merge → pull → commit |
| `lan_sync_session.dart` | LAN 阶段枚举、会话状态、配置、异常常量 |

---

## 2. 状态机定义（状态和迁移）

### 2.1 同步状态枚举 (`SyncState`)

| 状态 | 类型 | 语义 |
|---|---|---|
| `offline` | 正常 | 未配置服务器或用户手动断开 |
| `connecting` | 正常 | 正在连接/握手 |
| `pulling` | 正常 | 正在拉取远端更新 |
| `pushing` | 正常 | 正在推送已批准的本地变更 |
| `idle` | 正常 | 同步完成 |
| `conflictRecovery` | 正常 | 冲突恢复中（自动重试循环内） |
| `networkUnreachable` | **错误** | 网络不可达（Socket/Timeout/ClientException） |
| `serverError` | **错误** | 服务端 5xx |
| `protocolError` | **错误** | 协议解析失败、payload 校验失败、cleartext HTTP、max retries |
| `authError` | **错误** | 身份未建立 |

### 2.2 状态迁移图

```
[任意状态] ──► reset()/disconnect() ──► offline

offline ──► connect() ──► [syncNow()]
              │
              ▼
        ┌───────────┐
        │ connecting │ ◄── 循环开始 / recovery 后重试
        └─────┬─────┘
              │
              ▼
        ┌───────────┐     无 recovery marker
        │  pulling   │ ◄──┘
        └─────┬─────┘
              │ 有 ConflictException
              ▼
        ┌───────────┐      无冲突
        │  pushing   │ ─────┐
        └─────┬─────┘      │
              │            ▼
              │       ┌─────────┐
              │       │  idle   │
              │       └─────────┘
              │
              ▼
        ┌─────────────────┐
        │ conflictRecovery │ ──► 延迟 500ms × retryCount ──► 回到 connecting
        └─────────────────┘      (最多 3 次)

错误迁移（任何时候发生未捕获异常）：
  • SocketException / TimeoutException ──► networkUnreachable
  • http.ClientException 含 "SocketException"/"Connection failed" ──► networkUnreachable
  • http.ClientException 含 "cleartext" ──► protocolError
  • SyncHttpException status >= 500 ──► serverError
  • SyncHttpException status < 500 ──► protocolError
  • SyncProtocolException ──► protocolError
  • SyncPayloadException ──► protocolError
  • 其他 ──► protocolError
```

### 2.3 Recovery Marker 持久化状态

SyncService 在磁盘保存 `SyncRecoveryMarker`，支持崩溃恢复：

| Phase | 写入时机 | 恢复行为 |
|---|---|---|
| `pull` | pull phase 开始前 | 从 marker.localVersion 重新 pull |
| `push` | push phase 开始前 | 执行完整快照 pull + merge |
| `conflictRecovery` | 捕获 ConflictException 后 | 进入冲突恢复循环 |

---

## 3. CRDT 合并算法详细说明

系统支持三种实体的合并：`AccountItem`、`AccountTemplate`、`TotpCredential`。核心共同模式：**字段级 LWW + Tombstone 优先**。

### 3.1 HLC 比较规则

代码位于 `models/hlc.dart`（未在本次扫描范围内，由调用侧推断）：

- 比较优先级：**物理时间戳 > 逻辑计数器 > 设备 ID 字典序**
- `Hlc.zero('local')` / `Hlc.zero('remote')` 作为缺失字段的默认值
- `isCorrupted` 属性：若远程 HLC 被判定损坏，本地无条件获胜

### 3.2 AccountItem 合并算法 (`CrdtMergeEngine.merge`)

**输入**：`local`, `remote`（必须同 `id`）  
**输出**：`MergeResult(AccountItem, List<ConflictLog>, isPureFastForward)`

**步骤**：

1. **远程 HLC 损坏检测**  
   若 `remote.nameHlc.isCorrupted || remote.emailHlc.isCorrupted || remote.dataHlc.values.any(...) || remote.pinHlc?.isCorrupted`，返回本地副本 + `syncStatus = pendingPush`，并生成一条 `hlc.corrupted_remote` 冲突日志。

2. **Tombstone Trumps All（墓碑拦截）**  
   - 双方都删除：取 `deleteHlc` 更大的一方，返回其副本 + `synchronized`
   - 仅远程删除：若 `remote.deleteHlc > max(local 所有字段 HLC)`，接受墓碑；否则本地在删除后又做了修改，**本地复活**
   - 仅本地删除：若 `local.deleteHlc > max(remote 所有字段 HLC)`，坚持墓碑；否则远程在删除后又做了修改，**接受远程**

3. **字段级 LWW 穿透合并**  
   对以下字段逐对比较 HLC：

   | 字段 | 本地 HLC | 远程 HLC | 胜者 |
   |---|---|---|---|
   | `name` | `local.nameHlc` | `remote.nameHlc` | HLC 大者 |
   | `email` | `local.emailHlc` | `remote.emailHlc` | HLC 大者 |
   | `data.<key>` | `local.dataHlc[key]` (缺省 zero) | `remote.dataHlc[key]` (缺省 zero) | HLC 大者 |
   | `isPinned` | `local.pinHlc` (缺省 zero) | `remote.pinHlc` (缺省 zero) | HLC 大者 |

   - 若 remote 胜且 `lVal != rVal`，记录本地旧值到 `ConflictLog`
   - 若 local 胜且 `rVal != lVal` 且 `rHlc.time > 0`，记录远程旧值到 `ConflictLog`
   - `null` 值被视为**字段删除**（不写入 mergedData）

4. **收敛状态分析 (`isPureFastForward`)**  
   检查合并结果的每个字段 HLC 是否**完全等于 remote 的对应字段 HLC**：
   - 若全部相等 → `isPureFastForward = true`
   - 若存在差异 → `isPureFastForward = false`

5. **最终 `syncStatus` 判定**  
   - `isPureFastForward == true` → `synchronized`（本地完全被远端覆盖）
   - `isPureFastForward == false` 且 `local.syncStatus == pendingPush` → `conflict`（本地原本就有未推送修改，合并后需人工核对）
   - `isPureFastForward == false` 且 `local.syncStatus != pendingPush` → `pendingPush`（本地之前是同步状态，合并产生了新缝合内容，需要推回服务端）

### 3.3 AccountTemplate 合并算法 (`CrdtMergeEngine.mergeTemplate`)

与 AccountItem 类似，但结构不同：

- **顶层 tombstone**：比较 `deleteHlc`
- **顶层 LWW**：若未删除，比较 `local.hlc` vs `remote.hlc`，胜者决定 `title`, `subTitle`, `iconCodePoint`, `category`
- **字段级 LWW**：对 `fields` 列表中的每个 `AccountField`，分别比较 `labelHlc`, `descriptionHlc`, `attributesHlc`, `orderHlc`
- **字段排序**：合并后的 `resolvedFields` 按 `order` 升序排列
- **fast-forward 判定**：要求顶层 remote 赢，且每个 field 的四维 HLC 完全等于 remote 对应 field

### 3.4 TotpCredential 合并算法 (`TotpCredentialMergeEngine.merge`)

简化版三字段 + 删除：

| 字段 | HLC 来源 |
|---|---|
| `label` | `labelHlc` |
| `config` | `configHlc` |
| `linkedAccountIds` | `linksHlc` |
| `isDeleted` | `deleteHlc`（`_remoteDeleteWins` 特殊逻辑） |

- 损坏检测逻辑与 AccountItem 一致
- 无 `conflictLog` 产出（代码层面静默合并）
- 删除逻辑：若仅一方有 `deleteHlc`，则直接比较；若双方都有，取 HLC 更大者

---

## 4. Payload 加密规范

### 4.1 算法参数 (`SyncPayloadCodec`)

| 参数 | 值 |
|---|---|
| 前缀 | `sroy-sync:` |
| 版本 | `1` |
| 算法标识 | `aes-256-gcm-hkdf-sha256` |
| Nonce 长度 | 12 bytes |
| Salt 长度 | 16 bytes |
| 派生密钥长度 | 32 bytes |

### 4.2 密钥派生 (`_derivePayloadKey`)

```dart
Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
  secretKey: SecretKey(utf8.encode(symmetricKey) + [0x00] + utf8.encode(privateKey)),
  nonce: salt,
  info: utf8.encode('sroy-sync-payload|aes-256-gcm-hkdf-sha256|$vaultId'),
)
```

- **IKM** = `symmetricKey || 0x00 || privateKey`（UTF-8 字节拼接）
- **Salt** = 随机 16 bytes
- **Info** = 固定字符串 `sroy-sync-payload|aes-256-gcm-hkdf-sha256|<vaultId>`

### 4.3 附加认证数据 (AAD)

```
v=1;alg=aes-256-gcm-hkdf-sha256;vault=<vaultId>;node=<nodeId>
```

### 4.4 信封 JSON 结构

```json
{
  "v": 1,
  "alg": "aes-256-gcm-hkdf-sha256",
  "vault_id": "<vaultId>",
  "node_id": "<nodeId>",
  "salt": "<base64url>",
  "nonce": "<base64url>",
  "ciphertext": "<base64url>",
  "mac": "<base64url>"
}
```

外层：前缀 + base64url(UTF-8(信封 JSON))，无 padding。

### 4.5 解码校验流程

1. 检查 `sroy-sync:` 前缀
2. 解析信封 JSON
3. 校验 `v == 1`、`alg` 匹配、`vault_id` 非空且等于 `expectedVaultId`、`node_id` 非空
4. 校验 salt/nonce/ciphertext/mac 存在且长度合规
5. 重新派生密钥，用 AAD 解密
6. 返回 `Map<String, dynamic>` payload

### 4.6 实体类型标记

编码时向 `toJson()` 结果注入 `_type` 字段：
- AccountItem → `"account"`
- AccountTemplate → `"template"`
- TotpCredential → `"totp_credential"`

解码时根据 `_type` 路由到对应模型。

---

## 5. LAN 同步流程

LAN 同步是与 HTTP Server 同步**互斥**的独立通道，由 `LanSyncCoordinator` 管理。

### 5.1 红线约束（代码注释明确声明）

1. **不读写 `_localVersion` / `serverVersion`** — LAN 同步不影响服务端同步版本号
2. **不写 `syncStatus = synchronized`** — LAN 同步只产生 `pendingPush`（以便后续服务端同步时推送）
3. **与 server sync 互斥** — `LanSyncCoordinator` 和 `LanSyncClient` 都会检查 `_syncService.isSyncing`，若 server sync 活跃则拒绝启动

### 5.2 LAN 同步阶段 (`LanSyncPhase`)

```
idle → connecting → receiving → merging → resolving → pushing → committing → completed
                                          ↓
                                    interrupted / failed
```

| 阶段 | 说明 |
|---|---|
| `connecting` | 建立会话，交换 record ID 列表 |
| `receiving` | 请求者推送本地加密数据，宿主接收 |
| `merging` | 宿主执行 CRDT 合并 |
| `resolving` | 宿主侧存在冲突，等待用户确认 |
| `pushing` | 请求者拉取合并结果；宿主准备响应 |
| `committing` | 双方写入本地数据库 |
| `completed` | 完成 |
| `interrupted` | 用户/异常中断 |
| `failed` | 处理失败 |

### 5.3 完整流程（Host A ↔ Requester B）

```
B (Requester)                          A (Host)
──────────────────────────────────────────────────────────────────
1. discoverHost() ──► 获取 A 的 IP:Port
2. POST /lan-sync/start
   {device_id, record_ids} ──►
                              ◄─── {session_id, ttl_seconds}
3. _pushLocalData()
   分页 POST /lan-sync/push
   {session_id, page, items:[cipher,...]} ──►
                              ◄─── {accepted, phase}
4.                          触发 triggerMerge(sessionId)
                            调用 CrdtMergeEngine.merge()
                            生成 conflictPreview（如有）
5. _pollUntilMerged()
   轮询 POST /lan-sync/result
   {session_id} ──►
                              ◄─── {phase, conflict_count, [conflict_preview]}
                            直到 phase == "pushing"
6. POST /lan-sync/pull
   {session_id} ──►
                              ◄─── {items:[cipher,...]}
                            含：合并结果 + Host 有但 B 没有的增量
7. _commitLocal()
   解密并写入本地 DB
   标记为 pendingPush
8.                          用户确认后 hostCommit()
                            写入 Host 本地 DB
                            标记为 pendingPush
```

### 5.4 关键机制

- **会话 TTL**：默认 3 分钟 (`LanSyncConfig.sessionTtl`)
- **分页大小**：默认 100 条 (`LanSyncConfig.pageSize`)
- **轮询上限**：180 次 × 500ms = 90 秒超时
- **增量传输**：Host 在 `handlePull` 时，会把 Host 有但 Requester 没有（通过 `peerRecordIds` 过滤）的记录一并推给 B
- **加密连续性**：LAN 同步复用与服务端同步完全相同的 `SyncPayloadCodec`，密钥材料来自 `IdentityService`

---

## 6. 公共 API 清单

### 6.1 `SyncService` (`sync_service.dart`)

| 成员 | 类型 | 说明 |
|---|---|---|
| `state` | `SyncState` | 当前状态 |
| `errorMessage` | `String?` | 错误日志（供调试） |
| `statusNote` | `String?` | 用户友好状态说明 |
| `lastSyncTime` | `DateTime?` | 上次成功同步时间 |
| `isConnected` | `bool` | 是否处于连接/活跃状态 |
| `isSyncing` | `bool` | 是否正在同步中 |
| `localVersion` | `int` | 本地同步版本号 |
| `isDirty` | `bool` | 是否有未推送变更 |
| `initialize()` | `Future<void>` | 从持久化恢复版本/时间/dirty 状态 |
| `markDirty()` | `Future<void>` | 标记本地有变更待同步 |
| `reconcileDirtyState()` | `Future<void>` | 根据 outbox 实际存在性校准 dirty |
| `reset()` / `disconnect()` | `Future<void>` | 断开并停止定时器 |
| `connect()` | `Future<bool>` | 执行一次同步并启动定时同步 |
| `syncNow()` | `Future<SyncResult>` | 立即执行完整同步循环 |
| `recoveryPhase` | `String?` | `@visibleForTesting` 读取 recovery 阶段 |

### 6.2 异常与结果类型 (`sync_service_types.dart`)

| 类/枚举 | 说明 |
|---|---|
| `SyncState` + `SyncStateExt.isError` | 10 状态枚举 |
| `SyncConfig` | `serverUrl`, `syncInterval`（默认 5 分钟） |
| `SyncRecoveryPhase` | `pull` / `push` / `conflictRecovery` |
| `SyncRecoveryMarker` | 磁盘持久化的恢复标记 |
| `SyncProtocolException` | JSON/协议格式错误 |
| `ConflictException` | 服务端 409 冲突，可解析 `conflict_type`/`item_id` 等 |
| `SyncHttpException` | HTTP 非 200 错误，含 `userMessage`/`logMessage` |
| `SyncResult` | `success`, `pulled`, `pushed`, `version`, `conflictCount`, `notice` |

### 6.3 `SyncPayloadCodec` (`sync_payload_codec.dart`)

| 方法 | 说明 |
|---|---|
| `encodeAccount(...)` | 编码 AccountItem |
| `encodeTemplate(...)` | 编码 AccountTemplate |
| `encodeTotpCredential(...)` | 编码 TotpCredential |
| `encodePayload(...)` | 通用编码入口 |
| `decodePayload(...)` | 通用解码入口（返回 Map） |
| `decode(...)` | 解码并强制要求 `_type == account` |

### 6.4 `CrdtMergeEngine` (`crdt_merge_engine.dart`)

| 方法 | 说明 |
|---|---|
| `merge(local, remote)` | `AccountItem` → `MergeResult` |
| `mergeTemplate(local, remote)` | `AccountTemplate` → `TemplateMergeResult` |

### 6.5 `TotpCredentialMergeEngine` (`totp_credential_merge_engine.dart`)

| 方法 | 说明 |
|---|---|
| `merge(local, remote)` | `TotpCredential` → `TotpCredential` |

### 6.6 LAN 同步组件

| 类 | 关键公共成员 |
|---|---|
| `LanSyncCoordinator` | `isBusy`, `currentSession`, `currentRole`, `currentConflictPreview`, `startAsHost()`, `startAndRunAsRequester()`, `hostTriggerMerge()`, `hostCommit()`, `abort()` |
| `LanSyncClient` | `isBusy`, `phase`, `sessionId`, `startSync(...)`, `abort()`, `reset()` |
| `LanSyncHostHandler` | `handleStart()`, `handlePush()`, `triggerMerge()`, `handleResultQuery()`, `handlePull()`, `commit()`, `handleAbort()`, `cleanup()`, `getSessionPhase()`, `getConflictPreview()` |
| `LanSyncSessionState` | `sessionId`, `phase`, `startedAt`, `expiresAt`, `copyWith()` |
| `LanSyncResult` | `success`, `pushedItems`, `pulledItems`, `conflictCount`, `error` |
| `LanSyncConfig` | `sessionTtl` (3min), `pageSize` (100) |

---

## 7. TODO 清单

在 `lib/sync/` 目录的全部 12 个 Dart 文件中，**未发现任何 `TODO`、`FIXME`、`HACK`、`XXX` 或 `BUG` 注释**。

> 注：`docs/architecture/architecture-deep-dive.md` 中有一处提及 "scattered layout hacks"，但与同步协议无关。

---

## 8. 与现有文档的差异（Diff）

### 8.1 `docs/sync/sync-protocol.md` — 过期/不一致项

| # | 文档描述 | 代码实际 | 严重程度 |
|---|---|---|---|
| 1 | **2.2 节** 描述数据模型使用 `SyncValue` 包装器：`{"name": {"v": "...", "hlc": "..."}}` | 实际代码为**扁平字段**：`name` + `nameHlc`、`email` + `emailHlc`、`data` + `dataHlc`。不存在 `SyncValue` 包装结构。 | **高** |
| 2 | **2.3 节** 伪代码使用 `fields[key]` 泛型字典遍历 | 实际 `CrdtMergeEngine.merge()` 是**硬编码字段逐一比较**（name, email, data keys, isPinned），非泛型 Map 迭代。 | **中** |
| 3 | **2.3 节** Tombstone 逻辑伪代码过于简化：`compare(deleteHlc) > 0` 即决定胜负 | 实际算法更精细：删除方必须证明 `deleteHlc > max(对方所有字段 HLC)` 才能生效；否则**被删除方后续的字段修改会导致复活**。 | **高** |
| 4 | **2.4 节** 宣称有 "人工仲裁复写引擎" 和 "使用此记录覆盖当前 (Restore)" | 同步层代码**未实现任何 restore/rewind 机制**。`ConflictLog` 仅记录被覆盖的旧值，无反向写入逻辑。 | **高** |
| 5 | 文档未提及 `serverGeneration` | 代码中存在 `serverGeneration` 头传递与 vault reset 检测（generation mismatch 时触发全量重推）。 | **中** |
| 6 | 文档称 `SyncPayloadCodec` 使用 "记录级 nonce/ciphertext/HMAC 信封" | 实际使用 **AES-256-GCM (AEAD) + HKDF-SHA256**，不是独立 HMAC。文档术语错误。 | **中** |
| 7 | 文档未提及 `SyncRecoveryPhase` 和 recovery marker | 代码实现了三阶段 recovery marker 磁盘持久化（pull/push/conflictRecovery），文档完全未覆盖。 | **中** |
| 8 | 文档未提及 **批准制推送** (`loadApprovedLocalSyncChanges`) | 实际 push phase 只推送用户**已批准**的 outbox 条目，而非所有 `PendingPush`。文档说 "读取所有 PendingPush" 不准确。 | **高** |
| 9 | 文档未提及 **LAN 同步** | `lib/sync/` 有 4 个 LAN 相关文件，文档完全空白。 | **高** |
| 10 | 文档未提及 **TotpCredential** 作为独立同步实体 | 同步协议实际支持三种实体（account/template/totp），文档只提 account。 | **中** |

### 8.2 `docs/architecture/02-runtime-and-sync.md` — 过期/不一致项

| # | 文档描述 | 代码实际 | 严重程度 |
|---|---|---|---|
| 1 | **7. Security Runtime Assessment** 称 payload "仍不是标准 AEAD/E2EE 终局方案"，描述为 "nonce/ciphertext/HMAC 信封，使用 vault/device 派生材料做混淆加密" | 实际 `SyncPayloadCodec` 已是**标准 AEAD**（AES-256-GCM with HKDF-SHA256、标准 AAD、版本校验、vault 隔离）。该段落已过时，低估了当前实现。 | **高** |
| 2 | 序列图只显示 `CrdtMergeEngine.merge()` | 实际 pull phase 按 `_type` 分三路：`CrdtMergeEngine.merge()`（account）、`CrdtMergeEngine.mergeTemplate()`（template）、`TotpCredentialMergeEngine.merge()`（totp）。 | **中** |
| 3 | 文档说 "读取所有处于 PendingPush 状态的行" | 实际是先 `loadApprovedLocalSyncChanges`，再与 `pendingPush` 条目取交集。未批准的不推送。 | **高** |
| 4 | 文档未提及 **409 Conflict 自动重试循环** | 代码中 `_runSyncLoop` 有 `while (retries < 3)` 的冲突恢复重试，每次延迟 500ms×retries。 | **中** |
| 5 | 文档日期 `Last Updated: 2026-04-28` | 代码在 2026-05 之后有大量演进（LAN 同步、TotpCredential 合并、批准制推送、generation 处理）。 | **低** |

---

## 9. 结论与建议

1. **`docs/sync/sync-protocol.md` 需要重写**：当前文档中的伪代码、数据模型描述、加密术语均与代码实现存在实质性偏差。建议以本报告中第 3、4 节为基准更新。
2. **`docs/architecture/02-runtime-and-sync.md` 安全评估段落需修正**：`SyncPayloadCodec` 已实现标准 AEAD，不应再被描述为 "原型级 / 非标准方案"。
3. **新增 LAN 同步文档**：`lib/sync/lan_*.dart` 4 个文件形成了完整的 LAN 同步子系统，目前无任何文档覆盖，建议单独撰写 `docs/sync/lan-sync-protocol.md`。
4. **文档中缺失的批准制推送流程**：这是用户可见的核心行为（本地变更需先进入 outbox 并被批准后才推送），应在架构文档中明确说明。
