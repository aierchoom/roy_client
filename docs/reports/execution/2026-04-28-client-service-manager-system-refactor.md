# Client Service Manager System Refactor

## Status

Implemented and verified. Pending commit.

## Goal

Apply the client-side code organization rule:

- keep files close to single responsibility;
- avoid broad service files becoming catch-all modules;
- use `lib/system/` for focused helpers and narrow coordinators.

The first target is `ServiceManager`, because it is a central app facade and had
started to own platform sync URL rules, URL persistence, password tool proxies,
and encrypted vault dump import/export in addition to orchestration.

## Scope

Included:

- Keep the public `ServiceManager` API unchanged.
- Add `lib/system/README.md` for client system module guidance.
- Add `lib/system/service_manager/README.md` for service-manager helper rules.
- Move platform default sync server URL logic to
  `lib/system/service_manager/default_sync_server_url.dart`.
- Move sync server URL persistence, normalization, and resolution to
  `lib/system/service_manager/sync_server_url_store.dart`.
- Move password generation and strength proxy methods to
  `lib/system/service_manager/password_tools.dart`.
- Move encrypted vault dump import/export to
  `lib/system/service_manager/vault_dump_coordinator.dart`.

Out of scope:

- UI view decomposition.
- Large sync service decomposition.
- Behavior changes to unlock, sync, pairing, or password generation.
- Changing provider/view call sites that depend on `ServiceManager`.

## Changes

Code:

- `ServiceManager.defaultSyncServerUrl` now delegates to a focused platform URL
  helper.
- `ServiceManager.getSyncServerUrl`, `setSyncServerUrl`, and pairing URL
  resolution delegate to `SyncServerUrlStore`.
- Static password helper methods delegate to `ServiceManagerPasswordTools`.
- Vault link export/import flows delegate encrypted dump work to
  `VaultDumpCoordinator`.
- `ServiceManager` remains the orchestration facade for lifecycle, lock state,
  sync, pairing, and app reset.

Docs:

- Added `lib/system/README.md`.
- Added `lib/system/service_manager/README.md`.
- Added this execution report.

## Validation

Commands run:

```bash
dart format lib/services/service_manager.dart lib/system/service_manager/*.dart
dart analyze lib/services/service_manager.dart lib/system/service_manager
dart analyze lib test
flutter test --reporter expanded --timeout 20s
```

Results:

- `dart format`: completed successfully.
- `dart analyze`: no issues found.
- `dart analyze lib test`: no issues found.
- `flutter test --reporter expanded --timeout 20s`: all 47 tests passed.

Note: Dart commands need elevated execution in this environment because the CLI
writes analytics files under `C:\Users\choom\AppData\Roaming\.dart-tool`, which
the sandbox cannot create.

## Risk Notes

- Public method names and return types on `ServiceManager` were preserved.
- Sync URL normalization behavior is unchanged: trim, add `http://` if missing,
  and remove one trailing slash.
- Vault dump import/export still uses the same `SyncPayloadCodec`,
  `IdentityService`, and `SecureStorageService` flow.

## Follow-ups

- Continue with `sync_service.dart` or large view files in separate execution
  records.
- Add narrow unit tests for `SyncServerUrlStore.normalize` if URL rules evolve.
- Avoid adding new pure helpers directly into `ServiceManager`.
