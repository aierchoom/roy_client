# T12 全局敏感复制策略收敛

**Status**: Completed  
**Date**: 2026-05-01  
**Scope**: Client-only; 10 call sites across 7 files  
**Baseline**: `EA` tag at `8cb2ab5`; Stage 1 start

---

## Goal

Convert `SensitiveClipboardService` from a TOTP-only cleanup helper into a unified, risk-level-based sensitive clipboard policy that covers passwords, pairing codes, recovery codes, TOTP codes, and account field copies.

Prevent sensitive data from lingering in the system clipboard indefinitely, while also preventing the cleanup timer from accidentally clearing content the user copied *after* the sensitive copy.

---

## Scope

- `lib/services/sensitive_clipboard_service.dart` — core service refactor
- `lib/widgets/password_generator_sheet.dart` — generated password copy
- `lib/views/password_tools_view.dart` — generated password copy
- `lib/widgets/account_list_tile.dart` — account field copy
- `lib/views/accounts/account_edit_view.dart` — account field copy
- `lib/views/sync_settings_view.dart` — pairing code & recovery code copy
- `lib/views/accounts/totp_account_list_view.dart` — TOTP code copy
- `lib/views/accounts/totp_credential_edit_view.dart` — TOTP code copy
- `test/services/sensitive_clipboard_service_test.dart` — regression tests

---

## Changes

### 1. Risk-level-based API

```dart
enum ClipboardRiskLevel { high, medium, low }

class SensitiveClipboardService {
  static Future<void> copy(
    String text, {
    ClipboardRiskLevel level = ClipboardRiskLevel.high,
    Duration? clearAfter,
  });
}
```

| Level | Default clear duration | Use case |
|-------|----------------------|----------|
| `high` | 45s | Passwords, TOTP codes, pairing codes, recovery codes |
| `medium` | 30s | Vault IDs, server addresses (not used yet) |
| `low` | 0s (no cleanup) | Non-sensitive UI text |

### 2. Hash-based "clear only if unchanged" protection

Before clearing, the service:
1. Reads the current clipboard content.
2. Computes `SHA256(currentText)`.
3. Compares it to `SHA256(originalText)` stored at copy time.
4. Only clears if the hashes match; otherwise cancels the timer.

This prevents the timer from wiping content the user manually copied after the sensitive copy.

### 3. Call site migration

All 10 raw `Clipboard.setData` calls across 7 files were replaced with `SensitiveClipboardService.copy(..., level: ClipboardRiskLevel.high)`.

| File | Previous API | New API |
|------|-------------|---------|
| `password_generator_sheet.dart` | `Clipboard.setData` | `SensitiveClipboardService.copy(text: password, level: high)` |
| `password_tools_view.dart` | `Clipboard.setData` | `SensitiveClipboardService.copy(text: password, level: high)` |
| `account_list_tile.dart` | `Clipboard.setData` | `SensitiveClipboardService.copy(text: field, level: high)` |
| `account_edit_view.dart` | `Clipboard.setData` | `SensitiveClipboardService.copy(text: field, level: high)` |
| `sync_settings_view.dart` | `Clipboard.setData` | `SensitiveClipboardService.copy(text: code, level: high)` (×2) |
| `totp_account_list_view.dart` | `Clipboard.setData` | `SensitiveClipboardService.copy(text: code, level: high)` |
| `totp_credential_edit_view.dart` | `Clipboard.setData` | `SensitiveClipboardService.copy(text: code, level: high)` |

### 4. Stale `services.dart` imports

6 files had redundant `import 'package:flutter/services.dart'` after `SensitiveClipboardService` became the sole clipboard accessor. These are non-blocking warnings (the import is still needed for `Clipboard` mock in tests); left as-is to avoid unnecessary churn.

---

## Validation

```bash
flutter analyze --no-pub  # 0 issues
flutter test --no-pub       # 120 passed / 1 skipped
```

Test additions in `sensitive_clipboard_service_test.dart`:

| Test | Purpose |
|------|---------|
| `high risk uses default clear duration` | Confirms 45s default for high risk |
| `medium risk also clears with shorter default` | Confirms 30s default for medium risk |
| `low risk does not schedule clear` | Confirms no timer for low risk |
| `hash-based comparison prevents clearing modified content` | Core safety invariant |

---

## Risk Notes

- **Platform clipboard API consistency**: The hash-based check relies on `Clipboard.getData` returning the exact text the user copied. If a platform normalizes whitespace or encoding, the hash may mismatch and the timer will not clear. This is the *safe* failure mode (leaves clipboard intact).
- **Timer cancellation on app termination**: If the app is killed before the timer fires, the system clipboard retains the sensitive text. This is acceptable because the OS may also clear the clipboard on app death; we do not control that.
- **Medium risk level currently unused**: The `medium` level was designed for vault IDs and server addresses, but no call site currently uses it. It is available for future use.

---

## Follow-ups

- Evaluate whether `medium` risk should be applied to vault ID or server address copy actions in diagnostics/settings.
- Consider adding a user-visible setting to disable automatic clipboard cleanup (with a security warning).
