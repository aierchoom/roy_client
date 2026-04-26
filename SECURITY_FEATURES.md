# SecretRoy 密码管理器 - 安全功能实现

本文档描述了根据安全架构分析与改进方案实现的新安全功能。

## 已实现的安全功能

### 1. 增强加密服务 (EnhancedCryptoService)

**文件**: `lib/services/enhanced_crypto_service.dart`

#### 主要改进
- **升级PBKDF2参数**: 迭代次数从100,000提升到600,000 (OWASP 2023推荐)
- **密钥派生版本管理**: 支持密钥派生算法的版本控制，便于未来升级
- **向后兼容**: 支持从旧版本(v1)平滑迁移到新版本(v2)
- **子密钥派生**: 使用HKDF为不同用途派生独立密钥

#### 核心功能
```dart
// 初始化主密钥（自动处理版本）
await cryptoService.initMasterKey(password);

// 升级密钥派生版本
await cryptoService.upgradeKdfVersion(currentPassword);

// 派生子密钥
final syncKey = await cryptoService.deriveSubKey('sync_encryption_key');

// 密码生成与强度评估
final password = EnhancedCryptoService.generatePassword(length: 16);
final strength = EnhancedCryptoService.calculatePasswordStrength(password);
```

---

### 2. 生物识别认证 (BiometricAuthService)

**文件**: `lib/services/biometric_auth_service.dart`

#### 主要功能
- **多生物识别类型**: 支持指纹、面容识别、虹膜识别
- **安全存储**: 使用生物识别加密保护主密钥
- **状态管理**: 检测生物识别可用性和启用状态

#### 核心功能
```dart
// 检查生物识别状态
final status = await biometricService.getStatus();
// 返回: enabled, available, notSupported, notEnrolled, disabled

// 启用生物识别
final result = await biometricService.enableBiometric(currentPassword);

// 使用生物识别解锁
final password = await biometricService.unlockWithBiometric();
```

---

### 3. 自动锁定机制 (AutoLockService)

**文件**: `lib/services/auto_lock_service.dart`

#### 主要功能
- **后台自动锁定**: 应用切换到后台后自动计时
- **可配置超时**: 支持立即、5秒、30秒、1分钟、5分钟、10分钟、永不
- **生命周期监听**: 监听应用生命周期状态变化
- **跨会话持久化**: 保存最后活动时间，下次启动时检查

#### 核心功能
```dart
// 初始化（恢复上次状态）
await autoLockService.initialize();

// 设置自动锁定时间
await autoLockService.setDuration(AutoLockDuration.oneMinute);

// 监听生命周期（需在App中注册）
WidgetsBinding.instance.addObserver(AutoLockObserver(autoLockService));
```

---

### 4. 加密数据库存储 (SecureStorageService)

**文件**: `lib/services/secure_storage_service.dart`

#### 主要改进
- **SQLCipher**: 使用AES-256加密数据库替代SharedPreferences
- **数据完整性**: 数据库级加密保护所有存储数据
- **表结构**: 账号表、模板表、设置表、同步元数据表
- **流式通知**: 数据变更实时通知

#### 核心功能
```dart
// 初始化（使用主密码作为数据库密钥）
await secureStorageService.initialize(password);

// 账号CRUD操作
final accounts = await secureStorageService.loadAccounts();
await secureStorageService.saveAccount(account);
await secureStorageService.deleteAccount(id);

// 搜索功能
final results = await secureStorageService.searchAccounts('query');

// 从旧存储迁移
await secureStorageService.migrateFromOldStorage(oldAccounts, oldTemplates);
```

---

### 5. 端到端加密同步 (SyncService)

**文件**: `lib/sync/sync_service.dart`, `lib/sync/vector_clock.dart`, `lib/sync/conflict_resolver.dart`

#### 主要功能
- **WebSocket实时同步**: 支持双向实时同步通知
- **向量时钟**: 实现分布式系统的逻辑时钟和冲突检测
- **自动冲突解决**: 支持最后写入胜出、自动合并(CRDT)、手动解决
- **设备密钥**: 使用Ed25519签名保证数据完整性
- **端到端加密**: 服务器仅存储密文，无法读取用户数据

#### 向量时钟
```dart
final clock = VectorClock();
clock.increment(deviceId);

// 比较时钟
final relation = VectorClock.compare(localClock, remoteClock);
// 返回: equal, before, after, concurrent
```

#### 冲突解决
```dart
final result = ConflictResolver.resolve(
  local: localData,
  remote: remoteData,
  strategy: ConflictStrategy.autoMerge,
  deviceId: deviceId,
);
```

#### 同步服务
```dart
// 初始化
await syncService.initialize();

// 连接服务器
await syncService.connect(authToken);

// 执行同步
final result = await syncService.syncNow();

// 监听状态
syncService.onStateChange.listen((state) {
  // SyncState.offline, .connecting, .connected, .syncing, .synced, .error
});
```

---

### 6. 统一服务管理器 (ServiceManager)

**文件**: `lib/services/service_manager.dart`

#### 主要功能
- **单例模式**: 全局统一管理所有服务
- **解锁流程**: 统一处理密码解锁和生物识别解锁
- **生命周期管理**: 自动处理应用生命周期和安全状态
- **便捷访问**: 提供所有服务的统一访问接口

#### 核心功能
```dart
// 获取实例
final manager = ServiceManager.instance;

// 初始化
await manager.initialize();

// 解锁
final result = await manager.unlockWithPassword(password);
final result = await manager.unlockWithBiometric();

// 数据操作
final accounts = await manager.loadAccounts();
await manager.saveAccount(account);

// 同步
await manager.connectToSyncServer(token);
await manager.syncNow();

// 生物识别管理
await manager.enableBiometric(password);
await manager.disableBiometric();

// 自动锁定设置
await manager.setAutoLockDuration(AutoLockDuration.fiveMinutes);
```

---

## 新增依赖

在 `pubspec.yaml` 中添加:

```yaml
dependencies:
  # 生物识别
  local_auth: ^2.3.0
  local_auth_android: ^1.0.34
  local_auth_ios: ^1.1.6

  # 加密数据库
  sqflite_sqlcipher: ^3.1.0+1
  sqflite_common_ffi: ^2.3.5
  path: ^1.9.0
  path_provider: ^2.1.4

  # 同步
  web_socket_channel: ^3.0.1
  uuid: ^4.5.1
```

---

## UI界面

### 解锁页面 (UnlockView)
支持主密码和生物识别两种解锁方式

### 安全设置页面 (SecuritySettingsView)
配置自动锁定时间、生物识别、密码生成器、同步设置

---

## 安全最佳实践

1. **密钥管理**: 主密钥仅存在于内存中，不持久化存储
2. **数据库加密**: SQLCipher使用AES-256加密，密钥由用户主密码派生
3. **生物识别保护**: 生物识别加密保护主密码，而非直接解锁
4. **自动锁定**: 应用后台运行时自动清除内存中的敏感数据
5. **端到端加密**: 同步数据在离开设备前已加密，服务器无法解密
6. **签名验证**: 所有同步数据使用Ed25519签名，防止篡改

---

## 迁移指南

### 从旧版本迁移

应用启动时会自动检查并迁移旧数据：

1. 加密服务会自动检测并支持旧版本(v1)的盐值格式
2. SecureStorageService提供 `migrateFromOldStorage()` 方法迁移数据
3. 密钥派生版本可通过 `upgradeKdfVersion()` 升级

---

## 未来扩展

1. **Argon2id支持**: 未来可升级密钥派生算法到Argon2id
2. **多服务器联邦**: 实现Raft共识的多服务器架构
3. **紧急恢复**: 支持助记词恢复机制
4. **审计日志**: 记录所有安全相关操作
