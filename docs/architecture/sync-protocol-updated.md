# SecretRoy 同步协议 — 开发者教学版

> **文档定位**：面向需要接触同步模块的开发者，用流程和步骤描述替代伪代码，降低理解门槛。  
> **文档定位**：本文档是当前同步协议的**权威参考**，基于 2026-05-16 代码扫描生成，替代了过时的 旧版 `sync/sync-protocol.md`（已删除）。侧重"发生了什么"和"为什么这样设计"；精确算法参数和接口契约以代码实现为准。

---

## 1. 同步架构总览（一句话）

**SecretRoy 的同步核心 = HLC 逻辑时钟 + 字段级 LWW 合并 + 标准 AEAD 加密信封。**

也就是说：
- 每个字段修改都带一个**逻辑时钟戳**（HLC），不依赖设备物理时间。
- 冲突时比较字段级的时钟戳，**时间戳大的字段胜出**（Last-Write-Wins）。
- 所有数据在离开设备前，被装进一个**标准 AEAD 信封**（AES-256-GCM + HKDF-SHA256），服务端只存密文，不碰明文。

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
```

---

## 2. 状态机图解

### 2.1 正常状态（无错误）

```
offline ──► connect() ──► connecting ──► pulling ──► pushing ──► idle
   ▲                                            │
   │                                            │ 捕获 ConflictException
   │                                            ▼
   │                                     conflictRecovery
   │                                            │
   │                                            ▼ 延迟 500ms × retryCount
   └────────────────────────────────────────────┘ (最多 3 次，然后回到 connecting)
```

### 2.2 完整状态定义

| 状态 | 类型 | 语义 | 何时出现 |
|------|------|------|---------|
| `offline` | 正常 | 未配置服务器或用户手动断开 | 初始状态 / 用户点"断开" |
| `connecting` | 正常 | 正在连接/握手 | `syncNow()` 开始后 |
| `pulling` | 正常 | 正在拉取远端更新 | 收到服务端响应后 |
| `pushing` | 正常 | 正在推送已批准的本地变更 | pull 完成后 |
| `idle` | 正常 | 同步完成 | push 成功，无冲突 |
| `conflictRecovery` | 正常 | 冲突恢复中（自动重试循环内） | 服务端返回 409 |
| `networkUnreachable` | **错误** | 网络不可达 | Socket/Timeout/ClientException |
| `serverError` | **错误** | 服务端 5xx | 服务端内部错误 |
| `protocolError` | **错误** | 协议解析失败 | 非法 payload / 明文 HTTP / 超次重试 |
| `authError` | **错误** | 身份未建立 | 缺少 vault token / 配对失效 |

### 2.3 错误状态迁移规则

任何状态都可能因异常直接跳到错误态：

- **网络层问题**（SocketException、TimeoutException、Connection failed）→ `networkUnreachable`
- **服务端 5xx** → `serverError`
- **服务端 4xx（除 409）/ 非法 JSON / cleartext HTTP** → `protocolError`
- **409 Conflict** → 不进入错误态，进入 `conflictRecovery` 自动重试
- **其他未捕获异常** → `protocolError`

### 2.4 Recovery Marker（崩溃恢复）

SyncService 在磁盘持久化一个 `SyncRecoveryMarker`，记录当前执行到哪个阶段：

| Phase | 写入时机 | 崩溃后恢复行为 |
|-------|---------|--------------|
| `pull` | pull phase 开始前 | 从 marker 记录的版本号重新 pull |
| `push` | push phase 开始前 | 执行完整快照 pull + merge（防止 push 前已拉取的数据丢失） |
| `conflictRecovery` | 捕获 ConflictException 后 | 进入冲突恢复循环，延迟后重试 |

> **为什么要这样设计？** 因为同步是"先拉后推"的两阶段提交，如果应用在 pull 完、push 前被杀死，恢复时必须重新 pull，确保本地基于最新的服务端状态再做 push。

---

## 3. CRDT 合并流程（图文步骤）

### 3.1 前置概念：HLC 怎么比大小

HLC（Hybrid Logical Clock）是一个字符串，格式为 `{物理时间戳}-{计数器}-{设备ID}`，例如 `1681234567000-05-a1b2c3d4`。

比较规则像字典序，但有三层：
1. **物理时间戳**大的胜出（毫秒级，UInt64）。
2. 时间戳相同则**计数器**大的胜出（UInt16）。
3. 计数器也相同则**设备 ID 字典序**大的胜出（绝对平局打破器）。

> 关键性质：HLC 比较是**全序**的，任意两个 HLC 一定能比出大小，且所有设备的结果一致。这就是"最终一致性"的数学基础。

### 3.2 合并触发条件

只在**拉取到远端数据**且**本地已有同 ID 记录**时触发合并。三种实体分别处理：

| 实体 | 合并器 |
|------|--------|
| `AccountItem` | `CrdtMergeEngine.merge()` |
| `AccountTemplate` | `CrdtMergeEngine.mergeTemplate()` |
| `TotpCredential` | `TotpCredentialMergeEngine.merge()` |

### 3.3 AccountItem 合并步骤（以账号为例）

**输入**：本地记录 + 远端记录（必须同 `id`）  
**输出**：合并后的记录 + 冲突日志列表 + 是否为"纯快进"

**步骤 1：远程 HLC 损坏检测**  
如果远端记录的任意字段 HLC 被标记为 `isCorrupted`，说明远端数据可能已损坏。此时**无条件保留本地版本**，并生成一条 `hlc.corrupted_remote` 冲突日志，本地状态标记为 `pendingPush`（以便后续推回服务端覆盖坏数据）。

**步骤 2：墓碑拦截（Tombstone Trumps All）**  
删除操作的优先级高于一切字段修改，但必须证明"删除发生在对方最后一次修改之后"。

- **双方都删除**：取 `deleteHlc` 更大的一方，返回其副本，状态为 `synchronized`。
- **仅远程删除**：检查 `remote.deleteHlc > max(local 所有字段 HLC)`。如果成立，说明远程在本地最后一次修改之后才删除，**接受删除**；否则说明本地在远程删除后又修改过，**本地复活**（保留本地修改）。
- **仅本地删除**：对称地，检查 `local.deleteHlc > max(remote 所有字段 HLC)`。成立则坚持删除；否则**接受远程**（远程在删除后又做了修改）。

> **为什么要这样设计？** 防止"误删复活"和"修改丢失"。如果 A 删除了记录，B 在 A 的删除之后又修改了密码，那么 B 的修改应该被保留。

**步骤 3：字段级 LWW 穿透合并**  
对以下字段逐对比较本地和远端的 HLC：

| 字段 | 本地 HLC | 远端 HLC |
|------|---------|---------|
| `name` | `nameHlc` | `nameHlc` |
| `email` | `emailHlc` | `emailHlc` |
| `data` 中的每个 key | `dataHlc[key]` | `dataHlc[key]` |
| `isPinned` | `pinHlc` | `pinHlc` |

每一对比较：HLC 大的字段胜出，写入合并结果。  
- 如果 remote 胜出且值与本地不同 → 记录本地旧值到 `ConflictLog`。
- 如果 local 胜出且值与远程不同且远程 HLC 时间 > 0 → 记录远程旧值到 `ConflictLog`。
- `null` 值被视为**字段删除**（不写入合并后的 data）。

> **为什么能并发修改不同字段不互相覆盖？** 因为比较粒度是字段级。A 改 `name`，B 改 `password`，两者的 HLC 只在各自字段上竞争，不会跨字段覆盖。

**步骤 4：判断是否为"纯快进"（isPureFastForward）**  
检查合并结果的每个字段 HLC 是否**完全等于 remote 的对应字段 HLC**：
- 全部相等 → `isPureFastForward = true`（本地完全没修改过，直接采纳远端）。
- 有任何差异 → `isPureFastForward = false`（双方都有修改，产生了缝合结果）。

**步骤 5：确定最终同步状态（syncStatus）**  

| 条件 | 结果状态 | 含义 |
|------|---------|------|
| `isPureFastForward == true` | `synchronized` | 本地完全被远端覆盖，无需推送 |
| `isPureFastForward == false` 且本地原本 `pendingPush` | `conflict` | 本地原本就有未推送修改，合并后需要人工核对 |
| `isPureFastForward == false` 且本地原本不是 `pendingPush` | `pendingPush` | 合并产生了新缝合内容，需要推回服务端 |

### 3.4 AccountTemplate 合并（与账号类似，结构不同）

- **顶层 tombstone**：比较 `deleteHlc`。
- **顶层 LWW**：若未删除，比较 `local.hlc` vs `remote.hlc`，胜者决定 `title`, `subTitle`, `iconCodePoint`, `category`。
- **字段级 LWW**：对 `fields` 列表中的每个 `AccountField`，分别比较 `labelHlc`, `descriptionHlc`, `attributesHlc`, `orderHlc`。
- **字段排序**：合并后的字段按 `order` 升序排列。

### 3.5 TotpCredential 合并（简化版）

只有三个字段 + 删除：

| 字段 | HLC 来源 |
|------|---------|
| `label` | `labelHlc` |
| `config` | `configHlc` |
| `linkedAccountIds` | `linksHlc` |
| `isDeleted` | `deleteHlc` |

- 损坏检测逻辑与 AccountItem 一致。
- **无 ConflictLog 产出**，静默合并。
- 删除逻辑：若仅一方有 `deleteHlc`，直接比较；若双方都有，取 HLC 更大者。

---

## 4. Payload 加密流程

### 4.1 一句话概述

每条同步记录在离开设备前，被编码为 JSON，然后装进一个带 `sroy-sync:` 前缀的标准 AEAD 信封。服务端只存这个密文字符串，不解密、不验证内容。

### 4.2 加密步骤

**步骤 1：准备明文 JSON**  
将 `AccountItem` / `AccountTemplate` / `TotpCredential` 序列化为 JSON，并注入 `_type` 字段用于类型标记：
- `"account"` — 账号
- `"template"` — 模板
- `"totp_credential"` — TOTP 凭证

**步骤 2：生成随机盐值和 Nonce**  
- **Salt**：16 字节随机数（用于 HKDF 密钥派生）。
- **Nonce**：12 字节随机数（用于 AES-GCM 加密，即 IV）。

**步骤 3：派生加密密钥（HKDF-SHA256）**  
用 `IdentityService` 提供的密钥材料，通过 HKDF 派生出一个 32 字节的 AES 密钥：

- **IKM**（输入密钥材料）= `symmetricKey` 的 UTF-8 字节 + `0x00` + `privateKey` 的 UTF-8 字节
- **Salt** = 随机 16 字节
- **Info** = 固定字符串 `sroy-sync-payload|aes-256-gcm-hkdf-sha256|<vaultId>`

> 为什么要用 `symmetricKey + privateKey` 双材料？因为两者分别来自 Vault 配对包的不同部分，攻击者需要同时拥有才能推导同步密钥。

**步骤 4：AES-256-GCM 加密**  
- **密钥**：步骤 3 派生的 32 字节密钥。
- **Nonce**：步骤 2 生成的 12 字节。
- **AAD**（附加认证数据）：`v=1;alg=aes-256-gcm-hkdf-sha256;vault=<vaultId>;node=<nodeId>`
- **明文**：步骤 1 的 JSON 字符串的 UTF-8 字节。
- **输出**：ciphertext + authentication tag（GCM 的 MAC）。

**步骤 5：组装信封 JSON**  
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

**步骤 6：添加前缀并 Base64Url 编码**  
最终传输字符串 = `sroy-sync:` + base64url(UTF-8(信封 JSON))，无 padding。

### 4.3 解密验证流程

接收方（本机拉取到远端数据，或 LAN 同步的对端）执行：
1. 检查字符串以 `sroy-sync:` 开头。
2. 去掉前缀，Base64Url 解码，解析信封 JSON。
3. 校验 `v == 1`、`alg` 匹配、`vault_id` 等于预期的 `vaultId`、`node_id` 非空。
4. 校验 salt/nonce/ciphertext/mac 存在且长度合规。
5. 用同样的 HKDF 参数（相同的 IKM、接收到的 salt、固定的 info）重新派生密钥。
6. 用相同的 AAD 执行 AES-256-GCM 解密，验证 MAC。
7. 解密成功 → 解析 JSON，根据 `_type` 路由到对应模型。

> **vault 隔离**：`vault_id` 和 `info` 中的 `vaultId` 确保不同 Vault 之间的 payload 即使被截获也无法互相解密。

---

## 5. LAN 同步流程

LAN 同步是 HTTP Server 同步的**独立通道**，两者互斥。它适用于同一局域网内的快速设备间同步，无需互联网。

### 5.1 红线约束

代码中明确声明的三条红线：
1. **不读写 `_localVersion` / `serverVersion`** — LAN 同步不影响服务端同步版本号。
2. **不写 `syncStatus = synchronized`** — LAN 同步只产生 `pendingPush`，以便后续服务端同步时统一推送。
3. **与 server sync 互斥** — 如果 HTTP 同步正在进行，LAN 同步拒绝启动。

### 5.2 LAN 同步阶段

```
idle → connecting → receiving → merging → resolving → pushing → committing → completed
                                          ↓
                                    interrupted / failed
```

| 阶段 | 说明 |
|------|------|
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

- **会话 TTL**：默认 3 分钟。
- **分页大小**：默认 100 条记录/页。
- **轮询上限**：180 次 × 500ms = 90 秒超时。
- **增量传输**：Host 在 `handlePull` 时，会把 Host 有但 Requester 没有的记录（通过 `peerRecordIds` 过滤）一并推给 B。
- **加密连续性**：LAN 同步复用与服务端同步**完全相同的** `SyncPayloadCodec` 和密钥材料。

---

## 6. 批准制推送说明

### 6.1 为什么需要批准制？

本地修改不会立即推送到服务端，而是先进入**本地同步变更箱（outbox）**，等待用户批准。这是为了：
- 给用户一个"反悔"窗口，防止误改被立即同步到其他设备。
- 允许批量修改后一次性推送，减少服务端往返。

### 6.2 数据流

```
用户修改账号/模板/TOTP
        │
        ▼
SecureStorageService.saveAccount() ──► 记录自动标记为 pendingPush
        │                              同时写入 localSyncChange 表（outbox）
        ▼
UI 显示"有未同步变更"（isDirty = true）
        │
        ▼
用户进入同步设置 / 本地同步队列页
        │
        ▼
用户点击"批准并同步"
        │
        ▼
ServiceManager.approveAndSyncLocalChanges()
        │
        ▼
SyncService.push phase ──► 只读取"已批准"的 outbox 条目
        │                    与 pendingPush 记录取交集
        ▼
SyncPayloadCodec 加密 ──► POST /vaults/:id/sync
```

### 6.3 outbox 状态流转

| 状态 | 含义 | 谁设置 |
|------|------|--------|
| `open` | 刚写入 outbox，待用户批准 | `saveAccount()` 自动写入 |
| `approved` | 用户已批准，可以推送 | 用户点击"批准" |
| `synced` | 已成功推送到服务端 | push phase 成功后更新 |
| `discarded` | 用户丢弃此变更 | 用户点击"丢弃" |

> **注意**：`sync_service_push.dart` 的 push phase 只读取 `approved` 状态的 outbox 条目，不是读取所有 `pendingPush` 记录。未批准的变更会一直留在本地，不会推送。

---

## 7. 常见问题和调试技巧

### 7.1 同步一直没反应？

1. 检查 `SyncService.state` 是否为 `offline` — 如果是，说明没有配置同步服务器或用户手动断开了。
2. 检查 `ServiceManager.isUnlocked` — 同步只能在解锁状态下进行。
3. 检查 `SyncService.isDirty` — 如果为 `false` 且状态为 `idle`，说明确实没有需要同步的变更。

### 7.2 状态卡在 `connecting`？

- 查看 `SyncService.errorMessage`（调试日志，不用于 UI 判断）。
- 常见原因：`serverUrl` 为空 / 格式错误（检查 `SyncServerUrlStore`）。
- 检查 `IdentityService.hasIdentity` — 如果身份未初始化，同步会进入 `authError`。

### 7.3 反复进入 `conflictRecovery`？

- 查看 `SyncService.recoveryPhase`（测试可见性 getter）。
- 最多重试 3 次，每次延迟递增（500ms × retryCount）。
- 如果 3 次后仍冲突，状态会进入 `protocolError`。
- 根本原因：另一个设备在短时间内连续推送，导致本机的 `expected_base_server_version` 始终落后。

### 7.4 拉取到的数据看起来不对？

1. 检查 `SyncPayloadCodec.decodePayload()` 是否成功 — 如果 vaultId 不匹配或 MAC 验证失败，会抛 `SyncPayloadException`。
2. 检查 `CrdtMergeEngine.merge()` 的 `isPureFastForward` — 如果为 `false` 且本地原本没有 `pendingPush`，说明合并产生了缝合内容，这是正常的。
3. 查看 `SecureStorageService.getConflictLogs(accountId)` — 是否有 `hlc.corrupted_remote` 日志，说明远端数据损坏。

### 7.5 LAN 同步失败？

1. 检查 HTTP Server 同步是否正在进行 — LAN 同步与 server sync 互斥。
2. 检查 `LanSyncCoordinator.currentRole` — 确认当前是 Host 还是 Requester。
3. 检查 `LanSyncClient.phase` / `LanSyncHostHandler.getSessionPhase()` — 看卡在哪一个阶段。
4. 常见问题：
   - `connecting` 卡住 → UDP 广播未到达，检查防火墙/同网段。
   - `merging` 后一直不进入 `pushing` → 宿主侧冲突未解决，需要用户确认。
   - `committing` 后数据没变化 → 检查是否正确标记为 `pendingPush`（LAN 同步不写 `synchronized`）。

### 7.6 调试日志输出

项目使用 `AppLogger.d()` 统一输出日志，不直接用 `debugPrint`。同步模块的关键日志点：
- `sync_service.dart`：状态迁移、定时器触发。
- `sync_service_pull.dart`：拉取版本号、记录数、解密结果。
- `sync_service_push.dart`：推送记录数、服务端返回版本号。
- `sync_service_conflict.dart`：冲突类型、重试计数。
- `sync_payload_codec.dart`：编码/解码失败原因（vaultId 不匹配、MAC 失败等）。

### 7.7 测试命令速查

```bash
# 运行全部同步相关测试
flutter test test/sync

# 单独运行关键测试
flutter test test/sync/sync_state_machine_test.dart
flutter test test/sync/crdt_merge_engine_test.dart
flutter test test/sync/sync_payload_codec_test.dart
flutter test test/sync/multi_device_sync_test.dart
flutter test test/sync/sync_conflict_recovery_test.dart
```

---

## 8. 与旧文档的差异提示

本文档基于 2026-05-16 的代码扫描生成，与旧版同步协议文档存在以下实质性差异，以本文档为准：

| 旧文档描述 | 代码实际 | 影响 |
|-----------|---------|------|
| 使用 `SyncValue` 包装器 `{"name": {"v": "...", "hlc": "..."}}` | 实际为**扁平字段**：`name` + `nameHlc` | 旧文档的数据模型描述已过时 |
| Tombstone 逻辑：`compare(deleteHlc) > 0` 即决定胜负 | 实际需 `deleteHlc > max(对方所有字段 HLC)` 才能生效 | 旧伪代码过于简化，会导致误删 |
| 宣称有"人工仲裁复写引擎"和 Restore 功能 | 同步层**未实现**任何 restore/rewind 机制，`ConflictLog` 仅记录旧值 | 旧文档描述的功能不存在 |
| 称 Payload 使用 "nonce/ciphertext/HMAC 信封" | 实际使用 **AES-256-GCM (AEAD) + HKDF-SHA256** | 旧文档术语错误 |
| 说 push 读取所有 `PendingPush` | 实际只推送**已批准**的 outbox 条目 | 旧文档遗漏批准制推送 |
| 未提及 LAN 同步 | `lib/sync/` 有 4 个 LAN 相关文件，形成完整子系统 | 旧文档完全空白 |
| 未提及 `TotpCredential` 同步 | 同步协议支持三种实体（account/template/totp） | 旧文档只提 account |

---

*最后更新：2026-05-16*
