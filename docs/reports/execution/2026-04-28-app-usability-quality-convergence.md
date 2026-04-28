# App Usability Quality Convergence Execution Report

| Item | Value |
|---|---|
| Status | Implemented |
| Date | 2026-04-28 |
| Scope | Client model parsing, local storage mapping, home search filters, crash/blocker review |

## Goal

Reduce crash and business-blocking risks in the client so the app is closer to a usable daily-driver baseline after the template and local-first security iterations.

## Crash And Blocker Review

High-impact issues reviewed:

- Stored or synced `syncStatus` values could crash model JSON parsing when the value was out of range or from an older/newer enum shape.
- Custom template rows could be dropped by storage mapping when `sync_status` became invalid.
- Home search template filtering could crash if the selected template id no longer existed after template deletion or template-set changes.
- A stale template filter could make search appear empty even though matching accounts still existed.
- Sync version advancement could be blocked by a corrupted inline comment, causing repeated pull cycles to keep using an old local version.
- Malformed sync server responses could fall through as generic unexpected errors, making the user-facing failure hard to diagnose.
- Account edit time-field taps used a non-null assertion on the field controller.
- Records that reference removed built-in template ids now surface as missing-template records. This is intentional after built-in template simplification; the UI already exposes the missing-template state and lets the user retarget the record to an available template before saving.

## Scope

Included:

- Harden account and template sync-status parsing.
- Reuse the same sync-status parser in SQLite row mapping.
- Make home search tolerate stale template filter ids.
- Restore explicit sync local-version advancement after empty and non-empty pull phases.
- Validate sync pull/push response shapes before mutating local clean state.
- Guard account-edit time-field taps against missing controllers.
- Add regression tests for corrupted or alternate sync-status values.
- Document the current app-level crash and blocker review.

Out of scope:

- Legacy template compatibility wrappers.
- Full UI redesign of missing-template recovery.
- Cluster or high-availability server work.

## Changes

- Added `syncStatusFromJson` as the shared parser for `SyncStatus`.
- Updated `AccountItem.fromJson` to fall back instead of throwing on invalid `syncStatus`.
- Updated `AccountTemplate.fromJson` to use a synchronized fallback for unreadable template status values.
- Updated `SecureStorageService` account/template row mapping to avoid enum index crashes and hardcoded enum bounds.
- Updated home search to prune unavailable template filters and use only active template ids for labels and matching.
- Added typed sync protocol response validation for pull payloads, remote records, encrypted payload presence, and push `accepted_versions`.
- Ensured pull phases advance `_localVersion` only after the relevant remote batch is safely handled.
- Removed a nullable-controller crash path from account edit time-field tapping.
- Added model tests for safe sync-status parsing.
- Added sync state-machine tests for malformed pull responses and malformed push acknowledgements.

## Validation

- `dart format lib/models/account_item.dart lib/models/account_template.dart lib/services/secure_storage_service.dart lib/views/home/home_search_view.dart test/models/account_item_test.dart test/models/account_template_test.dart`
- `dart format lib/sync/sync_service.dart test/sync/sync_state_machine_test.dart`
- `dart format lib/views/accounts/account_edit_view.dart`
- `dart analyze lib/sync/sync_service.dart test/sync/sync_state_machine_test.dart`: no issues
- `flutter test test/sync/sync_state_machine_test.dart --reporter expanded --timeout 20s`: 9 passed
- `dart analyze lib test`: no issues
- `flutter test --reporter expanded --timeout 20s`: 54 passed
- `git diff --check`: no whitespace errors; CRLF conversion warnings only

## Risk Notes

- HLC parsing and malformed field payloads still cause individual unreadable SQLite rows to be skipped by storage mapping instead of crashing the app. That is acceptable for this iteration, but a future recovery screen could make skipped rows visible to the user.
- Missing-template records remain a deliberate non-compatibility behavior for removed built-ins. The current recovery path is to choose an available template, typically the generic information template, and save.
- Flutter tool commands may still hang or fail when the SDK writes to user-level Dart tool caches outside the workspace; this is tooling/environment risk rather than runtime app behavior.

## Follow-Ups

- Add a compact diagnostics view for unreadable local rows and sync recovery markers.
- Add a manual "retarget missing template" action if missing-template recovery becomes common in real use.
- Add small integration coverage for home-search filtering after template deletion.
