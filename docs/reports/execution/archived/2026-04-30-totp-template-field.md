# TOTP 模板字段执行报告

**日期**: 2026-04-30
**任务**: T11.2 账号字段与模板接入
**状态**: 已完成

## 目标

把 TOTP 从纯算法能力提升为正式账号字段类型，让模板系统可以声明 2FA 密钥字段，并让内置网站模板预留可选 `totp_secret` 字段。

## 范围

- `lib/models/account_template.dart`
- `lib/views/templates/template_edit_view.dart`
- `lib/widgets/template_edit_widgets.dart`
- `lib/widgets/account_list_tile.dart`
- `test/models/account_template_test.dart`
- `docs/product/iteration-tasks.md`
- `docs/features/two-factor-auth/feasibility-and-implementation-plan.md`

## 通过标准

- `AccountFieldType.totp` 可序列化、反序列化并在旧数据中保持 fallback。
- 模板编辑器字段类型列表出现“2FA 验证码”。
- 新建或切换到 TOTP 字段时默认保密、不可搜索、可复制。
- 内置网站模板包含可选 `totp_secret` 字段。
- 现有账号和旧模板 JSON 不需要数据库迁移。

## 结果

- 实现：新增 `AccountFieldType.totp`、`AccountFieldAttributes.totpDefaults`，模板编辑器支持“2FA 验证码”类型、图标和样例值。
- 内置模板：`websiteTemplate` 增加可选 `totp_secret` 字段，默认保密、不可搜索、可复制。
- 测试：`account_template_test.dart` 覆盖网站模板字段顺序、TOTP 默认属性和序列化/反序列化。
- 静态分析：`dart analyze lib test` 通过。

## 验证记录

```text
$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\models\account_template_test.dart
00:00 +4: All tests passed!

$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\services\totp_service_test.dart
00:00 +13: All tests passed!

$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze lib test
No issues found!
```

## 风险记录

- 本轮只接入字段类型和模板元数据，不实现验证码显示控件。
- TOTP 字段在账号编辑页暂时仍复用普通保密字段输入；专用解析/预览交互进入 T11.3。
- 合并执行 `flutter test test\services\totp_service_test.dart test\models\account_template_test.dart` 在本机无输出超时；已拆分为两个单文件测试并全部通过。
