# API 参考

**最后更新**: 2026-04-28

本文只记录当前 `roy_client` 中真实存在、被页面或测试直接使用的主要 API。同步服务端作为同级
`../roy_server/` 项目存在，客户端通过 `SyncService` 使用 HTTP 协议与其通信。

## 1. ServiceManager

文件：`lib/services/service_manager.dart`

```dart
class ServiceManager extends ChangeNotifier {
  static ServiceManager get instance;
  static String get defaultSyncServerUrl;

  ServiceManagerState get state;
  bool get isLocked;
  bool get isUnlocked;
  bool get hasIdentity;
  String? get errorMessage;

  EnhancedCryptoService get cryptoService;
  BiometricAuthService get biometricService;
  AutoLockService get autoLockService;
  IdentityService get identityService;
  SecureStorageService get storageService;
  SyncService get syncService;

  Future<void> initialize();
  void setupLifecycleObserver();
  void disposeLifecycleObserver();

  Future<UnlockResult> unlockWithPassword(String password);
  Future<UnlockResult> unlockWithBiometric();
  void lock();
  Future<void> logout();
  Future<void> resetApplication();

  Future<void> saveAccount(AccountItem account);
  Future<void> deleteAccount(String id);
  Future<int> countAccountsByTemplate(String templateId);
  Future<void> saveTemplate(AccountTemplate template);
  Future<void> deleteTemplate(String id);

  Future<bool> connectToSyncServer();
  Future<void> disconnectFromSyncServer();
  Future<SyncResult> syncNow();

  SyncState get syncState;
  String? get syncErrorMessage;
  String? get syncStatusNote;
  bool get isSyncConnected;
  int get syncVersion;
  bool get hasDirtyData;

  Future<String?> getSyncServerUrl();
  Future<void> setSyncServerUrl(String url);
}
```

`defaultSyncServerUrl` 由 `lib/system/service_manager/default_sync_server_url.dart` 决定：

- 桌面平台：`http://127.0.0.1:8080`
- Android / iOS / Web：空字符串

## 2. EnhancedAppProvider

文件：`lib/providers/enhanced_app_provider.dart`

```dart
class EnhancedAppProvider extends ChangeNotifier {
  List<AccountTemplate> get allTemplates;
  List<AccountItem> get allAccounts;
  List<AccountTemplate> get customTemplates;
  String get searchQuery;
  Set<String> get selectedTags;
  bool get isLoading;
  int get conflictCount;

  List<AccountItem> get accounts;
  AccountTemplate? getTemplate(String templateId);
  AccountItem? getAccount(String id);

  SyncState get syncState;
  bool get isSyncConnected;

  Future<void> refresh();
  void setSearchQuery(String query);
  void clearSearch();
  void toggleTag(String templateId);
  void setTags(Set<String> tags);
  void clearFilters();

  Future<void> addAccount(AccountItem item);
  Future<void> updateAccount(AccountItem item);
  Future<void> deleteAccount(String id);

  Future<void> addCustomTemplate(AccountTemplate template);
  Future<void> updateCustomTemplate(AccountTemplate template);
  int countAccountsByTemplate(String templateId);
  Future<void> deleteCustomTemplate(String templateId);

  String generatePassword({...});
  int calculatePasswordStrength(String password);
  String getPasswordStrengthLevel(int score);
  Future<SyncResult> syncNow();
}
```

UI 中的典型用法：

```dart
final provider = context.watch<EnhancedAppProvider>();
final accounts = provider.allAccounts;
```

修改数据时使用 `read`：

```dart
await context.read<EnhancedAppProvider>().addAccount(item);
```

## 3. SecureStorageService

文件：`lib/services/secure_storage_service.dart`

```dart
class SecureStorageService {
  Stream<StorageChangeEvent> get onChange;
  bool get isOpen;

  void setDatabaseCipher(DatabaseFileCipher cipher);
  void clearDatabaseCipher();
  Future<void> rotateDatabaseCipher(DatabaseFileCipher cipher);

  Future<void> initialize({String deviceId = 'local'});
  Future<void> close({bool dispose = false});
  Future<bool> isDatabaseInitialized();
  Future<void> deleteDatabaseFile();
  Future<void> clearAllData();
  Future<String> getDatabaseFilePath();
  Future<void> replaceDatabase(Uint8List newDbBytes);

  Future<List<AccountItem>> loadAccounts({bool includeDeleted = false});
  Future<List<AccountItem>> loadPendingSyncAccounts();
  Future<AccountItem?> getAccountById(String id, {bool includeDeleted = false});
  Future<void> saveAccount(AccountItem account, {bool isSyncMerge = false});
  Future<void> deleteAccount(String id, {bool isSyncMerge = false, Hlc? syncDeleteHlc});
  Future<int> countAccountsByTemplate(String templateId);

  Future<void> saveConflictLogs(List<ConflictLog> logs);
  Future<List<ConflictLog>> getConflictLogs(String accountId);
  Future<void> deleteConflictLog(String logId);

  Future<List<AccountTemplate>> loadCustomTemplates({bool includeDeleted = false});
  Future<List<AccountTemplate>> loadDirtyTemplates();
  Future<AccountTemplate?> loadTemplateById(String id);
  Future<void> saveTemplate(AccountTemplate template, {bool isSyncMerge = false});
  Future<void> deleteTemplate(String id, {bool isSyncMerge = false, Hlc? syncDeleteHlc});

  Future<String?> getSetting(String key);
  Future<void> setSetting(String key, String value);
}
```

变更事件：

```dart
class StorageChangeEvent {
  final StorageItemType type;   // account / template / setting
  final StorageAction action;   // save / delete
  final String? id;
}
```

## 4. SyncService

文件：`lib/sync/sync_service.dart`

```dart
enum SyncState {
  offline,
  syncing,
  synced,
  error,
  conflictRecovery,
}

class SyncService extends ChangeNotifier {
  SyncState get state;
  String? get errorMessage;
  String? get statusNote;
  DateTime? get lastSyncTime;
  bool get isConnected;
  bool get isSyncing;
  int get localVersion;
  bool get isDirty;

  Future<void> initialize();
  Future<void> markDirty();
  Future<void> reset();
  Future<void> disconnect();
  Future<bool> connect();
  Future<SyncResult> syncNow();
}
```

`SyncResult`：

```dart
class SyncResult {
  final bool success;
  final bool pushed;
  final bool pulled;
  final String? error;
  final int version;
  final int conflictCount;
  final String? notice;
}
```

同步请求：

```text
GET  /vaults/{vaultId}/sync?since={version}
POST /vaults/{vaultId}/sync
```

配对请求由 `ServiceManager` 通过 `VaultPairingService` / `LanPairingService` 发起。

## 5. IdentityService

文件：`lib/services/identity_service.dart`

```dart
class IdentityService {
  String get deviceId;
  String get vaultId;
  bool get hasIdentity;
  String get privateKey;
  String get symmetricKey;

  Future<bool> checkIdentityExists();
  Future<void> initialize();

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

编码约定：

- 内部兼容码：`sroy-link-v1:`，仅作为内部承载格式，不作为普通用户恢复入口
- 离线恢复码：`sroy-secure-v2:`
- 远程配对密文包：`sroy-pairing-v2:`
- 兼容导入：`sroy-secure-v1:`

## 6. EnhancedCryptoService

文件：`lib/services/enhanced_crypto_service.dart`

```dart
class EnhancedCryptoService {
  bool get hasMasterKey;

  Future<bool> initMasterKey(String masterPassword);
  Future<bool> updateMasterPassword(String oldPassword, String newPassword);
  Future<bool> verifyMasterPassword(String masterPassword);
  void logout();
  DatabaseFileCipher createDatabaseFileCipher();

  static String generatePassword({...});
  static int calculatePasswordStrength(String password);
  static String getPasswordStrengthLevel(int score);
}
```

主密码记录：

- 当前：`master_password_v2`，PBKDF2-HMAC-SHA256。
- 兼容迁移：`master_password_v1`。

## 7. BiometricAuthService

文件：`lib/services/biometric_auth_service.dart`

```dart
enum BiometricAuthStatus {
  notSupported,
  notEnrolled,
  available,
  enabled,
}

class BiometricAuthService {
  Future<BiometricAuthStatus> getStatus();
  Future<BiometricSetupResult> enableBiometric(String currentPassword);
  Future<void> disableBiometric();
  Future<String?> unlockWithBiometric();
  Future<String> getBiometricName();
}
```

## 8. AutoLockService

文件：`lib/services/auto_lock_service.dart`

```dart
class AutoLockService extends ChangeNotifier {
  AutoLockDuration get duration;
  bool get isLocked;

  Future<void> initialize();
  Future<void> setDuration(AutoLockDuration duration);
  void unlock();
  void lock();
  void updateActivity();
}
```

`ServiceManager.setupLifecycleObserver()` 会把它接到 Flutter 应用生命周期上。

## 9. AccountItem

文件：`lib/models/account_item.dart`

```dart
class AccountItem {
  final String id;
  final String name;
  final String email;
  final String templateId;
  final Map<String, String> data;
  final int createdAt;

  final Hlc nameHlc;
  final Hlc emailHlc;
  final Map<String, Hlc> dataHlc;
  final int serverVersion;
  final SyncStatus syncStatus;
  final bool isDeleted;
  final Hlc? deleteHlc;

  factory AccountItem.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
  AccountItem copyWith({...});
}
```

```dart
enum SyncStatus {
  synchronized,
  pendingPush,
  conflict,
}
```

## 10. AccountTemplate

文件：`lib/models/account_template.dart`

```dart
class AccountTemplate {
  final String templateId;
  final String title;
  final String subTitle;
  final IconData? icon;
  final TemplateCategory category;
  final List<AccountField> fields;
  final bool isCustom;

  final SyncStatus syncStatus;
  final Hlc? hlc;
  final int serverVersion;
  final bool isDeleted;
  final Hlc? deleteHlc;

  factory AccountTemplate.fromJson(Map<String, dynamic> json, {bool isCustom = true});
  Map<String, dynamic> toJson();
  AccountTemplate copyWith({...});
}
```

当前内置模板：

```dart
final List<AccountTemplate> basicAccountTemplates = [genericInfoTemplate];
```

## 11. 常用调用链

新增账号：

```text
AccountEditView._save()
↓
Navigator.pop(AccountItem)
↓
EnhancedAppProvider.addAccount()
↓
ServiceManager.saveAccount()
↓
SecureStorageService.saveAccount()
↓
SyncService.markDirty()
```

解锁：

```text
UnlockView._unlockWithPassword()
↓
ServiceManager.unlockWithPassword()
↓
IdentityService + EnhancedCryptoService + SecureStorageService + SyncService
↓
ServiceManagerState.unlocked
```

同步：

```text
EnhancedAppProvider.syncNow()
↓
ServiceManager.syncNow()
↓
SyncService.syncNow()
↓
SecureStorageService 保存 pull/merge/push 后的数据
```
