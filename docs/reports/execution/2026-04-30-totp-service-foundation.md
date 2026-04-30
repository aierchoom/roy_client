# TOTP Service 基础执行报告

**日期**: 2026-04-30
**任务**: T11.1 TOTP 算法与解析
**状态**: 已完成

## 目标

先建立 2FA/TOTP 的纯 Dart 算法层，支持 Base32 secret、`otpauth://totp` URI、HOTP/TOTP 计算和明确错误分类，为后续账号字段、UI、同步回归提供稳定基础。

## 范围

- `lib/services/totp_service.dart`
- `test/services/totp_service_test.dart`
- `docs/product/iteration-tasks.md`
- `docs/features/two-factor-auth/feasibility-and-implementation-plan.md`

## 通过标准

- RFC 6238 SHA1/SHA256/SHA512 测试向量通过。
- Base32 secret 支持大小写、空格、连字符和 padding。
- `otpauth://totp/...` 能解析 issuer、account、secret、algorithm、digits、period。
- 非法 secret、非法 URI、非法 digits、非法 period 有明确错误。
- 不新增服务端 route、独立同步状态或同步 metadata。

## 结果

- 实现：新增 `TotpConfig`、`TotpCode`、`TotpService`，覆盖 Base32 规整/解码、`otpauth://totp` 解析、JSON 配置解析、HOTP/TOTP 生成和错误分类。
- 定向测试：新增 `test/services/totp_service_test.dart`，覆盖 RFC 6238 SHA1/SHA256/SHA512 向量、Base32 输入规整、URI/JSON 解析、倒计时和非法输入。
- 静态分析：`dart analyze lib test` 通过。

## 验证记录

```text
$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\services\totp_service_test.dart
00:00 +13: All tests passed!

$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze lib test
No issues found!
```

## 风险记录

- 本轮只做算法层，不接账号模板和 UI。
- TOTP 使用本地系统时间；多设备一致性需要后续 UI/同步阶段再验证。
- 2FA secret 暂未接入账号字段；同步语义仍需在 T11.2-T11.4 通过 `AccountItem.data`、outbox 和多设备测试验证。
