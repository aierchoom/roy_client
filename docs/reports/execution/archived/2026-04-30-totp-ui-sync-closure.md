# TOTP UI 与同步闭环执行报告

**日期**: 2026-04-30
**任务**: T11.3-T11.5 账号体验、同步回归和质量收敛
**状态**: 已完成

## 目标

完成账号内置 2FA/TOTP 的首个可用闭环：用户可以录入 TOTP 密钥，在账号页查看和复制动态验证码，并让该密钥继续沿用现有加密同步、outbox 审阅、CRDT 合并和冲突收件箱。

## 范围

- `lib/views/accounts/account_edit_view.dart`
- `lib/services/totp_service.dart`
- `test/services/totp_service_test.dart`
- `test/sync/sync_state_machine_test.dart`
- `test/sync/multi_device_sync_test.dart`
- `docs/features/two-factor-auth/**`
- `docs/product/application-characteristics.md`
- `docs/product/iteration-tasks.md`

## 变更

- 账号编辑/查看页对 `AccountFieldType.totp` 显示专用验证码面板。
- 支持粘贴 Base32 secret、`otpauth://totp` URI 或结构化 JSON；保存时规范化为 JSON。
- 查看/编辑页显示当前验证码、剩余秒数、配置元信息和复制验证码按钮。
- 无效 TOTP 配置会在字段内展示错误，并在保存时阻止写入。
- “复制全部信息”和 TOTP 字段复制动作只复制当前验证码，不复制 secret。
- TOTP secret 继续作为 `AccountItem.data['totp_secret']` 保存，不新增数据库表、服务端 route、同步 metadata 或独立同步协议。

## 验证

```text
$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\services\totp_service_test.dart
00:00 +14: All tests passed!

$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\models\account_template_test.dart
00:00 +4: All tests passed!

$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\sync\sync_state_machine_test.dart
00:02 +14: All tests passed!

$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\sync\multi_device_sync_test.dart
00:00 +6: All tests passed!

$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\sync\sync_conflict_recovery_test.dart
00:02 +4: All tests passed!

$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze lib test
No issues found!

$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test
00:04 +97 ~1: All tests passed!

git diff --check
通过，仅有 CRLF 提示。

Markdown relative links
OK
```

## 手工验收清单

1. 新建或编辑网站模板账号，在 `2FA 密钥` 中粘贴 Base32 secret。
2. 保存账号后重新打开详情页，确认验证码面板显示 6 位验证码和倒计时。
3. 粘贴 `otpauth://totp/...` URI，保存后确认字段值被规范化，验证码仍可生成。
4. 点击 TOTP 字段复制按钮，确认复制的是当前验证码，不是 secret。
5. 输入非法 secret，确认字段内有错误提示，保存时不会静默写入。
6. 修改 TOTP secret 后确认首页待同步审阅仍可见；批准前不会自动 push。
7. 批准后在可信设备拉取，确认两端固定时间戳下验证码一致。
8. 两端并发修改 `totp_secret`，确认冲突进入 `data.totp_secret` 冲突日志。

## 风险记录

- 本轮不做 QR 扫码、二维码导出、SecretRoy 解锁 MFA、WebAuthn/passkey 或服务端验证码校验。
- TOTP 依赖本地系统时间；设备时间漂移仍可能导致目标网站拒绝验证码。
- 复制验证码仍会进入系统剪贴板；剪贴板自动清理留作后续增强。
- 普通沙箱下部分 Flutter 测试曾无输出超时，使用本机 Flutter/Pub cache 权限重跑后通过。
