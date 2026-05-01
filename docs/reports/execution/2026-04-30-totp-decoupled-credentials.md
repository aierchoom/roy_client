# 独立 2FA 凭据解耦执行报告

**Status**: Implemented and validated
**Goal**: 将 2FA/TOTP 从账号字段中解耦，改为独立保密对象，由账号信息页维护关联关系。

## Scope

- `lib/models/totp_credential.dart`
- `lib/services/secure_storage_service.dart`
- `lib/services/service_manager.dart`
- `lib/providers/enhanced_app_provider.dart`
- `lib/sync/sync_payload_codec.dart`
- `lib/sync/sync_service.dart`
- `lib/views/accounts/totp_account_list_view.dart`
- `lib/views/accounts/totp_credential_edit_view.dart`
- `lib/views/accounts/account_edit_view.dart`
- `lib/models/account_template.dart`
- `test/models/totp_credential_test.dart`
- `test/sync/sync_payload_codec_test.dart`
- `test/sync/sync_state_machine_test.dart`
- `test/sync/multi_device_sync_test.dart`
- `docs/features/two-factor-auth/**`

## Changes

- 新增 `TotpCredential`，包含 TOTP 配置、显示名、关联账号列表、HLC、同步版本和 tombstone。
- 新增 `totp_credentials` 加密存储表，随 vault DB schema 升级到 version 6。
- 新增 `LocalSyncEntityType.totpCredential`，同步层可推送和拉取 `_type = "totp_credential"` 的 AEAD payload。
- `2FA` 页面从账号筛选页升级为独立 2FA 项管理页，支持新增、编辑、删除、复制验证码和关联账号。
- 账号编辑页在模板 2FA 字段处展示“关联 2FA”面板，账号字段区域不再持有 TOTP secret，也不再内嵌验证码密钥输入框。
- 内置网站模板提供 2FA 关联字段；`AccountFieldType.totp` 保留为关联控件类型，`AccountFieldAttributes.totpDefaults` 已下线。
- 删除旧账号 TOTP 字段扫描、导入和兼容测试。由于项目尚未生产发布，本轮不兼容旧数据。

## Validation

- `dart analyze lib test`: passed with no issues.
- Targeted 2FA regression suite: passed, 40 tests.
- `flutter test`: passed, 111 passed and 1 skipped.

## Risk Notes

- 本轮明确不迁移旧 `totp_secret` 开发数据；如本地测试库里仍有旧字段，需要重建或手动清理。
- 2FA credential 冲突恢复走 HLC merge 和 outbox 重试，后续仍应补更细的 UI 冲突决策体验。

## Follow-ups

- 为账号关联面板补 widget test。
- 为 `totp_credentials` 增加真实 SQLite migration 测试。
- 把验证码复制纳入全局敏感剪切板策略评估。
