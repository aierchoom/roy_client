# TOTP QR 导入执行报告

**Status**: Implemented and validated
**Goal**: 为账户内置 TOTP 增加移动端扫码导入，并让桌面端和不便扫码设备可通过主动粘贴导入二维码图片。

## Scope

- `pubspec.yaml`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/xml/provider_paths.xml`
- `ios/Runner/Info.plist`
- `lib/services/totp_import_service.dart`
- `lib/services/totp_qr_image_import_service.dart`
- `lib/views/accounts/account_edit_view.dart`
- `lib/views/accounts/totp_qr_scanner_view.dart`
- `test/services/totp_import_service_test.dart`
- `test/services/totp_qr_image_import_service_test.dart`
- `docs/features/two-factor-auth/**`
- `docs/product/application-characteristics.md`
- `docs/product/iteration-tasks.md`
- `docs/todo.md`

## Changes

- 新增 `mobile_scanner` 依赖，用于 Android/iOS 账户页 TOTP 二维码扫描。
- 新增 `pasteboard`、`image` 和 `zxing2` 依赖，用于在用户触发粘贴动作后获取二维码图片并在本地解码。
- Android 增加 `CAMERA` 权限，iOS 增加相机用途说明。
- Android 增加 `FileProvider` 路径配置，满足 `pasteboard` 插件的图片剪贴板读写要求。
- 新增 `TotpQrScannerView`，只接受可被解析为 TOTP 配置的二维码内容。
- 新增 `TotpImportService`，统一处理扫码结果和剪贴板文本，支持完整 `otpauth://totp` URI、复制文本中的 URI、标注的 Base32 secret 和既有结构化 JSON。
- 新增 `TotpQrImageImportService`，只在用户点击粘贴或按系统粘贴键后获取本次粘贴内容，图片不可用时再保留文本导入兜底。
- `AccountEditView` 在 TOTP 字段提供“扫码导入”和“粘贴二维码”操作；扫码入口仅在 Android/iOS 显示，粘贴入口会打开主动粘贴面板。
- 导入后仍写回同一个 TOTP 字段，并在保存时继续按结构化 JSON 规范化，不新增同步协议或服务端参与。

## Validation

- `flutter pub get` passed.
- `dart analyze lib test` passed with no issues.
- `flutter test test/services/totp_import_service_test.dart` passed.
- `flutter test test/services/totp_qr_image_import_service_test.dart` passed.
- `flutter test test/services/totp_service_test.dart` passed.
- `flutter test` passed: 111 passed, 1 skipped.
- `flutter build apk --debug` passed and produced `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` passed with CRLF warnings only.
- Markdown relative link scan passed: 82 files.

## Risk Notes

- 扫码需要真实设备或模拟器相机权限；剪贴板图片读取还需要在 Windows/macOS/Linux/Android/iOS 实机上补一次平台行为验收。
- 自动化测试已覆盖二维码图片解码、坏图片和无二维码图片，但不直接依赖真实系统粘贴板事件。
- TOTP 仍依赖本机系统时间；扫码导入不改变验证码时间漂移风险。

## Follow-ups

- 在真机 Android/iOS 上补一次相机权限和扫码体验验收。
- 在 Windows/macOS/Linux 上补一次复制二维码图片后的粘贴导入手工验收。
