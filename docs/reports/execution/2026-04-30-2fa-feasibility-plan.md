# 2FA/TOTP 可行性分析执行报告

**日期**: 2026-04-30
**任务**: 2FA/TOTP 功能迭代计划
**状态**: 已完成

## 目标

在正式实现前，先判断 SecretRoy 当前模型、加密、同步、冲突和 UI 架构是否适合加入 2FA/TOTP 动态验证码，并给出可执行的分阶段计划。

## 范围

- `lib/models/account_template.dart`
- `lib/views/accounts/account_edit_view.dart`
- `lib/views/templates/template_edit_view.dart`
- `lib/services/secure_storage_service.dart`
- `lib/sync/sync_payload_codec.dart`
- `lib/sync/sync_service.dart`
- `docs/features/two-factor-auth/**`
- `docs/product/iteration-tasks.md`

## 结论

可行。推荐第一阶段只做账户内置 TOTP 验证器，不做 SecretRoy 解锁 MFA，也不先引入 QR 扫码插件。

核心理由：

- TOTP secret 可作为账号保密字段保存。
- 现有本地数据库加密和同步 AEAD 已能保护该 secret。
- outbox 审阅能防止用户未确认时自动扩散 TOTP 修改。
- CRDT data 字段和 conflict inbox 可覆盖 TOTP secret 并发修改。
- `crypto` 依赖已存在，TOTP 核心算法无需新增依赖。

## 输出文档

- `docs/features/two-factor-auth/README.md`
- `docs/features/two-factor-auth/feasibility-and-implementation-plan.md`

## 同步策略判定

2FA/TOTP 不需要独立同步协议。TOTP secret 和配置应作为账号保密数据，继续沿用现有链路：

```text
AccountItem.data
-> 本地加密数据库
-> local_sync_changes outbox 审阅
-> SyncPayloadCodec AEAD payload
-> CRDT data 字段合并
-> conflict inbox 冲突处理
```

服务端只保存 opaque 密文，不新增 TOTP route、metadata key 或验证码校验逻辑。

## 建议实现顺序

1. TOTP service + RFC 6238 测试向量。
2. `AccountFieldType.totp` 和模板编辑接入。
3. 内置网站模板增加可选 `totp_secret` 字段。
4. 账号编辑/查看页增加验证码、倒计时和复制动作。
5. 补同步、冲突、多设备和 outbox 回归。

## 当前落地状态

- T11.1 已完成：新增 `TotpService`，覆盖 Base32、JSON 配置、`otpauth://totp`、SHA1/SHA256/SHA512 HOTP/TOTP 和错误分类。
- T11.2 已完成：新增 `AccountFieldType.totp`、`AccountFieldAttributes.totpDefaults`，模板编辑器支持 TOTP 字段，内置网站模板增加可选 `totp_secret`。
- T11.3 已完成：账号编辑/查看页支持 TOTP 专用验证码面板、倒计时、复制验证码和保存前规范化。
- T11.4 已完成：TOTP secret 跟随现有 outbox、AEAD payload、CRDT merge 和 conflict inbox，不新增服务端协议。
- T11.5 已完成：功能文档、执行报告、全局特性文档和测试维护记录已同步。
- 已通过 `flutter test test\services\totp_service_test.dart`、`flutter test test\models\account_template_test.dart`、`flutter test test\sync\sync_state_machine_test.dart`、`flutter test test\sync\multi_device_sync_test.dart`、`flutter test test\sync\sync_conflict_recovery_test.dart` 和 `dart analyze lib test`。
- 已通过 `flutter test` 全量测试，结果为 97 passed, 1 skipped。

## 风险记录

- 如果第一阶段加入 QR 扫码，会显著扩大权限、平台插件和测试范围。
- TOTP secret 泄漏风险接近密码泄漏，应默认隐藏、不搜索、不在列表页展示验证码。
- 系统时间漂移会影响验证码正确性，UI 需要给出可理解提示。
