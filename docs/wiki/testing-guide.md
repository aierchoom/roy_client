# 测试指南

**版本**: v1.1.0
**最后更新**: 2026-04-28

---

## 目录

1. [测试概览](#1-测试概览)
2. [测试环境](#2-测试环境)
3. [单元测试](#3-单元测试)
4. [集成测试](#4-集成测试)
5. [Widget 测试](#5-widget-测试)
6. [测试最佳实践](#6-测试最佳实践)

---

## 1. 测试概览

### 1.1 测试统计

| 指标 | 数值 |
|------|------|
| 总测试数 | 37 |
| 测试文件数 | 8 |
| 覆盖模块 | 同步、加密、CRDT、配对 |

### 1.2 测试目录结构

```
test/
├── services/
│   └── identity_service_test.dart
├── sync/
│   ├── crdt_merge_engine_test.dart
│   ├── crdt_merge_invariants_test.dart
│   ├── multi_device_sync_test.dart
│   ├── sync_conflict_recovery_test.dart
│   ├── sync_recovery_loop_test.dart
│   ├── sync_state_machine_test.dart
│   └── lan_pairing_service_test.dart
└── widget/
    └── (待添加)
```

### 1.3 测试分类

| 类型 | 描述 | 位置 |
|------|------|------|
| 单元测试 | 测试单个函数/类 | `test/services/`, `test/sync/` |
| 集成测试 | 测试模块间交互 | `test/sync/` |
| Widget 测试 | 测试 UI 组件 | `test/widget/` |

---

## 2. 测试环境

### 2.1 运行测试

```bash
# 运行所有测试
flutter test

# 运行指定文件
flutter test test/sync/crdt_merge_engine_test.dart

# 运行指定测试
flutter test --name "merge is deterministic"

# 详细输出
flutter test --reporter expanded

# 紧凑输出
flutter test --reporter compact

# 并行运行
flutter test --concurrency=4
```

### 2.2 测试配置

创建 `test/test_config.dart` 配置测试环境：

```dart
import 'package:flutter_test/flutter_test.dart';

void setupTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 设置测试超时
  setUp(() {
    // 初始化测试环境
  });

  tearDown(() {
    // 清理测试环境
  });
}
```

### 2.3 Mock 服务

测试中常用的 Mock 类：

```dart
/// Mock 安全存储服务
class FakeSecureStorageService extends SecureStorageService {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> write(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<List<AccountTemplate>> loadDirtyTemplates() async => [];
}
```

---

## 3. 单元测试

### 3.1 测试结构

```dart
group('Hlc', () {
  test('parse correctly deserializes Hlc string', () {
    final hlc = Hlc.parse('1714205400000-5-device_abc');

    expect(hlc.time, equals(1714205400000));
    expect(hlc.counter, equals(5));
    expect(hlc.nodeId, equals('device_abc'));
  });

  test('compareTo orders by time first', () {
    final hlc1 = Hlc(1000, 0, 'a');
    final hlc2 = Hlc(2000, 0, 'b');

    expect(hlc1.compareTo(hlc2), lessThan(0));
  });
});
```

### 3.2 测试同步服务

```dart
group('SyncService', () {
  late SyncService syncService;
  late FakeSecureStorageService storage;

  setUp(() {
    storage = FakeSecureStorageService();
    syncService = SyncService(storage: storage);
  });

  test('connect returns true for valid server', () async {
    // 使用 mock HTTP 客户端
    final result = await syncService.connect('https://valid-server.com');

    expect(result, isTrue);
  });

  test('syncNow returns error when offline', () async {
    final result = await syncService.syncNow();

    expect(result.success, isFalse);
    expect(result.error, contains('offline'));
  });
});
```

### 3.3 测试 CRDT 合并

```dart
group('CRDTMergeEngine', () {
  late CRDTMergeEngine engine;

  setUp(() {
    engine = CRDTMergeEngine(deviceId: 'test_device');
  });

  test('newer remote tombstone wins over older local edits', () {
    final local = createTestVault([
      AccountItem(id: '1', name: 'Local', /* ... */),
    ]);

    final remote = createTestVault([
      AccountItem(id: '1', isDeleted: true, /* ... */),
    ]);

    final result = engine.merge(local, remote);

    expect(result.merged.accounts.first.isDeleted, isTrue);
  });

  test('merge is deterministic for same inputs', () {
    final vault1 = createRandomVault();
    final vault2 = createRandomVault();

    final result1 = engine.merge(vault1, vault2);
    final result2 = engine.merge(vault1, vault2);

    expect(result1.merged, equals(result2.merged));
  });
});
```

---

## 4. 集成测试

### 4.0 密钥同步回归测试

Key sync must preserve the receiving device identity while importing the shared vault identity.

Required regression coverage:

- `test/sync/sync_service_identity_test.dart`
  - raw transfer code imports `vaultId`, `privateKey`, and `symmetricKey`
  - target `deviceId` is not overwritten
  - `sroy-secure-v2:` secure link imports with the right password
  - secure link rejects the wrong password
- `test/sync/lan_pairing_service_test.dart`
  - LAN pairing codes are 8 readable characters
  - invalid/ambiguous characters are rejected
  - host can start, claim, and stop cleanly
- `roy_server/test/index.test.js`
  - pairing session create/join/approve/fetch lifecycle
  - unknown pairing code rejection
  - wrapped bundle is delivered as an opaque server payload

Suggested commands:

```powershell
& 'F:\FlutterSDK\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze lib test
& 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\sync\sync_service_identity_test.dart test\sync\lan_pairing_service_test.dart --timeout 20s
node --test
```

### 4.1 多设备同步测试

```dart
group('Multi-device Sync', () {
  test('device B pulls an account created by device A', () async {
    // 创建两个模拟设备
    final deviceA = await createTestDevice('device_a');
    final deviceB = await createTestDevice('device_b');

    // 设备 A 创建账户
    final account = AccountItem(
      id: '1',
      name: 'Test Account',
      templateId: 'generic',
      // ...
    );
    await deviceA.storage.saveAccount(account);
    await deviceA.syncService.syncNow();

    // 设备 B 同步
    await deviceB.syncService.syncNow();
    final accounts = await deviceB.storage.loadAccounts();

    expect(accounts.length, equals(1));
    expect(accounts.first.name, equals('Test Account'));
  });

  test('concurrent edits create conflict state', () async {
    final deviceA = await createTestDevice('device_a');
    final deviceB = await createTestDevice('device_b');

    // 初始同步
    await syncBoth(deviceA, deviceB);

    // 两设备离线编辑同一账户
    await deviceA.editAccount('1', name: 'Name A');
    await deviceB.editAccount('1', name: 'Name B');

    // 同步后检测冲突
    await syncBoth(deviceA, deviceB);

    final conflicts = await deviceA.getConflicts();
    expect(conflicts.length, greaterThan(0));
  });
});
```

### 4.2 同步状态机测试

```dart
group('Sync State Machine', () {
  test('connect stays in syncing until first sync finishes', () async {
    final service = createSyncService();

    final states = <SyncState>[];
    service.stateStream.listen((state) => states.add(state));

    await service.connect('https://server.com');

    expect(states.first, equals(SyncState.syncing));
    expect(states.last, equals(SyncState.synced));
  });

  test('syncNow surfaces server persistence errors', () async {
    final service = createSyncServiceWithError();

    final result = await service.syncNow();

    expect(result.success, isFalse);
    expect(result.error, contains('vault file is unreadable'));
  });
});
```

---

## 5. Widget 测试

### 5.1 基本 Widget 测试

```dart
group('ToneChip Widget', () {
  testWidgets('renders with correct label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ToneChip(
            icon: Icons.star,
            label: 'Test Label',
          ),
        ),
      ),
    );

    expect(find.text('Test Label'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('applies tint color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ToneChip(
            icon: Icons.star,
            label: 'Test',
            tint: Colors.red,
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    // 验证颜色应用
  });
});
```

### 5.2 对话框测试

```dart
group('LanPairingCodeDialog', () {
  testWidgets('accepts exactly 8 pairing characters', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog(
                  context: context,
                  builder: (_) => LanPairingCodeDialog(
                    title: 'Enter Code',
                    subtitle: 'Enter the 8-character pairing code',
                    confirmLabel: 'Confirm',
                    cancelLabel: 'Cancel',
                  ),
                );
              },
              child: Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    // 输入 8 位配对字符
    await tester.enterText(find.byType(TextField), 'ABCD2345');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(result, equals('ABCD2345'));
  });
});
```

---

## 6. 测试最佳实践

### 6.1 命名约定

```dart
// 好的测试命名
test('merge keeps newer value when fields conflict', () {});
test('connect returns false on transport failure', () {});

// 不好的测试命名
test('test merge', () {});
test('test1', () {});
```

### 6.2 测试隔离

```dart
group('Isolated Tests', () {
  late SomeService service;

  setUp(() {
    // 每个测试前创建新实例
    service = SomeService();
  });

  tearDown(() {
    // 每个测试后清理
    service.dispose();
  });

  test('test 1', () {
    // 使用独立的 service 实例
  });

  test('test 2', () {
    // 使用另一个独立的 service 实例
  });
});
```

### 6.3 使用 Helper 函数

```dart
/// 创建测试用账户
AccountItem createTestAccount({
  String id = 'test_id',
  String name = 'Test Account',
  Map<String, String>? data,
}) {
  return AccountItem(
    id: id,
    name: name,
    email: 'test@example.com',
    templateId: 'generic',
    data: data ?? {},
    createdAt: DateTime.now().millisecondsSinceEpoch,
    nameHlc: Hlc.now('test_device'),
    emailHlc: Hlc.now('test_device'),
    dataHlc: {},
  );
}

/// 创建测试用 Vault
Vault createTestVault(List<AccountItem> accounts) {
  return Vault(
    vaultId: 'test_vault',
    accounts: accounts,
    templates: [],
    version: 0,
  );
}
```

### 6.4 测试异步代码

```dart
test('async operation completes', () async {
  final result = await someAsyncOperation();

  expect(result, isNotNull);
});

test('async operation with timeout', () async {
  final result = await someAsyncOperation().timeout(
    Duration(seconds: 5),
    onTimeout: () => throw TimeoutException('Operation timed out'),
  );

  expect(result, isNotNull);
});
```

### 6.5 测试异常

```dart
test('throws on invalid input', () {
  expect(
    () => someFunction(invalidInput),
    throwsA(isA<ArgumentError>()),
  );
});

test('throws specific exception', () {
  expect(
    () => syncService.connect('invalid url'),
    throwsA(allOf(
      isA<SyncException>(),
      hasProperty('message', contains('invalid')),
    )),
  );
});
```

---

## 附录

### A. 测试覆盖率

```bash
# 生成覆盖率报告
flutter test --coverage

# 安装 lcov（如果未安装）
# macOS: brew install lcov
# Linux: sudo apt-get install lcov

# 生成 HTML 报告
genhtml coverage/lcov.info -o coverage/html

# 打开报告
open coverage/html/index.html
```

### B. 常用断言

```dart
// 相等
expect(actual, equals(expected));

// 类型
expect(actual, isA<String>());

// 布尔
expect(actual, isTrue);
expect(actual, isFalse);

// 集合
expect(list, contains(element));
expect(list, hasLength(3));

// 数字
expect(value, greaterThan(10));
expect(value, inInclusiveRange(1, 10));

// 字符串
expect(text, contains('substring'));
expect(text, startsWith('prefix'));

// 异常
expect(() => func(), throwsException);
```

### C. Mock 库

项目使用内置 Mock，不依赖外部 Mock 库。如需更复杂的 Mock，推荐：

- `mockito` - 经典 Mock 框架
- `mocktail` - Dart 原生 Mock 库

---

**文档版本**: 1.0
**最后更新**: 2026-04-28
