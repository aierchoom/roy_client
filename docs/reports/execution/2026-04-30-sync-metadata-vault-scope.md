# 同步元数据按 vault 隔离执行报告

| 项目 | 内容 |
|---|---|
| 日期 | 2026-04-30 |
| 状态 | 完成 |
| 任务 | T2 同步元数据按 vault 隔离 |
| 范围 | `SyncService`、`SyncServerUrlStore`、`ServiceManager`、同步身份测试 |

## 1. 目标

同步运行态元数据不能跨 vault 串用。一个 vault 的版本号、dirty 状态、恢复标记和同步服务器地址，不应该影响另一个 vault。

本轮覆盖：

- `sync_version_$vaultId`
- `sync_dirty_$vaultId`
- `sync_last_time_$vaultId`
- `sync_recovery_$vaultId`
- `sync_server_url_$vaultId`

## 2. 业务规则

读取同步元数据时：

```text
先读当前 vault scoped key。
如果不存在，再读取历史 legacy global key。
如果 legacy key 存在，迁移写入当前 vault scoped key。
后续运行只依赖 scoped key。
```

历史 legacy key 只作为兼容迁移来源，不能作为长期业务状态。

## 3. 代码变更

- `SyncService.initialize()` 统一通过 vault scoped setting 读取 `version`、`lastSyncTime`、`dirty`。
- `SyncService._loadRecoveryMarker()` 支持把历史 `sync_recovery` 迁移到 `sync_recovery_$vaultId`。
- `SyncService._getSyncServerUrl()` 优先读取 `sync_server_url_$vaultId`，并兼容迁移旧的全局 `sync_server_url`。
- `SyncServerUrlStore` 支持按 `vaultId` 读写和解析服务器地址。
- `ServiceManager` 保存、读取和解析同步服务器地址时传入当前 vaultId；导入密钥链接携带 server url 时写入导入目标 vault。

## 4. 验证

已通过：

- `dart analyze lib test`
- `flutter test test/sync/sync_service_identity_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/sync_state_machine_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/sync_recovery_loop_test.dart --reporter expanded --timeout 30s`

新增或强化覆盖：

- legacy `sync_dirty`、`sync_version`、`sync_last_time`、`sync_recovery` 会迁移到当前 vault scoped key。
- 不同 vault 读取到各自的 version、dirty、recovery 状态。
- legacy `sync_server_url` 会迁移为 `sync_server_url_$vaultId`。
- vault2 写入服务器地址不会覆盖 vault1 或全局 legacy 地址。

## 5. 风险和后续

- 本轮不改账号、模板实体表结构；当前应用仍是单 vault 本地库模型，实体数据跟随当前本地库。
- `local_sync_changes` 已经包含 `vault_id`，本轮未扩展 conflict log 的 vault 字段；真正多 vault 同库运行前仍需评估冲突日志表归属。
- T3 将继续处理同步 payload 标准 AEAD/E2EE，不属于本轮范围。

`docs/product/application-characteristics.md` 已检查并同步补充同步元数据隔离规则。
