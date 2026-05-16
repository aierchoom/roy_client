# SecretRoy 局域网同步实施文档

| 项目 | 内容 |
|---|---|
| 文档编号 | SR-IMPL-LAN-SYNC-001 |
| 文档类型 | 实施指南 |
| 依赖 | SR-PLAN-LAN-SYNC-001（业务设计） |
| 范围 | `roy_client` 局域网同步模块 |
| 状态 | 已实施（Phase 1-3 完成） |
| 最后更新 | 2026-05-10 |

---

## 1. 接口定义

### 1.1 LAN 同步端点（Host 端 HTTP Server）

复用 `LanPairingService` 的 HTTP Server，配对 Claim 成功后继续监听。

```dart
// lib/services/lan_pairing_service.dart 扩展

// POST /lan-sync/start
// Request Body: {"device_id": "device_xxx"}
// Response: {"session_id": "sess_xxx", "ttl_seconds": 300}
// Error: 503 {"error": "Sync in progress"} | 403 {"error": "Only local network"}

// POST /lan-sync/push
// Request Body: {"session_id": "sess_xxx", "page": 0, "items": [{"encrypted_payload": "sroy-sync:..."}]}
// Response: {"accepted": ["id1", "id2"], "has_more": false}
// Error: 404 {"error": "Session not found"} | 410 {"error": "Session expired"}

// GET /lan-sync/result
// Query: ?session_id=sess_xxx
// Response: {"phase": "merging", "conflicts": 0, "total_items": 12}
//           {"phase": "resolving", "conflicts": 3, "conflict_preview": [...]}
// Error: 404 {"error": "Session not found"}

// POST /lan-sync/pull
// Request Body: {"session_id": "sess_xxx"}
// Response: {"items": [{"encrypted_payload": "sroy-sync:..."}], "has_more": false}
// Error: 404 | 410

// POST /lan-sync/abort
// Request Body: {"session_id": "sess_xxx"}
// Response: {"aborted": true}
```

### 1.2 Dart 接口层

#### Host 端处理器

```dart
// lib/sync/lan_sync_host_handler.dart

class LanSyncHostHandler {
  final SecureStorageService _storage;
  final IdentityService _identity;

  // 内存中的活跃会话
  final Map<String, _HostSession> _sessions = {};

  /// HTTP Server 收到 /lan-sync/start 时调用
  Future<Map<String, dynamic>> handleStart(String peerDeviceId);

  /// HTTP Server 收到 /lan-sync/push 时调用
  Future<Map<String, dynamic>> handlePush(String sessionId, int page, List<String> encryptedPayloads);

  /// HTTP Server 收到 /lan-sync/result 时调用
  Future<Map<String, dynamic>> handleResultQuery(String sessionId);

  /// HTTP Server 收到 /lan-sync/pull 时调用
  Future<Map<String, dynamic>> handlePull(String sessionId);

  /// HTTP Server 收到 /lan-sync/abort 时调用
  Future<Map<String, dynamic>> handleAbort(String sessionId);

  /// 在 merging 阶段调用：运行 CRDT 合并
  Future<_MergeOutput> _runMerge(String sessionId);

  /// 在 committing 阶段调用：SQLite 事务写入
  Future<void> _commit(String sessionId);
}

class _HostSession {
  final String sessionId;
  final String peerDeviceId;
  final DateTime startedAt;
  final DateTime expiresAt;
  LanSyncPhase phase;
  final List<Map<String, dynamic>> peerPayloads = []; // 从 B 收到的加密数据（内存）
  List<dynamic>? mergedItems; // 合并结果（内存）
  List<ConflictItem>? conflicts; // 冲突列表（内存）
}
```

#### Requester 端客户端

```dart
// lib/sync/lan_sync_client.dart

class LanSyncClient {
  final SecureStorageService _storage;
  final IdentityService _identity;

  /// 发起 LAN 同步（B 调用）
  Future<LanSyncResult> startSync({
    required InternetAddress hostAddress,
    required int hostPort,
    required void Function(LanSyncPhase phase, String? message) onProgress,
  });

  /// 推送本地 pendingPush 数据给 Host
  Future<void> _pushLocalData(String sessionId, String hostUrl);

  /// 轮询合并结果
  Future<_MergeResult> _pollResult(String sessionId, String hostUrl);

  /// 拉取合并结果
  Future<List<dynamic>> _pullMergedResult(String sessionId, String hostUrl);

  /// 本地 SQLite 事务提交
  Future<void> _commitLocal(List<dynamic> mergedItems);
}

class LanSyncResult {
  final bool success;
  final int pushedItems;
  final int pulledItems;
  final int conflictCount;
  final String? error;
}
```

#### 会话状态机

```dart
// lib/sync/lan_sync_session.dart

enum LanSyncPhase {
  idle,
  connecting,
  receiving,
  merging,
  resolving,
  pushing,
  committing,
  completed,
  interrupted,
  failed,
}

class LanSyncSession {
  final String sessionId;
  final String peerDeviceId;
  final DateTime startedAt;
  LanSyncPhase phase;
  int? conflictCount;
  String? failureReason;

  bool get isActive =>
      phase == LanSyncPhase.connecting ||
      phase == LanSyncPhase.receiving ||
      phase == LanSyncPhase.merging ||
      phase == LanSyncPhase.resolving ||
      phase == LanSyncPhase.pushing ||
      phase == LanSyncPhase.committing;

  bool get isTerminal =>
      phase == LanSyncPhase.completed ||
      phase == LanSyncPhase.interrupted ||
      phase == LanSyncPhase.failed;
}
```

### 1.3 LAN 冲突处理 UI

```dart
// lib/sync/lan_conflict_resolver.dart

class LanConflictResolver {
  /// 弹出冲突处理 BottomSheet（仅在 Host 设备上调用）
  /// 返回用户确认后的 merged items
  static Future<List<dynamic>> showConflictSheet({
    required BuildContext context,
    required List<ConflictItem> conflicts,
    required List<dynamic> currentMergedItems,
  });
}

class ConflictItem {
  final String entityType; // account | template | totp
  final String entityId;
  final String fieldKey;
  final String localValue;
  final String remoteValue;
  final String localDeviceId;
  final String remoteDeviceId;
}
```

---

## 2. 数据模型与数据库变更

### 2.1 无新增表

LAN 同步的所有中间数据仅存于**内存**中，不新增数据库表。

复用现有表：
- `accounts` / `templates` / `totp_credentials`：`committing` 阶段写入
- `conflict_logs`：`resolving` 阶段用户确认后写入
- `local_sync_changes`：`committing` 阶段自动补录 approved 记录

### 2.2 新增 Settings 键

```dart
// 仅用于 UI 显示"上次局域网同步时间"
String _lanSyncLastTimeKey(String vaultId) => 'lan_sync_last_$vaultId';
```

### 2.3 SyncStatus 处理规则（Commit 时）

```dart
SyncStatus _determineStatusAfterLanSync(AccountItem local, AccountItem merged) {
  // 如果合并结果与本地不同（说明本地有字段胜出或被覆盖）
  // 且本地原本不是 synchronized
  // 则保持 pendingPush
  
  // 如果本地原本是 synchronized，且合并是 fast-forward（本地无修改）
  // 则保持 synchronized
  
  // LAN 同步永远不会把 pendingPush 改为 synchronized
  // LAN 同步永远不会把 synchronized 改为 pendingPush（除非本地字段胜出）
}
```

### 2.4 LocalSyncChange 补录

Commit 事务中，对每条 `syncStatus == pendingPush` 的记录：

```dart
await txn.execute('''
  INSERT OR REPLACE INTO local_sync_changes (
    id, vault_id, entity_type, entity_id, action, status, base_server_version, created_at
  ) VALUES (?, ?, ?, ?, 'update', 'approved', ?, ?)
''', [uuid, vaultId, 'account', entityId, localVersion, now]);
```

---

## 3. 错误码定义

### 3.1 Host 端 HTTP 错误码

| 状态码 | 场景 | Requester 行为 |
|---|---|---|
| 200 | 正常响应 | 继续 |
| 404 | Session 不存在 | 放弃当前 session，重新 `start` |
| 410 | Session 已过期 | 放弃当前 session，重新 `start` |
| 409 | Push 数据校验失败（MAC 不匹配）| 立即 abort，提示"数据校验失败" |
| 503 | Host 正在处理其他同步或服务器同步 | 延迟 2 秒后重试，最多 3 次 |
| 403 | 非局域网 IP | 拒绝连接 |

### 3.2 Dart 异常类型

```dart
class LanSyncException implements Exception {
  final String code;
  final String message;
  const LanSyncException(this.code, this.message);
}

// 预定义异常
const kLanSyncTimeout = LanSyncException('TIMEOUT', '同步超时');
const kLanSyncSessionExpired = LanSyncException('SESSION_EXPIRED', '会话已过期');
const kLanSyncDataCorrupted = LanSyncException('DATA_CORRUPTED', '数据校验失败');
const kLanSyncHostBusy = LanSyncException('HOST_BUSY', '对方设备正忙');
const kLanSyncChannelConflict = LanSyncException('CHANNEL_CONFLICT', '服务器同步进行中');
```

---

## 4. 关键业务逻辑伪代码

### 4.1 Host 端：接收 B 的数据并合并

```dart
Future<void> _onPushReceived(String sessionId, List<String> encryptedPayloads) async {
  final session = _sessions[sessionId];
  if (session == null) throw LanSyncException('SESSION_NOT_FOUND', '');
  
  session.phase = LanSyncPhase.receiving;
  
  for (final cipher in encryptedPayloads) {
    final payload = await SyncPayloadCodec.decodePayload(
      encodedPayload: cipher,
      expectedVaultId: _identity.vaultId,
      privateKey: _identity.privateKey,
      symmetricKey: _identity.symmetricKey,
    );
    session.peerPayloads.add(payload);
  }
  
  // 全部收到后进入 merging
  if (!hasMorePages) {
    await _runMerge(session);
  }
}

Future<void> _runMerge(_HostSession session) async {
  session.phase = LanSyncPhase.merging;
  
  final mergedItems = <dynamic>[];
  final conflicts = <ConflictItem>[];
  
  for (final payload in session.peerPayloads) {
    final type = payload['_type'] as String?;
    if (type == 'account') {
      final remote = AccountItem.fromJson(payload);
      final local = await _storage.getAccountById(remote.id, includeDeleted: true);
      
      if (local == null) {
        mergedItems.add(remote);
      } else {
        final result = CrdtMergeEngine.merge(local, remote);
        mergedItems.add(result.mergedItem);
        
        for (final log in result.conflictLogs) {
          conflicts.add(ConflictItem(
            entityType: 'account',
            entityId: log.accountId,
            fieldKey: log.fieldKey,
            localValue: log.localValue,
            remoteValue: log.remoteValue,
            localDeviceId: _identity.deviceId,
            remoteDeviceId: session.peerDeviceId,
          ));
        }
      }
    }
    // template / totp 同理
  }
  
  session.mergedItems = mergedItems;
  session.conflicts = conflicts;
  session.conflictCount = conflicts.length;
  
  if (conflicts.isEmpty) {
    session.phase = LanSyncPhase.pushing;
  } else {
    session.phase = LanSyncPhase.resolving;
    // 等待用户处理，UI 轮询 /lan-sync/result 看到 phase=resolving
  }
}
```

### 4.2 Host 端：用户确认冲突后提交

```dart
Future<void> _onUserResolved(String sessionId, List<dynamic> resolvedItems) async {
  final session = _sessions[sessionId]!;
  session.mergedItems = resolvedItems;
  session.phase = LanSyncPhase.pushing;
}

Future<void> _commit(String sessionId) async {
  final session = _sessions[sessionId]!;
  session.phase = LanSyncPhase.committing;
  
  await _storage.transaction((txn) async {
    for (final item in session.mergedItems!) {
      if (item is AccountItem) {
        await _storage.saveAccountInTransaction(txn, item, isSyncMerge: true);
        
        // 自动补录 LocalSyncChange
        if (item.syncStatus == SyncStatus.pendingPush) {
          await _storage.ensureLocalSyncChangeInTransaction(
            txn,
            vaultId: _identity.vaultId,
            entityType: LocalSyncEntityType.account,
            entityId: item.id,
            action: LocalSyncAction.update,
            status: LocalSyncChangeStatus.approved,
          );
        }
      }
      // template / totp 同理
    }
    
    // 写入 ConflictLog（如有）
    if (session.conflicts != null && session.conflicts!.isNotEmpty) {
      await _storage.saveConflictLogsInTransaction(
        txn,
        session.conflicts!.map((c) => ConflictLog(...)).toList(),
      );
    }
    
    // 记录上次同步时间
    await _storage.setSettingInTransaction(
      txn,
      'lan_sync_last_${_identity.vaultId}',
      DateTime.now().toIso8601String(),
    );
  });
  
  session.phase = LanSyncPhase.completed;
}
```

### 4.3 Requester 端：完整同步流程

```dart
Future<LanSyncResult> startSync({
  required InternetAddress hostAddress,
  required int hostPort,
  required void Function(LanSyncPhase, String?) onProgress,
}) async {
  // 红线 R3：检查服务器同步是否活跃
  if (syncService.isSyncing) {
    throw kLanSyncChannelConflict;
  }
  
  final hostUrl = 'http://${hostAddress.address}:$hostPort';
  
  try {
    // 1. Start session
    onProgress(LanSyncPhase.connecting, null);
    final startResp = await _post('$hostUrl/lan-sync/start', {
      'device_id': _identity.deviceId,
    });
    final sessionId = startResp['session_id'] as String;
    
    // 2. Push local pending data
    onProgress(LanSyncPhase.receiving, '正在发送本地数据...');
    await _pushLocalData(sessionId, hostUrl);
    
    // 3. Poll until merging complete or resolving
    onProgress(LanSyncPhase.merging, '等待对方合并...');
    _MergeResult mergeResult;
    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));
      mergeResult = await _pollResult(sessionId, hostUrl);
      
      if (mergeResult.phase == LanSyncPhase.pushing) {
        break; // 无冲突，Host 已准备好推送结果
      }
      if (mergeResult.phase == LanSyncPhase.resolving) {
        onProgress(LanSyncPhase.resolving, '发现 ${mergeResult.conflictCount} 个冲突');
        // B 设备只等待，冲突在 A 设备上处理
        // A 处理完成后 phase 会变回 pushing
        continue;
      }
      if (mergeResult.phase == LanSyncPhase.interrupted ||
          mergeResult.phase == LanSyncPhase.failed) {
        throw LanSyncException('HOST_FAILED', '对方处理失败');
      }
    }
    
    // 4. Pull merged result
    onProgress(LanSyncPhase.pushing, '正在接收合并结果...');
    final mergedItems = await _pullMergedResult(sessionId, hostUrl);
    
    // 5. Commit local
    onProgress(LanSyncPhase.committing, '正在写入数据库...');
    await _commitLocal(mergedItems);
    
    onProgress(LanSyncPhase.completed, '同步完成');
    return LanSyncResult(success: true, pulledItems: mergedItems.length);
    
  } on LanSyncException catch (e) {
    // 中断时 abort session
    try {
      await _post('$hostUrl/lan-sync/abort', {'session_id': sessionId});
    } catch (_) {}
    onProgress(LanSyncPhase.interrupted, e.message);
    return LanSyncResult(success: false, error: e.message);
  }
}
```

### 4.4 双通道互斥

```dart
// LanSyncClient.startSync 开头
if (syncService.isSyncing) {
  throw kLanSyncChannelConflict;
}

// SyncService.syncNow 开头
if (lanSyncClient.isBusy) {
  return SyncResult.failure('局域网同步进行中');
}
```

---

## 5. 测试策略

### 5.1 单元测试

| 测试文件 | 覆盖点 |
|---|---|
| `lan_sync_session_test.dart` | 阶段流转：idle→connecting→receiving→merging→pushing→committing→completed |
| `lan_sync_host_handler_test.dart` | Host 接收 push、运行 merge、处理冲突、commit |
| `lan_sync_client_test.dart` | Client 发起 start、push、poll、pull、commit 完整流程 |
| `lan_sync_status_test.dart` | Commit 后 syncStatus 规则：pendingPush 保持，synchronized 不主动改 |

### 5.2 集成测试

| 场景 | 验证点 |
|---|---|
| **快乐路径** | A(Host) 和 B 无冲突同步，双方数据库逐字段一致 |
| **冲突路径** | A 和 B 修改同一字段，Host 冲突 UI 处理，结果一致 |
| **Pull 中断** | B push 到一半断网，B 重新 start，数据无重复无丢失 |
| **merging 中断** | A 在 merging 阶段崩溃，重启后数据库与同步前一致 |
| **resolving 取消** | A 用户在冲突 Sheet 点击取消，双方数据库回滚 |
| **C 先 Push** | A↔B 同步 → C Push → A Push → B fast-forward 无 409 |
| **AB 先 Push** | A Push → B 遇 409 ConflictRecovery → fast-forward → C 正常同步 |
| **AB 同时 Push** | A 和 B 同时 Push，B 遇 409 → fast-forward 恢复 |
| **serverVersion 不修改** | LAN 同步前后，A._localVersion 和 B._localVersion 不变 |
| **syncStatus 红线** | LAN 同步不把 syncStatus 改为 synchronized |
| **outbox 补录** | LAN 同步后，B 的 pendingPush 记录有对应的 approved LocalSyncChange |

### 5.3 性能基准

| 指标 | 目标 |
|---|---|
| 100 条账号同步 | < 3 秒（同 WiFi） |
| 500 条账号同步 | < 10 秒 |
| 单条 payload 大小 | < 10KB（加密后） |
| 内存峰值 | < 50MB（1000 条账号） |

---

## 6. 回滚方案

### 6.1 功能开关

```dart
// lib/sync/lan_sync_feature_flag.dart
class LanSyncFeatureFlag {
  static bool get isEnabled {
    // 通过 RemoteConfig 或本地设置控制
    return _prefs.getBool('lan_sync_enabled') ?? false;
  }
}
```

### 6.2 回滚步骤

若线上发现问题：

1. 关闭功能开关 `lan_sync_enabled = false`
2. `LanPairingService` 恢复原有行为：配对成功后立即关闭 Server
3. 已完成的 LAN 同步数据不受影响（因为 commit 后就是正常本地数据）
4. 未完成的会话因 Server 关闭自然中断，内存数据丢弃

### 6.3 数据库兼容性

- 无新增表，回滚无需数据库 migration
- `settings` 中的 `lan_sync_last_$vaultId` 键可保留或忽略

---

## 7. 风险与应对

| 风险 | 概率 | 应对 |
|---|---|---|
| Host HTTP Server 在后台被系统杀死 | 高（移动端） | 限制 LAN 同步为前台手动触发；Server 被杀时 B 收到连接失败，自然中断 |
| B push 大量数据导致内存溢出 | 低 | 分页传输（每页 100 条）；大数据量时显示进度条 |
| Host 在 resolving 阶段崩溃，冲突状态丢失 | 低 | resolving 阶段的冲突数据在内存中，崩溃后丢失。用户重新触发同步即可 |
| 老版本客户端不支持新端点 | 中 | Negotiate 时检查版本号，不兼容时降级为仅配对 |

---

## 8. 实施记录

### Phase 1: 基础设施（已完成）

**新增文件：**
- `lib/sync/lan_sync_session.dart` — 会话状态模型（`LanSyncPhase`, `LanSyncHostSession`, `LanSyncSessionState`, `LanSyncResult`, `LanSyncConfig`）
- `lib/sync/lan_sync_host_handler.dart` — Host 端 HTTP 处理器（`handleStart`, `handlePush`, `handlePull`, `handleResultQuery`, `handleAbort`, `triggerMerge`, `commit`）
- `lib/sync/lan_sync_client.dart` — Requester 端客户端（`startSync`, `_pushLocalData`, `_pollUntilMerged`, `_pullMergedResult`, `_commitLocal`）
- `lib/sync/lan_sync_coordinator.dart` — 中央协调器（`startAsHost`, `startAndRunAsRequester`, `hostTriggerMerge`, `hostCommit`, `abort`）

**修改文件：**
- `lib/services/lan_pairing_service.dart` — 扩展 HTTP Server 生命周期：配对成功后不立即关闭，支持 `attachSyncHandler`/`detachSyncHandler`，新增 `discoverHost()` 方法
- `lib/services/secure_storage_service.dart` — 新增 `createApprovedLocalSyncChange()` 和 `commitLanSyncBatch()`，为 LAN sync 合并结果提供原子提交和自动 outbox 补录

**测试覆盖（34 个测试用例）：**
- `test/sync/lan_sync_session_test.dart` — 14 个测试（阶段枚举、会话状态 copyWith、配置默认值、异常常量、ID 生成）
- `test/sync/lan_sync_host_handler_test.dart` — 9 个测试（会话创建、中断、过期清理、阶段查询）
- `test/sync/lan_sync_coordinator_test.dart` — 11 个测试（Host 启动、Requester 启动、互斥锁、中止、服务附加/分离）

**静态分析：** `flutter analyze` 0 issues。
**回归测试：** 全部现有测试通过（288 个测试，1 个 pre-existing 失败与 LAN sync 无关）。

### 待完成项

- [x] `lan_sync_client_test.dart` — 基础状态测试（构造/reset/abort/互斥锁）
- [x] Host 端冲突处理 UI (`LanSyncConflictSheet` + `LanSyncConflictOverlay`) — 已集成到 HomeView
- [x] ServiceManager 集成 — `lanSyncCoordinator` getter，lock/dispose 时自动清理
- [ ] 功能开关 `LanSyncFeatureFlag` — 当前未接入 RemoteConfig
- [ ] 集成测试：A-B 双设备端到端流程

---

## 9. 已知问题（来自原 implementation-issues）

以下问题在开发过程中记录，其中 **P0 项（`createApprovedLocalSyncChange`、`commitLanSyncBatch`）已在 Phase 1 解决**，剩余问题待后续迭代：

### 问题 3：`_type` 字段干扰

`SyncPayloadCodec.encodeAccount()` 在序列化时注入 `_type: 'account'` 字段。`AccountItem.fromJson()` 需安全忽略未知字段，否则 LAN 同步反序列化可能失败。

**当前状态**：已在 `_payloadToItem` 中删除 `_type` 后调用 `fromJson`。

### 问题 5：TOTP 冲突日志

`TotpCredentialMergeEngine.merge()` 返回单个 `TotpCredential`（非 `MergeResult`），导致 `LanSyncHostHandler` 无法收集 TOTP 冲突日志。

**当前状态**：采用方案 B，暂不收集 TOTP 冲突日志（字段少、冲突概率低），后续统一 MergeResult 类型。

### 问题 6：全量传输优化

`handlePull()` 当前加载 Host 全部数据推给 B。若 Host 有 1000 条记录、B 只修改 1 条，仍传输 1000 条。

**当前状态**：全量传输（简化实现），后续优化为差集传输。

---

*文档结束*
