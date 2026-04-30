# 同步 payload 标准 AEAD/E2EE 执行报告

**日期**: 2026-04-30
**任务**: T3 同步 payload 标准 AEAD/E2EE
**状态**: 已完成

## 目标

将普通账号/模板同步 payload 从过渡型自定义保护升级为标准 AEAD 边界，确保同步服务器只保存 opaque payload，不能理解用户账号明文。

## 实施内容

- `SyncPayloadCodec` 改为使用 `AesGcm.with256bits()`。
- 新 envelope 使用 `sroy-sync:` 前缀和 `alg=aes-256-gcm-hkdf-sha256`。
- payload key 由 vault symmetric key + vault private key 经 HKDF-SHA256 派生。
- AEAD AAD 绑定版本、算法、`vaultId`、`nodeId`，避免跨 vault 或跨 envelope 上下文复用。
- 旧 base64 明文 JSON payload 不再被兼容接受。
- `SyncService` 的 push/pull payload 处理改为 async encode/decode。
- `VaultDumpCoordinator` 的 dump 加密、验证、导入链路同步改为 async AEAD codec。

## 风险收敛

- 篡改 ciphertext 或 mac 时，客户端拒绝解密。
- 非当前 vault 的 payload 在解密前被拒绝。
- 无前缀、无算法声明或 legacy 明文 payload 不再静默进入本地库。
- payload 无法解密时由 `SyncPayloadException` 上抛，`SyncService` 进入明确失败状态。

## 验证

已通过：

- `dart analyze lib test`
- `flutter test test/sync/sync_payload_codec_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/sync_state_machine_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/sync_conflict_recovery_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/sync_recovery_loop_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/sync_service_identity_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/multi_device_sync_test.dart --reporter expanded --timeout 30s`

## 文档同步

- `docs/product/iteration-tasks.md` 已将 T3 标记完成，并将 T4 标记进行中。
- `docs/product/application-characteristics.md` 已新增同步 payload 加密边界。

## 剩余关注

- 当前 payload 算法正式化后不兼容旧明文 payload；这是本次安全边界收敛的刻意选择。
- 后续 T4 需要让服务端对 invalid payload、冲突类型等返回更清晰的机器可读错误。
