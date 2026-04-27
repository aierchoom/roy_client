# SecretRoy 密码存储与多设备同步方案 - 执行总结

> Current delta (2026-04-28): this is a 2026-04-18 architecture proposal snapshot. Current code now has PBKDF2-HMAC-SHA256 master password verification, `sroy-secure-v2:` secure link codes with AES-GCM-256, and 8-character LAN pairing. SQLite at-rest encryption and the broader storage roadmap remain follow-up items.

**日期**: 2026-04-18  
**文档版本**: 1.0

---

## 快速概览

### 当前状态 ❌

| 层级         | 现状         | 问题等级 |
| ------------ | ------------ | -------- |
| **加密**     | 历史快照：加固前状态 | 🔴 严重   |
| **存储**     | SQLite 明文  | 🔴 严重   |
| **同步**     | 全库覆盖     | 🟠 重要   |
| **冲突处理** | 版本冲突丢失 | 🟠 重要   |
| **离线支持** | 无           | 🟠 重要   |

**核心问题**: 所有密码数据以明文方式存储，即使服务器被攻破用户数据也无法保护。

---

## 推荐方案 ✅

### 整体架构

```
应用级E2EE + CRDT 同步 + 向量时钟因果一致性

特点：
✓ 密码在客户端加密，服务器无法解密
✓ 多设备并发编辑自动合并
✓ 离线编辑网络恢复自动同步
✓ 完整的操作审计日志
✓ 微服务架构支持百万用户级别
```

### 三层架构

```
┌─ 客户端层 ────────────────────────┐
│ • AES-256-GCM 加密                │
│ • PBKDF2+Scrypt 密钥派生          │
│ • 向量时钟 + Lamport 时钟          │
│ • CRDT 冲突合并                    │
│ • SQLite 加密存储                  │
│ • 操作日志（离线支持）              │
└────────────────┬──────────────────┘
                 │
┌────────────────▼──────────────────┐
│ 传输层（HTTPS + 数字签名）         │
│ • 请求签名验证                     │
│ • 证书锁定                        │
│ • 速率限制                        │
└────────────────┬──────────────────┘
                 │
┌────────────────▼──────────────────┐
│ 服务器层（微服务）                 │
│ • Auth Service（认证）             │
│ • Sync Service（同步协调）         │
│ • Account Service（账号管理）      │
│ • Device Service（设备管理）       │
│                                   │
│ 存储：PostgreSQL + Redis + S3     │
└───────────────────────────────────┘
```

---

## 核心创新点

### 1. 应用级E2EE（End-to-End Encryption）

**原理**:
```
用户密码 ──→ Scrypt ──→ AES-256-GCM ──→ 加密数据 ──→ 服务器

服务器: 无法解密 ✓
设备盗窃: 数据安全 ✓
数据泄露: 无法使用 ✓
```

**密钥派生流程**:
- Scrypt: 防止暴力破解（CPU 密集）
- PBKDF2: 派生子密钥隔离（防止密钥泄露影响其他用途）
- HMAC: 数据完整性验证

### 2. CRDT 自动冲突合并

**场景**: 三台设备同时编辑同一条记录

```
设备A 修改密码: "new_pwd_a" (VC={A:2})
设备B 修改用户名: "user_b" (VC={B:2})
设备C 修改邮箱: "email@c.com" (VC={C:2})

同步结果:
{
  username: "user_b",      ✓ 来自设备B
  password: "new_pwd_a",   ✓ 来自设备A
  email: "email@c.com"     ✓ 来自设备C
}

无数据丢失，自动合并 ✓
```

**向量时钟**:
- 记录每个设备的逻辑时钟
- 检测并发编辑（冲突）
- 保证因果一致性

### 3. 离线优先设计

```
离线编辑:
1. 用户编辑账号 → 记录到操作日志
2. 本地数据立即更新 → 用户可正常使用
3. 网络恢复 → 自动同步操作日志
4. 服务器合并 → CRDT 处理冲突
5. 同步完成 → 用户无感知

优势:
✓ 网络不稳定环境可正常使用
✓ 操作不丢失
✓ 自动恢复
```

---

## 实现规划

### 分阶段部署（3个月）

#### 第1阶段：E2EE 基础 (3-4周)
```
目标: 实现端到端加密

任务:
- 实现 PBKDF2+Scrypt 密钥派生
- 实现 AES-256-GCM 加密/解密
- 数据库迁移（明文→加密）
- 所有旧数据加密

交付物:
- enhanced_crypto_service.dart（完整实现）
- 数据库升级脚本
- 密钥恢复机制
```

#### 第2阶段：本地同步准备 (2-3周)
```
目标: 支持向量时钟和操作日志

任务:
- 实现向量时钟管理器
- 创建操作日志表
- 实现本地冲突检测
- 添加 Lamport 时钟

交付物:
- vector_clock_manager.dart
- operation_log_manager.dart
- 数据库扩展
```

#### 第3阶段：后端服务升级 (3-4周)
```
目标: 构建 CRDT 同步服务

任务:
- PostgreSQL 数据库设计
- Auth Service 实现
- Sync Service 实现（核心）
- 冲突检测算法
- HTTPS + 签名验证

交付物:
- Docker Compose 本地环境
- 4 个微服务
- API 文档
- 数据库 Schema
```

#### 第4阶段：客户端集成 (2-3周)
```
目标: 多设备同步和冲突合并

任务:
- 重构 SyncService
- 实现 CRDT 合并策略
- UI 冲突提示
- 重试机制

交付物:
- SyncServiceV2
- ConflictResolutionUI
- 集成测试
```

#### 第5阶段：离线支持 (1-2周)
```
目标: 完整的离线编辑支持

任务:
- 离线检测
- 自动同步恢复
- 操作队列管理

交付物:
- OfflineSyncEngine
- 端到端测试
```

#### 第6阶段：微服务扩展 (2-3周)
```
目标: 支持多服务器部署

任务:
- 容器化（Docker）
- 负载均衡
- 分布式会话
- 监控告警

交付物:
- Kubernetes 配置
- 监控面板
- 部署文档
```

### 时间表

```
┌─────────────────────────────────────────────────────────┐
│  第1月     │  第2月     │  第3月     │  生产部署          │
├─────────────────────────────────────────────────────────┤
│ [E2EE] [←──LocalSync→] [←──BackendSvc→] [←─Integration  │
│         [←───────────────────────────→] [←─Offline──    │
│                                         [←─MicroSvc─   │
└─────────────────────────────────────────────────────────┘
     4周      3周         4周        3周   2周   3周
```

---

## 核心配置示例

### 客户端加密配置

```dart
// 主密码 + 邮箱 + 设备ID 派生密钥

DerivedKeys keys = await KeyDerivationService.deriveKeys(
  masterPassword: "user_password",
  userEmail: "user@example.com",
  deviceId: "device-uuid",
);

// EncryptionKey: 用于 AES-256-GCM
// AuthenticationKey: 用于 HMAC-SHA256

// 本地存储密钥（加密）
EncryptionResult encrypted = await crypto.encryptAccountData({
  "username": "john_doe",
  "password": "secret123",
  // ... 其他字段
});

// 数据库存储
{
  encrypted_data: encrypted.ciphertext,
  auth_tag: encrypted.authTag,
  record_mac: encrypted.recordMAC,
  iv: encrypted.iv
}
```

### 服务器同步 API

```
POST /sync/start
  → 初始化同步会话
  ← 返回服务器向量时钟

POST /sync/push
  → 上传加密的操作日志
  ← 返回冲突列表或成功

POST /sync/resolve-conflicts
  → 发送合并后的数据
  ← 确认合并

POST /sync/pull
  → 拉取远程新操作
  ← 返回需要应用的操作

POST /sync/finish
  → 完成同步，更新向量时钟
  ← 同步统计信息
```

### 数据库核心表

```sql
-- 账号（加密存储）
accounts {
  id, encrypted_data, auth_tag, record_mac,
  vector_clock, lamport_clock,
  is_deleted, tombstone_at
}

-- 操作日志（支持离线）
operation_log {
  id, account_id, operation, 
  vector_clock, lamport_clock,
  sync_status
}

-- 冲突日志（审计）
conflicts {
  id, account_id, local_version,
  remote_version, resolution_status,
  resolved_data
}

-- 向量时钟状态
vector_clock_state {
  device_id, vector_clock, lamport_clock
}
```

---

## 预期效果

### 安全性提升

| 指标       | 当前   | 改进后          | 提升 |
| ---------- | ------ | --------------- | ---- |
| 密码加密   | ❌      | ✅ AES-256-GCM   | 极大 |
| 密钥派生   | ❌      | ✅ PBKDF2+Scrypt | 极大 |
| 完整性验证 | ❌      | ✅ HMAC-SHA256   | 极大 |
| 传输安全   | ❌ HTTP | ✅ HTTPS+签名    | 极大 |
| 离线支持   | ❌      | ✅ 操作日志      | 有   |

### 功能性提升

| 功能       | 当前       | 改进后          |
| ---------- | ---------- | --------------- |
| 多设备同步 | ⚠️ 版本冲突 | ✅ CRDT 自动合并 |
| 并发编辑   | ❌          | ✅ 字段级合并    |
| 离线使用   | ❌          | ✅ 完全支持      |
| 冲突恢复   | ❌          | ✅ 审计日志      |
| 可扩展性   | ⚠️ 单服务器 | ✅ 微服务        |

### 性能指标

```
目标性能:

吞吐量:
- 单设备: 100+ ops/sec
- 服务器: 10,000+ sync/sec

延迟:
- 加密/解密: < 100ms
- 同步 RTT: < 500ms (P99)
- 冲突合并: < 50ms

容量:
- 单用户密码: 100万+
- 并发用户: 100万+
- 日活用户: 10万+
```

---

## 相关文档

1. **STORAGE_AND_SYNC_ARCHITECTURE_REPORT.md**
   - 详细的现状分析
   - 业内方案对比
   - 完整的架构设计

2. **MICROSERVICES_IMPLEMENTATION_PLAN.md**
   - 微服务详细设计
   - API 规范
   - 数据库 Schema
   - 部署架构
   - 安全设计

3. **technical-implementation-guide.md**
   - 客户端实现代码
   - 加密服务完整代码
   - 单元/集成测试
   - 实现时间表

---

## 关键决策点

### 1. 加密方案选择

✅ **选择: AES-256-GCM + PBKDF2+Scrypt**

原因:
- AES-256-GCM: 行业标准，性能好，提供认证
- PBKDF2: 标准密钥派生，广泛支持
- Scrypt: 抗暴力破解，内存难度高

替代方案:
- ❌ ChaCha20-Poly1305: 性能略好但支持度不如 AES
- ❌ Argon2: 更先进但依赖库较少

### 2. 同步策略选择

✅ **选择: CRDT + 向量时钟**

原因:
- CRDT: 支持离线编辑和自动合并
- 向量时钟: 准确的因果一致性检测
- 字段级合并: 最小化数据丢失

替代方案:
- ❌ Operational Transform (OT): 复杂度高，不适合非线性结构
- ❌ 强一致性 (Strong Consistency): 离线时无法使用

### 3. 服务架构选择

✅ **选择: 微服务 (4服务)**

原因:
- Auth Service: 独立认证，便于扩展
- Sync Service: 核心同步逻辑，可独立扩展
- Account Service: 账号管理，可缓存
- Device Service: 设备管理，轻量级

替代方案:
- ❌ 单体应用: 难以扩展
- ❌ 过度微服务化 (> 8): 运维复杂

---

## 成本估计

### 开发成本

```
E2EE 加密实现:      200 小时
本地同步准备:       120 小时
后端服务开发:       300 小时
客户端集成:         200 小时
测试和文档:         200 小时
───────────────────────────
总计:              1020 小时 ≈ 5-6个月 (一个2人团队)
```

### 基础设施成本（AWS 示例，月度）

```
PostgreSQL (db.t3.medium):     $50
Redis (cache.t3.micro):        $15
Elastic Load Balancer:         $20
2x EC2 (t3.small):            $40
S3 备份存储:                  $10
数据传输:                     $50
───────────────────────────
总计:                    ≈ $185/月
```

---

## 风险评估

### 高风险

| 风险     | 影响         | 缓解措施                   |
| -------- | ------------ | -------------------------- |
| 密钥丢失 | 数据无法恢复 | 实现密钥恢复流程、秘密问答 |
| 同步冲突 | 数据不一致   | CRDT 合并、完整测试        |

### 中风险

| 风险     | 影响     | 缓解措施           |
| -------- | -------- | ------------------ |
| 性能问题 | 同步慢   | 性能测试、缓存优化 |
| 数据库锁 | 并发问题 | 乐观锁、分布式锁   |

### 低风险

| 风险         | 影响     | 缓解措施           |
| ------------ | -------- | ------------------ |
| 依赖版本问题 | 编译失败 | 依赖锁定、持续集成 |

---

## 后续步骤

1. **立即行动** (本周)
   - [ ] 团队技术审查
   - [ ] 确认资源和时间表
   - [ ] 建立开发环境

2. **第1周**
   - [ ] 启动 E2EE 开发
   - [ ] 设置持续集成
   - [ ] 建立安全审计流程

3. **第2-3周**
   - [ ] E2EE 测试完成
   - [ ] 启动后端开发
   - [ ] 安全审查

4. **全程**
   - [ ] 每周技术同步
   - [ ] 持续的安全审计
   - [ ] 性能基准测试

---

## 总结

这个方案将 SecretRoy 从一个不安全的密码管理器转变为一个**行业级的加密系统**，具有:

✅ **完全的端到端加密** - 密码数据永远不被服务器看到  
✅ **自动冲突合并** - 多设备编辑不会丢失数据  
✅ **离线优先** - 网络不稳定仍可正常使用  
✅ **企业级可靠性** - 微服务架构支持百万用户  
✅ **完整审计日志** - 所有操作可追溯  

预期成为**与 1Password、Bitwarden 同等水平的密码管理系统**。

---

**建议**: 立即启动第1阶段（E2EE），同时做好未来3个月的开发计划。
