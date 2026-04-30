# SecretRoy 同步协议与冲突处理技术白皮书

> **文档分类:** 核心协议与算法指南
> **前置依赖:** 《SecretRoy 分布式加密同步架构白皮书》(Encryption & Identity)

本白皮书专注于解答由于极度放权给客户端而引发的代码级难题：**“在服务端不作任何干预的情况下，当多个设备断网或并发修改同一个密码本时，如何保证最终一致性绝对不乱？”**

---

## 1. HLC 逻辑时钟标准 (Hybrid Logical Clock)

由于不能信任设备的本地物理系统时间（用户可能调快/调慢手机时间，或者发生 NTP 时钟偏移），我们在内部使用一套强一致性的 **HLC 格式** 来追踪数据版本的先后秩序。

### 1.1 时钟结构
```text
HLC String := {毫秒级时间戳}-{自增计数器}-{设备公钥最后8位或随机设备ID}
例如：1681234567000-00-a1b2c3d4
```

### 1.2 时钟演进规则 (Clock Tik)
客户端在内存中维护一个全局单例 `current_hlc`。
- **本地写操作时**：更新 `current_hlc = max(current_hlc.time, current_system_time)`。如果时间没有变，在计数器上 `+1`。
- **接收到远端数据时**：强制校准本地时钟。`current_hlc = max(current_hlc, remote_hlc) + 1`。（这意味着哪怕某个设备时间倒流，它只要收到过未来时间的数据包，它的内部时钟标尺就会被拖着强行走到未来）。

### 1.3 `compare(hlc_A, hlc_B)` 比较规则优先级
1. 先比较 **物理时间戳** (UInt64)，大者为最近。
2. 若时间戳相等，比较 **逻辑计数器** (UInt16)，大者为最近。
3. 若恰巧连碰撞计数都相等，进行 **设备 ID 字典序排列**。这是绝对唯一的打破平局手段 (Tie-breaker)，保证所有设备的合并结果必须具备**确定性 (Deterministic)**。

---

## 2. LWW 数据模型与合并算法 (Local Merge Algorithm)

为了允许客户端 A 修改账户名，客户端 B 修改同个密码本里的登录密码而不互相覆盖，数据模型被精确下沉到**字段级最后写入胜出 (Field-Level Last-Write-Wins Map)**。

### 2.1 临床状态机的定义 (Local Sync Status)
每个记录（AccountItem）在本地 SQLite 中的运行状态必定是以下三种之一：
- `Synchronized (已同步)`：本地与最近一次远端确认过版本，完全一致。
- `PendingPush (待推送)`：本地发起了修改或合并，亟待把最新的状况推向弱服务端。
- `Tombstone (墓碑)`：数据标为被删除。

### 2.2 字段级包裹器 (The SyncValue Wrapper)
在旧架构中，账号是一堆明文字段；但在新架构中，任何可变的业务字段全部被包裹上了 HLC 戳：

```json
{
  "id": "item_uuid",
  "name": {"v": "Google 账号", "hlc": "168000-00-DevA"},
  "password": {"v": "my1234", "hlc": "168000-05-DevB"},
  "delete_hlc": "000000-00-DevA" // 墓碑特定时钟
}
```

### 2.3 `Merge()` 核心算法逻辑 (伪代码)
当且仅当拉取回来的别人修改的数据与自己待推送的数据发成撞车时，触发此算法：

```dart
AccountItem performMerge(AccountItem local, AccountItem remote) {
  // 内部辅助容器：记录所有在合并中被裁汰的“失败者”旧值，作用户的后悔药
  List<ConflictLog> conflictLogs = [];

  // 1. 拦截墓碑攻击权 (Tombstone Trumps All)
  // 如果有一方进行了事实上的删除（标记了 is_deleted），通过比较 HLC
  if (compare(remote.deleteHlc, local.deleteHlc) > 0) {
      if (remote.isDeleted) return remote; // 远端删除了，听远端的
  } else if (local.isDeleted) {
      return local; // 本地后来删除了它，不管远端怎么改，直接作废
  }

  // 2. 字段级穿透合并
  Map<String, SyncValue> mergedFields = {};
  for (String key in allKeys(local, remote)) {
      SyncValue lField = local.fields[key];
      SyncValue rField = remote.fields[key];

      if (lField == null) { mergedFields[key] = rField; continue; }
      if (rField == null) { mergedFields[key] = lField; continue; }

      // 核心：HLC 仲裁机
      if (HLC.compare(rField.hlc, lField.hlc) > 0) {
          mergedFields[key] = rField; // 远端更新，采用远端
          // 本地数据由于较老被覆盖，抽离存入覆写日志
          if(lField.v != rField.v) conflictLogs.add(ConflictLog(key, lField));
      } else {
          mergedFields[key] = lField; // 本地更新较晚，保留本地意见
          // 远端传来但过时，同样记录
          if(lField.v != rField.v) conflictLogs.add(ConflictLog(key, rField));
      }
  }

  // 3. 落地冲突历史记录，供用户在 UI 侧手动挑选“反悔复写”
  if (conflictLogs.isNotEmpty) {
      ConflictLogService.save(local.id, conflictLogs);
  }

  // 4. 将合并后的产物重新标记为待推送脏数据
  return AccountItem(fields: mergedFields, status: PendingPush);
}
```
经过这一套毫无感情的数学比对，无论发生何种诡异的并发或者断网，合并算法都会精准剔除跨越时空的覆盖。

### 2.4 冲突剥离与软回退日志 (Conflict Log & Soft-Revert)
单人多设备的场景下，冰冷的“时间戳最后修改胜出 (LWW)”有时会违背用户真实意图（例如用户晚上做出的较晚的修改其实是误触，而中午写的才是正确的）。
结合了极佳的用户体验，我们在底层做出了改良：**这套同步系统并非像 Git 一样强迫玩家在红绿代码中进行令人生畏的解冲突，而是全部静默完成自动合并，然后将失败的旧数据作为一条只读日志抛出**。

*   **剥离落败者**：如上述伪代码所示，所有在 HLC 竞争中落败的字段值，都不会被静默粉碎，而是抽取为一个 `ConflictLog` 写入本地专用抛弃库。
*   **非阻塞呈现**：在 UI 上，发生过冲突的账号右上角可以只是亮起一个小黄点或放入“同步历史记录”面板。用户不需要立刻解决它，不影响正常使用。
*   **人工仲裁复写引擎**：当玩家点进日志，如果发现“糟了，系统把我的正确密码给用旧/烂密码覆盖了”，玩家只需点击日志上的 **【使用此记录覆盖当前 (Restore)】**。
*   **时间戳降维打击**：点击恢复后，系统逻辑非常讨巧。系统直接用“用户点击所在的物理当前时间”生成一个最新的、无敌的霸主级 HLC，包裹这个日志旧值后原地复写本地。随后这将被自然当作“刚做的最新修改”顺理成章地 Push 覆盖云端其他任何错误分支。

---

## 3. 同步工作流状态推演 (The Pull / Merge / Push Triad)

这是一个典型的“非阻塞乐观并发控制” (OCC-based PMP Flow)。

### 阶段一：FETCH (无损侦测)
本地执行 `GET /vaults/<PublicKey>/sync?since_version=<LocalLastBaseVersion>`。
弱服务器直接抛出比这个版本号更新的所有密文 Block。
如果返回包是空的（Http 304 Not Modified），说明当前服务端没变化，且本地如果没有 `PendingPush`，结束流程。

### 阶段二：REBASE / MERGE (本地解决内政)
客户端利用对称主密钥解开所有 Block（即远端的真实被修改的 Item）。
客户端遍历这些 Item 进行检查：
1. **快进机制 (Fast-Forward)**：如果本地没有修改过该项，直接将其状态更新为 `Synchronized` 并覆盖覆写本地 SQLite。
2. **合并机制 (Merge)**：如果本地也是 `PendingPush` 状态，触发上文的 `performMerge` 算法。提取最优秀的基因组合后，打入 `PendingPush` 队列池。

### 阶段三：PUSH (定序与乐观锁)
1. 客户端从 SQLite 读取所有处于 `PendingPush` 状态的行。
2. 裹好数字签名，携带预期的 `expected_base_server_version`，提交向 `POST` 接口。
3. **退避回路 (The Retry Loop)**：如果服务端返回 409 Conflict（意味着在阶段一和阶段三这零点几秒的缝隙里，另一个设备居然抢发了更新），客户端立刻放弃任何争论。立刻切回阶段一的 FETCH 重做一遍拉取 - 合并 - 推送，直到拿到 Http 200 OK 为止。

---

## 结论

在这套 CRDT 与 OCC 组合拳的架构下：服务器成了一个绝对无状态的管道，而客户端变身为高精度解决内政合并的“微机房”。
即使有一万个客户端同时向主服务器提交对“同一条账号记录下不同备注与密码字段”的新增修改，在 HLC 严格排序下，网络收敛后，所有的一万个客户端的数据库最终字节表现形式将**100%分毫不差、数据毫无遗漏**。
