# vault/device identity 真实化执行报告

| 项目 | 内容 |
|---|---|
| 日期 | 2026-04-30 |
| 状态 | 完成 |
| 任务 | T1 真实化 vault/device identity |
| 范围 | `IdentityService`、`ServiceManager` 解锁链路、Unlock UI 错误展示、identity 测试 |

## 1. 目标

本轮目标不是新增配对路线，而是把本地 vault/device identity 的生命周期变成可推理、可测试、不可静默错配的基础能力。

必须满足：

- 新安装设备可以生成真实且持久的 `vaultId`。
- 独立安装默认不会共享同一个 `vaultId`。
- 密钥链接导入后，新设备继承旧设备 `vaultId`，但保留自己的 `deviceId`。
- 本地数据库已存在时，如果 vault identity 缺失或损坏，不允许静默生成新 `vaultId` 继续解锁。

## 2. 业务分支

| 场景 | 处理方式 |
|---|---|
| 首次安装，无数据库、无 identity | 允许生成新的 `deviceId`、`vaultId` 和 vault 密钥材料 |
| 应用重启，identity 完整 | 读取并复用原有身份 |
| 独立新安装 | 生成独立 `vaultId` 和 `deviceId` |
| 密钥链接导入 | 写入导入的 `vaultId` 和 vault 密钥材料，保留本机 `deviceId` |
| 已有数据库但 vault identity 缺失 | 解锁失败，提示使用恢复路线或重置，不生成新 vault 身份 |
| vault identity 完整但 `deviceId` 缺失 | 生成新的本机 `deviceId`，不改变 vault 归属 |
| identity 部分缺失或格式非法 | 抛出 `IdentityCorruptedException` |

## 3. 代码变更

- `IdentityService.initialize()` 增加 `allowGenerateVaultIdentity` 参数。
- `IdentityService.checkIdentityExists()` 改为校验 vault identity 格式，而不是只看 key 是否存在。
- 移除 `IdentityService` 内部的 mock 命名，改为明确的 key material 命名。
- `ServiceManager._completeUnlock()` 在本地数据库存在时禁止生成新 vault identity。
- `UnlockView` 不再把“有数据库但 identity 缺失”当成首次运行自动重建，并会展示 ServiceManager 返回的身份错误。
- `sync_service_identity_test.dart` 的 fake storage 显式跳过 outbox 补录，避免测试日志噪声。

## 4. 验证

已通过：

- `dart analyze lib test`
- `flutter test test/services/identity_service_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/sync_service_identity_test.dart --reporter expanded --timeout 30s`

新增或强化覆盖：

- 独立 store 会生成不同 `vaultId` 和 `deviceId`。
- 禁止生成 vault identity 时，缺失 vault identity 会抛出 `IdentityCorruptedException`。
- vault identity 完整但 `deviceId` 缺失时，会修复本机 `deviceId`。
- `checkIdentityExists()` 会拒绝格式非法的 vault 密钥材料。
- 密钥链接导入仍保持 `vaultId` 一致、`deviceId` 唯一。

## 5. 风险和后续

- 本轮仍沿用当前 `priv_` / `sym_` 格式作为本地 vault key material 承载格式；标准 AEAD/E2EE 密钥体系属于 T3。
- 本轮没有实现身份导出/恢复的新 UI，只保证已有恢复路线不会被静默新 identity 覆盖。
- T2 仍需要继续把所有同步元数据按 vault 隔离，本轮只处理身份生命周期本身。

`docs/product/application-characteristics.md` 已检查并同步补充 identity 验收边界。
