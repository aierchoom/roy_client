# 代码详细解读

**版本**: v1.1.0
**最后更新**: 2026-04-27

---

## 目录

1. [项目入口分析](#1-项目入口分析)
2. [服务管理器详解](#2-服务管理器详解)
3. [同步服务详解](#3-同步服务详解)
4. [CRDT合并引擎详解](#4-crdt合并引擎详解)
5. [安全存储服务](#5-安全存储服务)
6. [状态管理详解](#6-状态管理详解)
7. [加密服务详解](#7-加密服务详解)
8. [视图层分析](#8-视图层分析)

---

## 1. 项目入口分析

### 1.1 main.dart 完整解读

**文件位置**: `lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await ServiceManager.instance.initialize();

  runApp(SecretRoyApp(prefs: prefs));
}
```

**执行流程**:

```
┌─────────────────────────────────────────────────────────────┐
│                     应用启动流程                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. WidgetsFlutterBinding.ensureInitialized()               │
│     └── 初始化 Flutter 框架绑定                              │
│         └── 必须在 async 操作前调用                          │
│                                                              │
│  2. SharedPreferences.getInstance()                          │
│     └── 获取本地持久化存储实例                               │
│         └── 用于存储主题、服务器地址等配置                   │
│                                                              │
│  3. ServiceManager.instance.initialize()                     │
│     └── 初始化所有服务                                       │
│         └── 加密服务、生物识别、自动锁定等                   │
│                                                              │
│  4. runApp(SecretRoyApp(...))                                │
│     └── 启动应用根 Widget                                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 SecretRoyApp 类分析

```dart
class SecretRoyApp extends StatefulWidget {
  final SharedPreferences prefs;

  const SecretRoyApp({super.key, required this.prefs});

  @override
  State<SecretRoyApp> createState() => _SecretRoyAppState();
}
```

**设计要点**:
- 使用 `StatefulWidget` 因为需要管理生命周期观察者
- 接收 `SharedPreferences` 作为参数，避免重复初始化

### 1.3 Provider 配置

```dart
return MultiProvider(
  providers: [
    // 全局服务管理器
    ChangeNotifierProvider.value(value: _serviceManager),
    
    // 应用状态 Provider
    ChangeNotifierProvider(
      create: (_) => EnhancedAppProvider(
        ServiceManager.instance.storageService, 
        ServiceManager.instance
      ),
    ),
    
    // 主题 Provider
    ChangeNotifierProvider(create: (_) => AppThemeProvider(widget.prefs)),
  ],
  // ...
);
```

**Provider 职责划分**:

| Provider | 职责 | 通知时机 |
|----------|------|----------|
| ServiceManager | 服务状态、解锁状态 | 状态变更时 |
| EnhancedAppProvider | 账户/模板数据、同步状态 | 数据变更时 |
| AppThemeProvider | 主题设置 | 主题变更时 |

### 1.4 路由配置

```dart
routes: {
  '/unlock': (context) => const UnlockView(),
  '/home': (context) => const HomeView(),
  '/password-tools': (context) => const PasswordToolsView(),
  '/security': (context) => const SecuritySettingsView(),
  '/sync': (context) => const SyncSettingsView(),
},
```

### 1.5 主题构建

**浅色主题关键配置**:

```dart
ThemeData _buildLightTheme(Color seed) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed, 
    brightness: Brightness.light
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    
    // 背景渐变效果
    scaffoldBackgroundColor: Color.alphaBlend(
      colorScheme.primary.withAlpha(18), 
      colorScheme.surfaceContainerLow
    ),
    
    // 卡片圆角
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    
    // 输入框样式
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withAlpha(100),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide.none
      ),
    ),
  );
}
```

---

## 2. 服务管理器详解

### 2.1 ServiceManager 类结构

**文件位置**: `lib/services/service_manager.dart`

```dart
class ServiceManager extends ChangeNotifier {
  // 单例模式
  static ServiceManager? _instance;
  static ServiceManager get instance {
    _instance ??= ServiceManager._internal();
    return _instance!;
  }
}
```

**为什么使用单例**:
- 全局唯一的服务协调点
- 避免重复初始化
- 统一的生命周期管理

### 2.2 状态枚举

```dart
enum ServiceManagerState { 
  uninitialized,  // 未初始化
  locked,         // 已锁定
  unlocking,      // 解锁中
  unlocked,       // 已解锁
  error           // 错误状态
}
```

**状态转换图**:

```
┌───────────────┐
│ uninitialized │
└───────┬───────┘
        │ initialize()
        ▼
┌───────────────┐
│    locked     │◄──────────────┐
└───────┬───────┘               │
        │ unlockWithPassword()  │ lock()
        ▼                       │
┌───────────────┐               │
│   unlocking   │               │
└───────┬───────┘               │
        │ success               │
        ▼                       │
┌───────────────┐               │
│   unlocked    │───────────────┘
└───────┬───────┘
        │ error
        ▼
┌───────────────┐
│     error     │
└───────────────┘
```

### 2.3 服务初始化

```dart
ServiceManager._internal() {
  const secureStorage = FlutterSecureStorage();
  
  // 加密服务
  _cryptoService = EnhancedCryptoService(secureStorage: secureStorage);
  
  // 生物识别服务
  _biometricService = BiometricAuthService(secureStorage: secureStorage);
  
  // 自动锁定服务
  _autoLockService = AutoLockService(
    cryptoService: _cryptoService,
    secureStorage: secureStorage,
  );
  
  // 身份服务
  _identityService = IdentityService(
    secureStorage: const FlutterSecureKeyValueStore(secureStorage),
  );
  
  // 存储服务
  _secureStorageService = SecureStorageService();
  
  // 同步服务
  _syncService = SyncService(
    storageService: _secureStorageService,
    identityService: _identityService,
    config: SyncConfig(serverUrl: defaultSyncServerUrl),
  );
}
```

### 2.4 解锁流程详解

```dart
Future<UnlockResult> unlockWithPassword(String password) async {
  // 1. 防止重复解锁
  if (_state == ServiceManagerState.unlocking) {
    return UnlockResult.alreadyInProgress;
  }

  _updateState(ServiceManagerState.unlocking);
  return _completeUnlock(password);
}

Future<UnlockResult> _completeUnlock(String password) async {
  try {
    // 2. 初始化身份服务
    await _identityService.initialize();
    
    // 3. 初始化存储服务
    await _secureStorageService.initialize(
      deviceId: _identityService.deviceId,
    );
    
    // 4. 验证主密码
    final didUnlock = await _cryptoService.initMasterKey(password);
    if (!didUnlock) {
      await _secureStorageService.close();
      await _syncService.disconnect();
      _updateState(ServiceManagerState.locked);
      return UnlockResult.invalidPassword;
    }
    
    // 5. 解锁自动锁定服务
    _autoLockService.unlock();
    
    // 6. 初始化同步服务
    await _syncService.initialize();

    // 7. 异步连接同步服务器
    unawaited(_syncService.connect());
    
    _updateState(ServiceManagerState.unlocked);
    return UnlockResult.success;
  } catch (e, stack) {
    _setError('Unlock failed: $e');
    return UnlockResult.error;
  }
}
```

**解锁流程图**:

```
┌──────────────────────────────────────────────────────────────┐
│                       解锁流程                                │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  用户输入密码                                                 │
│       │                                                       │
│       ▼                                                       │
│  ┌─────────────────┐                                         │
│  │ 检查当前状态    │                                         │
│  └────────┬────────┘                                         │
│           │                                                   │
│           ▼                                                   │
│  ┌─────────────────┐                                         │
│  │ 初始化身份服务  │ ──→ 获取 deviceId, vaultId              │
│  └────────┬────────┘                                         │
│           │                                                   │
│           ▼                                                   │
│  ┌─────────────────┐                                         │
│  │ 初始化存储服务  │ ──→ 打开 SQLite 数据库                  │
│  └────────┬────────┘                                         │
│           │                                                   │
│           ▼                                                   │
│  ┌─────────────────┐                                         │
│  │ 验证主密码      │ ──→ PBKDF2 派生密钥并验证               │
│  └────────┬────────┘                                         │
│           │                                                   │
│     ┌─────┴─────┐                                            │
│     │           │                                            │
│   失败         成功                                          │
│     │           │                                            │
│     ▼           ▼                                            │
│  返回错误   ┌─────────────────┐                              │
│            │ 解锁自动锁定    │                              │
│            └────────┬────────┘                              │
│                     │                                        │
│                     ▼                                        │
│            ┌─────────────────┐                              │
│            │ 初始化同步服务  │                              │
│            └────────┬────────┘                              │
│                     │                                        │
│                     ▼                                        │
│            ┌─────────────────┐                              │
│            │ 异步连接服务器  │                              │
│            └────────┬────────┘                              │
│                     │                                        │
│                     ▼                                        │
│               解锁成功                                        │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### 2.5 数据操作方法

```dart
// 保存账户
Future<void> saveAccount(AccountItem account) async {
  if (!isUnlocked) return;  // 安全检查
  
  // 1. 持久化到本地
  await _secureStorageService.saveAccount(account);
  
  // 2. 标记为脏数据
  await _syncService.markDirty();
  
  // 3. 异步触发同步（不等待结果）
  unawaited(_syncService.syncNow());
}
```

---

## 3. 同步服务详解

### 3.1 SyncService 类结构

**文件位置**: `lib/sync/sync_service.dart`

```dart
class SyncService extends ChangeNotifier {
  final SecureStorageService _storageService;
  final IdentityService _identityService;
  final SyncConfig _config;

  // 状态
  SyncState _state = SyncState.offline;
  String? _errorMessage;
  int _localVersion = 0;
  bool _isDirty = false;
  
  // 恢复标记（用于断点续传）
  _SyncRecoveryMarker? _pendingRecovery;
}
```

### 3.2 同步状态枚举

```dart
enum SyncState { 
  offline,          // 离线
  syncing,          // 同步中
  synced,           // 已同步
  error,            // 错误
  conflictRecovery  // 冲突恢复中
}
```

### 3.3 核心同步循环

```dart
Future<SyncResult> _runSyncLoop(String serverUrl) async {
  _queuedConflictCount = 0;
  _queuedConflictNotice = null;
  var recoveredCount = 0;

  try {
    // 1. 检查是否有中断的同步需要恢复
    if (_pendingRecovery != null) {
      _updateState(SyncState.conflictRecovery);
      recoveredCount = await _resumeInterruptedSync(serverUrl);
    }

    // 2. 重试循环（最多3次）
    var retries = 0;
    while (retries < 3) {
      try {
        _updateState(SyncState.syncing);
        
        // 3. 写入恢复标记 - Pull 阶段
        await _writeRecoveryMarker(_SyncRecoveryPhase.pull);
        
        // 4. 执行 Pull 阶段
        final pullCount = await _runPullPhase(serverUrl);
        
        // 5. 写入恢复标记 - Push 阶段
        await _writeRecoveryMarker(_SyncRecoveryPhase.push);
        
        // 6. 执行 Push 阶段
        final pushCount = await _runPushPhase(serverUrl);

        // 7. 清理恢复标记
        await _clearRecoveryMarker();
        
        _updateState(SyncState.synced);
        return SyncResult.success(pulled: pullCount > 0, pushed: pushCount > 0);
        
      } on _ConflictException catch (ce) {
        // 8. 处理冲突
        await _handleConflict(serverUrl, ce);
        retries++;
        _updateState(SyncState.conflictRecovery);
        await Future.delayed(Duration(milliseconds: 500 * retries));
      }
    }
  } catch (e, stack) {
    return _handleGlobalSyncError(e, stack);
  }
}
```

**同步流程图**:

```
┌────────────────────────────────────────────────────────────────┐
│                        同步流程                                │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  syncNow()                                                      │
│      │                                                          │
│      ▼                                                          │
│  ┌────────────────┐                                             │
│  │ 检查恢复标记   │                                             │
│  └───────┬────────┘                                             │
│          │                                                      │
│    有恢复├────┐                                                 │
│          │    ▼                                                │
│          │  ┌────────────────┐                                 │
│          │  │ 恢复中断的同步 │                                 │
│          │  └───────┬────────┘                                 │
│          │          │                                          │
│          └──────────┤                                          │
│                     ▼                                          │
│  ┌────────────────────────┐                                    │
│  │  Pull Phase (拉取)     │                                    │
│  │  GET /vaults/{id}/sync │                                    │
│  │  ?since={localVersion} │                                    │
│  └───────────┬────────────┘                                    │
│              │                                                  │
│              ▼                                                  │
│  ┌────────────────────────┐                                    │
│  │  应用远程变更          │                                    │
│  │  - 解密 payload        │                                    │
│  │  - CRDT 合并           │                                    │
│  │  - 更新本地版本        │                                    │
│  └───────────┬────────────┘                                    │
│              │                                                  │
│              ▼                                                  │
│  ┌────────────────────────┐                                    │
│  │  Push Phase (推送)     │                                    │
│  │  POST /vaults/{id}/sync│                                    │
│  │  - 加密 + 签名 payload │                                    │
│  │  - 发送脏数据          │                                    │
│  └───────────┬────────────┘                                    │
│              │                                                  │
│        ┌─────┴─────┐                                           │
│        │           │                                           │
│      成功        409 冲突                                      │
│        │           │                                           │
│        ▼           ▼                                           │
│  ┌──────────┐  ┌──────────────┐                               │
│  │ 清理标记 │  │ 处理冲突    │                               │
│  │ 返回成功 │  │ 重试 (≤3次) │                               │
│  └──────────┘  └──────────────┘                               │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### 3.4 Pull 阶段详解

```dart
Future<int> _runPullPhase(String serverUrl) async {
  final vaultId = _identityService.vaultId;
  debugPrint('[Sync] >>> Pull Phase Start (Vault: $vaultId, Since: $_localVersion)');

  // 1. 获取远程变更
  final data = await _fetchRemoteChanges(serverUrl, since: _localVersion);
  
  // 2. 应用变更
  final mergedCount = await _applyRemoteChanges(data);
  
  debugPrint('[Sync] <<< Pull Phase Completed. Processed: $mergedCount');
  return mergedCount;
}

Future<int> _applyRemoteChanges(Map<String, dynamic> data) async {
  final itemsList = data['items'] as List<dynamic>? ?? [];
  
  for (final item in itemsList) {
    final remoteEncoded = item as Map<String, dynamic>;
    
    // 1. 解密并验证 payload
    final payload = _decryptAndVerifyPayload(remoteEncoded);
    
    // 2. 判断类型
    final type = payload['_type'] as String?;
    
    if (type == 'template') {
      // 处理模板
      final remoteTemplate = AccountTemplate.fromJson(payload);
      await _storageService.saveTemplate(remoteTemplate, isSyncMerge: true);
    } else {
      // 处理账户
      final remoteAccount = AccountItem.fromJson(payload);
      final maybeLocal = await _storageService.getAccountById(remoteAccount.id);
      
      if (maybeLocal != null && maybeLocal.syncStatus == SyncStatus.pendingPush) {
        // 本地有未推送的修改，需要合并
        final mergeResult = CrdtMergeEngine.merge(maybeLocal, remoteAccount);
        await _storageService.saveAccount(mergeResult.mergedItem, isSyncMerge: true);
        
        if (mergeResult.conflictLogs.isNotEmpty) {
          await _storageService.saveConflictLogs(mergeResult.conflictLogs);
        }
      } else {
        // 直接接受远程版本
        await _storageService.saveAccount(remoteAccount, isSyncMerge: true);
      }
    }
  }
  
  return itemsList.length;
}
```

### 3.5 Push 阶段详解

```dart
Future<int> _runPushPhase(String serverUrl) async {
  // 1. 加载待推送的数据
  final dirtyAccounts = await _storageService.loadPendingSyncAccounts();
  final dirtyTemplates = await _storageService.loadDirtyTemplates();
  
  if (dirtyItems.isEmpty) return 0;

  // 2. 构建推送 payload
  final pushPayloads = dirtyItems.map((item) {
    final ciphertext = _encryptAndSign(item);
    return {
      'id': itemId,
      'expected_base_version': serverVersion,
      'is_deleted': isDeleted,
      'encrypted_signed_payload': ciphertext,
    };
  }).toList();

  // 3. 发送请求
  final response = await http.post(
    Uri.parse('$serverUrl/vaults/$vaultId/sync'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'pushes': pushPayloads}),
  );

  // 4. 处理响应
  if (response.statusCode == 409) {
    throw _ConflictException(response.body);
  }

  // 5. 更新本地状态
  for (final item in dirtyItems) {
    final newVersion = acceptedVersions[itemId];
    // 更新为已同步状态
    await _storageService.saveAccount(
      item.copyWith(syncStatus: SyncStatus.synchronized, serverVersion: newVersion),
      isSyncMerge: true,
    );
  }

  return dirtyItems.length;
}
```

---

## 4. CRDT合并引擎详解

### 4.1 CrdtMergeEngine 类结构

**文件位置**: `lib/sync/crdt_merge_engine.dart`

```dart
class CrdtMergeEngine {
  /// 合并两个账户记录
  static MergeResult merge(AccountItem local, AccountItem remote);
  
  /// 合并模板
  static AccountTemplate mergeTemplate(AccountTemplate local, AccountTemplate remote);
  
  /// 获取记录中最大的 HLC
  static Hlc _getMaxHlc(AccountItem item);
}
```

### 4.2 合并算法详解

```dart
static MergeResult merge(AccountItem local, AccountItem remote) {
  final List<ConflictLog> logs = [];

  // ═══════════════════════════════════════════════════════════
  // 阶段 1: 墓碑优先规则 (Tombstone Trumps All)
  // ═══════════════════════════════════════════════════════════
  
  final localDel = local.deleteHlc;
  final remoteDel = remote.deleteHlc;

  if (localDel != null && remoteDel != null) {
    // 双方都删除了 → 选择删除时间较晚的
    if (remoteDel.compareTo(localDel) > 0) {
      return MergeResult(remote.copyWith(syncStatus: SyncStatus.synchronized), []);
    }
    return MergeResult(local, []);
  } else if (remoteDel != null) {
    // 远端删除了，本地没删
    if (remoteDel.compareTo(_getMaxHlc(local)) > 0) {
      // 远端删除时间晚于本地最后修改 → 接受删除
      return MergeResult(remote.copyWith(syncStatus: SyncStatus.synchronized), logs);
    }
    // 本地修改时间晚于删除时间 → 本地复活了记录
  } else if (localDel != null) {
    if (localDel.compareTo(_getMaxHlc(remote)) > 0) {
      return MergeResult(local, []);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 阶段 2: 字段级 LWW 合并 (Last Writer Wins)
  // ═══════════════════════════════════════════════════════════
  
  // 合并 name 字段
  late final String mergedName;
  late final Hlc mergedNameHlc;
  
  if (remote.nameHlc.compareTo(local.nameHlc) > 0) {
    // 远端更新 → 采用远端值
    mergedName = remote.name;
    mergedNameHlc = remote.nameHlc;
    // 记录冲突日志（保存被覆盖的本地值）
    if (local.name != remote.name) {
      logs.add(ConflictLog(
        accountId: local.id, 
        fieldKey: 'name', 
        fieldValue: local.name, 
        hlc: local.nameHlc
      ));
    }
  } else {
    // 本地更新 → 保持本地值
    mergedName = local.name;
    mergedNameHlc = local.nameHlc;
  }

  // 合并 email 字段（同理）
  // ...

  // 合并 data 字段（Map 类型）
  final Set<String> allDataKeys = {...local.data.keys, ...remote.data.keys};
  final Map<String, String> mergedData = {};
  final Map<String, Hlc> mergedDataHlc = {};

  for (final key in allDataKeys) {
    final lHlc = local.dataHlc[key] ?? Hlc.zero('local');
    final rHlc = remote.dataHlc[key] ?? Hlc.zero('remote');

    if (rHlc.compareTo(lHlc) > 0) {
      mergedData[key] = remote.data[key]!;
      mergedDataHlc[key] = rHlc;
    } else {
      mergedData[key] = local.data[key]!;
      mergedDataHlc[key] = lHlc;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 阶段 3: 确定最终状态
  // ═══════════════════════════════════════════════════════════
  
  bool isPureFastForward = true;
  // 检查是否完全是远端覆盖（没有本地修改被保留）
  // ...
  
  SyncStatus finalStatus;
  if (isPureFastForward) {
    finalStatus = SyncStatus.synchronized;
  } else {
    if (local.syncStatus == SyncStatus.pendingPush) {
      finalStatus = SyncStatus.conflict;  // 需要人工审核
    } else {
      finalStatus = SyncStatus.pendingPush;  // 需要推送到服务器
    }
  }

  return MergeResult(resultItem, logs);
}
```

### 4.3 HLC 比较规则

```dart
@override
int compareTo(Hlc other) {
  // 1. 先比较物理时间
  if (time != other.time) return time.compareTo(other.time);
  
  // 2. 再比较逻辑计数器
  if (counter != other.counter) return counter.compareTo(other.counter);
  
  // 3. 最后比较节点 ID（打破平局）
  return nodeId.compareTo(other.nodeId);
}
```

### 4.4 冲突日志结构

```dart
class ConflictLog {
  final String id;           // 日志 ID
  final String accountId;    // 关联账户 ID
  final String fieldKey;     // 字段名：'name', 'email', 'data.xxx'
  final String fieldValue;   // 被覆盖的值
  final Hlc hlc;             // 被覆盖值的时间戳
  final int savedAt;         // 日志创建时间
}
```

---

## 5. 安全存储服务

### 5.1 SecureStorageService 类

**文件位置**: `lib/services/secure_storage_service.dart`

```dart
class SecureStorageService {
  Database? _database;
  
  /// 初始化数据库连接
  Future<void> initialize({required String deviceId}) async {
    final dbPath = await _getDatabasePath(deviceId);
    _database = await openDatabase(dbPath);
    await _createTables();
  }
  
  /// 账户 CRUD
  Future<List<AccountItem>> loadAccounts();
  Future<void> saveAccount(AccountItem account);
  Future<void> deleteAccount(String id);
  
  /// 模板 CRUD
  Future<List<AccountTemplate>> loadTemplates();
  Future<void> saveTemplate(AccountTemplate template);
}
```

### 5.2 数据库 Schema

```sql
-- 账户表
CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  template_id TEXT,
  data TEXT,           -- JSON encoded
  created_at INTEGER,
  name_hlc TEXT,
  email_hlc TEXT,
  data_hlc TEXT,       -- JSON encoded
  server_version INTEGER DEFAULT 0,
  sync_status INTEGER DEFAULT 0,
  is_deleted INTEGER DEFAULT 0,
  delete_hlc TEXT
);

-- 模板表
CREATE TABLE templates (
  template_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  subtitle TEXT,
  category TEXT,
  fields TEXT,         -- JSON encoded
  is_custom INTEGER DEFAULT 0,
  server_version INTEGER DEFAULT 0,
  sync_status INTEGER DEFAULT 0,
  is_deleted INTEGER DEFAULT 0
);

-- 冲突日志表
CREATE TABLE conflict_logs (
  id TEXT PRIMARY KEY,
  account_id TEXT,
  field_key TEXT,
  field_value TEXT,
  hlc TEXT,
  saved_at INTEGER
);

-- 设置表
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT
);
```

---

## 6. 状态管理详解

### 6.1 EnhancedAppProvider

**文件位置**: `lib/providers/enhanced_app_provider.dart`

```dart
class EnhancedAppProvider extends ChangeNotifier {
  final SecureStorageService _storageService;
  final ServiceManager _serviceManager;

  // 状态
  List<AccountItem> _accounts = [];
  List<AccountTemplate> _templates = [];
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<AccountItem> get accounts => _accounts;
  List<AccountTemplate> get templates => _templates;
  bool get isLoading => _isLoading;
}
```

### 6.2 数据加载流程

```dart
Future<void> loadAccounts() async {
  _isLoading = true;
  notifyListeners();

  try {
    _accounts = await _storageService.loadAccounts();
    _error = null;
  } catch (e) {
    _error = e.toString();
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

### 6.3 在 Widget 中使用

```dart
class AccountListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 监听状态变化
    final provider = context.watch<EnhancedAppProvider>();
    
    if (provider.isLoading) {
      return CircularProgressIndicator();
    }
    
    return ListView.builder(
      itemCount: provider.accounts.length,
      itemBuilder: (context, index) {
        final account = provider.accounts[index];
        return AccountListTile(account: account);
      },
    );
  }
}

// 修改数据
Future<void> deleteAccount(BuildContext context, String id) async {
  final provider = context.read<EnhancedAppProvider>();
  await provider.deleteAccount(id);
}
```

---

## 7. 加密服务详解

### 7.1 EnhancedCryptoService

**文件位置**: `lib/services/enhanced_crypto_service.dart`

```dart
class EnhancedCryptoService {
  final FlutterSecureStorage _secureStorage;
  
  // 密钥存储键名
  static const _keySalt = 'master_salt';
  static const _keyVerifier = 'master_verifier';
  
  /// 初始化主密钥
  Future<bool> initMasterKey(String password) async {
    // 1. 读取盐值
    final salt = await _secureStorage.read(key: _keySalt);
    
    if (salt == null) {
      // 首次设置密码
      return await _setupNewPassword(password);
    }
    
    // 2. 派生密钥
    final derivedKey = await _deriveKey(password, salt);
    
    // 3. 验证密码
    final verifier = await _secureStorage.read(key: _keyVerifier);
    return await _verifyKey(derivedKey, verifier);
  }
}
```

### 7.2 密钥派生

```dart
Future<Uint8List> _deriveKey(String password, String salt) async {
  // PBKDF2-HMAC-SHA256
  final pbkdf2 = Pbkdf2(
    macAlgorithm: MacAlgorithm.sha256,
    iterations: 100000,
    bits: 256,
  );
  
  return await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: base64Decode(salt),
  );
}
```

### 7.3 数据加密

```dart
Future<String> encrypt(String plaintext, Uint8List key) async {
  // 1. 生成随机 IV
  final iv = Uint8List(16);
  Random.secure().getBytes(iv);
  
  // 2. XOR 加密
  final ciphertext = _xorEncrypt(utf8.encode(plaintext), key, iv);
  
  // 3. 计算 HMAC
  final hmac = await _calculateHmac(ciphertext, key);
  
  // 4. 组装输出
  return jsonEncode({
    'iv': base64Encode(iv),
    'data': base64Encode(ciphertext),
    'hmac': hmac,
  });
}
```

---

## 8. 视图层分析

### 8.1 视图目录结构

```
lib/views/
├── home/
│   ├── home_view.dart          # 主页
│   ├── home_search_view.dart   # 搜索页
│   └── layouts/
│       ├── home_view_mobile.dart
│       └── home_view_desktop.dart
├── accounts/
│   ├── account_list_view.dart  # 账户列表
│   ├── account_edit_view.dart  # 账户编辑
│   └── account_edit_utils.dart # 编辑工具类
├── templates/
│   ├── template_list_view.dart # 模板列表
│   └── template_edit_view.dart # 模板编辑
├── sync_settings_view.dart     # 同步设置
├── security_settings_view.dart # 安全设置
└── unlock_view.dart            # 解锁页
```

### 8.2 通用模式

**StatefulWidget 生命周期管理**:

```dart
class AccountEditView extends StatefulWidget {
  final AccountItem? initial;  // 编辑时传入

  @override
  State<AccountEditView> createState() => _AccountEditViewState();
}

class _AccountEditViewState extends State<AccountEditView> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  
  @override
  void initState() {
    super.initState();
    // 初始化控制器
    _nameController = TextEditingController(text: widget.initial?.name);
    _emailController = TextEditingController(text: widget.initial?.email);
  }
  
  @override
  void dispose() {
    // 释放资源
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

### 8.3 响应式布局

```dart
Widget _buildTopSection(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 980;
      
      if (!isWide) {
        // 移动端：垂直布局
        return Column(
          children: [overview, details],
        );
      }
      
      // 桌面端：水平布局
      return Row(
        children: [
          Expanded(flex: 5, child: overview),
          Expanded(flex: 7, child: details),
        ],
      );
    },
  );
}
```

---

## 附录

### A. 关键文件索引

| 功能 | 文件路径 | 行数 |
|------|----------|------|
| 应用入口 | `lib/main.dart` | 325 |
| 服务管理 | `lib/services/service_manager.dart` | 737 |
| 同步服务 | `lib/sync/sync_service.dart` | 936 |
| CRDT 合并 | `lib/sync/crdt_merge_engine.dart` | 224 |
| 数据模型 | `lib/models/account_item.dart` | 150+ |
| 存储服务 | `lib/services/secure_storage_service.dart` | 400+ |

### B. 调试技巧

```dart
// 启用详细日志
debugPrint('[Sync] Operation: $details');

// 使用断点调试
debugger();

// 检查 Widget 重建
@override
void didUpdateWidget(covariant OldWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  debugPrint('Widget updated');
}
```

### C. 性能优化建议

1. 使用 `const` 构造函数减少 Widget 重建
2. 使用 `Provider.select` 精确订阅状态
3. 大列表使用 `ListView.builder`
4. 异步操作使用 `compute` 隔离

---

**文档版本**: 1.0
**最后更新**: 2026-04-27
