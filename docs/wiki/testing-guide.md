# 测试指南

**最后更新**: 2026-05-01

本文记录当前 `roy_client/test/` 中真实存在的测试结构和常用运行方式。

## 1. 测试概览

当前客户端测试集中在模型、加密存储、身份、同步、CRDT、配对、TOTP 和敏感剪贴板逻辑。

| 指标 | 当前值 |
|---|---|
| 测试文件数 | 24 |
| 测试用例数 | 120+ |
| Widget 测试 | 1（account_list_tile_test.dart） |
| 主要覆盖 | models、services、sync、widgets |

目录结构：

```text
test/
├── models/
│   ├── account_item_test.dart
│   ├── account_template_test.dart
│   ├── hlc_test.dart
│   ├── local_sync_change_test.dart
│   └── totp_credential_test.dart
├── services/
│   ├── biometric_auth_service_test.dart
│   ├── database_file_cipher_test.dart
│   ├── database_file_key_manager_test.dart
│   ├── identity_service_test.dart
│   ├── secure_storage_service_encryption_test.dart
│   ├── secure_storage_service_sync_outbox_test.dart
│   ├── totp_import_service_test.dart
│   ├── totp_qr_image_import_service_test.dart
│   ├── totp_service_test.dart
│   └── vault_pairing_crypto_test.dart
├── sync/
│   ├── crdt_merge_engine_test.dart
│   ├── crdt_merge_invariants_test.dart
│   ├── lan_pairing_service_test.dart
│   ├── multi_device_sync_test.dart
│   ├── sync_conflict_recovery_test.dart
│   ├── sync_payload_codec_test.dart
│   ├── sync_recovery_loop_test.dart
│   ├── sync_service_identity_test.dart
│   └── sync_state_machine_test.dart
└── widgets/
    └── account_list_tile_test.dart
```

## 2. 运行测试

```bash
# 运行所有 Flutter/Dart 测试
flutter test

# 运行某个测试文件
flutter test test/sync/sync_state_machine_test.dart

# 运行指定名称的测试
flutter test --name "merge is deterministic"

# 展开输出
flutter test --reporter expanded
```

当前仓库还可以直接跑 Dart 测试：

```bash
dart test test/sync/lan_pairing_service_test.dart
```

同级服务端仓库的测试在 `../roy_server/test/`：

```bash
cd ../roy_server
node --test
```

## 3. 重点测试文件

### 3.1 模型测试

- `test/models/account_item_test.dart`
  - 校验 `SyncStatus` JSON 兼容解析。
  - 避免异常状态值导致模型解析崩溃。

- `test/models/account_template_test.dart`
  - 校验内置模板保持精简。
  - 校验网站模板默认隐藏密码字段。
  - 校验模板同步状态解析 fallback。

### 3.2 加密、身份和存储测试

- `test/services/database_file_cipher_test.dart`
  - 数据库字节流加密/解密。
  - 错误密钥和畸形信封拒绝。

- `test/services/database_file_key_manager_test.dart`
  - 数据库文件数据密钥创建、解封、轮换。

- `test/services/secure_storage_service_encryption_test.dart`
  - 本地数据库长期落盘为加密文件。
  - 遗留明文数据库不会被自动导入。
  - 中断恢复（`.bak`/`.tmp` 残留处理）。

- `test/services/secure_storage_service_sync_outbox_test.dart`
  - 本地同步变更记录（outbox）写入、合并、状态流转。
  - create→update→delete 合并规则守卫。

- `test/services/identity_service_test.dart`
  - 本机身份初始化和复用。
  - 部分损坏的身份状态会被拒绝。
  - `vault_api_token` 持久化和 transfer code 携带。

- `test/services/biometric_auth_service_test.dart`
  - AES-256-GCM 加密存储 round-trip。
  - Legacy plaintext 迁移路径。
  - 禁用后完整清理。

### 3.3 同步和 CRDT 测试

- `test/sync/crdt_merge_engine_test.dart`
  - 删除墓碑、字段冲突、远端/本地胜出规则。

- `test/sync/crdt_merge_invariants_test.dart`
  - 合并确定性。
  - 合并顺序和重复执行不破坏结果。

- `test/sync/multi_device_sync_test.dart`
  - 多设备 push/pull。
  - 并发修改和删除同步。

- `test/sync/sync_state_machine_test.dart`
  - 同步状态迁移。
  - 缺少服务器地址、畸形响应、push 成功提示等。

- `test/sync/sync_recovery_loop_test.dart`
  - 中断恢复 marker。
  - 成功同步后清理恢复标记。

- `test/sync/sync_conflict_recovery_test.dart`
  - 冲突恢复链路。

- `test/sync/sync_payload_codec_test.dart`
  - 加密签名 payload 编解码。
  - 篡改、跨 vault payload 和旧 base64 payload 兼容。

- `test/sync/sync_service_identity_test.dart`
  - vault identity 导入导出。
  - 离线恢复码密码校验。
  - 导入 preview 不提前写入密钥。
  - 坏 dump 不写 storage。
  - dirty 状态按 vault 隔离。

- `test/sync/lan_pairing_service_test.dart`
  - 8 位面对面临时码。
  - 非法字符拒绝。
  - 主机创建、领取、停止流程。

### 3.4 TOTP 与敏感剪贴板测试

- `test/services/totp_service_test.dart`
  - RFC 6238 标准向量验证。
  - SHA1/SHA256/SHA512、时间窗口、Base32 解析。

- `test/services/totp_import_service_test.dart`
  - `otpauth://` URI、文本、标签化密钥提取与规范化。

- `test/services/totp_qr_image_import_service_test.dart`
  - 剪贴板二维码图片解码与导入。

- `test/services/sensitive_clipboard_service_test.dart`
  - 高/中/低风险等级定时清理。
  - SHA-256 hash 比对防误删。

### 3.5 Widget 测试

- `test/widgets/account_list_tile_test.dart`
  - 账号列表项风险标签展示。

## 4. 常见测试模式

### 4.1 模型兼容性

```dart
test('accepts numeric and named status values', () {
  expect(syncStatusFromJson(1), SyncStatus.pendingPush);
  expect(syncStatusFromJson('synchronized'), SyncStatus.synchronized);
});
```

### 4.2 ChangeNotifier 状态观察

`SyncService` 当前通过 `ChangeNotifier` 发状态变化：

```dart
final states = <SyncState>[];
service.addListener(() => states.add(service.state));

await service.connect();

expect(states.first, SyncState.syncing);
expect(states.last, SyncState.synced);
```

### 4.3 临时文件和加密存储

涉及 `SecureStorageService` 的测试应使用临时目录、测试 cipher 和独立设备 ID，避免污染真实用户数据。

```dart
final cipher = DatabaseFileCipher(keyBytes: testKeyBytes);
final storage = SecureStorageService(databaseCipher: cipher);
await storage.initialize(deviceId: 'device_test');
```

### 4.4 同步 payload 安全性

同步 payload 测试应至少覆盖：

- 正常 encode/decode。
- MAC 或 ciphertext 被改动后拒绝。
- vaultId 不匹配时拒绝。
- 旧 payload 兼容路径。

## 5. 回归建议

改动模型解析时，至少跑：

```bash
flutter test test/models
```

改动本地加密或数据库时，至少跑：

```bash
flutter test test/services
```

改动同步协议、HLC、CRDT、配对时，至少跑：

```bash
flutter test test/sync
```

改动客户端和服务端同步契约时，同时跑：

```bash
flutter test test/sync
cd ../roy_server
node --test
```

## 6. 覆盖缺口

当前主要缺口：

- Widget 测试仅覆盖 `account_list_tile`，缺少端到端 UI 流程测试。
- 缺少真实网络环境下的客户端/服务端联合测试。
- 安全设置、同步设置、模板编辑页仍主要依赖手动验证。
- 缺少 TOTP 关联面板、冲突箱、同步设置等页面的 widget 测试。

新增 UI 测试时建议创建明确目录，例如：

```text
test/widgets/
test/views/
```
