# Vault Sync Boundary State Diagrams

> 本文档使用 Mermaid 绘制密钥同步（vault pairing / sync / identity）各子系统的边界状态与决策分支。
> 覆盖范围：Identity 生命周期、LAN/远程配对、同步状态机、导入/导出安全边界、解锁鉴权。

---

## 1. Identity Initialization Boundary

```mermaid
flowchart TD
    START([identityService.initialize]) --> CHECK_ALLOW{allowGenerateVaultIdentity?}
    CHECK_ALLOW -- No --> CHECK_POPULATED{populatedIdentityKeys empty?}
    CHECK_ALLOW -- Yes --> CHECK_POPULATED

    CHECK_POPULATED -- empty --> GEN_NEW[Generate new vaultId + deviceId]
    CHECK_POPULATED -- not empty --> CHECK_PARTIAL{length == expected?}

    CHECK_PARTIAL -- No --> THROW_PARTIAL["throw IdentityCorruptedException<br/>missingKeys: [...]"]
    CHECK_PARTIAL -- Yes --> VALIDATE_FORMAT{Regex match?<br/>vaultId / privateKey /<br/>symmetricKey / deviceId}

    VALIDATE_FORMAT -- Fail --> THROW_INVALID["throw IdentityCorruptedException<br/>invalidKeys: [...]"]
    VALIDATE_FORMAT -- Pass --> CHECK_DEVICE{_isValidDeviceId?}

    CHECK_DEVICE -- Fail --> THROW_INVALID
    CHECK_DEVICE -- Pass --> IDENTITY_READY[Identity ready]

    GEN_NEW --> IDENTITY_READY

    THROW_PARTIAL --> SM_ERROR["ServiceManager.state = error<br/>Message: identity missing/damaged"]
    THROW_INVALID --> SM_ERROR
```

### Key Branches

| Condition | Outcome |
|---|---|
| `allowGenerateVaultIdentity=false` + no stored keys | `IdentityCorruptedException` |
| Partial keys stored | `IdentityCorruptedException(missingKeys)` |
| Regex format mismatch | `IdentityCorruptedException(invalidKeys)` |
| Legacy 8-char hex `deviceId` | Accepted via `_legacyDeviceIdPattern` |
| All valid | `hasIdentity == true` |

---

## 2. LAN Pairing Host Lifecycle

```mermaid
flowchart TD
    START([startHosting<br/>transferCode, ttl=3min]) --> BIND_HTTP[Bind HTTP server<br/>anyIPv4:0]
    BIND_HTTP --> BIND_UDP[Bind UDP sockets<br/>per interface]
    BIND_UDP --> BROADCAST[Broadcast endpoint<br/>every 700ms]
    BROADCAST --> SET_TIMER[Set expiry timer]
    SET_TIMER --> WAIT["Session active<br/>(expiresAt)"]

    WAIT --> REQ{Incoming HTTP request}
    REQ -- Wrong method/path --> R404["404 Not Found"]
    REQ -- Session expired / no code --> R410["410 Gone"] --> CLEAR["clearHostedBundleState()<br/>stopHosting()"]
    REQ -- Already claimed --> R409["409 Conflict"]
    REQ -- Wrong pairing code --> R403["403 Forbidden"] --> INC_FAIL["_hostFailedClaims++"]
    REQ -- Missing requester_public_key --> R400["400 Bad Request"]
    REQ -- Correct code + pubkey --> R200["200 OK<br/>wrapped_transfer_code"] --> CLAIMED["_hostClaimed=true<br/>schedule stopHosting(250ms)"]

    INC_FAIL --> FAIL_CHECK{failedClaims >= 5?}
    FAIL_CHECK -- Yes --> CLEAR
    FAIL_CHECK -- No --> WAIT

    CLAIMED --> STOP([stopHosting])
    CLEAR --> STOP
    STOP --> CANCEL["Cancel timers<br/>Close UDP sockets<br/>Close HTTP server"]
```

---

## 3. LAN Pairing Client Claim Flow

```mermaid
flowchart TD
    START([claimTransferCodeByCode]) --> CHECK_WEB{Platform.isWeb?}
    CHECK_WEB -- Yes --> THROW_WEB["throw LanPairingServiceException<br/>'Not supported on web builds.'"]
    CHECK_WEB -- No --> GEN_EPHEMERAL[Generate ephemeral<br/>X25519 keypair]
    GEN_EPHEMERAL --> LISTEN_UDP[Listen UDP discovery<br/>on _discoveryPort]
    LISTEN_UDP --> WAIT_AD["Wait for broadcast<br/>advertisements"]

    WAIT_AD --> GOT_AD{Received endpoint?}
    GOT_AD -- Yes --> DEDUP{Deduplicate<br/>address:port}
    GOT_AD -- Timeout --> TIMEOUT_CHECK{sawPairingHost?}

    TIMEOUT_CHECK -- Yes --> ERR_NO_MATCH["Error: 'Pairing code did not match<br/>any LAN host.'"]
    TIMEOUT_CHECK -- No --> ERR_NO_HOST["Error: 'No LAN pairing host<br/>found on this network.'"]

    DEDUP --> SEND_CLAIM[POST claim to endpoint]
    SEND_CLAIM --> CLAIM_RESP{Response status}

    CLAIM_RESP -- 200 --> DECRYPT[Decrypt<br/>wrapped_transfer_code] --> SUCCESS["Return transfer code"]
    CLAIM_RESP -- 403/409/410 --> THROW_STATUS["throw LanPairingServiceException"]
    CLAIM_RESP -- Other --> SWALLOW["Swallow failure<br/>(try next endpoint)"]

    SWALLOW --> WAIT_AD
```

---

## 4. Remote Pairing (Server-Assisted) Flow

```mermaid
flowchart TD
    START([Remote Pairing]) --> BRANCH{Role}

    BRANCH -- Initiator --> CREATE["POST /pairing/sessions<br/>Create session"] --> GET_CODE["Obtain 8-char pairing code"]
    GET_CODE --> WAIT_APPROVAL["Wait for existing device<br/>to approve"]

    BRANCH -- Joiner --> JOIN["POST /pairing/sessions/join<br/>with ephemeral pubkey"] --> STORE_KEY["Store ephemeral keypair<br/>_vaultPairingJoinKeysByRequestId"]
    STORE_KEY --> POLL["Poll GET /pairing/sessions/{id}/bundle"]

    POLL --> STATUS{HTTP status}
    STATUS -- 200 --> FETCH["Bundle available"] --> DECRYPT["Decrypt with stored<br/>ephemeral private key"] --> IMPORT["Import vault identity + dump"]
    STATUS -- 202 --> WAIT_APPROVAL
    STATUS -- 403 --> REJECTED["Rejected"]
    STATUS -- 410 --> EXPIRED["Expired / Gone"]

    WAIT_APPROVAL --> APPROVE["Existing device approves<br/>POST /pairing/sessions/{id}/approve<br/>with encrypted bundle"] --> BUNDLE_READY["Bundle encrypted with<br/>joiner ephemeral pubkey"]

    BUNDLE_READY --> FETCH

    IMPORT --> CHECK_LOCK{App locked<br/>before fetch?}
    CHECK_LOCK -- Yes --> THROW_EXPIRED["throw VaultPairingServiceException<br/>'Pairing key expired locally.'"]
    CHECK_LOCK -- No --> DONE["Pairing complete"]
```

---

## 5. Sync State Machine with Boundary States

```mermaid
stateDiagram-v2
    [*] --> offline : App start / disconnect()
    offline --> connecting : connect()
    connecting --> pulling : Network OK, start pull
    connecting --> networkUnreachable : SocketException / Timeout
    connecting --> authError : !hasIdentity

    pulling --> idle : No changes (304) / applied
    pulling --> conflictRecovery : ConflictException on apply
    pulling --> pushing : Changes applied, pendingPush exists
    pulling --> networkUnreachable : Network failure
    pulling --> serverError : HTTP >= 500
    pulling --> protocolError : Generation mismatch / payload invalid

    pushing --> idle : Push success
    pushing --> conflictRecovery : ConflictException on push
    pushing --> networkUnreachable : Network failure
    pushing --> serverError : HTTP >= 500
    pushing --> protocolError : invalid_payload / protocol error

    conflictRecovery --> pulling : Retry pull+push (backoff)
    conflictRecovery --> protocolError : Max retries exceeded (3x)

    idle --> pushing : Local changes approved
    idle --> pulling : Periodic sync / manual sync
    idle --> offline : disconnect()

    networkUnreachable --> connecting : Retry after delay
    serverError --> connecting : Retry after delay
    protocolError --> offline : User intervention required
    authError --> offline : User intervention required
```

### Global Error Handler Mapping

| Exception | SyncState | User-Facing Message |
|---|---|---|
| `SocketException` / `TimeoutException` | `networkUnreachable` | "Cannot reach sync server..." |
| `ClientException` wrapping `SocketException` | `networkUnreachable` | "Network unreachable..." |
| `ClientException` cleartext blocked | `protocolError` | "Cleartext HTTP blocked..." |
| `SyncHttpException` (status >= 500) | `serverError` | `serverMessage` or generic |
| `SyncHttpException` (generation_mismatch) | `protocolError` | "Server vault has been reset..." |
| `SyncHttpException` (invalid_payload) | `protocolError` | "Sync payload rejected..." |
| `SyncProtocolException` | `protocolError` | "Sync protocol invalid..." |
| `SyncPayloadException` | `protocolError` | "Sync payload invalid..." |

---

## 6. Vault Import Safety Boundary

```mermaid
flowchart TD
    START([Import vault<br/>from any route]) --> PREVIEW["_importVaultIdentityPreview<br/>(preview, forceOverwrite)"]
    PREVIEW --> VALIDATE["_validateIncomingVaultDump(preview)"]
    VALIDATE -- Invalid --> THROW_INVALID["throw VaultImportException"]
    VALIDATE -- Valid --> CHECK_CLEAN{"_hasLocalVaultDataForImport()?"}

    CHECK_CLEAN -- No --> DISCONNECT["disconnect sync"]
    CHECK_CLEAN -- Yes --> CHECK_FORCE{forceOverwrite?}

    CHECK_FORCE -- No --> THROW_OVERWRITE["throw VaultImportPreconditionException<br/>'Confirm overwrite...'"]
    CHECK_FORCE -- Yes --> DISCONNECT

    DISCONNECT --> APPLY_ID["Apply identity preview<br/>(vaultId, keys, token)"]
    APPLY_ID --> HAS_DUMP{dumpPlan != null<br/>&& hasData?}

    HAS_DUMP -- Yes --> IMPORT_DUMP["importValidatedVaultDump(plan)"]
    HAS_DUMP -- No --> HAD_LOCAL{hadLocalData?}

    HAD_LOCAL -- Yes --> CLEAR_ALL["clearAllData()"]
    HAD_LOCAL -- No --> WRITE_URL["Write syncServerUrl<br/>if present"]

    IMPORT_DUMP --> WRITE_URL
    CLEAR_ALL --> WRITE_URL
    WRITE_URL --> REINIT["Reinitialize syncService"]

    IMPORT_DUMP -- Any error --> ROLLBACK["Rollback to previousIdentity"]
    ROLLBACK --> THROW_IMPORT["throw VaultImportException"]

    REINIT --> DONE([Import complete])
```

### _hasLocalVaultDataForImport Check

Returns `true` if **any** of:
- `loadAccounts(includeDeleted:true).isNotEmpty`
- `loadCustomTemplates(includeDeleted:true).isNotEmpty`
- `_syncService.localVersion > 0`
- `_syncService.isDirty`

---

## 7. Unlock Flow with Identity Boundary

```mermaid
flowchart TD
    START([Unlock with password]) --> UNLOCK_DB["_secureStorageService.unlockDatabase(password)"]
    UNLOCK_DB --> UNLOCK_OK{Decryption success?}
    UNLOCK_OK -- No --> RETURN_WRONG["return UnlockResult.wrongPassword"]

    UNLOCK_OK -- Yes --> CHECK_DB{"Database file exists?"}
    CHECK_DB -- No --> INIT_ID["identity.initialize<br/>allowGenerate=true"]
    CHECK_DB -- Yes --> INIT_ID_EXISTING["identity.initialize<br/>allowGenerate=false"]

    INIT_ID_EXISTING --> IDENTITY_OK{Success?}
    IDENTITY_OK -- No / Corrupted --> SM_ERROR["ServiceManager.state = error<br/>UnlockResult.error"]

    INIT_ID --> INIT_CRYPTO["_cryptoService.initMasterKey(password)"]
    IDENTITY_OK -- Yes --> INIT_CRYPTO
    INIT_CRYPTO --> CRYPTO_OK{Success?}
    CRYPTO_OK -- No --> RETURN_WRONG

    CRYPTO_OK -- Yes --> INIT_STORAGE["_secureStorageService.initialize(deviceId)"]
    INIT_STORAGE --> INIT_SYNC["_syncService.initialize()"]
    INIT_SYNC --> ENSURE_OUTBOX["ensurePendingSyncOutboxEntries(vaultId)"]
    ENSURE_OUTBOX --> CONNECT["_syncService.connect() (unawaited)"]
    CONNECT --> STATE_UNLOCKED["_updateState(unlocked)"]
    STATE_UNLOCKED --> RETURN_SUCCESS["return UnlockResult.success"]
```

---

## 8. Sync Payload Codec Boundary

```mermaid
flowchart TD
    START([decodePayload]) --> CHECK_PREFIX{Starts with<br/>'sroy-sync:'?}
    CHECK_PREFIX -- No --> THROW_NOT["throw SyncPayloadException<br/>'Not a SecretRoy envelope.'"]
    CHECK_PREFIX -- Yes --> PARSE_JSON{Valid JSON?}

    PARSE_JSON -- No --> THROW_JSON["throw SyncPayloadException<br/>'Not valid envelope JSON.'"]
    PARSE_JSON -- Yes --> CHECK_VER{Version OK?}

    CHECK_VER -- No --> THROW_VER["throw SyncPayloadException<br/>'Unsupported payload version.'"]
    CHECK_VER -- Yes --> CHECK_ALG{Algorithm OK?}

    CHECK_ALG -- No --> THROW_ALG["throw SyncPayloadException<br/>'Unsupported payload algorithm.'"]
    CHECK_ALG -- Yes --> CHECK_VAULT{vaultId present?}

    CHECK_VAULT -- No --> THROW_VAULT_MISS["throw SyncPayloadException<br/>'Payload vault id missing.'"]
    CHECK_VAULT -- Yes --> CHECK_VAULT_MATCH{vaultId == current?}

    CHECK_VAULT_MATCH -- No --> THROW_VAULT_DIFF["throw SyncPayloadException<br/>'Payload belongs to different vault.'"]
    CHECK_VAULT_MATCH -- Yes --> CHECK_NODE{nodeId present?}

    CHECK_NODE -- No --> THROW_NODE["throw SyncPayloadException<br/>'Payload node id missing.'"]
    CHECK_NODE -- Yes --> CHECK_FIELDS{salt/nonce/ct/mac<br/>all present?}

    CHECK_FIELDS -- No --> THROW_FIELDS["throw SyncPayloadException<br/>'Payload envelope incomplete.'"]
    CHECK_FIELDS -- Yes --> DECRYPT["AES-256-GCM decrypt<br/>HKDF-derived key"]

    DECRYPT -- Fail --> THROW_DECRYPT["throw SyncPayloadException<br/>'Payload decryption failed.'"]
    DECRYPT -- Success --> RETURN["Return plaintext JSON"]
```

---

## 9. Recovery Marker Resume Boundary

```mermaid
flowchart TD
    START([SyncService.initialize]) --> LOAD_MARKER["_loadRecoveryMarker()"]
    LOAD_MARKER --> HAS_MARKER{Marker exists?}
    HAS_MARKER -- No --> NORMAL["Normal sync init"]
    HAS_MARKER -- Yes --> PARSE{Valid JSON?}

    PARSE -- No / Malformed --> CLEAR["Clear marker<br/>Normal init"]
    PARSE -- Yes --> CHECK_PHASE{Marker.phase}

    CHECK_PHASE -- pull --> RESUME_PULL["Resume from<br/>marker.localVersion<br/>Incremental pull"]
    CHECK_PHASE -- push --> RESUME_PUSH["_pullAndMergeLatestSnapshot()<br/>then push"]
    CHECK_PHASE -- conflictRecovery --> RESUME_CONFLICT["Enter conflictRecovery<br/>from stored conflictType"]

    RESUME_PULL --> CLEAR
    RESUME_PUSH --> CLEAR
    RESUME_CONFLICT --> RETRY["Retry with backoff<br/>max 3 attempts"]
    RETRY --> MAX_CHECK{Retries >= 3?}
    MAX_CHECK -- Yes --> PROTO_ERROR["SyncState.protocolError<br/>'Max retries exceeded!'"]
    MAX_CHECK -- No --> CLEAR
```

---

## 10. Server Generation Mismatch Recovery

```mermaid
flowchart TD
    START([_applyRemoteChanges]) --> CHECK_GEN{"_serverGeneration != 0<br/>&& serverGeneration != _serverGeneration?"}
    CHECK_GEN -- No --> NORMAL_APPLY["Apply changes normally"]
    CHECK_GEN -- Yes --> HANDLE_RESET["_handleServerReset()"]

    HANDLE_RESET --> RESET_LOCAL["_localVersion = 0"]
    RESET_LOCAL --> CLEAR_CHANGES["Clear local_sync_changes"]
    CLEAR_CHANGES --> MARK_PENDING["Mark ALL synchronized items<br/>as pendingPush"]
    MARK_PENDING --> RE_PUSH["Re-push everything<br/>to recover server vault"]
```

---

## 附录：错误类型速查

| 错误类型 | 来源 | 含义 |
|---|---|---|
| `IdentityCorruptedException` | `IdentityService` | 身份密钥缺失、部分存储或格式非法 |
| `VaultPairingCryptoException` | `VaultPairingCrypto` | 配对包加解密失败、格式不支持 |
| `VaultPairingServiceException` | `VaultPairingService` | 远程配对 HTTP 错误或会话状态异常 |
| `LanPairingServiceException` | `LanPairingService` | LAN 配对网络/平台/验证失败 |
| `VaultImportException` | `VaultDumpCoordinator` | 导入过程中 dump 解密或写入失败 |
| `VaultImportPreconditionException` | `ServiceManager` | 非干净设备未确认覆盖 |
| `SyncPayloadException` | `SyncPayloadCodec` | Payload 信封格式/解密/vault 隔离失败 |
| `SyncProtocolException` | `SyncService` | 协议语义错误（如 generation 不匹配） |
| `SyncHttpException` | `SyncService` | HTTP 层错误，携带 `conflict_type` |
| `ConflictException` | `SyncService` | 推送到服务器时发生冲突，需恢复 |

---

*文档版本：基于 2026-05-07 代码基线绘制。*
