# 架构概览

**版本**: v1.1.0
**最后更新**: 2026-04-28

> Current implementation delta (2026-04-28): master password verification is handled by `EnhancedCryptoService` with PBKDF2-HMAC-SHA256 storage and legacy `master_password_v1` migration. Secure vault link codes use `sroy-secure-v2:` with PBKDF2-HMAC-SHA256 plus AES-GCM-256. LAN pairing now uses 8 readable characters via `LanPairingCodeDialog`; see [../07_Key_Sync_Implementation.md](../07_Key_Sync_Implementation.md).

---

## 目录

1. [系统架构](#1-系统架构)
2. [技术栈](#2-技术栈)
3. [核心模块](#3-核心模块)
4. [数据流](#4-数据流)
5. [安全架构](#5-安全架构)
6. [同步架构](#6-同步架构)

---

## 1. 系统架构

### 1.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        SecretRoy Client                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   Views     │  │  Providers  │  │      Widgets            │ │
│  │  (UI Layer) │←→│  (State)    │  │  (Components)           │ │
│  └──────┬──────┘  └──────┬──────┘  └─────────────────────────┘ │
│         │                │                                      │
│         └────────────────┼──────────────────────────────────────┤
│                          ▼                                      │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                    Services Layer                          │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐  │ │
│  │  │  Secure     │ │   Vault     │ │    Sync             │  │ │
│  │  │  Storage    │ │   Crypto    │ │    Service          │  │ │
│  │  └─────────────┘ └─────────────┘ └─────────────────────┘  │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐  │ │
│  │  │  CRDT       │ │  Identity   │ │   LAN               │  │ │
│  │  │  Merge      │ │  Service    │ │   Pairing           │  │ │
│  │  └─────────────┘ └─────────────┘ └─────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                          │                                      │
│                          ▼                                      │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                    Data Layer                              │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐  │ │
│  │  │  Models     │ │   Local     │ │    Cache            │  │ │
│  │  │             │ │   Storage   │ │                     │  │ │
│  │  └─────────────┘ └─────────────┘ └─────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │   Sync Server (可选)    │
              │   (Node.js + Express)  │
              └────────────────────────┘
```

### 1.2 分层说明

| 层级 | 职责 | 关键文件 |
|------|------|----------|
| **表现层** | UI 渲染、用户交互 | `lib/views/`, `lib/widgets/` |
| **状态层** | 应用状态管理 | `lib/providers/` |
| **服务层** | 业务逻辑、加密、同步 | `lib/services/` |
| **数据层** | 数据模型、持久化 | `lib/models/` |

---

## 2. 技术栈

### 2.1 前端技术

| 技术 | 版本 | 用途 |
|------|------|------|
| Flutter | 3.x | 跨平台 UI 框架 |
| Dart | 3.x | 编程语言 |
| Provider | ^6.0 | 状态管理 |
| FlutterSecureStorage | ^10.0 | 安全存储 |
| SharedPreferences | ^2.0 | 本地配置 |
| Intl | ^0.18 | 国际化 |

### 2.2 同步技术

| 技术 | 用途 |
|------|------|
| CRDT | 无冲突复制数据类型 |
| HLC | 混合逻辑时钟 |
| HTTP/HTTPS | 同步协议传输 |
| WebSocket | 实时通信（可选） |

### 2.3 加密技术

| 技术 | 用途 |
|------|------|
| AES-GCM-256 | 安全 Vault 链接码加密 |
| HMAC-SHA256 | 完整性校验 |
| PBKDF2 | 密钥派生 |
| SecureRandom | 随机数生成 |

---

## 3. 核心模块

### 3.1 模块依赖图

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  enhanced   │────→│   secure    │────→│   models    │
│  _app_      │     │   _storage  │     │             │
│  provider   │     │  _service   │     │             │
└──────┬──────┘     └─────────────┘     └─────────────┘
       │
       │     ┌─────────────┐
       └────→│    sync     │
             │  _service   │
             └──────┬──────┘
                    │
       ┌────────────┼────────────┐
       ▼            ▼            ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│    crdt     │ │   vault     │ │    lan      │
│   _merge    │ │   _crypto   │ │  _pairing   │
│   _engine   │ │  _service   │ │  _service   │
└─────────────┘ └─────────────┘ └─────────────┘
```

### 3.2 核心服务

#### SecureStorageService

负责数据的本地持久化和加密存储。

```dart
class SecureStorageService {
  // Vault 操作
  Future<Vault?> loadVault();
  Future<void> saveVault(Vault vault);
  
  // 账户操作
  Future<List<Account>> loadAccounts();
  Future<void> saveAccounts(List<Account> accounts);
  
  // 模板操作
  Future<List<AccountTemplate>> loadTemplates();
  Future<void> saveTemplates(List<AccountTemplate> templates);
}
```

#### EnhancedCryptoService

负责主密码设置、验证和遗留明文主密码迁移。Vault 链接码的加解密由 `IdentityService` 通过 `sroy-secure-v2:` 信封处理。

```dart
class EnhancedCryptoService {
  bool get hasMasterKey;
  Future<bool> initMasterKey(String password);
  Future<bool> verifyMasterPassword(String password);
  Future<bool> updateMasterPassword(String oldPassword, String newPassword);
  void logout();
}
```

#### SyncService

负责与同步服务器的通信。

```dart
class SyncService {
  // 连接管理
  Future<bool> connect(String serverUrl);
  Future<void> disconnect();
  
  // 同步操作
  Future<SyncResult> syncNow();
  Future<void> scheduleSync();
  
  // 状态查询
  SyncState get state;
  Stream<SyncState> get stateStream;
}
```

#### CRDTMergeEngine

负责处理多设备数据合并。

```dart
class CRDTMergeEngine {
  // 合并操作
  MergeResult merge(Vault local, Vault remote);
  
  // 冲突检测
  List<Conflict> detectConflicts(Vault local, Vault remote);
  
  // 冲突解决
  Vault resolveConflicts(Vault vault, List<ConflictResolution> resolutions);
}
```

### 3.3 状态管理

使用 Provider 进行全局状态管理：

```dart
class EnhancedAppProvider extends ChangeNotifier {
  // 数据状态
  List<Account> _accounts = [];
  List<AccountTemplate> _templates = [];
  
  // 同步状态
  SyncState _syncState = SyncState.offline;
  
  // 操作方法
  Future<void> loadAccounts();
  Future<void> saveAccount(Account account);
  Future<void> deleteAccount(String accountId);
}
```

---

## 4. 数据流

### 4.1 账户创建流程

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│   UI     │───→│ Provider │───→│ Service  │───→│ Storage  │
│ (Input)  │    │ (State)  │    │ (Logic)  │    │ (Persist)│
└──────────┘    └──────────┘    └──────────┘    └──────────┘
     │               │               │               │
     │ 1. 用户输入   │               │               │
     │──────────────→│               │               │
     │               │ 2. 验证数据   │               │
     │               │──────────────→│               │
     │               │               │ 3. 加密敏感字段│
     │               │               │──────────────→│
     │               │               │               │ 4. 持久化
     │               │               │               │──→ 文件系统
     │               │ 5. 更新状态   │               │
     │               │←──────────────│               │
     │ 6. UI 刷新    │               │               │
     │←──────────────│               │               │
```

### 4.2 同步流程

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Local   │    │   Sync   │    │  Server  │    │  Remote  │
│  Vault   │    │  Service │    │          │    │  Vault   │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
     │               │               │               │
     │ 1. 本地变更   │               │               │
     │──────────────→│               │               │
     │               │ 2. 推送变更   │               │
     │               │──────────────→│               │
     │               │               │ 3. 存储       │
     │               │               │──→ 文件       │
     │               │ 4. 拉取远程   │               │
     │               │──────────────→│               │
     │               │←──────────────│               │
     │               │ 5. 远程变更   │               │
     │ 6. CRDT 合并  │               │               │
     │←──────────────│               │               │
     │ 7. 解决冲突   │               │               │
     │──────────────→│               │               │
```

---

## 5. 安全架构

### 5.1 加密模型

```
┌─────────────────────────────────────────────────────────┐
│                    用户主密码                            │
└─────────────────────┬───────────────────────────────────┘
                      │ PBKDF2 (100,000 iterations)
                      ▼
┌─────────────────────────────────────────────────────────┐
│                    派生密钥 (256-bit)                    │
└─────────────────────┬───────────────────────────────────┘
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│   加密密钥       │     │   HMAC 密钥      │
│   (AES-GCM)     │     │   (SHA-256)     │
└────────┬────────┘     └────────┬────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│   数据加密       │     │   完整性签名     │
└─────────────────┘     └─────────────────┘
```

### 5.2 数据保护

| 数据类型 | 存储位置 | 加密方式 |
|----------|----------|----------|
| 主密码 | 不存储 | 仅内存中派生密钥 |
| Vault 密钥 | Keychain/Keystore | 系统级加密 |
| 账户数据 | 应用沙盒 | 本地持久化 + 同步载荷完整性保护 |
| 敏感字段 | 应用沙盒 | 额外加密标记 |
| 同步数据 | 传输中 | TLS + 端到端加密 |

### 5.3 密钥管理

```dart
// 密钥派生
class KeyDerivation {
  static Future<DerivedKeys> derive(String masterPassword, Salt salt) {
    // PBKDF2-HMAC-SHA256
    final bytes = await PBKDF2(
      password: masterPassword,
      salt: salt,
      iterations: 100000,
      keyLength: 64,  // 两个 256-bit 密钥
    );
    
    return DerivedKeys(
      encryptionKey: bytes.sublist(0, 32),
      hmacKey: bytes.sublist(32, 64),
    );
  }
}
```

---

## 6. 同步架构

### 6.1 CRDT 实现

SecretRoy 使用 **State-based CRDT** 实现数据同步：

```
┌─────────────────────────────────────────────────────────┐
│                    Account CRDT                          │
├─────────────────────────────────────────────────────────┤
│  accountId: string                                       │
│  fields: Map<fieldKey, FieldValue>                      │
│  tombstone: boolean                                      │
│  hlc: HybridLogicalClock  // 每个字段的时间戳           │
│  deviceId: string                                        │
└─────────────────────────────────────────────────────────┘

合并规则 (LWW - Last Writer Wins):
1. 比较 HLC 时间戳
2. 时间戳大者胜出
3. 相同时间戳时，deviceId 字典序决定
```

### 6.2 HLC (Hybrid Logical Clock)

```dart
class HybridLogicalClock {
  final int physicalTime;  // 物理时间戳
  final int logicalCount;  // 逻辑计数器
  final String deviceId;   // 设备标识
  
  // 比较操作
  bool operator <(HybridLogicalClock other);
  
  // 合并操作
  HybridLogicalClock merge(HybridLogicalClock other);
  
  // 递增操作
  HybridLogicalClock tick();
}
```

### 6.3 同步协议

```
客户端                          服务器
   │                              │
   │──── POST /sync/pull ────────→│
   │     { vaultId, sinceVersion }│
   │                              │
   │←─── 200 OK ──────────────────│
   │     { items, maxVersion }    │
   │                              │
   │──── POST /sync/push ────────→│
   │     { vaultId, items }       │
   │                              │
   │←─── 200 OK ──────────────────│
   │     { success, newVersion }  │
   │                              │
```

### 6.4 冲突处理

```
┌─────────────────────────────────────────────────────────┐
│                    冲突检测流程                          │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  1. 检测同一字段的并发修改                               │
│     if (local.hlc != remote.hlc &&                      │
│         local.baseVersion == remote.baseVersion)        │
│                                                          │
│  2. 自动合并策略                                         │
│     - 不同字段：直接合并                                 │
│     - 同字段不同值：HLC 决定胜者                         │
│                                                          │
│  3. 人工干预                                             │
│     - 标记冲突账户                                       │
│     - 显示在冲突收件箱                                   │
│     - 用户选择保留版本                                   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 附录

### A. 文件结构

```
lib/
├── main.dart
├── app.dart
├── models/
│   ├── account.dart
│   ├── account_template.dart
│   ├── vault.dart
│   └── sync_state.dart
├── services/
│   ├── secure_storage_service.dart
│   ├── enhanced_crypto_service.dart
│   ├── sync_service.dart
│   ├── crdt_merge_engine.dart
│   ├── identity_service.dart
│   └── lan_pairing_service.dart
├── providers/
│   └── enhanced_app_provider.dart
├── views/
│   ├── accounts/
│   ├── templates/
│   └── sync_settings_view.dart
├── widgets/
├── l10n/
└── utils/
```

### B. 关键配置

```yaml
# pubspec.yaml 关键依赖
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  flutter_secure_storage: ^10.0.0
  shared_preferences: ^2.0.0
  http: ^1.0.0
  crypto: ^3.0.0
  intl: ^0.18.0
```

---

**文档版本**: 1.0
**最后更新**: 2026-04-28
