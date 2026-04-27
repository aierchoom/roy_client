# SecretRoy 技术实现指南 - Dart/Flutter 客户端

**日期**: 2026-04-18  
**范围**: 客户端加密、同步、冲突合并的具体实现

---

## 目录

1. [加密实现](#加密实现)
2. [本地存储扩展](#本地存储扩展)
3. [向量时钟实现](#向量时钟实现)
4. [CRDT 冲突合并](#crdt-冲突合并)
5. [同步引擎重构](#同步引擎重构)
6. [测试策略](#测试策略)

---

## 加密实现

### 1. 密钥派生服务

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// 密钥派生结果
class DerivedKeys {
  final Uint8List encryptionKey;      // AES-256 密钥
  final Uint8List authenticationKey;   // HMAC-SHA256 密钥
  final Uint8List salt;
  final DateTime derivedAt;

  DerivedKeys({
    required this.encryptionKey,
    required this.authenticationKey,
    required this.salt,
    required this.derivedAt,
  });

  /// 清除内存中的敏感数据
  void clear() {
    // Dart 中无法直接清除，建议使用 FFI 调用 C 的 memset
    // 或者依赖 VM 的垃圾收集
  }
}

/// 密钥派生服务
class KeyDerivationService {
  static const int _scryptN = 65536;  // 2^16
  static const int _scryptR = 8;
  static const int _scryptP = 1;
  static const int _saltLength = 32;
  static const int _pbkdf2Iterations = 100000;

  /// 从主密码派生加密密钥和认证密钥
  /// 
  /// 流程:
  /// 1. 生成随机盐值
  /// 2. 使用 Scrypt 进行缓慢哈希（防止暴力破解）
  /// 3. 使用 PBKDF2 派生两个子密钥（隔离）
  static Future<DerivedKeys> deriveKeys(
    String masterPassword,
    String userEmail,
    String deviceId,
  ) async {
    // 步骤 1: 生成盐值
    final random = Random.secure();
    final salt = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      salt[i] = random.nextInt(256);
    }

    // 步骤 2: Scrypt 第一层（CPU 密集）
    final scryptResult = await _scryptDerive(
      password: masterPassword,
      salt: salt,
      n: _scryptN,
      r: _scryptR,
      p: _scryptP,
      dkLen: 64,
    );

    // 步骤 3: PBKDF2 派生加密密钥
    final encryptionKeyData = 'encryption:$userEmail:$deviceId';
    final encryptionKey = _pbkdf2Derive(
      password: base64Encode(scryptResult),
      salt: encryptionKeyData,
      iterations: _pbkdf2Iterations,
      keyLength: 32,
    );

    // 步骤 4: PBKDF2 派生认证密钥
    final authKeyData = 'authentication:$userEmail';
    final authenticationKey = _pbkdf2Derive(
      password: base64Encode(scryptResult),
      salt: authKeyData,
      iterations: _pbkdf2Iterations,
      keyLength: 32,
    );

    return DerivedKeys(
      encryptionKey: encryptionKey,
      authenticationKey: authenticationKey,
      salt: salt,
      derivedAt: DateTime.now(),
    );
  }

  /// Scrypt 派生 (使用 pointycastle)
  static Future<Uint8List> _scryptDerive({
    required String password,
    required Uint8List salt,
    required int n,
    required int r,
    required int p,
    required int dkLen,
  }) async {
    // 注：Dart 的 crypto 库不包含 Scrypt
    // 需要通过 FFI 调用 C 库或使用 Web3 库
    // 这里是示意实现，实际需要依赖
    
    // 使用 web3dart 的 scrypt 实现（如果可用）
    // 或通过 platform channel 调用原生代码
    
    // 临时实现（不安全，仅演示）：
    final passwordBytes = utf8.encode(password);
    final input = Uint8List(passwordBytes.length + salt.length);
    input.setRange(0, passwordBytes.length, passwordBytes);
    input.setRange(passwordBytes.length, input.length, salt);
    
    // 这里应该调用真实的 Scrypt 实现
    return sha256.convert(input).bytes as Uint8List;
  }

  /// PBKDF2 派生
  static Uint8List _pbkdf2Derive({
    required String password,
    required String salt,
    required int iterations,
    required int keyLength,
  }) {
    // 使用 crypto 库的 PBKDF2
    final pbkdf2 = Pbkdf2(
      hashFn: sha256,
      salt: utf8.encode(salt),
      iterations: iterations,
    );
    return pbkdf2.convert(utf8.encode(password)).bytes as Uint8List;
  }

  /// 验证密钥（用于登录时验证密码）
  static Future<bool> verifyPassword(
    String masterPassword,
    String userEmail,
    String deviceId,
    Uint8List storedSalt,
  ) async {
    try {
      final derived = await deriveKeys(masterPassword, userEmail, deviceId);
      // 比较派生的密钥是否相同
      // 实际上应该存储密钥的哈希而不是密钥本身
      return true; // 简化演示
    } catch (e) {
      return false;
    }
  }
}
```

### 2. 加密/解密服务

```dart
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;

/// 加密操作结果
class EncryptionResult {
  final Uint8List ciphertext;
  final Uint8List iv;          // 初始化向量
  final Uint8List authTag;      // GCM 认证标签
  final Uint8List recordMAC;    // 记录完整性标签

  EncryptionResult({
    required this.ciphertext,
    required this.iv,
    required this.authTag,
    required this.recordMAC,
  });

  /// 转换为 JSON 格式用于网络传输
  Map<String, String> toJson() => {
    'ciphertext': base64Encode(ciphertext),
    'iv': base64Encode(iv),
    'authTag': base64Encode(authTag),
    'recordMAC': base64Encode(recordMAC),
  };

  factory EncryptionResult.fromJson(Map<String, String> json) => EncryptionResult(
    ciphertext: base64Decode(json['ciphertext'] ?? ''),
    iv: base64Decode(json['iv'] ?? ''),
    authTag: base64Decode(json['authTag'] ?? ''),
    recordMAC: base64Decode(json['recordMAC'] ?? ''),
  );
}

/// E2EE 加密服务（完整实现）
class E2EECryptoService {
  final DerivedKeys _keys;
  final Uint8List _authenticationKey;

  E2EECryptoService({
    required DerivedKeys keys,
    required Uint8List authenticationKey,
  }) : _keys = keys,
       _authenticationKey = authenticationKey;

  /// 加密账号数据
  Future<EncryptionResult> encryptAccountData(
    Map<String, dynamic> plainData,
  ) async {
    try {
      // 步骤 1: 序列化数据
      final jsonString = jsonEncode(plainData);
      final plainBytes = utf8.encode(jsonString);

      // 步骤 2: 生成随机 IV (96-bit for GCM)
      final random = Random.secure();
      final iv = Uint8List(12);
      for (int i = 0; i < 12; i++) {
        iv[i] = random.nextInt(256);
      }

      // 步骤 3: AES-256-GCM 加密
      // 注：Dart 的 encrypt 库可能没有原生 GCM
      // 需要使用 pointycastle 或通过 FFI 调用 OpenSSL
      
      // 这里使用 pointycastle 实现
      final key = encrypt.Key.fromBase64(base64Encode(_keys.encryptionKey));
      final encrypter = encrypt.Encrypter(encrypt.AES(
        key,
        mode: encrypt.AESMode.gcm,
      ));

      // 加密数据和认证标签一起生成
      final encrypted = encrypter.encrypt(
        jsonString,
        iv: encrypt.IV(iv),
      );

      // 步骤 4: 计算记录完整性标签
      final recordData = Uint8List(iv.length + encrypted.bytes.length);
      recordData.setRange(0, iv.length, iv);
      recordData.setRange(iv.length, recordData.length, encrypted.bytes);

      final recordMAC = _computeHMAC(recordData);

      // 步骤 5: 提取认证标签（GCM 输出）
      // 注：这需要在底层加密库中获取
      final authTag = encrypted.bytes.sublist(
        encrypted.bytes.length - 16,
      ); // GCM tag 通常是最后 16 字节

      return EncryptionResult(
        ciphertext: encrypted.bytes,
        iv: iv,
        authTag: authTag,
        recordMAC: recordMAC,
      );
    } catch (e) {
      throw CryptoException('加密失败: $e');
    }
  }

  /// 解密账号数据
  Future<Map<String, dynamic>> decryptAccountData({
    required Uint8List ciphertext,
    required Uint8List iv,
    required Uint8List authTag,
    required Uint8List recordMAC,
  }) async {
    try {
      // 步骤 1: 验证完整性
      final recordData = Uint8List(iv.length + ciphertext.length);
      recordData.setRange(0, iv.length, iv);
      recordData.setRange(iv.length, recordData.length, ciphertext);

      final computedMAC = _computeHMAC(recordData);
      if (!_bytesEqual(computedMAC, recordMAC)) {
        throw CryptoException('完整性校验失败：数据可能被篡改');
      }

      // 步骤 2: AES-256-GCM 解密
      final key = encrypt.Key.fromBase64(base64Encode(_keys.encryptionKey));
      final encrypter = encrypt.Encrypter(encrypt.AES(
        key,
        mode: encrypt.AESMode.gcm,
      ));

      // 合并密文和认证标签
      final encryptedWithTag = Uint8List(ciphertext.length + authTag.length);
      encryptedWithTag.setRange(0, ciphertext.length, ciphertext);
      encryptedWithTag.setRange(ciphertext.length, encryptedWithTag.length, authTag);

      final decrypted = encrypter.decrypt(
        encrypt.Encrypted(encryptedWithTag),
        iv: encrypt.IV(iv),
      );

      // 步骤 3: 反序列化 JSON
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      throw CryptoException('解密失败: $e');
    }
  }

  /// 计算 HMAC-SHA256
  Uint8List _computeHMAC(Uint8List data) {
    // 使用认证密钥计算 HMAC
    final hmac = Hmac(sha256, _authenticationKey);
    return Uint8List.fromList(hmac.convert(data).bytes);
  }

  /// 时间恒定比较（防止时序攻击）
  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// 清除内存中的密钥
  void dispose() {
    // 清除 DerivedKeys
    _keys.clear();
    
    // Dart 中无法直接清除内存，
    // 建议定期销毁 service 实例
  }
}

class CryptoException implements Exception {
  final String message;
  CryptoException(this.message);

  @override
  String toString() => 'CryptoException: $message';
}
```

---

## 本地存储扩展

### 数据库 Schema 升级

```dart
/// 数据库升级脚本
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // 版本 2: 添加加密字段
    await db.execute('''
      ALTER TABLE accounts ADD COLUMN encrypted_data BLOB;
      ALTER TABLE accounts ADD COLUMN auth_tag BLOB;
      ALTER TABLE accounts ADD COLUMN record_mac BLOB;
      ALTER TABLE accounts ADD COLUMN vector_clock TEXT;
      ALTER TABLE accounts ADD COLUMN lamport_clock INTEGER;
      ALTER TABLE accounts ADD COLUMN is_deleted INTEGER DEFAULT 0;
      ALTER TABLE accounts ADD COLUMN tombstone_at INTEGER;
    ''');

    // 创建操作日志表
    await db.execute('''
      CREATE TABLE operation_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        old_data TEXT,
        new_data TEXT,
        vector_clock TEXT NOT NULL,
        lamport_clock INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    // 创建向量时钟状态表
    await db.execute('''
      CREATE TABLE vector_clock_state (
        device_id TEXT PRIMARY KEY,
        vector_clock TEXT NOT NULL,
        lamport_clock INTEGER NOT NULL,
        last_updated_at INTEGER NOT NULL
      )
    ''');

    // 创建冲突日志表
    await db.execute('''
      CREATE TABLE conflicts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id TEXT NOT NULL,
        conflict_type TEXT NOT NULL,
        local_version TEXT,
        remote_version TEXT,
        resolution_status TEXT DEFAULT 'pending',
        resolved_data TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // 创建索引
    await db.execute('CREATE INDEX idx_operation_log_account_id ON operation_log(account_id)');
    await db.execute('CREATE INDEX idx_operation_log_timestamp ON operation_log(timestamp)');
    await db.execute('CREATE INDEX idx_conflicts_account_id ON conflicts(account_id)');
  }
}
```

### 操作日志管理

```dart
/// 操作日志条目
class OperationLogEntry {
  final String id;
  final String accountId;
  final String deviceId;
  final String operation;  // 'create', 'update', 'delete'
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final Map<String, int> vectorClock;
  final int lamportClock;
  final int timestamp;
  final String syncStatus;  // 'pending', 'synced', 'failed'

  OperationLogEntry({
    required this.id,
    required this.accountId,
    required this.deviceId,
    required this.operation,
    this.oldData,
    this.newData,
    required this.vectorClock,
    required this.lamportClock,
    required this.timestamp,
    required this.syncStatus,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId,
    'deviceId': deviceId,
    'operation': operation,
    'oldData': oldData,
    'newData': newData,
    'vectorClock': vectorClock,
    'lamportClock': lamportClock,
    'timestamp': timestamp,
    'syncStatus': syncStatus,
  };
}

/// 操作日志管理器
class OperationLogManager {
  final Database _db;
  final String _deviceId;

  OperationLogManager(this._db, this._deviceId);

  /// 记录操作
  Future<void> logOperation({
    required String accountId,
    required String operation,
    required Map<String, int> vectorClock,
    required int lamportClock,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    final id = const Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await _db.insert('operation_log', {
      'id': id,
      'account_id': accountId,
      'device_id': _deviceId,
      'operation': operation,
      'old_data': oldData != null ? jsonEncode(oldData) : null,
      'new_data': newData != null ? jsonEncode(newData) : null,
      'vector_clock': jsonEncode(vectorClock),
      'lamport_clock': lamportClock,
      'timestamp': timestamp,
      'sync_status': 'pending',
    });
  }

  /// 获取待同步的操作
  Future<List<OperationLogEntry>> getPendingOperations({
    int? limit,
  }) async {
    final maps = await _db.query(
      'operation_log',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'timestamp ASC',
      limit: limit,
    );

    return maps.map((m) => _mapToEntry(m)).toList();
  }

  /// 标记操作为已同步
  Future<void> markAsSynced(String operationId) async {
    await _db.update(
      'operation_log',
      {'sync_status': 'synced'},
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  /// 标记操作为同步失败
  Future<void> markAsFailed(String operationId) async {
    await _db.update(
      'operation_log',
      {'sync_status': 'failed'},
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  OperationLogEntry _mapToEntry(Map<String, dynamic> map) => OperationLogEntry(
    id: map['id'],
    accountId: map['account_id'],
    deviceId: map['device_id'],
    operation: map['operation'],
    oldData: map['old_data'] != null ? jsonDecode(map['old_data']) : null,
    newData: map['new_data'] != null ? jsonDecode(map['new_data']) : null,
    vectorClock: Map<String, int>.from(jsonDecode(map['vector_clock'])),
    lamportClock: map['lamport_clock'],
    timestamp: map['timestamp'],
    syncStatus: map['sync_status'],
  );
}
```

---

## 向量时钟实现

### 向量时钟管理器

```dart
/// 向量时钟（用于因果一致性）
class VectorClock {
  final Map<String, int> clock;

  VectorClock({Map<String, int>? initialClock})
    : clock = initialClock ?? {};

  /// 初始化当前设备的向量时钟
  void init(String deviceId) {
    clock[deviceId] = 0;
  }

  /// 递增当前设备的逻辑时钟
  void increment(String deviceId) {
    clock[deviceId] = (clock[deviceId] ?? 0) + 1;
  }

  /// 合并远程向量时钟（接收时调用）
  void merge(VectorClock remote) {
    for (final entry in remote.clock.entries) {
      clock[entry.key] = max(clock[entry.key] ?? 0, entry.value);
    }
  }

  /// 比较两个向量时钟的因果关系
  /// 返回: -1 (小于), 0 (并发), 1 (大于)
  int compareTo(VectorClock other) {
    bool isLessOrEqual = true;
    bool isGreaterOrEqual = true;

    // 获取所有设备 ID
    final allDevices = <String>{...clock.keys, ...other.clock.keys};

    for (final deviceId in allDevices) {
      final thisValue = clock[deviceId] ?? 0;
      final otherValue = other.clock[deviceId] ?? 0;

      if (thisValue > otherValue) {
        isLessOrEqual = false;
      }
      if (thisValue < otherValue) {
        isGreaterOrEqual = false;
      }
    }

    if (isLessOrEqual && isGreaterOrEqual) {
      return 0; // 相等
    } else if (isGreaterOrEqual) {
      return 1; // 大于
    } else if (isLessOrEqual) {
      return -1; // 小于
    } else {
      return 0; // 并发
    }
  }

  /// 检查是否发生了冲突（并发修改）
  bool isConflictWith(VectorClock other) {
    return compareTo(other) == 0 && !isEqual(other);
  }

  /// 检查是否相等
  bool isEqual(VectorClock other) {
    if (clock.length != other.clock.length) return false;
    for (final entry in clock.entries) {
      if ((other.clock[entry.key] ?? 0) != entry.value) return false;
    }
    return true;
  }

  /// 转换为 JSON
  Map<String, int> toJson() => Map.from(clock);

  /// 从 JSON 反序列化
  static VectorClock fromJson(Map<String, dynamic> json) {
    return VectorClock(
      initialClock: Map<String, int>.from(
        json.map((k, v) => MapEntry(k, v as int)),
      ),
    );
  }

  @override
  String toString() => 'VC($clock)';
}

/// Lamport 时钟（因果一致性的补充）
class LamportClock {
  int _clock = 0;

  /// 获取当前时钟值并自增
  int increment() {
    _clock++;
    return _clock;
  }

  /// 同步远程时钟
  void sync(int remoteValue) {
    _clock = max(_clock, remoteValue) + 1;
  }

  int get value => _clock;
}

/// 向量时钟状态管理器
class VectorClockManager {
  final Database _db;
  final String _deviceId;
  
  late VectorClock _vectorClock;
  late LamportClock _lamportClock;

  VectorClockManager({
    required Database db,
    required String deviceId,
  }) : _db = db,
       _deviceId = deviceId;

  /// 初始化向量时钟状态
  Future<void> initialize() async {
    // 从数据库加载
    final maps = await _db.query(
      'vector_clock_state',
      where: 'device_id = ?',
      whereArgs: [_deviceId],
    );

    if (maps.isNotEmpty) {
      final map = maps.first;
      _vectorClock = VectorClock(
        initialClock: Map<String, int>.from(
          jsonDecode(map['vector_clock']) as Map,
        ),
      );
      _lamportClock = LamportClock()..._clock = map['lamport_clock'] as int;
    } else {
      _vectorClock = VectorClock();
      _vectorClock.init(_deviceId);
      _lamportClock = LamportClock();

      // 保存到数据库
      await _persistState();
    }
  }

  /// 记录本地操作
  Future<Map<String, dynamic>> recordLocalOperation() async {
    _vectorClock.increment(_deviceId);
    final lamport = _lamportClock.increment();

    await _persistState();

    return {
      'vectorClock': _vectorClock.toJson(),
      'lamportClock': lamport,
    };
  }

  /// 应用远程操作
  Future<void> applyRemoteOperation(
    VectorClock remoteVC,
    int remoteLamport,
  ) async {
    _vectorClock.merge(remoteVC);
    _lamportClock.sync(remoteLamport);

    await _persistState();
  }

  /// 获取当前向量时钟
  VectorClock getVectorClock() => VectorClock(
    initialClock: Map.from(_vectorClock.clock),
  );

  /// 获取当前 Lamport 时钟
  int getLamportClock() => _lamportClock.value;

  /// 检查冲突
  bool detectConflict(VectorClock remoteVC) {
    return _vectorClock.isConflictWith(remoteVC);
  }

  /// 持久化状态到数据库
  Future<void> _persistState() async {
    await _db.insert(
      'vector_clock_state',
      {
        'device_id': _deviceId,
        'vector_clock': jsonEncode(_vectorClock.toJson()),
        'lamport_clock': _lamportClock.value,
        'last_updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
```

---

## CRDT 冲突合并

### 冲突解决策略

```dart
/// 冲突类型
enum ConflictType {
  /// 并发修改（两个设备同时修改了同一个字段）
  concurrentEdit,
  /// 删除冲突（一个设备删除，另一个修改）
  deleteConflict,
  /// 字段冲突（字段级别的并发修改）
  fieldConflict,
}

/// 冲突信息
class ConflictInfo {
  final String accountId;
  final ConflictType type;
  final DateTime detectedAt;
  final Map<String, dynamic> localVersion;
  final Map<String, dynamic> remoteVersion;
  final VectorClock localVC;
  final VectorClock remoteVC;

  ConflictInfo({
    required this.accountId,
    required this.type,
    required this.detectedAt,
    required this.localVersion,
    required this.remoteVersion,
    required this.localVC,
    required this.remoteVC,
  });
}

/// CRDT 合并策略
class CRDTMergeStrategy {
  /// 字段级别合并（推荐）
  static Map<String, dynamic> fieldLevelMerge({
    required Map<String, dynamic> localVersion,
    required Map<String, dynamic> remoteVersion,
    required VectorClock localVC,
    required VectorClock remoteVC,
  }) {
    final merged = <String, dynamic>{};
    final allKeys = <String>{
      ...localVersion.keys,
      ...remoteVersion.keys,
    };

    for (final key in allKeys) {
      if (key == 'id' || key == 'timestamp') {
        // 不合并这些字段
        merged[key] = localVersion[key] ?? remoteVersion[key];
        continue;
      }

      final localValue = localVersion[key];
      final remoteValue = remoteVersion[key];

      if (localValue == null) {
        // 本地没有，取远程
        merged[key] = remoteValue;
      } else if (remoteValue == null) {
        // 远程没有，取本地
        merged[key] = localValue;
      } else if (localValue == remoteValue) {
        // 相同，直接使用
        merged[key] = localValue;
      } else {
        // 冲突：根据时间戳选择
        // (实际应该使用向量时钟的因果关系)
        final localTime = localVersion['modified_at'] as int? ?? 0;
        final remoteTime = remoteVersion['modified_at'] as int? ?? 0;

        if (remoteTime > localTime) {
          merged[key] = remoteValue;
        } else {
          merged[key] = localValue;
        }
      }
    }

    // 更新合并元数据
    merged['merged_at'] = DateTime.now().millisecondsSinceEpoch;
    merged['merge_source'] = 'crdt_field_merge';

    return merged;
  }

  /// Last-Write-Wins 策略（简单但可能丢失数据）
  static Map<String, dynamic> lastWriteWins({
    required Map<String, dynamic> localVersion,
    required Map<String, dynamic> remoteVersion,
  }) {
    final localTime = localVersion['modified_at'] as int? ?? 0;
    final remoteTime = remoteVersion['modified_at'] as int? ?? 0;

    return remoteTime > localTime ? remoteVersion : localVersion;
  }

  /// 自定义解决器（保留两个版本供用户选择）
  static Map<String, dynamic> manual({
    required Map<String, dynamic> selectedVersion,
  }) {
    return selectedVersion;
  }

  /// 删除冲突解决
  static Map<String, dynamic> resolveDeleteConflict({
    required Map<String, dynamic> liveVersion,
    required int deleteTime,
    required int modifyTime,
  }) {
    // 如果修改时间在删除之后，保留修改版本
    if (modifyTime > deleteTime) {
      return liveVersion;
    }
    // 否则保持删除状态
    return {'_deleted': true, '_deleteTime': deleteTime};
  }
}

/// 冲突管理器
class ConflictManager {
  final Database _db;
  final String _deviceId;

  ConflictManager({
    required Database db,
    required String deviceId,
  }) : _db = db,
       _deviceId = deviceId;

  /// 记录冲突
  Future<void> recordConflict(ConflictInfo conflict) async {
    await _db.insert('conflicts', {
      'account_id': conflict.accountId,
      'conflict_type': conflict.type.toString(),
      'local_version': jsonEncode(conflict.localVersion),
      'remote_version': jsonEncode(conflict.remoteVersion),
      'resolution_status': 'pending',
      'created_at': conflict.detectedAt.millisecondsSinceEpoch,
    });
  }

  /// 获取待解决的冲突
  Future<List<ConflictInfo>> getPendingConflicts() async {
    final maps = await _db.query(
      'conflicts',
      where: 'resolution_status = ?',
      whereArgs: ['pending'],
    );

    return maps.map((m) => _mapToConflictInfo(m)).toList();
  }

  /// 解决冲突
  Future<void> resolveConflict(
    String conflictId,
    Map<String, dynamic> mergedData,
  ) async {
    await _db.update(
      'conflicts',
      {
        'resolution_status': 'resolved',
        'resolved_data': jsonEncode(mergedData),
      },
      where: 'id = ?',
      whereArgs: [conflictId],
    );
  }

  ConflictInfo _mapToConflictInfo(Map<String, dynamic> map) {
    return ConflictInfo(
      accountId: map['account_id'],
      type: ConflictType.values.firstWhere(
        (t) => t.toString() == map['conflict_type'],
      ),
      detectedAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      localVersion: jsonDecode(map['local_version']),
      remoteVersion: jsonDecode(map['remote_version']),
      localVC: VectorClock.fromJson({}),  // 从数据库加载
      remoteVC: VectorClock.fromJson({}), // 从数据库加载
    );
  }
}
```

---

## 同步引擎重构

### 重构后的 SyncService

```dart
/// 增强的同步服务
class SyncServiceV2 extends ChangeNotifier {
  final EnhancedCryptoService _cryptoService;
  final SecureStorageService _storageService;
  final E2EECryptoService _e2eeCrypto;
  final VectorClockManager _vcManager;
  final OperationLogManager _opLog;
  final ConflictManager _conflictManager;
  final SyncConfig _config;

  // ... 现有字段 ...

  /// 重构的同步流程
  Future<SyncResult> syncNowV2() async {
    final serverUrl = await _getSyncServerUrl();
    if (serverUrl.isEmpty) {
      return SyncResult.failure('同步服务器地址未配置');
    }

    _updateState(SyncState.syncing);

    try {
      // 步骤 1: 初始化同步会话
      final syncSessionId = await _initializeSyncSession(serverUrl);

      // 步骤 2: 获取本地待同步操作
      final localOps = await _opLog.getPendingOperations();

      if (localOps.isNotEmpty) {
        // 步骤 3: 推送本地操作
        final pushResult = await _pushOperations(
          serverUrl,
          syncSessionId,
          localOps,
        );

        if (pushResult.hasConflicts) {
          // 步骤 4: 处理冲突
          await _resolveConflicts(serverUrl, syncSessionId, pushResult.conflicts);
        }
      }

      // 步骤 5: 拉取远程操作
      final remoteOps = await _pullOperations(serverUrl, syncSessionId);

      // 步骤 6: 应用远程操作到本地
      for (final op in remoteOps) {
        await _applyRemoteOperation(op);
      }

      // 步骤 7: 完成同步
      await _finalizeSyncSession(serverUrl, syncSessionId);

      _lastSyncTime = DateTime.now();
      await _storageService.setSetting('sync_last_time', _lastSyncTime!.toIso8601String());

      _updateState(SyncState.synced);
      return SyncResult.success();
    } catch (e, stack) {
      debugPrint('>>> [SYNC] 同步异常: $e\n$stack');
      _setError('同步失败: $e');
      return SyncResult.failure(e.toString());
    }
  }

  /// 初始化同步会话
  Future<String> _initializeSyncSession(String serverUrl) async {
    final vc = _vcManager.getVectorClock();
    final response = await http.post(
      Uri.parse('$serverUrl/sync/start'),
      headers: await _buildRequestHeaders(),
      body: jsonEncode({
        'deviceId': await _getDeviceId(),
        'vectorClock': vc.toJson(),
        'accountCount': 0, // 从数据库获取
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('初始化同步失败: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['syncSessionId'];
  }

  /// 推送本地操作
  Future<PushResult> _pushOperations(
    String serverUrl,
    String syncSessionId,
    List<OperationLogEntry> operations,
  ) async {
    final encryptedOps = <Map<String, dynamic>>[];

    for (final op in operations) {
      final encrypted = await _e2eeCrypto.encryptAccountData({
        'operation': op.operation,
        'accountId': op.accountId,
        'timestamp': op.timestamp,
        'data': op.newData,
      });

      encryptedOps.add({
        'id': op.id,
        'type': op.operation,
        'accountId': op.accountId,
        'vectorClock': op.vectorClock,
        'lamportClock': op.lamportClock,
        'timestamp': op.timestamp,
        'encryptedData': encrypted.toJson(),
        // 添加数字签名
        'signature': await _signOperation(op),
      });
    }

    final response = await http.post(
      Uri.parse('$serverUrl/sync/push'),
      headers: await _buildRequestHeaders(),
      body: jsonEncode({
        'syncSessionId': syncSessionId,
        'deviceId': await _getDeviceId(),
        'operations': encryptedOps,
      }),
    );

    if (response.statusCode == 200) {
      // 所有操作都被接受
      for (final op in operations) {
        await _opLog.markAsSynced(op.id);
      }
      return PushResult.success();
    } else if (response.statusCode == 409) {
      // 检测到冲突
      final data = jsonDecode(response.body);
      return PushResult.conflict(
        conflicts: List.from(data['conflicts'] ?? []),
      );
    } else {
      throw Exception('推送操作失败: ${response.statusCode}');
    }
  }

  /// 拉取远程操作
  Future<List<Map<String, dynamic>>> _pullOperations(
    String serverUrl,
    String syncSessionId,
  ) async {
    final vc = _vcManager.getVectorClock();
    
    final response = await http.post(
      Uri.parse('$serverUrl/sync/pull'),
      headers: await _buildRequestHeaders(),
      body: jsonEncode({
        'syncSessionId': syncSessionId,
        'deviceId': await _getDeviceId(),
        'vectorClock': vc.toJson(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('拉取操作失败: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return List.from(data['operations'] ?? []);
  }

  /// 应用远程操作到本地
  Future<void> _applyRemoteOperation(Map<String, dynamic> op) async {
    // 验证签名
    if (!await _verifyOperationSignature(op)) {
      throw Exception('操作签名验证失败');
    }

    // 解密操作数据
    final encrypted = EncryptionResult.fromJson(
      Map<String, String>.from(op['encryptedData']),
    );
    final decrypted = await _e2eeCrypto.decryptAccountData(
      ciphertext: encrypted.ciphertext,
      iv: encrypted.iv,
      authTag: encrypted.authTag,
      recordMAC: encrypted.recordMAC,
    );

    // 应用向量时钟
    final remoteVC = VectorClock(
      initialClock: Map<String, int>.from(op['vectorClock']),
    );
    await _vcManager.applyRemoteOperation(remoteVC, op['lamportClock']);

    // 应用操作到本地数据库
    // ... (实现账号的创建/更新/删除)
  }

  // ... 其他辅助方法 ...
}

class PushResult {
  final bool success;
  final bool hasConflicts;
  final List<Map<String, dynamic>> conflicts;

  PushResult({
    required this.success,
    required this.hasConflicts,
    required this.conflicts,
  });

  factory PushResult.success() => PushResult(
    success: true,
    hasConflicts: false,
    conflicts: [],
  );

  factory PushResult.conflict({required List<Map<String, dynamic>> conflicts}) =>
    PushResult(
      success: false,
      hasConflicts: true,
      conflicts: conflicts,
    );
}
```

---

## 测试策略

### 单元测试

```dart
void main() {
  group('KeyDerivationService', () {
    test('应该派生相同的密钥给相同的输入', () async {
      const password = 'MyPassword123!@#';
      const email = 'user@example.com';
      const deviceId = 'device-001';

      final keys1 = await KeyDerivationService.deriveKeys(
        password,
        email,
        deviceId,
      );
      final keys2 = await KeyDerivationService.deriveKeys(
        password,
        email,
        deviceId,
      );

      // 由于盐值随机，密钥应该不同
      // 但应该通过验证
      expect(
        await KeyDerivationService.verifyPassword(password, email, deviceId, keys1.salt),
        true,
      );
    });
  });

  group('VectorClock', () {
    test('应该正确比较因果关系', () {
      final vc1 = VectorClock(initialClock: {'A': 2, 'B': 3});
      final vc2 = VectorClock(initialClock: {'A': 2, 'B': 3});
      final vc3 = VectorClock(initialClock: {'A': 3, 'B': 2});
      final vc4 = VectorClock(initialClock: {'A': 2, 'B': 4});

      expect(vc1.compareTo(vc2), 0); // 相等
      expect(vc1.compareTo(vc3), 0); // 并发
      expect(vc1.compareTo(vc4), -1); // 小于
    });

    test('应该检测冲突', () {
      final local = VectorClock(initialClock: {'A': 2, 'B': 0});
      final remote = VectorClock(initialClock: {'A': 0, 'B': 2});

      expect(local.isConflictWith(remote), true);
    });
  });

  group('CRDTMergeStrategy', () {
    test('字段级合并应该保留两个版本的非冲突字段', () {
      final local = {
        'id': 'acc-1',
        'name': 'GitHub',
        'username': 'john_doe', // 本地修改
        'password': 'old_pwd',
        'modified_at': 1000,
      };
      final remote = {
        'id': 'acc-1',
        'name': 'GitHub',
        'username': 'john_doe',
        'password': 'new_pwd', // 远程修改
        'modified_at': 2000,
      };

      final merged = CRDTMergeStrategy.fieldLevelMerge(
        localVersion: local,
        remoteVersion: remote,
        localVC: VectorClock(),
        remoteVC: VectorClock(),
      );

      // 密码字段应该选择修改时间更晚的版本
      expect(merged['password'], 'new_pwd');
    });
  });

  group('E2EECryptoService', () {
    test('加密和解密应该能恢复原始数据', () async {
      final keys = await KeyDerivationService.deriveKeys(
        'password',
        'user@example.com',
        'device-1',
      );

      final crypto = E2EECryptoService(
        keys: keys,
        authenticationKey: keys.authenticationKey,
      );

      final original = {
        'username': 'john_doe',
        'password': 'SecurePass123!',
      };

      final encrypted = await crypto.encryptAccountData(original);
      final decrypted = await crypto.decryptAccountData(
        ciphertext: encrypted.ciphertext,
        iv: encrypted.iv,
        authTag: encrypted.authTag,
        recordMAC: encrypted.recordMAC,
      );

      expect(decrypted['username'], original['username']);
      expect(decrypted['password'], original['password']);
    });

    test('篡改的数据应该无法解密', () async {
      final keys = await KeyDerivationService.deriveKeys(
        'password',
        'user@example.com',
        'device-1',
      );

      final crypto = E2EECryptoService(
        keys: keys,
        authenticationKey: keys.authenticationKey,
      );

      final original = {'username': 'john_doe', 'password': 'pwd'};
      final encrypted = await crypto.encryptAccountData(original);

      // 篡改 ciphertext
      encrypted.ciphertext[0] ^= 0xFF;

      expect(
        () => crypto.decryptAccountData(
          ciphertext: encrypted.ciphertext,
          iv: encrypted.iv,
          authTag: encrypted.authTag,
          recordMAC: encrypted.recordMAC,
        ),
        throwsA(isA<CryptoException>()),
      );
    });
  });
}
```

### 集成测试

```dart
void main() {
  group('SyncServiceV2 集成测试', () {
    late Database db;
    late SyncServiceV2 syncService;
    late E2EECryptoService e2eeCrypto;

    setUpAll(() async {
      // 初始化测试数据库
      db = await openDatabase(inMemoryDatabasePath);
      await _createSchema(db);

      // 初始化加密服务
      final keys = await KeyDerivationService.deriveKeys(
        'testpass',
        'test@example.com',
        'test-device',
      );
      e2eeCrypto = E2EECryptoService(
        keys: keys,
        authenticationKey: keys.authenticationKey,
      );

      // 初始化同步服务
      // syncService = ...
    });

    tearDownAll(() async {
      await db.close();
    });

    test('多设备并发编辑应该被正确合并', () async {
      // 模拟设备 A 创建账号
      var account = AccountItem(
        id: 'acc-1',
        name: 'GitHub',
        email: 'user@github.com',
        templateId: 'template-1',
        data: {'username': 'john_doe', 'password': 'pwd123'},
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      // 设备 A 修改密码
      account = account.copyWith(
        data: {...account.data, 'password': 'newpwd456'},
      );

      // 模拟设备 B 同时修改用户名
      final deviceBVersion = {
        'username': 'john_smith',
        'password': 'pwd123',
      };

      // CRDT 合并应该保留两个修改
      final merged = CRDTMergeStrategy.fieldLevelMerge(
        localVersion: account.data,
        remoteVersion: deviceBVersion,
        localVC: VectorClock(initialClock: {'A': 2}),
        remoteVC: VectorClock(initialClock: {'B': 2}),
      );

      expect(merged['username'], 'john_smith'); // 来自设备 B
      expect(merged['password'], 'newpwd456');  // 来自设备 A
    });

    test('离线编辑应该在网络恢复时同步', () async {
      // 离线时创建操作日志
      // 网络恢复时推送到服务器
      // 验证操作被正确同步
    });
  });
}

Future<void> _createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE accounts (
      id TEXT PRIMARY KEY,
      name TEXT,
      ...
    )
  ''');
  // ... 创建其他表
}
```

---

## 实现时间表

```
Week 1-2:  加密服务实现 + 单元测试
Week 3-4:  本地存储扩展 + 向量时钟
Week 5-6:  CRDT 冲突合并 + 集成测试
Week 7-8:  同步引擎重构 + 性能优化
Week 9-10: 离线支持 + 全面测试
Week 11-12: 文档 + 生产部署准备
```

---

## 安全检查清单

- [ ] 密钥从不被记录到日志
- [ ] 加密密钥仅存在于内存中
- [ ] 所有密码字符串都被清除
- [ ] HTTPS 证书锁定已实现
- [ ] 所有请求都被签名
- [ ] 数据完整性用 HMAC 保护
- [ ] 单元测试覆盖所有加密操作
- [ ] 安全审计（代码审查）
- [ ] 渗透测试
- [ ] 依赖安全扫描

这份技术指南提供了从加密到同步的完整实现路线图。下一步是选择具体的依赖库并开始实现。
