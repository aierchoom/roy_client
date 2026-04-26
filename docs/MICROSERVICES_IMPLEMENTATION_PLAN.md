# SecretRoy 微服务架构实现方案 V1.0

**日期**: 2026-04-18  
**目标**: 构建支持多设备、离线编辑、E2EE的账号同步系统

---

## 目录

1. [架构概述](#架构概述)
2. [微服务设计](#微服务设计)
3. [API 规范](#api-规范)
4. [数据库设计](#数据库设计)
5. [部署架构](#部署架构)
6. [安全设计](#安全设计)
7. [性能优化](#性能优化)

---

## 架构概述

### 核心原则

1. **弱服务器**: 服务器仅存储加密数据，无法解密
2. **终端用户加密 (E2EE)**: 所有密码数据在客户端加密后上传
3. **离线优先**: 本地优先，网络仅用于同步
4. **CRDT**: 支持并发编辑和自动冲突合并
5. **审计友好**: 完整的操作日志和版本控制

### 系统分层

```
┌─────────────────────────────────────────┐
│         Flutter 客户端                   │
│     (加密、同步、离线支持)                │
└────────────────┬────────────────────────┘
                 │ HTTPS + 签名
                 │
┌────────────────▼────────────────────────┐
│      API 网关 (Kong/Nginx)               │
│   (速率限制、请求路由、日志)              │
└────────────────┬────────────────────────┘
                 │
    ┌────────────┼────────────┬──────────┐
    │            │            │          │
    ▼            ▼            ▼          ▼
┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐
│ Auth   │  │ Sync   │  │Account │  │Device  │
│Service │  │Service │  │Service │  │Service │
└────┬───┘  └────┬───┘  └────┬───┘  └────┬───┘
     │           │           │           │
     └───────────┼───────────┼───────────┘
                 │
         ┌───────▼────────┐
         │ PostgreSQL     │
         │ (核心数据存储)  │
         └───────┬────────┘
                 │
    ┌────────────┼─────────────┐
    │            │             │
    ▼            ▼             ▼
┌────────┐  ┌────────┐   ┌──────────┐
│ Redis  │  │ S3/OSS │   │ RabbitMQ │
│(缓存)  │  │(备份)  │   │ (队列)   │
└────────┘  └────────┘   └──────────┘
```

---

## 微服务设计

### 1. Auth Service (用户认证服务)

**职责**: 用户注册、登录、会话管理

#### API 端点

```
# 用户注册
POST /auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "username": "john_doe",
  "passwordHash": "scrypt_hash_base64",  // 客户端计算的密钥派生结果
  "salt": "random_base64",                // 用于密钥派生的盐值
  "deviceInfo": {
    "deviceId": "uuid",
    "deviceName": "iPhone 13",
    "platform": "ios",
    "osVersion": "16.1"
  }
}

Response 201:
{
  "accountId": "uuid",
  "deviceId": "uuid",
  "accessToken": "jwt_token",
  "refreshToken": "jwt_token",
  "expiresIn": 3600,
  "setupComplete": false
}

---

# 用户登录
POST /auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "deviceInfo": {
    "deviceId": "uuid",
    "deviceName": "iPhone 13",
    "platform": "ios"
  }
}

Response 200:
{
  "accountId": "uuid",
  "deviceId": "uuid",
  "salt": "original_salt_from_registration",  // 用于本地密钥派生验证
  "accessToken": "jwt_token",
  "refreshToken": "jwt_token",
  "expiresIn": 3600
}

---

# 令牌刷新
POST /auth/refresh
Content-Type: application/json
Authorization: Bearer {refreshToken}

{
  "deviceId": "uuid"
}

Response 200:
{
  "accessToken": "new_jwt_token",
  "expiresIn": 3600
}

---

# 登出
POST /auth/logout
Authorization: Bearer {accessToken}

Response 200:
{
  "success": true
}

---

# 生物认证预检
GET /auth/biometric-challenge
Authorization: Bearer {accessToken}

Response 200:
{
  "challenge": "random_bytes_base64",
  "algorithm": "EdDSA"
}
```

#### 数据库模型

```sql
-- 用户表
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(255),
  
  -- 密钥派生信息（用于服务器验证）
  kdf_version INT DEFAULT 2,
  kdf_salt VARCHAR(255) NOT NULL,        -- 注册时的盐值
  kdf_iterations INT,
  
  -- 安全信息
  require_biometric BOOLEAN DEFAULT false,
  security_level VARCHAR(50),            -- 'basic', 'enhanced', 'maximal'
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login_at TIMESTAMP,
  
  CONSTRAINT users_email_key UNIQUE(email)
);

-- 设备表
CREATE TABLE devices (
  id UUID PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_name VARCHAR(255),
  platform VARCHAR(50),                  -- 'ios', 'android', 'web', 'desktop'
  os_version VARCHAR(50),
  app_version VARCHAR(50),
  
  -- 设备密钥（用于离线验证）
  device_public_key VARCHAR(1024),       -- EdDSA 公钥
  
  -- 状态
  is_active BOOLEAN DEFAULT true,
  last_seen_at TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT devices_account_id_fkey FOREIGN KEY(account_id)
);

-- 会话表
CREATE TABLE sessions (
  id UUID PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  
  access_token_hash VARCHAR(255) NOT NULL,
  refresh_token_hash VARCHAR(255) NOT NULL,
  
  expires_at TIMESTAMP NOT NULL,
  refresh_expires_at TIMESTAMP NOT NULL,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT sessions_account_device_unique UNIQUE(account_id, device_id)
);

-- 登录日志
CREATE TABLE login_logs (
  id BIGSERIAL PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id UUID REFERENCES devices(id),
  
  login_type VARCHAR(50),                -- 'password', 'biometric'
  ip_address VARCHAR(45),
  user_agent TEXT,
  success BOOLEAN,
  failure_reason VARCHAR(255),
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CREATE INDEX idx_login_logs_account_id ON login_logs(account_id),
  CREATE INDEX idx_login_logs_created_at ON login_logs(created_at)
);

CREATE INDEX idx_devices_account_id ON devices(account_id);
CREATE INDEX idx_sessions_account_id ON sessions(account_id);
CREATE INDEX idx_sessions_device_id ON sessions(device_id);
```

---

### 2. Sync Service (同步服务)

**职责**: 多设备同步、冲突检测、向量时钟管理

#### API 端点

```
# 初始化同步
POST /sync/start
Authorization: Bearer {accessToken}
Content-Type: application/json

{
  "deviceId": "uuid",
  "vectorClock": {              // 本地向量时钟
    "device_a": 5,
    "device_b": 3,
    "device_c": 0
  },
  "lastKnownServerVersion": 42,
  "accountCount": 150
}

Response 200:
{
  "syncSessionId": "uuid",
  "serverVectorClock": {
    "device_a": 7,
    "device_b": 5,
    "device_c": 2
  },
  "lastServerVersion": 45,
  "hasConflicts": false,
  "pendingOperations": [
    {
      "id": "op_uuid",
      "type": "update",
      "accountId": "account_uuid",
      "timestamp": 1682500000,
      "sourceDevice": "device_a"
    }
  ]
}

---

# 推送本地操作
POST /sync/push
Authorization: Bearer {accessToken}
Content-Type: application/json

{
  "syncSessionId": "uuid",
  "deviceId": "uuid",
  "operations": [
    {
      "id": "op_uuid_1",
      "type": "create",                   // 'create', 'update', 'delete'
      "accountId": "account_uuid",
      "vectorClock": {"device_a": 6},
      "lamportClock": 43,
      "timestamp": 1682500010,
      "encryptedData": "base64_encrypted_json",
      "authTag": "base64_auth_tag",
      "recordMAC": "base64_mac",
      "signature": "base64_ed25519_signature"
    },
    {
      "id": "op_uuid_2",
      "type": "update",
      "accountId": "account_uuid",
      "vectorClock": {"device_a": 7},
      "lamportClock": 44,
      "timestamp": 1682500020,
      "encryptedData": "base64",
      "authTag": "base64",
      "recordMAC": "base64",
      "signature": "base64"
    }
  ]
}

Response 200 | 409:
{
  "success": true,
  "appliedOperations": ["op_uuid_1", "op_uuid_2"],
  "rejectedOperations": [],
  "conflicts": [
    {
      "accountId": "account_uuid",
      "conflictType": "concurrent_edit",
      "localVersion": {
        "id": "op_uuid_local",
        "timestamp": 1682500010,
        "vectorClock": {"device_a": 6}
      },
      "remoteVersion": {
        "id": "op_uuid_remote",
        "timestamp": 1682500005,
        "vectorClock": {"device_b": 5}
      },
      "suggestedResolution": "field_level_merge"
    }
  ],
  "newServerVectorClock": {"device_a": 7, "device_b": 5, "device_c": 2}
}

---

# 解决冲突
POST /sync/resolve-conflicts
Authorization: Bearer {accessToken}
Content-Type: application/json

{
  "syncSessionId": "uuid",
  "deviceId": "uuid",
  "resolutions": [
    {
      "conflictId": "conflict_uuid",
      "resolution": "field_merge",
      "mergedData": {
        "id": "account_uuid",
        "encrypted_data": "base64",
        "auth_tag": "base64",
        "record_mac": "base64",
        "sourceDevice": "device_a",
        "vectorClock": {"device_a": 7, "device_b": 5}
      }
    }
  ]
}

Response 200:
{
  "success": true,
  "resolvedCount": 1,
  "newServerVectorClock": {"device_a": 7, "device_b": 5, "device_c": 2}
}

---

# 拉取远程更新
POST /sync/pull
Authorization: Bearer {accessToken}
Content-Type: application/json

{
  "syncSessionId": "uuid",
  "deviceId": "uuid",
  "vectorClock": {"device_a": 5, "device_b": 3}  // 拉取此后的所有操作
}

Response 200:
{
  "operations": [
    {
      "id": "op_uuid_remote",
      "type": "update",
      "accountId": "account_uuid",
      "timestamp": 1682500015,
      "sourceDevice": "device_b",
      "vectorClock": {"device_a": 5, "device_b": 4},
      "lamportClock": 42,
      "encryptedData": "base64",
      "authTag": "base64",
      "recordMAC": "base64",
      "signature": "base64_ed25519_signature"
    }
  ],
  "serverVectorClock": {"device_a": 5, "device_b": 5, "device_c": 2},
  "lastOperationTime": 1682500015
}

---

# 完成同步
POST /sync/finish
Authorization: Bearer {accessToken}
Content-Type: application/json

{
  "syncSessionId": "uuid",
  "deviceId": "uuid",
  "localVectorClock": {"device_a": 7, "device_b": 5}
}

Response 200:
{
  "success": true,
  "syncDurationMs": 1234,
  "operationsProcessed": 5,
  "conflictsResolved": 1,
  "totalSyncedBytes": 5120
}

---

# 获取操作日志（用于恢复/审计）
GET /sync/operations?limit=100&offset=0
Authorization: Bearer {accessToken}

Response 200:
{
  "operations": [...],
  "total": 1523,
  "hasMore": true
}

---

# 获取冲突历史
GET /sync/conflicts?limit=50&resolved=true
Authorization: Bearer {accessToken}

Response 200:
{
  "conflicts": [...],
  "total": 23,
  "hasMore": false
}
```

#### 数据库模型

```sql
-- 操作表（核心同步表）
CREATE TABLE operations (
  id UUID PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id UUID NOT NULL REFERENCES devices(id),
  
  operation_type VARCHAR(50) NOT NULL,    -- 'create', 'update', 'delete'
  target_id TEXT NOT NULL,                -- 被操作的账号ID
  
  -- 向量时钟和Lamport时钟
  vector_clock JSONB NOT NULL,            -- {"device_a": 5, "device_b": 3}
  lamport_clock BIGINT NOT NULL,
  
  -- 加密数据
  encrypted_data BYTEA,                   -- AES-256-GCM 加密后
  auth_tag BYTEA,                         -- GCM 认证标签
  record_mac BYTEA,                       -- HMAC-SHA256
  
  -- 操作元数据
  timestamp BIGINT NOT NULL,              -- Unix timestamp (ms)
  signature VARCHAR(512),                 -- Ed25519 签名
  
  -- 同步状态
  sync_status VARCHAR(50) DEFAULT 'pending',  -- 'pending', 'applied', 'synced'
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT operations_account_id_fkey FOREIGN KEY(account_id),
  CONSTRAINT operations_device_id_fkey FOREIGN KEY(device_id)
);

-- 冲突表
CREATE TABLE conflicts (
  id UUID PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- 冲突的两个操作
  local_operation_id UUID REFERENCES operations(id),
  remote_operation_id UUID REFERENCES operations(id),
  
  conflict_type VARCHAR(50),              -- 'concurrent_edit', 'delete_conflict'
  
  -- 冲突检测时间
  detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- 解决方案
  resolution_type VARCHAR(50),            -- 'field_merge', 'last_write_wins', 'manual'
  resolved_at TIMESTAMP,
  resolved_operation_id UUID REFERENCES operations(id),
  
  -- 冲突详情
  local_data JSONB,
  remote_data JSONB,
  
  status VARCHAR(50) DEFAULT 'pending'    -- 'pending', 'resolved', 'rejected'
);

-- 向量时钟状态表
CREATE TABLE vector_clock_state (
  account_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  device_id UUID NOT NULL REFERENCES devices(id),
  
  vector_clock JSONB NOT NULL,
  lamport_clock BIGINT NOT NULL,
  
  last_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 同步会话表（用于恢复和调试）
CREATE TABLE sync_sessions (
  id UUID PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id UUID NOT NULL REFERENCES devices(id),
  
  started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP,
  
  operations_pushed INT DEFAULT 0,
  operations_pulled INT DEFAULT 0,
  conflicts_detected INT DEFAULT 0,
  conflicts_resolved INT DEFAULT 0,
  
  status VARCHAR(50) DEFAULT 'active'     -- 'active', 'completed', 'failed'
);

CREATE INDEX idx_operations_account_id ON operations(account_id);
CREATE INDEX idx_operations_device_id ON operations(device_id);
CREATE INDEX idx_operations_timestamp ON operations(timestamp);
CREATE INDEX idx_operations_vector_clock ON operations USING GIN(vector_clock);
CREATE INDEX idx_conflicts_account_id ON conflicts(account_id);
CREATE INDEX idx_conflicts_status ON conflicts(status);
CREATE INDEX idx_sync_sessions_account_id ON sync_sessions(account_id);
```

---

### 3. Account Service (账号管理服务)

**职责**: 账号创建、查询、模板管理

#### API 端点

```
# 创建账号
POST /accounts
Authorization: Bearer {accessToken}
Content-Type: application/json

{
  "templateId": "template_uuid",
  "name": "GitHub",
  "email": "user@github.com",
  "encryptedData": "base64_encrypted_json",
  "authTag": "base64_auth_tag",
  "recordMAC": "base64_mac",
  "vectorClock": {"device_a": 5},
  "sourceDevice": "device_a"
}

Response 201:
{
  "id": "account_uuid",
  "templateId": "template_uuid",
  "name": "GitHub",
  "email": "user@github.com",
  "createdAt": 1682500000,
  "version": 1
}

---

# 获取所有账号（分页）
GET /accounts?limit=50&offset=0
Authorization: Bearer {accessToken}

Response 200:
{
  "accounts": [
    {
      "id": "uuid",
      "name": "GitHub",
      "email": "user@github.com",
      "templateId": "uuid",
      "createdAt": 1682500000,
      "modifiedAt": 1682500100,
      "version": 2,
      "syncStatus": "synced"
    }
  ],
  "total": 150,
  "limit": 50,
  "offset": 0,
  "hasMore": true
}

---

# 获取单个账号
GET /accounts/{accountId}
Authorization: Bearer {accessToken}

Response 200:
{
  "id": "uuid",
  "templateId": "uuid",
  "name": "GitHub",
  "email": "user@github.com",
  "encryptedData": "base64",
  "authTag": "base64",
  "createdAt": 1682500000,
  "modifiedAt": 1682500100,
  "version": 2
}

---

# 搜索账号
GET /accounts/search?q=github&limit=20
Authorization: Bearer {accessToken}

Response 200:
{
  "results": [
    {
      "id": "uuid",
      "name": "GitHub",
      "email": "user@github.com",
      "matchScore": 0.95
    }
  ]
}

---

# 删除账号
DELETE /accounts/{accountId}
Authorization: Bearer {accessToken}

Response 204:
{}

---

# 创建模板
POST /templates
Authorization: Bearer {accessToken}
Content-Type: application/json

{
  "title": "Email Account",
  "subtitle": "Email Services",
  "fields": [
    {
      "name": "email",
      "type": "email",
      "required": true
    },
    {
      "name": "password",
      "type": "password",
      "required": true
    },
    {
      "name": "recovery_email",
      "type": "email",
      "required": false
    }
  ]
}

Response 201:
{
  "id": "template_uuid",
  "title": "Email Account",
  "subtitle": "Email Services",
  "fields": [...]
}

---

# 获取所有模板
GET /templates
Authorization: Bearer {accessToken}

Response 200:
{
  "templates": [...]
}
```

---

### 4. Device Service (设备管理服务)

**职责**: 设备信息、去重、远程清除

#### API 端点

```
# 获取所有已授权设备
GET /devices
Authorization: Bearer {accessToken}

Response 200:
{
  "devices": [
    {
      "id": "device_uuid",
      "name": "iPhone 13",
      "platform": "ios",
      "osVersion": "16.1",
      "appVersion": "1.0.0",
      "lastSeenAt": 1682500000,
      "isActive": true,
      "isCurrent": true
    }
  ]
}

---

# 远程删除设备
DELETE /devices/{deviceId}
Authorization: Bearer {accessToken}

Response 204:
{}

---

# 更新设备信息
PATCH /devices/{deviceId}
Authorization: Bearer {accessToken}
Content-Type: application/json

{
  "deviceName": "My iPhone"
}

Response 200:
{
  "id": "device_uuid",
  "name": "My iPhone",
  ...
}

---

# 获取设备的同步历史
GET /devices/{deviceId}/sync-history?limit=20
Authorization: Bearer {accessToken}

Response 200:
{
  "history": [
    {
      "syncSessionId": "uuid",
      "startedAt": 1682500000,
      "completedAt": 1682500010,
      "operationsPushed": 5,
      "operationsPulled": 3,
      "conflictsResolved": 1,
      "status": "completed"
    }
  ]
}
```

---

## API 规范

### 请求签名机制

每个请求都需要签名以防止篡改：

```
请求签名步骤:

1. 准备签名数据
   signData = METHOD + '\n' +
              PATH + '\n' +
              TIMESTAMP + '\n' +
              CONTENT_HASH + '\n' +
              REQUEST_BODY (如果有)

2. 计算内容哈希
   CONTENT_HASH = base64(SHA256(requestBody))

3. 使用设备私钥签名
   SIGNATURE = base64(Ed25519.sign(signData, devicePrivateKey))

4. 添加签名头
   X-Signature: SIGNATURE
   X-Timestamp: TIMESTAMP
   X-Content-Hash: CONTENT_HASH
```

### 错误响应

```
{
  "error": {
    "code": "SYNC_CONFLICT",
    "message": "Concurrent modification detected",
    "details": {
      "conflictId": "uuid",
      "suggestedResolution": "field_merge"
    }
  }
}

常见错误码:
- INVALID_TOKEN: 令牌过期/无效
- INSUFFICIENT_PERMISSION: 权限不足
- SYNC_CONFLICT: 同步冲突
- DATA_INTEGRITY_ERROR: 数据完整性校验失败
- RATE_LIMIT_EXCEEDED: 超过速率限制
- VERSION_MISMATCH: 版本不匹配
- DEVICE_NOT_FOUND: 设备未找到
- ACCOUNT_NOT_FOUND: 账号未找到
```

---

## 数据库设计

### PostgreSQL Schema

```sql
-- 用户账户
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(255),
  kdf_version INT DEFAULT 2,
  kdf_salt VARCHAR(255) NOT NULL,
  kdf_iterations INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login_at TIMESTAMP,
  status VARCHAR(50) DEFAULT 'active'  -- 'active', 'suspended', 'deleted'
);

-- 设备
CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_name VARCHAR(255) NOT NULL,
  platform VARCHAR(50) NOT NULL,     -- ios, android, web, macos, windows
  os_version VARCHAR(50),
  app_version VARCHAR(50),
  device_public_key TEXT,            -- Ed25519 公钥 PEM 格式
  is_active BOOLEAN DEFAULT true,
  last_seen_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 账号（密码存储）
CREATE TABLE accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  template_id UUID NOT NULL,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255),
  
  -- 加密数据
  encrypted_data BYTEA NOT NULL,
  auth_tag BYTEA NOT NULL,
  record_mac BYTEA NOT NULL,
  
  -- 版本控制
  vector_clock JSONB,
  lamport_clock BIGINT,
  
  -- 元数据
  source_device_id UUID,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP,
  
  CONSTRAINT accounts_account_id_fkey FOREIGN KEY(account_id)
);

-- 操作日志
CREATE TABLE operations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id UUID NOT NULL REFERENCES devices(id),
  target_id TEXT NOT NULL,           -- 被操作的资源ID
  operation_type VARCHAR(50) NOT NULL,  -- create, update, delete
  
  vector_clock JSONB NOT NULL,
  lamport_clock BIGINT NOT NULL,
  
  encrypted_data BYTEA,
  auth_tag BYTEA,
  record_mac BYTEA,
  
  timestamp BIGINT NOT NULL,
  signature TEXT,                    -- Ed25519 签名
  sync_status VARCHAR(50) DEFAULT 'pending',
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 冲突日志
CREATE TABLE conflicts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  local_operation_id UUID REFERENCES operations(id),
  remote_operation_id UUID REFERENCES operations(id),
  
  conflict_type VARCHAR(50),
  detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  resolution_type VARCHAR(50),
  resolved_at TIMESTAMP,
  resolved_operation_id UUID REFERENCES operations(id),
  
  local_data JSONB,
  remote_data JSONB,
  
  status VARCHAR(50) DEFAULT 'pending'
);

-- 创建必要的索引
CREATE INDEX idx_devices_account_id ON devices(account_id);
CREATE INDEX idx_accounts_account_id ON accounts(account_id);
CREATE INDEX idx_accounts_deleted ON accounts(is_deleted, deleted_at);
CREATE INDEX idx_operations_account_id ON operations(account_id);
CREATE INDEX idx_operations_timestamp ON operations(timestamp DESC);
CREATE INDEX idx_operations_sync_status ON operations(sync_status);
CREATE INDEX idx_conflicts_account_id ON conflicts(account_id);
CREATE INDEX idx_conflicts_status ON conflicts(status);
```

---

## 部署架构

### Docker Compose 本地开发环境

```yaml
version: '3.8'

services:
  # PostgreSQL 数据库
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: secretroy
      POSTGRES_USER: secretroy
      POSTGRES_PASSWORD: dev_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql

  # Redis 缓存
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

  # API 网关 (Kong)
  kong:
    image: kong:3.1-alpine
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: postgres
      KONG_PG_USER: secretroy
      KONG_PG_PASSWORD: dev_password
    ports:
      - "8000:8000"  # HTTP API
      - "8001:8001"  # Admin API
    depends_on:
      - postgres

  # Auth Service
  auth-service:
    build:
      context: ./services/auth
      dockerfile: Dockerfile
    environment:
      DATABASE_URL: postgresql://secretroy:dev_password@postgres:5432/secretroy
      REDIS_URL: redis://redis:6379
      JWT_SECRET: dev_jwt_secret
    ports:
      - "3001:3000"
    depends_on:
      - postgres
      - redis

  # Sync Service
  sync-service:
    build:
      context: ./services/sync
      dockerfile: Dockerfile
    environment:
      DATABASE_URL: postgresql://secretroy:dev_password@postgres:5432/secretroy
      REDIS_URL: redis://redis:6379
    ports:
      - "3002:3000"
    depends_on:
      - postgres
      - redis

  # Account Service
  account-service:
    build:
      context: ./services/account
      dockerfile: Dockerfile
    environment:
      DATABASE_URL: postgresql://secretroy:dev_password@postgres:5432/secretroy
      REDIS_URL: redis://redis:6379
    ports:
      - "3003:3000"
    depends_on:
      - postgres
      - redis

volumes:
  postgres_data:
  redis_data:
```

---

## 安全设计

### 传输安全

1. **HTTPS 强制**: 所有请求必须使用 HTTPS
2. **证书锁定**: 客户端必须验证服务器证书
3. **请求签名**: 使用 Ed25519 签署每个请求
4. **时间戳验证**: 防止重放攻击

### 数据安全

1. **E2EE**: 密码在客户端加密，服务器无密钥
2. **HMAC 验证**: 所有数据都有 HMAC-SHA256 标签
3. **数据库加密**: 使用 pgcrypto 加密敏感字段
4. **备份加密**: 备份文件必须加密存储

### 认证授权

1. **JWT 令牌**: 访问令牌有效期 1 小时
2. **设备绑定**: 令牌与特定设备绑定
3. **双因素认证**: 支持生物认证和 TOTP
4. **会话管理**: 会话可远程终止

### 审计日志

```sql
CREATE TABLE audit_logs (
  id BIGSERIAL PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES users(id),
  device_id UUID NOT NULL REFERENCES devices(id),
  
  action VARCHAR(100) NOT NULL,
  resource_type VARCHAR(50),
  resource_id VARCHAR(255),
  
  old_values JSONB,
  new_values JSONB,
  
  ip_address VARCHAR(45),
  user_agent TEXT,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_logs_account_id ON audit_logs(account_id, created_at DESC);
```

---

## 性能优化

### 缓存策略

```
redis_key = "account:{account_id}:{resource_id}"
ttl = 5分钟（对于 GET）

for update/delete: 立即清除缓存
```

### 数据库优化

1. **连接池**: 使用 PgBouncer，池大小 20-50
2. **查询优化**: 使用 EXPLAIN ANALYZE
3. **分区**: 按 created_at 分区操作表
4. **归档**: 旧操作移到归档表

### 并发控制

```
乐观锁:
- version 字段
- 更新时检查版本号

分布式锁 (Redis):
- 同步操作需要锁
- 锁超时 30 秒
```

---

## 监控告警

```
关键指标:

1. API 响应时间
   - P50 < 100ms
   - P99 < 500ms

2. 数据库查询时间
   - 平均 < 10ms
   - 慢查询 > 100ms

3. 同步冲突率
   - 警告: > 5%
   - 严重: > 10%

4. 错误率
   - 警告: > 0.1%
   - 严重: > 1%

5. 并发用户数
   - 监控峰值并发

6. 存储空间
   - 数据库大小
   - 备份大小
```

---

## 总结

这个微服务架构提供：

✅ **E2EE**: 密码完全加密，服务器无法读取  
✅ **多设备同步**: 向量时钟支持因果一致性  
✅ **自动冲突合并**: CRDT 处理并发编辑  
✅ **离线优先**: 本地优先，网络仅用于同步  
✅ **完整审计**: 所有操作可追溯  
✅ **高可用**: 微服务架构支持水平扩展  
✅ **安全**: 多层安全防护  

预期支持：
- 100+ 万用户
- 数十亿条密码记录  
- 每秒 10,000+ 同步请求
