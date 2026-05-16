# Mock 数据工厂 — 测试辅助工具

> 面向 QA 和开发者的 Mock 数据生成与注入框架。
>
> 目标：一行代码生成完整测试场景，一键注入 FakeStorage 或 ServiceManager。

---

## 目录结构

```
test/helpers/
├── README.md                    # 本文档
├── hlc_helpers.dart             # HLC 时钟快捷构造
├── mock_data_factory.dart       # Builder + 工厂方法 + 批量生成
├── mock_scenarios.dart          # 预定义场景（标准用户、冲突、大数据量等）
└── mock_injector.dart           # 数据注入器（FakeStorage / ServiceManager）
```

---

## 快速开始

### 1. 生成一个账户

```dart
import 'helpers/mock_data_factory.dart';

final account = MockDataFactory.account(id: 'acc_001', name: 'GitHub')
  .withEmail('alice@example.com')
  .withPassword('secret123')
  .withWebsite('https://github.com')
  .build();
```

### 2. 一键生成标准用户场景

```dart
import 'helpers/mock_scenarios.dart';

final data = MockScenario.standardUser();

print(data.totalAccounts);   // 6
print(data.totalTemplates);  // 2
print(data.totalTotps);      // 2
```

### 3. 注入到 FakeStorage（单元测试 / Widget 测试）

```dart
import 'helpers/mock_injector.dart';
import '../sync/sync_server_test_harness.dart';

final storage = FakeSecureStorageService();
final data = MockScenario.standardUser();

MockInjector.intoFakeStorage(data, storage);

expect(storage.accounts.length, 6);
```

### 4. 注入到 ServiceManager（集成测试）

```dart
final sm = createFakeServiceManager();
await sm.unlockWithPassword('test');

final data = MockScenario.standardUser();
await MockInjector.intoServiceManager(data, sm);

expect(sm.storageService.loadAccounts(), completion(hasLength(6)));
```

---

## API 参考

### AccountItemBuilder

| 方法 | 说明 |
|------|------|
| `.withId(id)` | 设置 ID（**必填**） |
| `.withName(name)` | 设置名称（**必填**） |
| `.withEmail(email)` | 设置邮箱 |
| `.withTemplateId(id)` | 设置模板 ID |
| `.withTemplate(template)` | 使用模板对象设置 ID |
| `.withField(key, value)` | 设置 data 字段（自动带 HLC） |
| `.withData(map)` | 批量设置 data 字段 |
| `.withPassword(pw)` | 快捷设置 `data['password']` |
| `.withUsername(u)` | 快捷设置 `data['username']` |
| `.withWebsite(url)` | 快捷设置 `data['website']` |
| `.withNotes(text)` | 快捷设置 `data['notes']` |
| `.withPhone(p)` | 快捷设置 `data['phone']` |
| `.withOtpToken(t)` | 快捷设置 `data['otpToken']` |
| `.withPinned(true)` | 置顶 |
| `.withDeleted()` | 标记为已删除（tombstone） |
| `.withSyncStatus(status)` | 设置同步状态 |
| `.withServerVersion(v)` | 设置服务端版本 |
| `.withNameHlc(h)` / `.withEmailHlc(h)` / `.withDataHlc(key, h)` | 手动覆盖 HLC |
| `.build()` | 构造 AccountItem |

### AccountTemplateBuilder

| 方法 | 说明 |
|------|------|
| `AccountTemplateBuilder(id)` | 构造器（**必填 templateId**） |
| `AccountTemplateBuilder.fromPreset('bank_card')` | 从字段预设复制 |
| `.withTitle(t)` / `.withSubTitle(t)` | 标题 |
| `.withCategory(c)` | 分类 |
| `.withIcon(codePoint)` | 图标 |
| `.addField(...)` | 添加字段（详细参数见源码） |
| `.addFields(list)` | 批量添加字段 |
| `.withSyncStatus(s)` / `.withServerVersion(v)` | 状态与版本 |
| `.withDeleted()` | 标记为已删除 |
| `.build()` | 构造 AccountTemplate |

### TotpCredentialBuilder

| 方法 | 说明 |
|------|------|
| `TotpCredentialBuilder(id)` | 构造器（**必填 id**） |
| `.withLabel(l)` | 设置标签 |
| `.fromOtpAuthUri(uri)` | 从 otpauth URI 解析配置 |
| `.fromParams(secret, issuer, account, ...)` | 从离散参数构造 |
| `.linkToAccount(accountId)` | 关联账户 |
| `.withSyncStatus(s)` / `.withServerVersion(v)` | 状态与版本 |
| `.withDeleted()` | 标记为已删除 |
| `.build()` | 构造 TotpCredential |

### MockDataFactory 静态方法

| 方法 | 说明 |
|------|------|
| `.account(id, name)` | 返回 AccountItemBuilder |
| `.websiteAccount(...)` | 一键构造网站登录账户 |
| `.secureNote(...)` | 一键构造安全笔记 |
| `.bankAccount(...)` | 一键构造银行账号 |
| `.deletedAccount(...)` | 一键构造 tombstone |
| `.template(id)` | 返回 AccountTemplateBuilder |
| `.totp(id, label)` | 返回 TotpCredentialBuilder |
| `.batchAccounts(count, builder)` | 批量生成账户 |
| `.batchWebsiteAccounts(count, ...)` | 批量生成同构网站账户 |
| `.batchTemplates(count, builder)` | 批量生成模板 |
| `.batchTotps(count, builder)` | 批量生成 TOTP |
| `.conflictAccountPair(...)` | 构造冲突账户对（local + remote） |
| `.setDefaultTimestamp(ts)` / `.resetDefaultTimestamp()` | 控制默认时间戳 |

### 预定义场景

| 场景 | 包含内容 | 用途 |
|------|---------|------|
| `MockScenario.standardUser()` | 6账户 + 2模板 + 2TOTP | 常规功能测试 |
| `MockScenario.conflictPair()` | 4账户（2对冲突） | CRDT 合并测试 |
| `MockScenario.largeDataset(count: 100)` | N账户 + 10模板 + 20TOTP | 性能/列表测试 |
| `MockScenario.emptyVault()` | 空数据 | 空状态 UI 测试 |
| `MockScenario.pendingSync(count: 10)` | N账户 + N待同步变更 | 同步队列测试 |
| `MockScenario.mixedRealWorld()` | 标准用户 + 通知 + 健康报告 | 综合回归测试 |

### 注入器

| 方法 | 目标 | 用途 |
|------|------|------|
| `MockInjector.intoFakeStorage(data, storage)` | FakeSecureStorageService | 单元/Widget 测试 |
| `MockInjector.accountsIntoFakeStorage(...)` | FakeSecureStorageService | 仅注入账户 |
| `MockInjector.templatesIntoFakeStorage(...)` | FakeSecureStorageService | 仅注入模板 |
| `MockInjector.totpsIntoFakeStorage(...)` | FakeSecureStorageService | 仅注入 TOTP |
| `MockInjector.intoServiceManager(data, sm)` | ServiceManager | 集成/E2E 测试 |
| `MockInjector.accountsIntoServiceManager(...)` | ServiceManager | 仅注入账户 |

所有注入方法均支持 `clearExisting: true` 先清空已有数据。

---

## HLC 辅助

测试中不再需要手写 `Hlc(10, 0, 'local')`：

```dart
import 'helpers/hlc_helpers.dart';

hlc.zero                // Hlc(0, 0, 'local')
hlc.local(10)           // Hlc(10, 0, 'local')
hlc.remote(20)          // Hlc(20, 0, 'remote')
hlc.deviceA(5)          // Hlc(5, 0, 'device_a')
hlc.now('device_b')     // 当前时间戳
hlcSequence(nodeId: 'local', start: 10, count: 5)
// => [Hlc(10,0,'local'), Hlc(11,0,'local'), ...]
```

---

## 典型测试用例示例

### Widget 测试：验证账户列表渲染

```dart
testWidgets('renders account list with mock data', (tester) async {
  final sm = createFakeServiceManager();
  await sm.unlockWithPassword('test');

  final data = MockScenario.standardUser();
  await MockInjector.intoServiceManager(data, sm);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: sm,
      child: const MaterialApp(home: AccountListView()),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('GitHub'), findsOneWidget);
  expect(find.text('Gmail'), findsOneWidget);
  expect(find.text('招商银行'), findsOneWidget);
});
```

### 单元测试：验证 CRDT 合并

```dart
test('merges conflicted accounts correctly', () {
  final pair = MockDataFactory.conflictAccountPair(
    id: 'acc_1',
    localName: 'Local',
    remoteName: 'Remote',
  );

  final result = CrdtMergeEngine.merge(pair.local, pair.remote);

  expect(result.name, 'Remote'); // remote HLC 更大
});
```

### 性能测试：大数据量滚动

```dart
testWidgets('scrolls through 100 accounts smoothly', (tester) async {
  final storage = FakeSecureStorageService();
  final data = MockScenario.largeDataset(accountCount: 100);
  MockInjector.intoFakeStorage(data, storage);

  // ... pump widget and scroll
});
```

---

## 扩展指南

### 添加新的预设场景

在 `mock_scenarios.dart` 的 `MockScenario` 类中添加静态方法：

```dart
static MockScenarioData myCustomScenario() {
  return MockScenarioData(
    accounts: [
      MockDataFactory.websiteAccount(id: 'acc_custom', name: 'Custom'),
    ],
    templates: [
      MockDataFactory.template('tpl_custom').withTitle('Custom').build(),
    ],
  );
}
```

### 添加新的快捷构造器

在 `mock_data_factory.dart` 的 `MockDataFactory` 类中添加静态方法：

```dart
static AccountItem sshKeyAccount({required String id, ...}) {
  return AccountItemBuilder()
    ..withId(id)
    ..withField('host', '192.168.1.1')
    ..withField('ssh_key', '-----BEGIN OPENSSH PRIVATE KEY-----')
    ...
    ..build();
}
```

---

## 注意事项

1. **HLC 自动填充**：`withName`、`withEmail`、`withField` 等方法会自动为对应字段生成 `Hlc.now('local')`。如需精确控制冲突场景，使用 `withNameHlc` / `withDataHlc` 手动覆盖。
2. **ID 唯一性**：批量生成时内部使用 `_nextId(prefix, index)` 确保唯一。手动设置 ID 时需自行保证不重复。
3. **模板外键**：注入到 FakeStorage 时，模板先于账户注入，确保账户引用的 `templateId` 已存在。
4. **ServiceManager 需解锁**：`intoServiceManager` 要求 ServiceManager 处于 `unlocked` 状态，否则会 assert 失败。
5. **默认时间戳**：所有对象默认使用 `2024-01-01` 的时间戳，可通过 `MockDataFactory.setDefaultTimestamp()` 覆盖。
