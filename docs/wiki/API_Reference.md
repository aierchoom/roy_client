# API 参考

**版本**: v1.1.0
**最后更新**: 2026-04-28

---

## 目录

1. [服务 API](#1-服务-api)
2. [Provider API](#2-provider-api)
3. [同步 API](#3-同步-api)
4. [加密 API](#4-加密-api)
5. [存储 API](#5-存储-api)

---

## 1. 服务 API

### 1.1 ServiceManager

服务管理器，全局单例，管理所有服务实例。

```dart
class ServiceManager {
  /// 单例实例
  static ServiceManager get instance;

  /// 默认同步服务器地址
  static const String defaultSyncServerUrl = 'https://sync.secretroy.com';

  /// 安全存储服务
  SecureStorageService get storage;

  /// 同步服务
  SyncService get sync;

  /// 身份服务
  IdentityService get identity;

  /// LAN 配对服务
  LanPairingService get lanPairing;

  /// Vault 配对服务
  VaultPairingService get vaultPairing;

  /// 初始化所有服务
  Future<void> initialize();

  /// 释放所有服务
  Future<void> dispose();
}
```

**使用示例**:
```dart
// 获取服务实例
final storage = ServiceManager.instance.storage;

// 初始化
await ServiceManager.instance.initialize();
```

### 1.2 SecureStorageService

安全存储服务，负责数据持久化。

```dart
class SecureStorageService {
  // === Vault 操作 ===

  /// 加载 Vault
  Future<Vault?> loadVault();

  /// 保存 Vault
  Future<void> saveVault(Vault vault);

  // === 账户操作 ===

  /// 加载所有账户
  Future<List<AccountItem>> loadAccounts();

  /// 保存账户列表
  Future<void> saveAccounts(List<AccountItem> accounts);

  /// 加载单个账户
  Future<AccountItem?> loadAccount(String id);

  /// 保存单个账户
  Future<void> saveAccount(AccountItem account);

  /// 删除账户
  Future<void> deleteAccount(String id);

  // === 模板操作 ===

  /// 加载所有模板
  Future<List<AccountTemplate>> loadTemplates();

  /// 保存模板列表
  Future<void> saveTemplates(List<AccountTemplate> templates);

  /// 加载未同步的模板
  Future<List<AccountTemplate>> loadDirtyTemplates();

  // === 同步状态 ===

  /// 加载同步状态
  Future<SyncState?> loadSyncState();

  /// 保存同步状态
  Future<void> saveSyncState(SyncState state);
}
```

---

## 2. Provider API

### 2.1 EnhancedAppProvider

全局状态管理 Provider。

```dart
class EnhancedAppProvider extends ChangeNotifier {
  // === 数据状态 ===

  /// 所有账户
  List<AccountItem> get accounts;

  /// 所有模板
  List<AccountTemplate> get templates;

  /// 当前同步状态
  SyncState get syncState;

  /// 同步状态流
  Stream<SyncState> get syncStateStream;

  // === 账户操作 ===

  /// 加载账户数据
  Future<void> loadAccounts();

  /// 保存账户
  Future<void> saveAccount(AccountItem account);

  /// 删除账户
  Future<void> deleteAccount(String accountId);

  /// 按模板统计账户数
  int countAccountsByTemplate(String templateId);

  // === 模板操作 ===

  /// 加载模板数据
  Future<void> loadTemplates();

  /// 保存模板
  Future<void> saveTemplate(AccountTemplate template);

  /// 删除模板
  Future<void> deleteTemplate(String templateId);

  // === 同步操作 ===

  /// 连接同步服务器
  Future<bool> connectToSyncServer(String serverUrl);

  /// 断开同步
  Future<void> disconnectSync();

  /// 执行同步
  Future<SyncResult> syncNow();

  /// 获取同步错误
  String? get syncError;

  /// 清除同步错误
  void clearSyncError();

  // === 冲突管理 ===

  /// 获取冲突列表
  List<ConflictItem> get conflicts;

  /// 解决冲突
  Future<void> resolveConflict(String conflictId, Resolution resolution);
}
```

**使用示例**:
```dart
// 在 Widget 中使用
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EnhancedAppProvider>();

    return ListView.builder(
      itemCount: provider.accounts.length,
      itemBuilder: (context, index) {
        final account = provider.accounts[index];
        return ListTile(title: Text(account.name));
      },
    );
  }
}

// 修改数据
Future<void> addAccount(BuildContext context, AccountItem account) async {
  final provider = context.read<EnhancedAppProvider>();
  await provider.saveAccount(account);
}
```

---

## 3. 同步 API

### 3.1 SyncService

同步服务，处理与服务器的通信。

```dart
class SyncService {
  /// 当前状态
  SyncState get state;

  /// 状态变化流
  Stream<SyncState> get stateStream;

  /// 当前服务器地址
  String? get serverUrl;

  /// 是否已连接
  bool get isConnected;

  /// 连接服务器
  /// 返回 true 表示连接成功
  Future<bool> connect(String serverUrl);

  /// 断开连接
  Future<void> disconnect();

  /// 执行同步
  Future<SyncResult> syncNow();

  /// 调度同步（延迟执行）
  void scheduleSync({Duration delay = const Duration(seconds: 5)});

  /// 取消待执行的同步
  void cancelScheduledSync();

  /// 设置同步间隔
  void setSyncInterval(Duration interval);

  /// 手动触发推送
  Future<void> pushChanges();

  /// 手动触发拉取
  Future<PullResult> pullChanges();
}
```

**SyncState 枚举**:
```dart
enum SyncState {
  /// 离线
  offline,

  /// 同步中
  syncing,

  /// 冲突恢复中
  conflictRecovery,

  /// 已同步
  synced,

  /// 错误状态
  error,
}
```

**SyncResult 结构**:
```dart
class SyncResult {
  /// 是否成功
  final bool success;

  /// 错误信息（如果失败）
  final String? error;

  /// 推送的账户数
  final int pushedCount;

  /// 拉取的账户数
  final int pulledCount;

  /// 检测到的冲突数
  final int conflictCount;

  /// 新服务器版本
  final int newVersion;
}
```

### 3.2 CRDTMergeEngine

CRDT 合并引擎，处理数据合并。

```dart
class CRDTMergeEngine {
  /// 设备 ID
  final String deviceId;

  /// 合并两个 Vault
  MergeResult merge(Vault local, Vault remote);

  /// 检测冲突
  List<Conflict> detectConflicts(Vault local, Vault remote);

  /// 应用冲突解决
  Vault applyResolutions(Vault vault, List<ConflictResolution> resolutions);

  /// 合并单个账户
  AccountItem mergeAccount(AccountItem local, AccountItem remote);

  /// 合并字段值
  MapEntry<String, String> mergeField(
    String key,
    String localValue,
    String remoteValue,
    Hlc localHlc,
    Hlc remoteHlc,
  );
}
```

**MergeResult 结构**:
```dart
class MergeResult {
  /// 合并后的 Vault
  final Vault merged;

  /// 是否有冲突
  final bool hasConflicts;

  /// 冲突列表
  final List<Conflict> conflicts;

  /// 合并统计
  final MergeStats stats;
}

class MergeStats {
  final int localWins;
  final int remoteWins;
  final int autoMerged;
  final int conflicts;
}
```

### 3.3 LanPairingService

局域网配对服务。

```dart
class LanPairingService {
  /// 创建主机会话
  /// 返回 8 位可读配对码
  Future<LanPairingHostSession> startHosting();

  /// 停止主机会话
  Future<void> stopHosting();

  /// 加入主机会话
  Future<LanPairingJoinResult> join(String pairingCode);

  /// 取消加入
  Future<void> cancelJoin();

  /// 当前主机会话
  LanPairingHostSession? get hostSession;

  /// 当前加入结果
  LanPairingJoinResult? get joinResult;

  /// 是否正在配对
  bool get isPairing;
}
```

---

## 4. 加密 API

### 4.1 EnhancedCryptoService

主密码服务。

```dart
class EnhancedCryptoService {
  bool get hasMasterKey;

  /// 初始化主密码；首次使用会创建 PBKDF2 记录
  Future<bool> initMasterKey(String masterPassword);

  /// 校验主密码
  Future<bool> verifyMasterPassword(String masterPassword);

  /// 修改主密码
  Future<bool> updateMasterPassword(
    String oldPassword,
    String newPassword,
  );

  /// 锁定当前会话
  void logout();
}
```

Current implementation note:

- `EnhancedCryptoService` handles master password verification with `master_password_v2` PBKDF2-HMAC-SHA256 hashes and migrates legacy `master_password_v1` after successful verification.
- Secure vault link codes use `sroy-secure-v2:` with PBKDF2-HMAC-SHA256 and AES-GCM-256.
- `sroy-secure-v1:` import remains supported only for legacy compatibility.

---

## 5. 存储 API

### 5.1 IdentityService

身份服务，管理设备身份。

```dart
class IdentityService {
  /// 获取或创建设备 ID
  Future<String> getDeviceId();

  /// 获取设备信息
  Future<DeviceInfo> getDeviceInfo();

  /// 检查是否已初始化
  Future<bool> isInitialized();

  /// 重置身份（清除所有数据）
  Future<void> reset();
}
```

Current key sync API:

```dart
class IdentityService {
  String exportTransferCode({String? syncServerUrl, String? vaultDump});

  Future<Map<String, String?>> importTransferCode(String rawCode);

  Future<String> exportSecureLinkCode(
    String password, {
    String? syncServerUrl,
    String? vaultDump,
  });

  Future<Map<String, String?>> importSecureLinkCode(
    String secureCode,
    String password,
  );
}
```

Notes:

- `exportSecureLinkCode` emits `sroy-secure-v2:` codes.
- `sroy-secure-v2:` uses PBKDF2-HMAC-SHA256 and AES-GCM-256.
- Imports preserve the local `deviceId` and replace only vault-level identity fields.
- `sroy-secure-v1:` import remains available for legacy compatibility.

LAN pairing code contract:

- `LanPairingService.normalizePairingCode(...)` accepts exactly 8 readable characters.
- Allowed alphabet: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`.
- Whitespace is removed and letters are uppercased before validation.

### 5.2 本地存储键名

| 键名 | 用途 | 类型 |
|------|------|------|
| `vault_data` | Vault 主数据 | JSON |
| `device_id` | 设备 ID | String |
| `sync_server_url` | 同步服务器地址 | String |
| `sync_state` | 同步状态 | JSON |
| `last_sync_time` | 最后同步时间 | int |
| `biometric_enabled` | 生物识别开关 | bool |
| `auto_lock_minutes` | 自动锁定时间 | int |

---

## 附录

### A. 错误处理

所有异步 API 都可能抛出异常：

```dart
try {
  await syncService.syncNow();
} on SyncException catch (e) {
  // 同步特定错误
  print('Sync failed: ${e.message}');
} on NetworkException catch (e) {
  // 网络错误
  print('Network error: ${e.message}');
} catch (e) {
  // 其他错误
  print('Unknown error: $e');
}
```

### B. 事件流

订阅状态变化：

```dart
// 同步状态
syncService.stateStream.listen((state) {
  print('Sync state: $state');
});

// 账户变化
provider.accountsStream.listen((accounts) {
  print('Accounts updated: ${accounts.length}');
});
```

### C. 批量操作

```dart
// 批量保存账户
Future<void> saveAccountsBatch(List<AccountItem> accounts) async {
  final storage = ServiceManager.instance.storage;
  final existing = await storage.loadAccounts();

  final updated = [...existing];
  for (final account in accounts) {
    final index = updated.indexWhere((a) => a.id == account.id);
    if (index >= 0) {
      updated[index] = account;
    } else {
      updated.add(account);
    }
  }

  await storage.saveAccounts(updated);
}
```

---

**文档版本**: 1.0
**最后更新**: 2026-04-28
