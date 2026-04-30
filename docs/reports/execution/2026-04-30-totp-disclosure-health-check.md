# TOTP Disclosure Health Check

**Status**: Completed
**Date**: 2026-04-30
**Scope**: 2FA/TOTP list disclosure, sensitive clipboard cleanup, and documentation health check

## Goal

Close the next 2FA quality gap after the first TOTP workflow landed:

- account detail can generate and copy the current TOTP code;
- list/search surfaces must not expose raw TOTP secret data;
- copied TOTP codes should not remain in the system clipboard indefinitely;
- the product and feature docs should record these safety boundaries.

## Scope

Touched client-only code and docs:

- `lib/widgets/account_list_tile.dart`
- `lib/views/accounts/account_edit_view.dart`
- `lib/services/sensitive_clipboard_service.dart`
- `test/widgets/account_list_tile_test.dart`
- `test/services/sensitive_clipboard_service_test.dart`
- 2FA feature docs, iteration tasks, application characteristics, and execution report index

No server route, sync protocol, database schema, or independent TOTP sync metadata was added.

## Changes

- `AccountListTile` now treats TOTP fields as a configured-state indicator instead of a normal secret field.
- List rows and search cards show only "已配置 2FA" / "2FA configured" for TOTP fields.
- Expanded list details no longer provide reveal or copy actions for TOTP secret values.
- TOTP fields are skipped from list summaries so raw JSON, `otpauth://`, or Base32 content cannot appear as masked preview text.
- Added `SensitiveClipboardService` to clear copied TOTP codes after 45 seconds if the clipboard still contains the same code.
- `AccountEditView` now uses the sensitive clipboard path for TOTP code copy and for copy-all when the current template contains TOTP fields.
- Feature docs now record that clipboard cleanup is implemented and that list/search surfaces must only show configured state.

## Validation

Passed:

```text
dart analyze lib test
flutter test test\services\sensitive_clipboard_service_test.dart
flutter test test\widgets\account_list_tile_test.dart
flutter test
```

Full Flutter test result:

```text
100 passed, 1 skipped
```

Also checked during implementation:

- ordinary sandbox `flutter test` runs timed out with no output;
- rerunning the same targeted commands with elevated permissions completed normally;
- the timeout is recorded as an environment/tooling issue, not a failed assertion.

## Risk Notes

- Clipboard cleanup is best-effort: it only clears if the clipboard content still equals the copied TOTP code, so it will not erase a later user copy.
- The list disclosure guard recognizes formal `AccountFieldType.totp` fields and likely legacy TOTP/2FA keys; unusual custom field names may still need template type tagging for full protection.
- The account detail page intentionally remains the place where users can reveal the TOTP secret while editing and copy the current generated code.

## Follow-ups

- Consider applying the same sensitive clipboard path to generated passwords and other high-risk copy actions.
- Keep QR scan/import out of the next step unless camera permission and platform-plugin scope are explicitly accepted.
