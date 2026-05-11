# SecretRoy QA 自动化测试指南

## 1. 测试分层策略

```
        ┌─────────────────┐
        │   E2E Smoke     │  integration_test/  (桌面端 UI 冒烟)
        │  (2 tests)      │
        ├─────────────────┤
        │   Widget Tests  │  test/views/*       (业务边界：编辑、列表、解锁)
        │  (20+ tests)    │
        ├─────────────────┤
        │   Integration   │  test/sync/*        (同步协议、CRDT、网络故障)
        │  (20+ tests)    │  test/services/*    (加密、存储、TOTP)
        ├─────────────────┤
        │      Unit       │  test/models/*      (序列化、兼容性)
        │  (120+ tests)   │  test/theme/*       (Token、布局断点)
        │                 │  test/utils/*       (工具函数)
        └─────────────────┘
```

| 层级 | 目录 | 运行时间 | 运行频率 |
|------|------|---------|---------|
| Unit | `test/models`, `test/theme`, `test/utils`, `test/widgets` | < 10s | 每次提交 |
| Integration | `test/services`, `test/sync`, `test/system` | ~30s | 每次提交 |
| Widget | `test/views` | ~10s | 每次提交 |
| E2E Smoke | `integration_test/` | ~20s | CI / 发布前 |

## 2. 单台设备同步测试

### 原理

无需真实多设备或外网服务器。核心组件：

- **`InMemoryVaultServer`**（`test/sync/sync_server_test_harness.dart`）
  - 本地 `HttpServer.bind(127.0.0.1, 0)` 启动内存中的 Vault 同步服务器
  - 完整实现 GET（分页拉取）与 POST（批量推送 + 409 冲突检测）
  - 支持 `isUnavailable`（503 模拟）、`returnMalformedJson`（协议错误）、`pageSizeLimit`（分页）

- **`TestClient`**（同上）
  - 包含独立的 `IdentityService` + `FakeSecureStorageService` + `SyncService`
  - 两个 `TestClient` 实例共用同一个 `vaultId` / 密钥，但拥有不同 `deviceId`，即可模拟 A/B 双设备

- **`FakeSecureStorageService`**
  - 完全在内存中运行，不依赖 SQLite
  - 子类可覆写 `loadApprovedLocalSyncChanges` 等方法来控制审批流

### 典型场景

| 场景 | 关键类/方法 | 所在文件 |
|------|------------|---------|
| A 创建账号 → B 拉取 | `TestClient.create` + `InMemoryVaultServer.start` | `multi_device_sync_test.dart` |
| 并发编辑 → CRDT 冲突 | `baseItem` + HLC 控制 | `multi_device_sync_test.dart` |
| 离线编辑 → 恢复推送 | `server.isUnavailable` | `multi_device_sync_test.dart` |
| 服务端 503 → 恢复重试 | `server.isUnavailable` | `sync_fault_injection_test.dart` |
| 畸形 JSON → 协议错误 | `server.returnMalformedJson` | `sync_fault_injection_test.dart` |
| 分页拉取聚合 | `server.pageSizeLimit` | `sync_fault_injection_test.dart` |
| 并发 syncNow → 状态机互斥 | 双 Client 同时调用 | `sync_fault_injection_test.dart` |

## 3. 一键回归脚本

### Windows

```powershell
# 完整回归（analyze + style + unit + coverage + integration）
.\tool\run_regression.ps1

# 仅单元测试
.\tool\run_regression.ps1 -UnitOnly

# 仅集成测试
.\tool\run_regression.ps1 -IntegrationOnly

# 跳过覆盖率
.\tool\run_regression.ps1 -NoCoverage
```

### Linux / macOS

```bash
# 完整回归
./tool/run_regression.sh

# 仅单元测试
./tool/run_regression.sh --unit-only

# 仅集成测试
./tool/run_regression.sh --integration-only

# 跳过覆盖率
./tool/run_regression.sh --no-coverage
```

### 输出示例

```
========================================
Regression Summary
========================================

Dart Analyze                            | PASS | 2s
Style Token Check                       | PASS | 1s
Unit Tests                              | PASS | 45s
Integration Tests                       | PASS | 18s

All 4 stages passed.
```

## 4. CI 覆盖范围

`.github/workflows/build-packages.yml` 中的 job：

| Job | 触发条件 | 内容 |
|-----|---------|------|
| `validate` | PR / Push / Tag | `dart analyze` + `style check` + `flutter test --coverage` + 上传 `lcov.info` |
| `integration-test` | PR / Push / Tag | Matrix: Ubuntu (`xvfb-run`) + Windows (`run_regression.ps1`) |
| `android-minimal-apk` | Push / Tag (非 PR) | 构建 release APK |
| `windows-portable` | Push / Tag (非 PR) | 构建 Windows release ZIP |

## 5. 本地调试速查

```bash
# 只跑同步相关测试
flutter test test/sync

# 只跑故障注入
flutter test test/sync/sync_fault_injection_test.dart

# 按名称过滤
flutter test --name "concurrent"

# 展开输出
flutter test --reporter expanded

# Windows 专用（自动处理 winsqlite3）
.\tool\flutter_test.ps1 test\sync
```

## 6. Widget 测试基础设施

### Fake Service Stack

`test/fakes/` 提供了一组可注入的 fake 服务，用于隔离平台依赖：

| Fake | 用途 | 关键覆写 |
|------|------|---------|
| `FakeSecureStorageService` | 内存中的 SecureStorage，无 SQLite | `saveAccount`, `loadAccounts`, `onChange` |
| `FakeIdentityService` | 固定 identity（无需 FlutterSecureStorage） | `hasIdentity = true`, `deviceId`, `vaultId` |
| `FakeCryptoService` | 跳过 PBKDF2 与 secure storage | `initMasterKey`, `verifyMasterPassword` |
| `FakeSyncService` | no-op 同步 | `syncNow`, `connect`, `disconnect` |
| `FakeAutoLockService` | 无生命周期定时器 | `initialize()`, `lock()`, `unlock()` |
| `FakeBiometricAuthService` | 可控生物识别状态 | `getStatus()`, `enableBiometric()` |

### ServiceManager 测试化

`lib/services/service_manager.dart` 提供了 `ServiceManager.testable(...)` 构造函数：

```dart
final manager = ServiceManager.testable(
  secureStorageService: FakeSecureStorageService(),
  identityService: FakeIdentityService(),
  cryptoService: FakeCryptoService(),
  initialState: ServiceManagerState.unlocked,
);
ServiceManager.setInstanceForTesting(manager);
addTearDown(ServiceManager.resetInstance);
```

- 所有 `late final` 服务字段均可注入
- `initialState` 直接设置状态机初始状态
- `setInstanceForTesting` / `resetInstance` 用于控制全局单例

### 典型 Widget 测试模式

```dart
testWidgets('renders edit form', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2000));
  final provider = EnhancedAppProvider(
    FakeSecureStorageService(),
    ServiceManager.testable(initialState: ServiceManagerState.unlocked),
  );
  ServiceManager.setInstanceForTesting(provider.serviceManager);

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<EnhancedAppProvider>.value(
        value: provider,
        child: const AccountEditView(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(AccountEditView), findsOneWidget);
});
```

> 注意：包含 `Timer.periodic` 的视图（如 `AccountListView`）应使用 `pump(duration)` 而非 `pumpAndSettle()`，避免无限等待。

## 7. 新增同步测试的最佳实践

1. **优先使用 harness**：`import 'sync_server_test_harness.dart';`
2. **一台设备模拟多设备**：创建多个 `TestClient`，指向同一个 `InMemoryVaultServer`
3. **故障注入**：通过设置 `server.isUnavailable`、`server.returnMalformedJson`、`server.pageSizeLimit` 等字段模拟异常
4. **保持独立**：每个 test 内创建新的 server/client，`addTearDown(server.close)` 清理
5. **验证状态机**：除了结果对象，还要检查 `syncService.state` 是否进入预期状态（`SyncState.idle`、`SyncState.serverError` 等）
