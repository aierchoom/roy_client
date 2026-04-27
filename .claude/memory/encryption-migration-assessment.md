---
name: encryption-migration-assessment
description: 加密方案迁移可行性评估报告
type: project
---

# 加密方案迁移可行性评估

## 一、当前实现分析

### 1.1 加密流程

**位置**: [sync_payload_codec.dart](lib/sync/sync_payload_codec.dart)

```
加密流程:
1. 密钥派生: SHA-256("sync-payload-encryption|{vaultId}|{symmetricKey}")
2. MAC密钥派生: SHA-256("sync-payload-mac|{vaultId}|{privateKey}|{symmetricKey}")
3. 生成16字节随机Nonce
4. 加密: XOR流密码 (使用SHA-256作为密钥流生成器)
5. MAC: HMAC-SHA256(version|vaultId|nodeId|nonce|ciphertext)
```

### 1.2 安全特性

| 特性 | 实现 | 评估 |
|------|------|------|
| 机密性 | XOR流密码 | ⚠️ 非标准 |
| 完整性 | HMAC-SHA256 | ✅ 标准 |
| 认证 | MAC验证 | ✅ 有 |
| Nonce重用 | 16字节随机 | ✅ 低概率 |

### 1.3 潜在风险

1. **自定义加密方案**: 未经过专业密码学审计
2. **加密与认证分离**: 应使用AEAD（认证加密）
3. **密钥派生简单**: 应使用HKDF或PBKDF2

---

## 二、迁移方案评估

### 2.1 方案A: 迁移到AES-256-GCM

**优点**:
- 行业标准认证加密
- 硬件加速支持广泛
- 库支持成熟

**缺点**:
- 需要添加`pointycastle`依赖
- Dart原生性能不如平台原生

**兼容性策略**:
```dart
// 检测格式版本，自动选择解密方式
if (envelope['version'] == 1) {
  return _decodeLegacyXOR(envelope);  // 旧格式
} else if (envelope['version'] == 2) {
  return _decodeAESGCM(envelope);     // 新格式
}
```

### 2.2 方案B: 迁移到ChaCha20-Poly1305

**优点**:
- 现代认证加密算法
- 软件实现性能好
- Google推荐

**缺点**:
- 同样需要`pointycastle`
- 支持不如AES广泛

### 2.3 方案C: 保持现状，增强文档

**优点**:
- 零风险
- 零迁移成本

**缺点**:
- 安全性问题未解决

---

## 三、依赖分析

### 3.1 当前依赖

```yaml
crypto: ^3.0.7  # 仅提供哈希和HMAC
```

### 3.2 需要添加

```yaml
pointycastle: ^3.7.3  # 提供AES-GCM, ChaCha20-Poly1305
```

### 3.3 替代方案

```yaml
encrypt: ^5.0.1  # 基于pointycastle的高级API
```

---

## 四、迁移路径

### Phase 1: 准备阶段（1-2天）

1. 添加`pointycastle`依赖
2. 实现AES-256-GCM加密/解密封装
3. 编写单元测试

### Phase 2: 兼容性实现（2-3天）

1. 修改`SyncPayloadCodec`支持版本检测
2. 保留旧格式解密能力
3. 新数据使用新格式加密

### Phase 3: 渐进迁移（持续）

1. 新设备优先使用新格式
2. 旧设备自动升级
3. 监控兼容性问题

---

## 五、风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 格式不兼容 | 中 | 高 | 版本检测 + 双格式支持 |
| 性能下降 | 低 | 中 | 性能基准测试 |
| 依赖问题 | 低 | 中 | 锁定版本号 |

---

## 六、建议

### 短期（建议立即执行）

1. **增强文档**: 明确说明当前加密方案的设计决策
2. **安全审计**: 如果项目用于生产，建议进行专业安全审计

### 中期（建议在下一个版本）

1. **添加pointycastle依赖**
2. **实现AES-256-GCM封装**
3. **修改SyncPayloadCodec支持双格式**

### 长期

1. **所有新数据使用新格式**
2. **监控迁移进度**
3. **最终移除旧格式支持**

---

## 七、结论

**当前风险等级**: 中等

当前实现虽然有自定义加密方案，但：
1. 有MAC保护完整性
2. 有Nonce防止重放
3. 密钥派生有分层设计

**迁移建议**: 
- 如果项目用于个人/内部使用：可暂缓迁移
- 如果项目用于生产/商业：建议在专业审计后决定迁移方案

**Why**: 迁移需要权衡风险与收益。自定义加密虽然不是最佳实践，但当前实现的基本安全属性是存在的。

**How to apply**: 根据项目使用场景和资源情况，选择适当的迁移时机。
