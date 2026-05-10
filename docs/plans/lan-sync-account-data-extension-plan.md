# SecretRoy 局域网账号同步扩展业务设计方案

| 项目 | 内容 |
|---|---|
| 文档编号 | SR-PLAN-LAN-SYNC-001 |
| 文档类型 | 业务设计与实施规划 |
| 适用对象 | 客户端架构、同步协议、CRDT 引擎维护者 |
| 范围 | `roy_client` 局域网配对 + 账号数据 P2P 同步 |
| 状态 | 设计草案 |
| 最后更新 | 2026-05-10 |

---

## 目录

1. [核心思路：单点合并中心](#1-核心思路单点合并中心)
2. [会话模型](#2-会话模型)
3. [同步协议](#3-同步协议)
4. [LAN 冲突处理机制](#4-lan-冲突处理机制)
5. [事务性：中断即未完成](#5-事务性中断即未完成)
6. [版本号处理](#6-版本号处理)
7. [设备 C 的业务冲突边界](#7-设备-c-的业务冲突边界)
8. [实施建议](#8-实施建议)

---

## 1. 核心思路：单点合并中心

### 1.1 现状

当前 `LanPairingService`：A(Host) 和 B(Requester) 配对成功，交换 Vault Identity 后 Server 关闭。

### 1.2 扩展：Host 作为合并中心

配对完成后，**Host（A）作为合并中心**，整个 LAN 同步只有三个步骤：

```
Step 1: B 把自己的全部数据推给 A
Step 2: A 在本地合并双方数据（CRDT），如有冲突 A 的用户现场处理
Step 3: A 把合并结果推给 B，B 直接覆盖本地数据（不做二次合并）
```

双方数据库内容达成一致，session 结束。

### 1.3 为什么选 Host 做合并中心

- Host 是配对发起方，天然处于"等待"状态，适合承担计算和交互
- Requester（B）的操作路径最短：推数据 → 等结果 → 接受结果
- 冲突处理只需要在 A 一台设备上出 UI，B 无需弹窗

---

## 2. 会话模型

### 2.1 会话状态机

```dart
enum LanSyncPhase {
  idle,
  connecting,       // B 发现 A，请求开始会话
  receiving,        // A 接收 B 推送的数据（内存暂存）
  merging,          // A 在内存中运行 CRDT 合并
  resolving,        // A 发现冲突，用户正在处理
  pushing,          // A 把合并结果推给 B
  committing,       // 双方 SQLite 事务提交
  completed,        // 完成
  interrupted,      // 中断（网络断开、用户取消、App 崩溃）
  failed,           // 数据校验失败等硬错误
}
```

### 2.2 状态流转

```
B 用户点击"局域网同步"
         ↓
    connecting ──[发现 Host]──→ receiving
                                    ↓
                              [B 数据全部到达]
                                    ↓
                                merging
                                    ↓
                    ┌───────── 无冲突 ─────────┐
                    ↓                          ↓
                pushing                   resolving
                    ↓                          ↓
                committing ←──[用户确认]───────┘
                    ↓
                completed
```

### 2.3 会话数据

A（Host）在内存中维护：

```dart
class LanSyncSession {
  final String sessionId;
  final String peerDeviceId;
  final DateTime startedAt;
  final List<SyncPayload> peerData;      // B 推过来的数据（内存中）
  final List<SyncPayload> mergedResult;  // A 合并后的结果（内存中）
  final List<ConflictItem> conflicts;    // 待处理的冲突（内存中）
  LanSyncPhase phase;
}
```

B（Requester）只需要知道自己当前处于哪个 phase，无需暂存数据。

---

## 3. 同步协议

### 3.1 端点

复用配对 HTTP Server，配对成功后继续监听：

| 端点 | 方法 | 职责 |
|---|---|---|
| `/lan-sync/start` | POST | B 请求开始会话，A 创建 session |
| `/lan-sync/push` | POST | B 分页推送自己的数据给 A（携带 sessionId） |
| `/lan-sync/result` | GET | B 查询合并结果和冲突状态（携带 sessionId） |
| `/lan-sync/pull` | POST | B 从 A 拉取合并后的结果（携带 sessionId） |
| `/lan-sync/abort` | POST | B 主动取消会话 |

### 3.2 完整交互

```
A (Host, 合并中心)                  B (Requester)
  |                                    |
  |<--- 1. POST /lan-sync/start -------|  B 请求开始
  |---- 2. {sessionId} --------------->|  A 创建 session
  |                                    |
  |<--- 3. POST /lan-sync/push --------|  B 推送第 1 页数据
  |---- 4. {accepted: [...]} --------->|  A 存入内存 peerData
  |                                    |
  |<--- 5. POST /lan-sync/push --------|  B 推送最后一页
  |---- 6. {accepted: [...]} --------->|  A 标记 receiving 完成
  |                                    |
  [A 在内存中运行 CRDT 合并]
  [如有冲突，A 的用户在 A 设备上处理]
  |                                    |
  |<--- 7. GET /lan-sync/result -------|  B 轮询状态
  |---- 8. {phase: "merging", conflicts: 0} → 无冲突
  |      {phase: "resolving", conflicts: 3} → 有冲突
  |                                    |
  [A 的用户处理完冲突，phase → pushing]
  |                                    |
  |<--- 9. POST /lan-sync/pull --------|  B 请求拉取合并结果
  |---- 10. {items: mergedPayloads} -->|  B 接收后内存暂存
  |                                    |
  [A 执行 SQLite 事务提交]
  [B 执行 SQLite 事务提交]
  |                                    |
  |---- 11. {committed: true} -------->|  A 通知 B commit 成功
  |                                    |
  phase → completed                   phase → completed
```

### 3.3 载荷加密

复用 `SyncPayloadCodec`，AAD 中附加 `sessionId` 防重放。

---

## 4. LAN 冲突处理机制

### 4.1 冲突发生在哪里

冲突只在**A（Host）**上发生。A 收到 B 的数据后，运行 `CrdtMergeEngine.merge(local, remote)`：

```dart
for (final remoteItem in peerData) {
  final localItem = await storageService.getAccountById(remoteItem.id);
  if (localItem == null) {
    mergedResult.add(remoteItem);  // B 有 A 没有的，直接接受
  } else {
    final result = CrdtMergeEngine.merge(localItem, remoteItem);
    mergedResult.add(result.mergedItem);
    conflicts.addAll(result.conflictLogs);  // 收集冲突
  }
}
```

### 4.2 无冲突：快乐路径

```
conflicts.isEmpty → phase 直接从 merging → pushing
A 自动把 mergedResult 推给 B
双方 commit
用户看到 toast："同步完成，无冲突"
```

### 4.3 有冲突：LAN 冲突处理 UI

冲突只在 A 的设备上弹出处理界面。B 的设备只显示"等待对方处理冲突..."

**A 设备上的 LAN 冲突处理 Sheet：**

```
┌─────────────────────────────┐
│ 局域网同步冲突 (3个)           │
├─────────────────────────────┤
│ 账号: Github                  │
│ 字段: 密码                    │
│ 我的版本: ******** (A)        │
│ 对方版本: ******** (B)        │
│ [保留我的]  [保留对方的]       │
├─────────────────────────────┤
│ 账号: 支付宝                  │
│ 字段: 手机号                  │
│ ...                          │
└─────────────────────────────┘
      [确认并继续同步]
```

- A 的用户逐个选择"保留我的"或"保留对方的"
- 选择结果直接修改 `mergedResult` 中对应字段的值
- 全部确认后，phase → pushing
- A 把最终 mergedResult 推给 B

### 4.4 与服务器 ConflictLog 的关系

LAN 冲突处理是**现场即时处理**，不是异步记录。

但为了审计和可追溯，处理完成后，胜出的修改仍然可以生成一条 `ConflictLog`（标记 `source: lan`）进数据库，供用户在 `ConflictInboxView` 中事后查看。

---

## 5. 事务性：中断即未完成

### 5.1 核心原则

Commit 之前，所有数据只在**内存**中。任何中断 = 内存丢弃 = 数据库不受影响。

### 5.2 中断场景

| 中断时机 | A 的状态 | B 的状态 | 处理 |
|---|---|---|---|
| B push 数据到 A 途中 | 有部分 peerData（内存） | 已发送部分 | A 丢弃内存 session，标记 interrupted。B 下次重新 start。 |
| A merging 途中 | peerData 在内存，正在合并 | 等待结果 | A 丢弃内存，标记 interrupted。B 超时后重试或取消。 |
| A resolving 冲突时 | mergedResult + conflicts 在内存 | 显示"等待对方处理" | A 用户取消 → abort → 双方内存丢弃。 |
| A push 结果给 B 途中 | mergedResult 在内存 | 收到部分 | B 丢弃内存，A 标记 interrupted。 |
| Commit 途中 | SQLite 事务执行中 | 等待确认 | SQLite 保证：若崩溃，事务自动回滚。 |
| B 收到结果后、commit 前崩溃 | 已 commit | 结果在内存，未 commit | B 重启后无感知（数据库状态与同步前一致）。用户重新触发同步即可。 |

### 5.3 B 的特殊补偿：Pull 模式兜底

如果 A push 结果给 B 时网络中断，B 可以主动 pull：

```dart
// B 在 push 阶段超时后
if (phase == LanSyncPhase.pushing && timeout) {
  // 切换到 pull 模式，主动从 A 获取结果
  final result = await _pullResultFromHost(sessionId);
  if (result != null) {
    await _commitToLocalDatabase(result);
  }
}
```

---

## 6. 版本号处理

### 6.1 LAN 同步不碰 serverVersion

```
同步前:  A._localVersion = 42,  B._localVersion = 45
同步后:  A._localVersion = 42,  B._localVersion = 45（保持不变）
```

serverVersion 是服务器独占的游标，LAN 同步只交换数据，不分配、不修改版本号。

### 6.2 同步后数据库一致性

LAN 同步完成后，A 和 B 的数据库内容**完全一致**：

| 字段 | A | B | 说明 |
|---|---|---|---|
| `name` / `email` / `data` | 相同 | 相同 | 合并后的值 |
| `nameHlc` / `emailHlc` / `dataHlc` | 相同 | 相同 | 合并后的 HLC |
| `syncStatus` | 相同 | 相同 | pendingPush 或 synchronized（见 6.3） |
| `serverVersion`（每条记录） | 相同 | 相同 | 合并后的值 |
| `_localVersion`（全局游标） | 42 | 45 | **各自保留，不修改** |

### 6.3 syncStatus 的处理

这是最关键的业务边界。

**问题**：A 和 B 合并后，双方的记录 syncStatus 应该是什么？

**方案**：

| 场景 | syncStatus 处理 |
|---|---|
| 合并结果中包含 A 或 B 的本地胜出字段 | 双方该记录都设为 `pendingPush`（因为服务器还没有确认这些修改） |
| 合并结果是 fast-forward（双方都没有修改，或修改不冲突） | 保持原 syncStatus（如果原先是 synchronized，就保持 synchronized） |
| 记录被删除（tombstone 胜出） | 双方该记录 syncStatus 设为 `pendingPush`（删除需要推送到服务器） |

**红线**：LAN 同步**不能**把 `syncStatus` 从 `pendingPush` 改成 `synchronized`。只有服务器 Push 返回 200 后才能改。

### 6.4 辅助标记：lastLanSyncAt

双方各自记录本次 LAN 同步的时间戳：

```dart
await storageService.setSetting('lan_sync_last_$vaultId', DateTime.now().toIso8601String());
```

用于 UI 显示"上次局域网同步：2分钟前"，不做任何业务逻辑判断。

---

## 7. 设备 C 的业务冲突边界

这是用户最关心的场景。设 A 为 Host（合并中心），B 为 Requester，C 为未参与 LAN 同步的第三方设备。

### 7.1 场景设定

```
T0: A、B、C 初始数据一致，各自 serverVersion = 100

T1: A ↔ B LAN 同步，A 为合并中心
     - A 和 B 交换数据，A 做 CRDT 合并
     - 假设无冲突，A 和 B 数据库内容完全一致
     - A.lastLanSyncAt = T1, B.lastLanSyncAt = T1
     - C 未参与，C 不知情

T2: A 修改账号 X 的密码（生成 HLC_A）
T3: B 修改账号 Y 的备注（生成 HLC_B）
T4: C 修改账号 X 的密码（生成 HLC_C）

T5: A 与服务器同步
     - Pull since=100 → 无新数据（C 还没 push）
     - Push X → 服务器接受 → serverVersion = 101
     - A._localVersion = 101

T6: B 与服务器同步
     - Pull since=100 → 收到 X（v101）
     - B 本地：X_remote vs X_local（B 没有修改 X）→ fast-forward 接受
     - Push Y → 服务器接受 → serverVersion = 102
     - B._localVersion = 102

T7: C 与服务器同步
     - Pull since=100 → 收到 X（v101，A 的修改）和 Y（v102，B 的修改）
     - C 本地合并：
       - X_remote（A）vs X_local（C 自己修改了 X）→ HLC 比较决定胜负
       - Y_remote（B）vs Y_local（C 没有修改 Y）→ fast-forward 接受
     - 如果 HLC_A > HLC_C：A 胜出，C 的 X 被覆盖，C 的修改进 ConflictLog
     - 如果 HLC_C > HLC_A：C 胜出，C 的 X 保留，A 的修改进 ConflictLog
     - C 然后 Push 自己的修改（如果有 pendingPush）
```

### 7.2 关键业务边界

#### 边界 1：C 感知的冲突是 C 与 A/B 的冲突，不是 A+B "联手" 对付 C

A 和 B 的 LAN 同步只是让他们提前达成一致，但**不会给他们在服务器上带来任何优势**。C 从服务器 Pull 到 A/B 的修改时，冲突消解完全由 HLC 决定，与 A/B 是否 LAN 同步过无关。

```
C 的视角：
- 从服务器收到 A 修改的 X（v101）
- C 自己本地也修改了 X
- CRDT 合并：HLC 高的赢
- 结果与 "A 是否和 B 同步过" 完全无关
```

#### 边界 2：A/B LAN 同步后 serverVersion 不同，但不会导致数据丢失

```
A._localVersion = 101
B._localVersion = 102
C._localVersion = 100

C 与服务器同步：GET /sync?since=100
→ 服务器返回 v101（X）、v102（Y）
→ C 正常合并
→ 无数据丢失
```

各自的 `_localVersion` 只是游标，不影响数据正确性。

#### 边界 3：A/B 必须把自己在 LAN 同步后的修改 Push 到服务器，C 才能看到

如果 A 在 T2 修改了 X，但 A 一直不连服务器（T5 未发生），那么 C 永远看不到 A 的修改。这是正常行为，与 LAN 同步无关。

**LAN 同步不是服务器同步的替代**，A/B 仍然需要定期与服务器同步，才能让 C 获取到他们的修改。

#### 边界 4：C 的 ConflictLog 中看到的冲突来源是 `server`，不是 `lan`

C 的冲突是在与服务器同步时产生的，所以 `ConflictLog.source = server`。A 的 LAN 冲突处理界面只影响 A 和 B 的本地数据，不影响 C 的冲突记录。

#### 边界 5：极端场景 —— A 和 B 的 LAN 同步结果覆盖了 C 的合法修改

假设：
```
T1: A ↔ B LAN 同步，A 和 B 达成一致
T2: A 修改 X（HLC_A = 1000-1-device_A）
T3: C 修改 X（HLC_C = 2000-1-device_C）
T4: B 未修改 X
T5: A Push → serverVersion = 101
T6: C Pull → 收到 X（HLC_A = 1000）
T7: C 本地合并：HLC_C(2000) > HLC_A(1000) → C 胜出
T8: C Push → serverVersion = 102
```

在这个场景中，C 的修改因为 HLC 更高而胜出，A 的修改被覆盖。这是正确的 CRDT 行为。

但如果 A 的系统时间被调快：
```
T2: A 修改 X（HLC_A = 5000-1-device_A，因为 A 的系统时间错误调快）
T3: C 修改 X（HLC_C = 2000-1-device_C，正常时间）
T5: A Push → serverVersion = 101
T6: C Pull → 收到 X（HLC_A = 5000）
T7: C 本地合并：HLC_A(5000) > HLC_C(2000) → A 胜出
```

C 的合法修改被 A 的"时间作弊"覆盖了。这是 HLC 的已知缺陷，**与 LAN 同步无关**。

应对：`SyncClock.receive()` 已有的 5 分钟漂移保护 + 更严格的本地时间监测。

#### 边界 6：C 长时间离线，只通过 LAN 与其他设备同步

如果 C 长期不连服务器，但 C 与 A（或 B）进行了 LAN 同步，C 可以获取到 A/B 的所有修改。这是 LAN 同步的价值所在。

但 C 仍然需要最终与服务器同步一次，以确保 `_localVersion` 对齐和服务器上的数据完整。

### 7.3 Push 时序导致的两种业务边界

这是 LAN 同步引入后**最关键的新边界**。AB 先达成一致再分别 Push，与 C 的 Push 存在时序竞争。

#### 边界 A：C 先 Push，AB 后 Push

```
T0: 服务器 S0, version=100
T1: A↔B LAN 同步，双方数据一致（假设都修改了 X）
T2: C 先 Push → 服务器接受 → version=101（C 的修改成为权威）
T3: A 再同步：Pull v101 → 与本地合并 → Push → version=102
T4: B 再同步：Pull v101,v102 → fast-forward（与 A 数据一致）→ 无需 Push
```

| 角色 | 结果 |
|---|---|
| C | 正常完成，无 ConflictRecovery |
| A | Pull 到 C 的数据，本地 CRDT 合并后 Push。无 409 |
| B | Pull 到 C 和 A 的数据，B 本地与 A 数据一致 → fast-forward → 无 409 |

**特点**：B 的体验最好，因为 LAN 同步后 B 与 A 数据一致，A 先 Push 了合并结果，B 再同步时直接 fast-forward。

#### 边界 B：AB 先 Push，C 后 Push

```
T0: 服务器 S0, version=100
T1: A↔B LAN 同步，双方数据一致
T2: A 先 Push → 服务器接受 → version=101
T3: B 再 Push → expected=100, actual=101 → 409 stale_base_version
    B ConflictRecovery：Pull v101 → 发现与本地一致（LAN 同步的正面效果）→ fast-forward → 重新 Push → version=102
T4: C 再同步：Pull v101,v102 → 与本地合并 → Push → version=103
```

| 角色 | 结果 |
|---|---|
| A | 正常完成 |
| B | **遇到 409**，走 ConflictRecovery。但 LAN 同步后 B 已拥有 A 的数据，Pull 到的 v101 与 B 本地 fast-forward，恢复成本极低 |
| C | Pull 到 AB 的合并结果，本地 CRDT 合并后 Push。如果 C 本地也有修改且 HLC 更高，C 的修改覆盖 AB 的，AB 的修改进 C 的 ConflictLog |

**特点**：B 会触发一次 ConflictRecovery，但因为 LAN 同步预加载了 A 的数据，恢复路径是 fast-forward，比没有 LAN 同步时快得多。

#### 边界 C：AB 同时 Push

```
T1: A↔B LAN 同步，双方一致
T2: A 和 B 同时 Push
    服务器先收到 A → 接受 → version=101
    服务器后收到 B → expected=100, actual=101 → 409
    B ConflictRecovery：Pull v101（就是 A 推的数据，与 B 本地一致）→ fast-forward → 重新 Push → version=102
```

**结论**：B 总会遇到 409，但 LAN 同步使 B 的 ConflictRecovery 变成无成本 fast-forward。

### 7.4 关键结论

| 结论 | 说明 |
|---|---|
| **Push 时序决定 serverVersion 序列，但不决定最终数据** | 无论 C 先还是 AB 先，最终所有设备通过 HLC 收敛到相同状态 |
| **LAN 同步降低 ConflictRecovery 成本** | AB 先 Push 时，B 会遇到 409，但因为 LAN 同步预加载了 A 的数据，B 的 ConflictRecovery 几乎是零成本 fast-forward |
| **C 的体验与时序无关** | C 总是走正常的服务器同步流程：Pull → CRDT 合并 → Push。C 不知道 AB 是否 LAN 同步过 |
| **最终数据由 HLC 决定，不是由 Push 顺序决定** | 即使 AB 先 Push 占领了 serverVersion 高位的"话语权"，如果 C 的 HLC 更高，C 的修改仍然会在后续的 CRDT 合并中胜出 |

### 7.5 冲突边界总结表

| 场景 | 涉及设备 | 冲突处理方 | 冲突结果决定因素 |
|---|---|---|---|
| A ↔ B LAN 同步，双方修改同一字段 | A、B | A（Host 合并中心） | A 的用户在 LAN 冲突 UI 中选择 |
| A/B 与 C 通过服务器同步，修改同一字段 | A/B、C | C（C 的设备上） | HLC 比较 |
| A LAN 同步后修改 X，B 也修改 X，C 也修改 X | A、B、C | A（LAN 阶段）+ C（服务器阶段） | A 先处理 A↔B，C 再处理 C↔服务器。最终由 HLC 在 C 设备上决定 |
| A 和 B LAN 同步达成一致后，A 删除 X，C 修改 X | A、C | C（服务器同步时） | `deleteHlc` vs `dataHlc` |
| AB 同时 Push，B 遇到 409 | A、B | B（ConflictRecovery） | LAN 同步使 B 的恢复为零成本 fast-forward |

---

## 8. 实施建议

### 8.1 文件清单

```text
lib/
├── services/
│   └── lan_pairing_service.dart          [改] 配对后不关闭 Server，增加同步端点
├── sync/
│   ├── lan_sync_host_handler.dart        [新增] Host 端：接收 B 数据、CRDT 合并、冲突处理、推结果
│   ├── lan_sync_client.dart              [新增] Requester 端：推数据、轮询状态、拉结果、commit
│   ├── lan_sync_session.dart             [新增] Session 模型、阶段枚举
│   └── lan_conflict_resolver.dart        [新增] Host 端的 LAN 冲突处理 UI 逻辑（BottomSheet）
└── views/
    └── sync_settings_view.dart           [改] 增加"局域网同步"按钮
```

### 8.2 阶段划分

**第一阶段（1 周）：会话基础设施**
- `LanPairingService`：配对后保持 Server，增加 `/lan-sync/start|push|result|pull|abort`
- `LanSyncSession` 模型和阶段枚举
- Host 端内存 Session 管理（Map<String, LanSyncSession>）

**第二阶段（1 周）：数据传输**
- B 向 A 分页 Push 数据
- A 接收并存入内存
- A 向 B Push 合并结果
- B 接收并存入内存

**第三阶段（1 周）：合并与冲突**
- Host 端集成 `CrdtMergeEngine`
- 无冲突自动完成（快乐路径）
- 有冲突弹出 LAN 冲突处理 BottomSheet
- 冲突确认后生成 mergedResult

**第四阶段（1 周）：Commit 与边界**
- 双方 SQLite 事务提交
- 双通道互斥（LAN 和服务器同步不能同时执行）
- 设备 C 场景集成测试
- `syncStatus` 和 `LocalSyncChange` 补录逻辑

### 8.3 关键测试场景

| 测试 | 场景 |
|---|---|
| 快乐路径 | A↔B 无冲突同步，双方数据一致 |
| 冲突路径 | A↔B 修改同一字段，Host 冲突处理，结果一致 |
| 中断恢复 | Pull 中断、Push 中断、merging 中断、commit 前崩溃 |
| 三设备 | A↔B LAN 同步 → A→Server → C→Server → 验证 C 的合并结果 |
| 时间作弊 | A 系统时间调快，验证 `SyncClock` 漂移保护 |

---

*文档结束*
