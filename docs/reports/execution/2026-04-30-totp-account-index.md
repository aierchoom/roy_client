# TOTP 账号索引页执行报告

**Status**: Implemented and validated
**Goal**: 增加一个独立页面集中展示已配置 2FA/TOTP 的账号。

## Scope

- `lib/services/totp_account_filter.dart`
- `lib/views/accounts/totp_account_list_view.dart`
- `lib/views/home/home_view.dart`
- `lib/views/home/layouts/home_view_mobile.dart`
- `lib/views/home/layouts/home_view_desktop.dart`
- `test/services/totp_account_filter_test.dart`
- `docs/features/two-factor-auth/**`
- `docs/reports/execution/README.md`

## Changes

- 主导航新增 `2FA` 页面入口，移动端底部导航和桌面侧边栏保持同一入口。
- 新增 `TotpAccountFilter`，统一判断账号是否配置 TOTP。
- 新增 `TotpAccountListView`，集中展示已配置 2FA 的账号数量和密钥数量。
- 页面复用 `AccountListTile`，继续沿用列表页“已配置 2FA”的暴露面规则，不展示、不复制 TOTP secret。
- 从该页可进入账号编辑，也可使用既有删除确认流程。

## Validation

- `dart analyze lib test` passed with no issues.
- `flutter test test/services/totp_account_filter_test.dart` passed.
- `flutter test` passed: 106 passed, 1 skipped.
- `git diff --check` passed with CRLF warnings only.
- Markdown relative link scan passed: 82 files.

## Risk Notes

- 该页只做客户端本地筛选，不改变账号数据结构、同步协议或服务端行为。
- 遗留字段只有在 key/label 像 TOTP 且内容可解析为 TOTP 配置时才会被收录，避免普通 2FA 备注误入。

## Follow-ups

- 后续可在该页增加“即将过期倒计时排序”或多 TOTP 字段筛选，但不应把 secret 推到列表页。
