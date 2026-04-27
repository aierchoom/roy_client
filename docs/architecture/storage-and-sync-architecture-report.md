# SecretRoy 密码存储与账号同步架构分析报告

> Current delta (2026-04-28): this is a historical risk report from 2026-04-18. Master password verification has since been hardened with `master_password_v2` PBKDF2-HMAC-SHA256 storage, secure vault link codes now use `sroy-secure-v2:` with AES-GCM-256, LAN pairing uses 8 readable characters, and local SQLite-at-rest encryption is now implemented as `secret_roy_vault.db.enc` with a Dart AES-GCM-256 binary file envelope. See `../security/local-database-encryption.md` for the current storage security model.

**生成日期**: 2026-04-18  
**分析范围**: 密码管理、本地存储、远程同步三层架构

---

## 目录
1. [现状分析](#现状分析)
2. [问题诊断](#问题诊断)
3. [业内成熟解决方案](#业内成熟解决方案)
4. [推荐架构设计](#推荐架构设计)
5. [实现路线图](#实现路线图)

---

## 现状分析

### 1. 加密层架构

#### 当前实现 (EnhancedCryptoService + DatabaseFileCipher)

```dart
// 2026-04-28 当前状态
initMasterKey(password) → PBKDF2 verifier 校验/建立
createDatabaseFileCipher() → 解开 32-byte random DB data key
DatabaseFileCipher.encrypt(sqliteBytes) → secret_roy_vault.db.enc
```

| 指标       | 当前状态              |
| ---------- | --------------------- |
| 加密算法   | AES-GCM-256 文件信封 |
| 密钥派生   | PBKDF2-HMAC-SHA256 |
| 主密钥管理 | `master_password_v2` verifier + 解锁态内存密钥 |
| 盐值使用   | 主密码 verifier salt + `database_key_salt_v1` |
| 密钥迭代   | 100000 次 |

**剩余风险**: ⚠️ 中高
- 解锁期间仍需要临时 runtime SQLite 工作库
- 生物识别解锁仍依赖 secure storage 中的主密码材料
- 远端传输、服务端认证和密钥撤销仍需要继续加固

---

### 2. 本地存储层架构

#### 数据库结构

**长期数据库文件**: `secret_roy_vault.db.enc` (AES-GCM-256 binary envelope)
**运行时工作库**: `secret_roy_vault.runtime.db` (temporary SQLite, unlocked session only)

| 表名            | 存储内容                              | 加密状态 |
| --------------- | ------------------------------------- | -------- |
| `accounts`      | 账号记录 (id, name, email, data JSON) | 长期落盘加密；运行时临时明文 |
| `templates`     | 账号模板定义                          | 长期落盘加密；运行时临时明文 |
| `settings`      | 应用设置                              | 长期落盘加密；运行时临时明文 |
| `conflict_logs` | 并发编辑冲突记录                      | 长期落盘加密；运行时临时明文 |

**关键字段**:
```sql
CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  name TEXT,
  email TEXT,
  data TEXT,           -- JSON: {"password": "...", "username": "..."}
  created_at INTEGER,
  modified_at INTEGER,
  version INTEGER      -- 乐观锁版本号
)
```

#### 存储特性

- ✅ 使用 SQLite (跨平台支持)
- ✅ 事务支持 (原子性)
- ✅ 索引优化 (快速查询)
- ✅ 长期落盘文件使用 AES-GCM-256 加密并带认证标签
- ✅ 锁定/关闭时重新封装并删除 runtime 工作库
- ⚠️ 解锁期间 runtime SQLite 仍依赖 OS 权限与应用锁定清理
- ⚠️ 尚未使用 SQLCipher/page-level 加密

**数据暴露面**:
- 数据库文件: `~/Documents/secret_roy_vault.db.enc`
- 运行时临时文件: OS temp/secret_roy/`secret_roy_vault.runtime.db`，仅解锁态存在
- 内存: 解锁后的数据在内存中明文使用
- SharedPreferences: 同步配置/版本号明文存储

---

### 3. 远程同步架构

#### 同步策略

```
┌─────────────────────────────────────┐
│         SyncService (客户端)         │
├─────────────────────────────────────┤
│ 本地版本 (sync_version)             │
│ 脏标记   (sync_dirty)               │
│ 同步地址 (sync_server_url)          │
└─────────────┬───────────────────────┘
              │
        ┌─────▼─────┐
        │  版本号比较 │
        └─────┬─────┘
              │
    ┌─────────┴─────────┐
    │                   │
 ┌──▼──┐           ┌───▼──┐
 │ 推送  │           │ 拉取  │
 │ (PUT)│           │ (GET) │
 └──┬──┘           └───┬──┘
    │                 │
    └────────┬────────┘
             │
    ┌────────▼────────┐
    │  同步服务器Node.js  │
    ├─────────────────┤
    │ vault_<id>.json │
    │ record payloads │
    └─────────────────┘
```

**同步算法**:

```
pull changes since localVersion
merge remote account/template records with CRDT rules
push local pending records with expected_base_version
server accepts only if expected_base_version matches stored version
persist accepted versions and conflict notices locally
```

#### 服务器端实现

**技术栈**: Express.js + 文件系统

| 功能       | 实现       | 问题                   |
| ---------- | ---------- | ---------------------- |
| 版本存储   | `vault_<id>.json` currentVersion | 原子写 + bak，仍是弱服务器文件存储 |
| 数据存储 | 记录级 `encrypted_signed_payload` | 无压缩/去重 |
| 多设备支持 | record version + HLC/CRDT | 身份和密钥体系仍需正式化 |
| 并发控制   | expected_base_version | 可拒绝陈旧推送，但复杂协作仍依赖客户端合并 |
| 认证授权   | 无         | 任何人可访问           |
| 加密传输   | HTTP 明文  | 中间人攻击风险         |

**服务器端冲突处理**:

```javascript
// 版本冲突检查
if (push.expected_base_version !== storedItem.version) {
  return 409 Conflict  // 拒绝陈旧记录推送
}
acceptRecord(push.encrypted_signed_payload)
```

---

### 4. 2026-04-18 历史同步流程问题（当前已部分缓解）

#### 场景: 三台设备同步

```
时间  Device A        Device B        Device C      Server
─────────────────────────────────────────────────────────
T0    v1:修改密码     v1:离线          v1:离线        v1

T1    v2:push()   ──────────────────→                v2

T2    v2:idle      v1:在线            v1:idle        v2
                   pull()←─────────────────         

T3    v2:pull()  ←──────────────────────────────    v2
                                    v1:修改新密码

T4                                   v2:push()  ──→ [冲突!]
                                    [失败]

T5   v2:idle      v2:同步            v2:retry   ───→ ?
```

**当前结论**:
1. ✅ 已从整库覆盖收敛为记录级同步。
2. ✅ 账号/模板带 HLC、serverVersion、syncStatus，并有冲突日志。
3. ✅ 客户端通过 `CrdtMergeEngine` 合并并发编辑。
4. ⚠️ 服务端仍只是弱文件存储与版本守门，不承担复杂合并。
5. ⚠️ 身份、密钥撤销、服务端认证和传输安全仍未达到外部 Beta 要求。

---

## 问题诊断

### 安全性问题

| 问题         | 严重性 | 影响                        |
| ------------ | ------ | --------------------------- |
| 运行时明文窗口 | 🟠 重要 | 解锁期间 runtime SQLite 和内存仍需 OS 权限保护 |
| 无传输加密   | 🔴 严重 | WiFi窃听、中间人攻击        |
| 无身份认证   | 🔴 严重 | 服务器任何人可访问          |
| 无访问控制   | 🟠 重要 | 解锁运行期仍依赖系统权限边界 |
| 自定义加密实现 | 🟠 重要 | sync payload 需要替换为标准 AEAD/E2EE |

### 功能性问题

| 问题             | 影响                 |
| ---------------- | -------------------- |
| 服务端弱认证     | 任何知道地址的人都可尝试访问 |
| 远端密钥治理不足 | 撤销、轮换、设备加入仍需正式设计 |
| 冲突体验仍需打磨 | 已有 ConflictInbox，但仍需更多 UI/测试 |
| 弱服务器文件存储 | 可用但缺少数据库级查询和审计 |

### 可维护性问题

| 问题             | 技术债               |
| ---------------- | -------------------- |
| sync metadata 仍分散 | settings key、服务端版本和本机偏好需要继续收敛 |
| 自定义 payload codec | 当前有 HMAC/nonce/ciphertext，但应替换为标准 AEAD |
| 服务器无数据库   | 弱服务器场景可接受，但扩展能力有限 |

---

## 业内成熟解决方案

### 方案对比

#### 方案1: 应用级E2EE (推荐 ⭐⭐⭐⭐⭐)

**代表产品**: 1Password, Bitwarden, LastPass

```
客户端                                  服务器
┌──────────────────┐                ┌──────────────┐
│ 明文数据          │                │ 加密数据存储  │
│ ↓ 加密            │                │ (无密钥)      │
│ 加密数据          │                │              │
│ ↓ 上传            │                │              │
└────────┬──────────┘                │              │
         └───────────────────────────→ 存储加密数据
         ←───────────────────────────┘
         │ 下载加密数据
         │ ↓ 解密
         └──┐
            │
         明文数据
```

**特点**:
- ✅ 密钥只存在客户端
- ✅ 服务器对数据无法解密
- ✅ 即使服务器被攻破数据仍安全
- ✅ 适合所有类型的机密数据

**实现**:
```
1. 主密码 + PBKDF2 → 加密密钥
2. 数据库 + 密钥 → AES-256-GCM 加密
3. 加密数据 + 签名 → 服务器存储
4. 接收时验证签名 + 解密
```

---

#### 方案2: 端到端加密同步 (推荐 ⭐⭐⭐⭐)

**代表产品**: Sync.com, NextCloud E2EE

```
设备A                设备B              设备C         服务器
│                   │                 │            │
├─ 修改              │                 │            │
├─ 加密              │                 │            │
├─ 上传加密数据 ─────┼─────────────────┼───────────→
│                   │                 │            │
│                   │← 拉取加密数据 ←──┼───────────┐
│                   │  解密、合并      │            │
│                   ├─ 加密合并结果 ──→ 存储       │
│                   │                 │            │
```

**特点**:
- ✅ 原生支持多设备同步
- ✅ 服务器无法解密
- ✅ 自动冲突合并
- ✅ 支持离线编辑

---

#### 方案3: Operational Transformation (OT) (⭐⭐⭐)

**代表产品**: Google Docs, SharePoint

适合**文档协作**，不适合**密码管理**（密码是非线性结构）

---

### 推荐: 应用级E2EE + CRDT 混合方案

结合:
1. **应用级E2EE**: 加密密码数据
2. **CRDT**: 处理并发编辑
3. **向量时钟**: 因果一致性

---

## 推荐架构设计

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter 客户端                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐     ┌──────────────────┐              │
│  │  UI层            │     │  业务逻辑层       │              │
│  │  (账号管理视图)   │ ←→  │  (账号CRUD)      │              │
│  └──────────────────┘     └────────┬─────────┘              │
│                                    │                        │
│  ┌──────────────────────────────────▼────────────────────┐ │
│  │           增强的加密服务层                              │ │
│  ├────────────────────────────────────────────────────────┤ │
│  │ • 主密码管理 (PBKDF2+Scrypt)                           │ │
│  │ • 数据加密 (AES-256-GCM)                              │ │
│  │ • 完整性校验 (HMAC-SHA256)                            │ │
│  │ • 密钥派生 (子密钥隔离)                               │ │
│  └─────────┬──────────────────────────────────────────────┘ │
│            │                                                 │
│  ┌─────────▼────────────────────────────────────────────┐   │
│  │      本地存储层 (SQLite)                              │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │ • 账号表 (encrypted_data, mac_tag)                   │   │
│  │ • 模板表 (加密)                                       │   │
│  │ • 同步元数据表 (向量时钟, lamport_clock)              │   │
│  │ • 操作日志表 (离线编辑操作记录)                        │   │
│  └──────────┬────────────────────────────────────────────┘   │
│             │                                                │
│  ┌──────────▼────────────────────────────────────────────┐   │
│  │        同步引擎层                                      │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │ • 向量时钟管理                                         │   │
│  │ • 操作变换 (OT) 或 CRDT                               │   │
│  │ • 冲突检测与合并                                      │   │
│  │ • 脏数据跟踪                                          │   │
│  └──────────┬────────────────────────────────────────────┘   │
│             │                                                │
└─────────────┼────────────────────────────────────────────────┘
              │ HTTPS + 双向认证
              │
┌─────────────▼────────────────────────────────────────────────┐
│                   微服务架构 (Node.js/Go)                      │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  ┌──────────────────┐   ┌────────────────────┐            │
│  │ API网关          │   │ 用户认证服务       │            │
│  │ (速率限制)       │   │ (OAuth2/JWT)       │            │
│  └──────┬───────────┘   └────────┬───────────┘            │
│         │                        │                        │
│  ┌──────▼──────────────────────▼──────────────────────┐   │
│  │          同步服务 (核心)                            │   │
│  ├────────────────────────────────────────────────────┤   │
│  │ • 版本管理                                          │   │
│  │ • 向量时钟维护                                      │   │
│  │ • 操作日志存储                                      │   │
│  │ • 多设备协调                                        │   │
│  └──────┬────────────────────────────────────────────┘   │
│         │                                                 │
│  ┌──────▼──────────────────────────────────────────────┐   │
│  │       数据存储层                                      │   │
│  ├────────────────────────────────────────────────────┤   │
│  │ • PostgreSQL: 用户、版本控制、操作日志              │   │
│  │ • Redis: 会话、缓存、实时推送队列                   │   │
│  │ • 对象存储: 加密数据库快照                          │   │
│  └──────────────────────────────────────────────────┘   │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

### 1. 加密层设计 (V2)

#### 密钥派生

```dart
// PBKDF2 + Scrypt 混合
MasterKey = Scrypt(
  password = userPassword,
  salt = randomBytes(32),
  N = 2^15,           // CPU 成本参数
  r = 8,              // 块大小
  p = 1,              // 并行化参数
  dkLen = 32          // 输出 256-bit
)

EncryptionKey = PBKDF2(
  PRF = HMAC-SHA256,
  password = MasterKey,
  salt = userEmail + deviceId,  // 设备隔离
  iterations = 100_000,
  dkLen = 32
)

AuthenticationKey = PBKDF2(
  PRF = HMAC-SHA256,
  password = MasterKey,
  salt = "auth_" + userEmail,
  iterations = 100_000,
  dkLen = 32
)
```

#### 数据加密

```dart
// 对每条账号记录
plaintext = {
  "id": "...",
  "username": "...",
  "password": "...",
  "customFields": {...}
}

// 1. 序列化
jsonData = jsonEncode(plaintext)

// 2. 生成随机初始化向量 (IV)
iv = randomBytes(12)  // 96-bit for GCM

// 3. AES-256-GCM 加密
ciphertext, authTag = AES256GCM.encrypt(
  plaintext = jsonData,
  key = EncryptionKey,
  nonce = iv
)

// 4. 计算整体完整性标签
recordMAC = HMAC-SHA256(
  key = AuthenticationKey,
  msg = iv + ciphertext
)

// 5. 存储到数据库
{
  id: recordId,
  iv: base64(iv),
  encrypted_data: base64(ciphertext),
  auth_tag: base64(authTag),
  record_mac: base64(recordMAC),
  encrypted_at: timestamp,
  version: vectorClock
}
```

#### 密钥存储

```
┌────────────────────────────────┐
│      主密码 (用户输入)           │
└────────────┬───────────────────┘
             │
   ┌─────────▼─────────┐
   │ Scrypt + PBKDF2   │
   └─────────┬─────────┘
             │
   ┌─────────▼────────────────────────┐
   │ 加密密钥 (EncryptionKey) - 内存   │
   │ 认证密钥 (AuthenticationKey)     │
   └─────────┬────────────────────────┘
             │ 加锁后清除
   ┌─────────▼────────────────────────┐
   │ Keychain/Secure Enclave 存储      │
   │ (生物认证后恢复)                   │
   └────────────────────────────────┘
```

---

### 2. 本地存储层设计

#### 数据库Schema (V2)

```sql
-- 账号表（加密存储）
CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  
  -- 加密数据
  encrypted_data BLOB NOT NULL,      -- JSON加密后
  auth_tag BLOB NOT NULL,            -- AES-GCM 认证标签
  record_mac BLOB NOT NULL,          -- HMAC-SHA256 完整性
  
  -- 向量时钟（用于因果一致性）
  vector_clock TEXT NOT NULL,        -- JSON: {"deviceA": 5, "deviceB": 3}
  lamport_clock INTEGER NOT NULL,    -- 单调递增时钟
  
  -- 同步元数据
  device_id TEXT NOT NULL,           -- 创建/修改设备
  created_at INTEGER NOT NULL,
  modified_at INTEGER NOT NULL,
  
  -- 版本控制
  version INTEGER DEFAULT 1,         -- 乐观锁
  is_deleted INTEGER DEFAULT 0,      -- 软删除标记
  tombstone_at INTEGER,              -- 删除时间戳
  
  -- 同步状态
  sync_state TEXT DEFAULT 'synced',  -- 'synced', 'pending', 'conflict'
  last_sync_at INTEGER
);

-- 操作日志表（用于离线支持）
CREATE TABLE operation_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  operation TEXT NOT NULL,          -- 'create', 'update', 'delete'
  old_data TEXT,                     -- 变更前的加密数据
  new_data TEXT,                     -- 变更后的加密数据
  vector_clock TEXT NOT NULL,        -- 向量时钟快照
  lamport_clock INTEGER NOT NULL,
  timestamp INTEGER NOT NULL,
  sync_status TEXT DEFAULT 'pending' -- 'pending', 'synced', 'failed'
);

-- 向量时钟表（跟踪每个设备的因果关系）
CREATE TABLE causality_tracking (
  device_id TEXT PRIMARY KEY,
  vector_clock TEXT NOT NULL,        -- JSON
  last_seen_lamport INTEGER NOT NULL,
  last_updated_at INTEGER NOT NULL
);

-- 同步元数据表
CREATE TABLE sync_metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

-- 冲突日志表（用于人工审查）
CREATE TABLE conflicts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id TEXT NOT NULL,
  local_version TEXT NOT NULL,       -- JSON
  remote_version TEXT NOT NULL,      -- JSON
  conflict_type TEXT NOT NULL,       -- 'concurrent_edit', 'delete_conflict'
  resolution_status TEXT DEFAULT 'pending',  -- 'pending', 'resolved', 'merged'
  resolved_data TEXT,                -- 合并后的数据
  created_at INTEGER NOT NULL
);
```

---

### 3. 远程同步架构设计

#### 同步协议 (基于 CRDT + 向量时钟)

```
客户端                                          服务器
│                                              │
├─ 1. 初始化同步                                │
│     生成本地向量时钟                          │
│     VC = {deviceA: 5, deviceB: 3}            │
├─────────────── sync/start ──────────────────→
│                                              ├─ 存储VC
│                                              ├─ 生成服务器VC
│                         ←───────── {serverVC} ─┤
│                                              │
├─ 2. 上传脏操作                                │
│     收集本地未同步的操作                      │
│     operations = [op1, op2, ...]             │
├─────────── sync/push (operations) ──────────→
│                                              ├─ 验证因果关系
│                                              ├─ 检测冲突
│                                              ├─ 合并到服务器状态
│                                              ├─ 更新服务器VC
│                         ←──── {conflicts: [...]} ┤
│                                              │
├─ 3. 处理冲突                                 │
│     apply(CRDTMergeStrategy)                 │
│     生成合并操作                              │
├─────── sync/merge (mergedOps) ──────────────→
│                                              ├─ 提交合并
│                                              ├─ 更新VC
│                         ←──── {success: true} ──┤
│                                              │
├─ 4. 拉取远程更新                             │
│     感知向量时钟之后的所有操作                │
├──────────── sync/pull (ourVC) ──────────────→
│                                              ├─ 查询: VC > ourVC
│                                              ├─ 返回新操作
│                         ←─ {remoteOps: [...]} ┤
│                                              │
├─ 5. 本地应用                                 │
│     apply(remoteOps)                        │
│     更新本地状态和VC                        │
│                                              │
└──────────────────────────────────────────────┘
```

#### 向量时钟示例

```json
// 初始状态
{
  "deviceA": 0,
  "deviceB": 0,
  "deviceC": 0
}

// Device A 创建账号
→ deviceA VC = 1
{
  "deviceA": 1,
  "deviceB": 0,
  "deviceC": 0
}

// Device B 修改密码
→ deviceB VC = 1
{
  "deviceA": 1,
  "deviceB": 1,
  "deviceC": 0
}

// Device A 再次修改
→ deviceA VC = 2
{
  "deviceA": 2,
  "deviceB": 1,
  "deviceC": 0
}

// Device C 离线修改 (本地)
→ deviceC VC = 1
{
  "deviceA": 2,
  "deviceB": 1,
  "deviceC": 1
}

// Device C 上线同步时，服务器可以判断：
// 本地 {A:2, B:1, C:1} vs 服务器 {A:2, B:1, C:0}
// → C有新操作，需要合并
```

#### CRDT 冲突合并策略

```dart
enum ConflictResolution {
  // 1. Last-Write-Wins (简单)
  lastWriteWins,
  
  // 2. Field-Level Merge (推荐)
  fieldLevelMerge,
  
  // 3. Custom Resolver (复杂场景)
  customResolver,
}

// 字段级合并示例
class CRDTMerger {
  Map merge(
    Map localVersion,
    Map remoteVersion,
    OperationLog operations,
  ) {
    final result = {...localVersion};
    
    for (final field in remoteVersion.keys) {
      if (!localVersion.containsKey(field)) {
        // 远程新增字段
        result[field] = remoteVersion[field];
      } else if (localVersion[field] == remoteVersion[field]) {
        // 相同，无需合并
        continue;
      } else {
        // 冲突：检查修改时间戳
        if (remoteVersion['modified_at'] > localVersion['modified_at']) {
          result[field] = remoteVersion[field];
        }
        // 否则保留本地版本
      }
    }
    
    return result;
  }
}
```

---

### 4. 多设备同步流程

#### 设备同步状态机

```
┌─────────────┐
│   OFFLINE   │◄──────────────┐
│   (离线)    │               │
└──────┬──────┘               │
       │ 获取同步服务器地址    │
       │ 建立连接             │
       ▼                      │
┌──────────────────┐          │
│ CONNECTING       │          │
│ (连接中)         │          │
└──────┬───────────┘          │
       │                      │
       ├─→ 成功 ──────────────┤
       │                      │
       ▼                      │
┌────────────────────┐        │
│ CHECKING_VERSIONS  │        │
│ (检查版本)         │        │
└──────┬─────────────┘        │
       │                      │
       ├─→ 需要同步 ───┐      │
       │              │      │
       ▼              │      │
┌────────────────────┐│      │
│ PULLING/PUSHING    ││      │
│ (同步中)           ││      │
└──────┬─────────────┘│      │
       │              │      │
       ├─→ 无冲突 ────┤      │
       │              │      │
       ├─→ 有冲突 ────┐      │
       │              │      │
       ▼              ▼      │
┌────────────────────┐       │
│ RESOLVING_CONFLICTS│       │
│ (解决冲突)         │       │
└──────┬─────────────┘       │
       │                     │
       ├─→ 已合并 ───────────┤
       │                     │
       ▼                     │
┌────────────────────┐       │
│ SYNCED             │       │
│ (已同步)           │       │
└──────┬─────────────┘       │
       │ 断开连接             │
       └─────────────────────┘
```

---

### 5. 微服务架构 (后端)

#### 核心服务

```
┌──────────────────────────────────────────────────────┐
│                  API 网关 (Kong/Nginx)               │
├──────────────────────────────────────────────────────┤
│ • 请求路由                                           │
│ • 速率限制 (rate limiting)                           │
│ • 请求签名验证                                        │
│ • 日志记录                                           │
└──────────┬───────────────────────────────────────────┘
           │
    ┌──────┴──────┬──────────────┬────────────┐
    │             │              │            │
    ▼             ▼              ▼            ▼
┌─────────┐ ┌──────────┐ ┌─────────┐ ┌─────────────┐
│ Auth    │ │ Sync     │ │ Account │ │ Metrics     │
│ Service │ │ Service  │ │ Service │ │ Service     │
└────┬────┘ └────┬─────┘ └────┬────┘ └─────────────┘
     │           │            │
     └───────────┼────────────┘
                 │
         ┌───────▼───────┐
         │ PostgreSQL    │
         │ (账号、操作日志)|
         └───────┬───────┘
                 │
         ┌───────▼───────┐
         │ Redis         │
         │ (缓存、队列)   │
         └───────────────┘
```

**Auth Service**:
```
POST /auth/register
  {username, email, masterPassword}
  → 生成 accountId, deviceId
  → 返回 {token, deviceId}

POST /auth/login
  {email, deviceId}
  → 返回 {token, salt}

POST /auth/logout
  → 清除会话
```

**Sync Service**:
```
POST /sync/start
  {accountId, vectorClock}
  → 返回 {serverVC, pendingOps}

POST /sync/push
  {accountId, operations, vectorClock}
  → 检测冲突
  → 返回 {conflicts: [...]}

POST /sync/merge
  {accountId, mergedOps}
  → 提交合并

GET /sync/pull
  ?accountId=...&since={vectorClock}
  → 返回 {newOps: [...], serverVC}
```

---

### 6. 离线支持设计

#### 离线编辑流程

```
┌──────────────────────────────────────┐
│     用户离线编辑账号                   │
└──────────────────────────────────────┘
         ↓
┌──────────────────────────────────────┐
│ 操作被记录到本地 operation_log        │
│ {                                     │
│   account_id: "...",                 │
│   operation: "update",               │
│   vector_clock: {...},               │
│   lamport_clock: 42,                 │
│   sync_status: "pending"             │
│ }                                    │
└──────────────────────────────────────┘
         ↓
┌──────────────────────────────────────┐
│     用户数据（本地加密存储）          │
│     ✓ 本地可查询、修改                │
│     ✓ 无网络延迟                     │
│     ✗ 可能与服务器不一致              │
└──────────────────────────────────────┘
         ↓ [网络恢复]
┌──────────────────────────────────────┐
│ 自动同步：                            │
│ 1. 检查操作因果关系                    │
│ 2. 检测冲突                           │
│ 3. 应用 CRDT 合并                     │
│ 4. 更新 vector_clock                 │
│ 5. 更新 sync_status → "synced"       │
└──────────────────────────────────────┘
```

---

## 推荐架构设计

### 分阶段实施计划

#### 阶段1: E2EE 基础 (3-4周)

```
┌─────────────────────────────────────┐
│  目标：实现应用级端到端加密            │
├─────────────────────────────────────┤
│ • 实现 PBKDF2+Scrypt 密钥派生        │
│ • 实现 AES-256-GCM 数据加密          │
│ • 数据库迁移（明文→加密）            │
│ • 客户端密钥管理                     │
│ • 测试：密码导入、本地查询、修改      │
└─────────────────────────────────────┘
```

**关键工作**:
1. `EnhancedCryptoService` 完整实现
2. 数据库Schema升级（添加`encrypted_data`, `auth_tag`, `record_mac`）
3. 数据迁移脚本
4. 单元测试

---

#### 阶段2: 本地同步准备 (2-3周)

```
┌─────────────────────────────────────┐
│  目标：实现向量时钟和操作日志         │
├─────────────────────────────────────┤
│ • 向量时钟生成和维护                 │
│ • Lamport时钟实现                    │
│ • 操作日志表创建和维护                │
│ • 本地冲突检测                       │
│ • 单设备多操作合并                   │
└─────────────────────────────────────┘
```

**关键工作**:
1. 实现 `VectorClockManager`
2. 创建 `OperationLog` 表和管理器
3. 修改所有数据操作以记录操作日志

---

#### 阶段3: 后端服务升级 (3-4周)

```
┌─────────────────────────────────────┐
│  目标：构建支持CRDT的同步服务         │
├─────────────────────────────────────┤
│ • PostgreSQL 数据库设计              │
│ • 向量时钟管理服务                   │
│ • 操作日志存储和查询                 │
│ • 冲突检测算法                       │
│ • 身份认证 (OAuth2/JWT)              │
│ • HTTPS/TLS 支持                     │
└─────────────────────────────────────┘
```

**关键服务**:
1. `SyncService` (同步协调)
2. `ConflictResolver` (冲突检测)
3. `OperationStore` (操作持久化)
4. `AuthService` (用户认证)

---

#### 阶段4: 客户端同步集成 (2-3周)

```
┌─────────────────────────────────────┐
│  目标：多设备同步和冲突合并           │
├─────────────────────────────────────┤
│ • 同步客户端实现（新）                │
│ • 冲突合并策略                       │
│ • UI 冲突提示                        │
│ • 重试机制                           │
│ • 离线模式检测                       │
└─────────────────────────────────────┘
```

**关键工作**:
1. 重构 `SyncService`
2. 实现 `CRDTMerger`
3. 实现 `ConflictResolutionUI`
4. 测试：多设备并发编辑

---

#### 阶段5: 离线支持 (1-2周)

```
┌─────────────────────────────────────┐
│  目标：完整的离线编辑支持             │
├─────────────────────────────────────┤
│ • 离线检测                           │
│ • 自动同步恢复                       │
│ • 离线操作队列                       │
│ • 冲突自动合并                       │
└─────────────────────────────────────┘
```

---

#### 阶段6: 多微服务扩展 (2-3周)

```
┌─────────────────────────────────────┐
│  目标：支持多微服务部署              │
├─────────────────────────────────────┤
│ • Docker 容器化                      │
│ • 负载均衡 (Nginx/HAProxy)           │
│ • 分布式会话 (Redis)                 │
│ • 消息队列 (RabbitMQ)                │
│ • 监控告警 (Prometheus/Grafana)      │
└─────────────────────────────────────┘
```

---

## 实现路线图

```
时间线:

第1月  |═══ E2EE基础  |═══ 本地同步准备 |
第2月  |    |═══ 后端服务升级  |═══ 客户端集成 |
第3月  |    |           |═══ 离线支持  |═══ 微服务扩展 |
第4月  |    |           |               |═══ 生产部署 |
       └────┴───────────┴───────────────┴────────────→

并行工作:
- 持续集成 (CI/CD)
- 安全审计
- 性能测试
- 文档编写
```

---

## 总结

| 方面       | 当前       | 改进后          |
| ---------- | ---------- | --------------- |
| 加密       | ❌ 无       | ✅ AES-256-GCM   |
| 密钥管理   | ❌ 无       | ✅ PBKDF2+Scrypt |
| 多设备同步 | ⚠️ 版本号   | ✅ 向量时钟+CRDT |
| 冲突处理   | ❌ 丢失     | ✅ 自动合并      |
| 离线支持   | ❌ 无       | ✅ 操作日志      |
| 传输安全   | ❌ HTTP     | ✅ HTTPS+签名    |
| 可扩展性   | ⚠️ 单服务器 | ✅ 微服务        |

**预期效果**:
- 🔒 密码数据完全加密，即使服务器被攻破也无法读取
- 🔄 多设备无缝同步，支持并发编辑
- 📱 离线模式下正常使用，网络恢复自动同步
- 🛡️ 完整的审计日志和冲突记录
- 📈 支持百万级用户和千万级密码记录
