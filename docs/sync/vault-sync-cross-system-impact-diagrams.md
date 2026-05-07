# Vault Sync Cross-System Impact Diagrams

> 本文档绘制密钥同步各子系统**互相影响**下的边界状态流程图。
> 覆盖：身份损坏级联、锁定事件清理、Vault 导入原子替换、同步失败跨系统恢复、配对-同步-数据四系统交互。

---

## 1. Identity Corruption Cascade

当 `IdentityService` 检测到密钥不完整或格式非法时，级联阻断所有依赖身份的系统。

```mermaid
flowchart TD
    subgraph IDENTITY["IdentityService"]
        INIT["initialize()<br/>allowGenerate=false"]
        CHECK1{"populatedKeys<br/>empty?"}
        CHECK2{"partial keys?"}
        CHECK3{"regex/format<br/>invalid?"}
        THROW["throw<br/>IdentityCorruptedException"]
    end

    subgraph UNLOCK["ServiceManager<br/>Unlock Flow"]
        UNLOCK_TRY["_completeUnlock()"]
        CATCH["catch<br/>IdentityCorruptedException"]
        SM_ERR["state = error"]
        UNLOCK_RET["return<br/>UnlockResult.error"]
    end

    subgraph SYNC["SyncService"]
        SYNC_TRY["syncNow() / connect()"]
        SYNC_GATE{"hasIdentity?"}
        SYNC_ERR["state = authError"]
        SYNC_RET["return<br/>SyncResult.failure"]
    end

    subgraph PAIRING["VaultPairingService<br/>LAN Pairing"]
        PAIR_TRY["startHosting()<br/>claimTransferCode()"]
        PAIR_GATE{"hasIdentity?"}
        PAIR_ERR["throw<br/>StateError / auth blocked"]
    end

    INIT --> CHECK1
    CHECK1 -- yes --> THROW
    CHECK1 -- no --> CHECK2
    CHECK2 -- yes --> THROW
    CHECK2 -- no --> CHECK3
    CHECK3 -- yes --> THROW
    CHECK3 -- no --> OK["Identity OK<br/>hasIdentity=true"]

    THROW --> CATCH
    CATCH --> SM_ERR
    SM_ERR --> UNLOCK_RET

    OK --> SYNC_GATE
    OK --> PAIR_GATE

    SYNC_GATE -- no --> SYNC_ERR
    SYNC_GATE -- yes --> SYNC_RUN["Sync proceeds"]

    PAIR_GATE -- no --> PAIR_ERR
    PAIR_GATE -- yes --> PAIR_RUN["Pairing proceeds"]

    UNLOCK_TRY -.->|"triggers"| INIT
    SYNC_TRY -.->|"reads"| SYNC_GATE
    PAIR_TRY -.->|"reads"| PAIR_GATE

    style THROW fill:#f66,stroke:#333
    style SM_ERR fill:#f66,stroke:#333
    style SYNC_ERR fill:#f66,stroke:#333
    style PAIR_ERR fill:#f66,stroke:#333
```

### 级联规则

| 源系统异常 | 直接影响 | 间接影响 | 恢复路径 |
|---|---|---|---|
| `IdentityCorruptedException` | Unlock 失败，App 卡在 error 状态 | Sync 无法连接、Pairing 无法启动 | 用户必须 Reset Application 或使用 Recovery Code 重建身份 |
| `hasIdentity == false` | Sync 进入 `authError` | 所有 pull/push 被拒绝 | 解锁成功后自动恢复 |
| `hasIdentity == false` | Pairing 服务抛出 `StateError` | 新设备无法加入 vault | 解锁成功后自动恢复 |

---

## 2. Lock Event Cascade

当用户手动锁定或自动锁触发时，多个系统需要同步清理内存中的敏感状态。

```mermaid
flowchart TD
    subgraph TRIGGER["Lock Trigger"]
        MANUAL["user.lock()"]
        AUTO["autoLock fires"]
    end

    subgraph SM["ServiceManager"]
        CLOSE["_closeStorageForLock()<br/>关闭运行时数据库"]
        SYNC_DISC["_syncService.disconnect()"]
        LAN_STOP["_lanPairingService.stopHosting()"]
        KEYS_CLR["_vaultPairingJoinKeysByRequestId.clear()<br/>清除远程配对临时密钥"]
        RESET["_syncService.reset()"]
        STATE["_updateState(locked)"]
    end

    subgraph SYNC["SyncService"]
        SYNC_OFF["state = offline"]
        MARKER_CLR["recovery marker 保留<br/>（磁盘持久化）"]
    end

    subgraph LAN["LAN Pairing Host"]
        UDP_CLOSE["关闭 UDP sockets"]
        HTTP_CLOSE["关闭 HTTP server"]
        BUNDLE_CLR["清除 hosted bundle"]
    end

    subgraph REMOTE["Remote Pairing Client"]
        KEY_LOST["内存中的 ephemeral keypair 丢失"]
        FETCH_FAIL["后续 fetchBundle()<br/>'Pairing key expired locally'"]
    end

    MANUAL --> CLOSE
    AUTO --> CLOSE

    CLOSE --> SYNC_DISC
    SYNC_DISC --> SYNC_OFF
    SYNC_DISC --> MARKER_CLR
    SYNC_OFF --> LAN_STOP
    SYNC_OFF --> KEYS_CLR
    SYNC_OFF --> RESET

    LAN_STOP --> UDP_CLOSE
    LAN_STOP --> HTTP_CLOSE
    LAN_STOP --> BUNDLE_CLR

    KEYS_CLR --> KEY_LOST
    KEY_LOST --> FETCH_FAIL

    RESET --> STATE

    style CLOSE fill:#fa0,stroke:#333
    style KEYS_CLR fill:#fa0,stroke:#333
    style KEY_LOST fill:#f66,stroke:#333
```

### 关键级联规则

| 清理动作 | 影响系统 | 后果 |
|---|---|---|
| `_vaultPairingJoinKeysByRequestId.clear()` | Remote Pairing Client | 已加入会话但未取 bundle 的设备，锁定后永远丢失解密能力，必须重新加入 |
| `_lanPairingService.stopHosting()` | LAN Pairing Host | 正在等待 claim 的主机会立即停止广播，新设备无法发现 |
| `_syncService.disconnect()` | SyncService | 状态回退到 `offline`，但**磁盘上的 recovery marker 不会被清除**，下次解锁可恢复 |
| `_closeStorageForLock()` | SecureStorageService | 运行时数据库句柄释放，再次解锁需重新解密 |

---

## 3. Vault Import Atomic Swap & Rollback

Vault 导入涉及身份、数据、同步状态三个系统的原子替换；任何一步失败都会触发回滚。

```mermaid
flowchart TD
    subgraph PRE["Pre-Import Checks"]
        ROUTE["任意导入路由<br/>LAN / Remote / Recovery Code"]
        PREVIEW["构建 VaultImportPreview<br/>identity + dumpPlan"]
        VALIDATE["验证 dump 可解密"]
        CLEAN{"_hasLocalVaultDataForImport?"}
        FORCE{"forceOverwrite?"}
    end

    subgraph PHASE1["Phase 1: Disconnect"]
        DISC["_syncService.disconnect()"]
    end

    subgraph PHASE2["Phase 2: Apply Identity"]
        APPLY_ID["写入新 identity<br/>vaultId / keys / token"]
        STORE_OLD["内存中保留<br/>previousIdentity"]
    end

    subgraph PHASE3["Phase 3: Import Data"]
        HAS_DUMP{"dumpPlan != null<br/>&& hasData?"}
        IMPORT["replaceAllDataForImport()<br/>写入账号+模板"]
        CLEAR["clearAllData()"]
        NO_DATA["无数据，跳过"]
    end

    subgraph PHASE4["Phase 4: Rebuild Sync"]
        WRITE_URL["写入 syncServerUrl"]
        REINIT["_syncService.initialize()<br/>localVersion=0, dirty=false"]
        OUTBOX_CLR["清空 outbox / conflict_log"]
    end

    subgraph ERROR["Error Handler"]
        ERR{"Import 任何步骤失败?"}
        ROLLBACK["恢复 previousIdentity"]
        THROW["throw VaultImportException"]
        LEAVE_DIRTY["Identity 已换但数据失败<br/>系统处于不一致状态"]
    end

    ROUTE --> PREVIEW
    PREVIEW --> VALIDATE
    VALIDATE --> CLEAN
    CLEAN -- no --> DISC
    CLEAN -- yes --> FORCE
    FORCE -- no --> THROW_PRE["throw VaultImportPreconditionException"]
    FORCE -- yes --> DISC

    DISC --> APPLY_ID
    APPLY_ID --> STORE_OLD
    STORE_OLD --> HAS_DUMP

    HAS_DUMP -- yes --> IMPORT
    HAS_DUMP -- no --> CHECK_LOCAL{"hadLocalData?"}
    CHECK_LOCAL -- yes --> CLEAR
    CHECK_LOCAL -- no --> NO_DATA

    IMPORT --> WRITE_URL
    CLEAR --> WRITE_URL
    NO_DATA --> WRITE_URL
    WRITE_URL --> REINIT
    REINIT --> OUTBOX_CLR
    OUTBOX_CLR --> DONE["Import 完成<br/>state = unlocked"]

    IMPORT -- error --> ERR
    CLEAR -- error --> ERR
    REINIT -- error --> ERR
    ERR -- yes --> ROLLBACK
    ROLLBACK --> THROW
    ERR -- no --> DONE

    THROW -.->|"用户可见"| LEAVE_DIRTY

    style APPLY_ID fill:#9f9,stroke:#333
    style ROLLBACK fill:#f66,stroke:#333
    style THROW fill:#f66,stroke:#333
    style LEAVE_DIRTY fill:#f66,stroke:#333
    style OUTBOX_CLR fill:#fa0,stroke:#333
```

### 跨系统状态重建规则

| 系统 | 导入前状态 | 导入后状态 | 回滚时行为 |
|---|---|---|---|
| **Identity** | 旧 vaultId/deviceId/keys | 新 vaultId，**保留旧 deviceId**，新 keys/token | 恢复 previousIdentity（全部旧值） |
| **Account Data** | 本地账号+模板 | 被 dump 数据完全替换，或 `clearAllData()` 清空 | 无法回滚数据（已覆盖），只能回滚身份 |
| **Sync Outbox** | 可能有 pendingReview/pendingPush | **强制清空**，不继承源状态 | N/A |
| **Conflict Log** | 可能有未解决冲突 | **强制清空** | N/A |
| **Sync Metadata** | `localVersion > 0`, `isDirty = true/false` | `localVersion = 0`, `dirty = false`（由 `SyncService.initialize()` 重建） | N/A |
| **Sync Server URL** | 旧 URL 或无 | 新 URL（如果 dump 携带） | 不自动恢复旧 URL |

---

## 4. Sync Conflict Recovery Cross-System Impact

同步冲突不仅改变 SyncService 状态，还会触发数据层修改、UI 状态变化和潜在的身份/配对动作。

```mermaid
flowchart TD
    subgraph PUSH["Push Phase"]
        PUSH_REQ["POST /vaults/{id}/sync<br/>with local changes"]
        RESP{"Server Response"}
        OK["200 OK"]
        CONFLICT["409 Conflict<br/>+ conflict_type"]
    end

    subgraph CONFLICT_TYPES["Conflict Type Branch"]
        CT1["remote_missing"]
        CT2["stale_base_version"]
        CT3["concurrent_edit"]
        CT4["concurrent_delete"]
        CT5["invalid_payload"]
    end

    subgraph RECOVERY["Recovery Actions"]
        R1["生成 conflict inbox 记录<br/>用户选择覆盖远端"]
        R2["重新 pull 快照<br/>CRDT merge"]
        R3["字段级 merge<br/>冲突字段进 inbox"]
        R4["tombstone 优先<br/>远端删除胜出"]
        R5["protocolError<br/>payload 格式/密钥问题"]
    end

    subgraph DATA["Data Layer Impact"]
        D1["账号 syncStatus 保持 pendingPush"]
        D2["账号 syncStatus = synchronized<br/>dataHlc 更新"]
        D3["conflict_log 写入字段冲突"]
        D4["本地账号被标记删除<br/>或恢复远端删除"]
        D5["不变，需人工检查 identity/keys"]
    end

    subgraph UI["UI State Impact"]
        U1["ConflictInboxView 显示<br/>remote missing 行项"]
        U2["Home 显示最新合并数据"]
        U3["ConflictInboxView 显示<br/>字段冲突卡片"]
        U4["SnackBar: '已在其他设备删除'"]
        U5["SyncSettingsView 显示<br/>protocolError + 诊断"]
    end

    subgraph RETRY["Retry Loop"]
        LOOP{"retries < 3?"}
        BACKOFF["delay 500ms * retries"]
        MAX["retries >= 3<br/>SyncState.protocolError"]
    end

    PUSH_REQ --> RESP
    RESP --> OK
    RESP --> CONFLICT

    CONFLICT --> CT1
    CONFLICT --> CT2
    CONFLICT --> CT3
    CONFLICT --> CT4
    CONFLICT --> CT5

    CT1 --> R1 --> D1 --> U1
    CT2 --> R2 --> D2 --> U2
    CT3 --> R3 --> D3 --> U3
    CT4 --> R4 --> D4 --> U4
    CT5 --> R5 --> D5 --> U5

    R2 --> LOOP
    R3 --> LOOP
    LOOP -- yes --> BACKOFF --> PUSH_REQ
    LOOP -- no --> MAX

    MAX --> USER_ACT["用户手动触发:<br/>1. 重新 sync<br/>2. 检查 server URL<br/>3. 重新配对（若密钥损坏）<br/>4. Reset Application"]

    style CONFLICT fill:#fa0,stroke:#333
    style MAX fill:#f66,stroke:#333
    style USER_ACT fill:#9cf,stroke:#333
```

### 冲突类型到跨系统影响矩阵

| conflict_type | SyncService | Data Layer | UI | 可能触发的其他系统动作 |
|---|---|---|---|---|
| `remote_missing` | `conflictRecovery` → 重试 | `syncStatus = pendingPush` 保留 | ConflictInbox 显示 | 用户选择覆盖 → 再次 push |
| `stale_base_version` | `conflictRecovery` → 重 pull | CRDT merge 覆盖本地数据 | Home 刷新显示 | `localVersion` 对齐远端 |
| `concurrent_edit` | `conflictRecovery` → 重 pull | conflict_log 写入差异字段 | ConflictInbox 显示字段冲突 | 用户解决后再次 push |
| `concurrent_delete` | `conflictRecovery` → tombstone 优先 | 本地账号删除 或 恢复远端 | SnackBar 提示 | 无自动重试，需用户确认 |
| `invalid_payload` | `protocolError`（不重试） | 无数据变更 | 诊断区显示 payload 被拒绝 | 检查 `vaultApiToken`、identity 完整性，可能需要重新配对 |

---

## 5. Pairing-Sync-Data Four-System Interaction

新设备通过配对加入 vault 时，四个系统（Pairing、Identity、Sync、Data）的交互全貌。

```mermaid
sequenceDiagram
    autonumber
    participant OLD as Existing Device
    participant S as Pairing Server
    participant NEW as New Device
    participant ID as IdentityService
    participant DB as SecureStorageService
    participant SYNC as SyncService

    Note over OLD,NEW: LAN Pairing 场景（Remote Pairing 逻辑类似，只是经 Server 转发）

    OLD->>OLD: startHosting(transferCode)
    OLD->>OLD: 广播 UDP endpoint

    NEW->>NEW: 生成 ephemeral X25519 keypair
    NEW->>OLD: UDP 发现 + POST claim(code, pubkey)
    OLD->>OLD: 验证 code，加密 transferCode
    OLD->>NEW: 200 OK + wrapped_transfer_code

    NEW->>NEW: 解密获得 transferCode
    NEW->>S: GET /vaults/{vaultId}/sync?since=0<br/>X-Vault-Token: (from transferCode)
    S->>NEW: 200 + 全量快照 + x-vault-token

    NEW->>ID: importVaultLinkCode(code)<br/>或 importSecureVaultLinkCode
    ID->>DB: 写入新 identity<br/>vaultId=旧, deviceId=新, keys=旧

    alt 设备非干净（有本地数据）
        NEW->>NEW: throw VaultImportPreconditionException
        Note right of NEW: 用户必须确认覆盖
        NEW->>DB: clearAllData()
    end

    NEW->>DB: replaceAllDataForImport(快照数据)
    DB->>DB: syncStatus 保留源值<br/>outbox/conflict_log 清空

    NEW->>SYNC: initialize()<br/>localVersion=远端version, dirty=false
    SYNC->>SYNC: connect()
    SYNC->>S: 开始正常 pull/push 循环

    Note over NEW: 首次同步后，新设备拥有：<br/>- 与旧设备相同的 vaultId/keys/token<br/>- 独立的 deviceId<br/>- 全量数据副本<br/>- 空的 outbox（需重新审阅）
```

---

## 6. Server Reset Detection Cascade

当服务端 vault 被重置（generation 突变）时，客户端数据层和同步层的连锁反应。

```mermaid
flowchart TD
    subgraph DETECT["Detection in _applyRemoteChanges"]
        PULL["Pull response"]
        CHECK{"_serverGeneration != 0<br/>&& serverGeneration != _serverGeneration?"}
    end

    subgraph SYNC["SyncService Impact"]
        HANDLE["_handleServerReset()"]
        V0["_localVersion = 0"]
        CLR["clear local_sync_changes"]
        MARK["mark ALL synchronized<br/>items as pendingPush"]
        STATE["state = pulling<br/>(继续当前 sync 流程)"]
    end

    subgraph DATA["Data Layer Impact"]
        ACCOUNTS["所有账号：<br/>syncStatus = pendingPush"]
        TEMPLATES["所有模板：<br/>syncStatus = pendingPush"]
        TOTP["所有 TOTP：<br/>syncStatus = pendingPush"]
    end

    subgraph UI["UI Impact"]
        HOME["首页：大量账号显示<br/>'待同步' 角标"]
        REVIEW["LocalSyncChangesView：<br/>显示大量 pendingPush"]
        WARN["可能触发审阅提醒"]
    end

    subgraph PUSH_AFTER["Subsequent Push"]
        PUSH_LOOP["下一个 sync cycle<br/>进入 push phase"]
        FULL["全量推送所有数据<br/>到全新 server vault"]
        RECOVER["serverVersion 重建<br/>generation 重新对齐"]
    end

    PULL --> CHECK
    CHECK -- yes --> HANDLE
    CHECK -- no --> NORMAL["正常 apply changes"]

    HANDLE --> V0
    V0 --> CLR
    CLR --> MARK
    MARK --> STATE

    MARK --> ACCOUNTS
    MARK --> TEMPLATES
    MARK --> TOTP

    ACCOUNTS --> HOME
    TEMPLATES --> HOME
    ACCOUNTS --> REVIEW
    REVIEW --> WARN

    STATE --> PUSH_LOOP
    PUSH_LOOP --> FULL
    FULL --> RECOVER

    style HANDLE fill:#fa0,stroke:#333
    style MARK fill:#fa0,stroke:#333
    style FULL fill:#9cf,stroke:#333
```

### 级联规则

| 触发条件 | SyncService | Data Layer | UI | 恢复路径 |
|---|---|---|---|---|
| `serverGeneration` 突变 | `_localVersion = 0` | 所有 item `syncStatus → pendingPush` | 大量待同步提示 | 下一个 sync cycle 自动全量 push，无需用户操作 |
| 清空 `local_sync_changes` | outbox 丢失 | 丢失的 pendingReview 不再可见 | 已审阅但尚未 push 的变更消失 | 用户需重新编辑才能产生新的 outbox |
| `dirty = false` | 下次 sync 从 0 开始 pull | 无直接数据影响 | 无 | 服务端返回全量数据，本地 CRDT merge |

---

## 7. Application Reset Nuclear Option

用户选择"重置应用"时，所有子系统的终极清理路径。

```mermaid
flowchart TD
    subgraph TRIGGER["User Action"]
        RESET_BTN["用户点击<br/>Reset Application"]
    end

    subgraph SM["ServiceManager.resetApplication()"]
        LOCK["lock()<br/>触发 Lock Event Cascade"]
        CRYPTO_LOGOUT["_cryptoService.logout()<br/>清除内存主密钥"]
        STORAGE_CLOSE["_secureStorageService.close()<br/>关闭数据库"]
        DEL_DB["deleteDatabaseFile()<br/>删除 .enc 主文件"]
        DEL_SECURE["FlutterSecureStorage.deleteAll()<br/>删除 identity / token / master key / biometric"]
        DEL_PREFS["SharedPreferences.clear()<br/>删除 sync URL / dirty / version / recovery marker"]
    end

    subgraph EFFECTS["Cross-System Final State"]
        ID["IdentityService:<br/>hasIdentity = false"]
        SYNC["SyncService:<br/>offline, localVersion=0"]
        LAN["LAN Pairing:<br/>stopped"]
        PAIR["Remote Pairing:<br/>keys cleared"]
        CRYPTO["CryptoService:<br/>master key erased"]
        DB_STATE["Database:<br/>文件已删除，下次启动创建空库"]
    end

    subgraph NEXT["Next Launch"]
        LAUNCH["App restart"]
        FIRST_RUN["视为首次运行<br/>生成全新 vault identity"]
    end

    RESET_BTN --> LOCK
    LOCK --> CRYPTO_LOGOUT
    CRYPTO_LOGOUT --> STORAGE_CLOSE
    STORAGE_CLOSE --> DEL_DB
    DEL_DB --> DEL_SECURE
    DEL_SECURE --> DEL_PREFS

    DEL_PREFS --> ID
    DEL_PREFS --> SYNC
    DEL_PREFS --> LAN
    DEL_PREFS --> PAIR
    DEL_PREFS --> CRYPTO
    DEL_PREFS --> DB_STATE

    ID --> LAUNCH
    SYNC --> LAUNCH
    DB_STATE --> LAUNCH
    LAUNCH --> FIRST_RUN

    style RESET_BTN fill:#f66,stroke:#333
    style DEL_SECURE fill:#f66,stroke:#333
    style DEL_DB fill:#f66,stroke:#333
    style FIRST_RUN fill:#9f9,stroke:#333
```

---

## 附录：跨系统影响速查表

| 触发事件 | Identity | Sync | Pairing | Data | 恢复方式 |
|---|---|---|---|---|---|
| **Identity Corrupted** | ❌ 损坏 | ❌ authError | ❌ 无法启动 | ➖ 不影响 | Recovery Code / Reset |
| **Lock / Auto-Lock** | ✅ 保留（磁盘） | ➖ offline | ❌ Host 停止 / Key 丢失 | ➖ 已加密落盘 | 重新解锁 |
| **Vault Import 成功** | ✅ 替换（保留 deviceId） | ✅ 重建（version=0） | ➖ 不影响 | ✅ 替换/清空 | 自动进入新 vault |
| **Vault Import 失败** | ⚠️ 回滚到旧 identity | ➖ 断开状态 | ➖ 不影响 | ⚠️ 可能已覆盖 | 检查 dump / 重试 |
| **Server Generation Mismatch** | ➖ 不影响 | ⚠️ localVersion=0 | ➖ 不影响 | ⚠️ 全量 pendingPush | 自动全量 push 恢复 |
| **Max Conflict Retries** | ➖ 不影响 | ❌ protocolError | ➖ 不影响 | ➖ 不影响 | 用户手动 sync / 检查配置 |
| **App Reset** | ❌ 删除 | ❌ 重置 | ❌ 停止 | ❌ 删除 | 重新初始化 |

图例：✅ 正常变更 | ❌ 功能阻断 | ⚠️ 状态异常 | ➖ 无直接影响

---

*文档版本：基于 2026-05-07 代码基线绘制。*
