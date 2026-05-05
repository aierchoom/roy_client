# T9 同步状态机清理

**Status**: Completed  
**Date**: 2026-05-01  
**Scope**: Client-only; `SyncState` enum expansion + UI consumption refactor  
**Baseline**: `EA` tag at `8cb2ab5`; Stage 1 start

---

## Goal

Eliminate the ambiguous 5-state `SyncState` enum (`offline`, `syncing`, `synced`, `error`, `conflictRecovery`) where `error` mixed network timeout, protocol parse failure, payload corruption, server 503, and auth failure into a single opaque bucket. The UI was forced to parse `syncErrorMessage` strings to guess internal failure reasons.

Replace with a typed, exhaustive state model where the UI consumes stable states directly without string inference.

---

## Scope

- `lib/sync/sync_service.dart` — state machine core
- `lib/views/sync_settings_view.dart` — UI consumption refactor
- `test/sync/sync_state_machine_test.dart` — test assertions update

---

## Changes

### 1. New `SyncState` enum (10 states)

```dart
enum SyncState {
  offline,            // Never connected or explicitly disconnected
  connecting,         // Handshaking / starting sync cycle
  pulling,            // Running pull phase
  pushing,            // Running push phase
  idle,               // Sync healthy, nothing in flight (was `synced`)
  conflictRecovery,   // Automatic conflict recovery in progress
  networkUnreachable, // Cannot reach server (SocketException, timeout, bad URL)
  serverError,        // Server 5xx or persistence failure
  protocolError,      // Malformed response, invalid payload, parse failure
  authError,          // Identity missing or auth rejected
}
```

### 2. State transition mapping

| Old transition | New state | Trigger |
|----------------|-----------|---------|
| `_updateState(syncing)` on sync start | `connecting` | `syncNow()` entry |
| `_updateState(syncing)` during pull | `pulling` | After recovery marker write for pull |
| `_updateState(syncing)` during push | `pushing` | After recovery marker write for push |
| `_updateState(synced)` on success | `idle` | Sync loop completion |
| `_setError(...)` on missing URL | `networkUnreachable` | `syncNow()` preflight check |
| `_setError(...)` on identity missing | `authError` | `syncNow()` preflight check |
| `_setError(...)` on mobile loopback | `networkUnreachable` | `syncNow()` preflight check |
| `_setError(...)` on SocketException | `networkUnreachable` | `_handleGlobalSyncError` |
| `_setError(...)` on ClientException | `networkUnreachable` | `_handleGlobalSyncError` (network-related) |
| `_setError(...)` on cleartext block | `protocolError` | `_handleGlobalSyncError` |
| `_setError(...)` on 5xx HTTP | `serverError` | `_handleGlobalSyncError` |
| `_setError(...)` on invalid payload | `protocolError` | `_handleGlobalSyncError` |
| `_setError(...)` on malformed response | `protocolError` | `_handleGlobalSyncError` |
| `_setError(...)` on protocol exception | `protocolError` | `_handleGlobalSyncError` |
| `_setError(...)` on payload verify fail | `protocolError` | `_handleGlobalSyncError` |
| `_setError(...)` on max retries | `protocolError` | Conflict recovery exhaustion |
| `_updateState(offline)` on transport failure | `networkUnreachable` | `_handleGlobalSyncError` |

### 3. `_setError` signature change

```dart
// Before
void _setError(String message, {String? statusNote})

// After
void _setError(SyncState errorState, String message, {String? statusNote})
```

`errorState` is asserted to be one of the four error states via `_SyncStateExt.isError`.

### 4. `isConnected` / `isSyncing` getter updates

```dart
bool get isConnected =>
    state == idle ||
    state == connecting ||
    state == pulling ||
    state == pushing ||
    state == conflictRecovery;

bool get isSyncing =>
    state == connecting ||
    state == pulling ||
    state == pushing ||
    state == conflictRecovery;
```

### 5. UI elimination of string parsing

**Deleted from `sync_settings_view.dart`:**
- `_isServerPersistenceIssue(String? message)` — entire method removed
- All `message.contains('server address')`, `message.contains('LAN IP')`, `message.contains('loopback')` branches
- All `message.contains('vault file is unreadable')` branches

**Replaced with:**
- `_syncStatusTone(BuildContext, SyncState)` — exhaustive switch, no `message` parameter
- `_syncStatusDescription(SyncState, {hasDirtyData, statusNote})` — typed routing
- `_syncActionTitle(SyncState, {hasDirtyData})` — typed routing
- `_syncActionDetail(SyncState, {hasDirtyData})` — typed routing
- `_showsInlineServerEditAction(SyncState)` — `== networkUnreachable` only
- `_syncStateLabel(SyncState)` — covers all 10 states

---

## Validation

```bash
flutter analyze --no-pub  # 0 issues
flutter test --no-pub       # 120 passed / 1 skipped
```

Test updates in `sync_state_machine_test.dart`:

| Test | Old assertion | New assertion |
|------|--------------|---------------|
| `syncNow sets error state when sync server URL is missing` | `SyncState.error` | `SyncState.networkUnreachable` |
| `connect reuses setup guidance when sync server URL is missing` | `SyncState.error` | `SyncState.networkUnreachable` |
| `connect stays in syncing until the first sync finishes` | `SyncState.syncing` | `isSyncing == true` (allows connecting→pulling progression) |
| `connect returns false and leaves the service offline on transport failure` | `SyncState.offline` | `SyncState.networkUnreachable` |
| `syncNow surfaces server persistence errors from pull responses` | `SyncState.error` | `SyncState.serverError` |
| `syncNow surfaces server persistence errors from push responses` | `SyncState.error` | `SyncState.serverError` |
| `syncNow surfaces invalid payload conflict types from push responses` | `SyncState.error` | `SyncState.protocolError` |
| `syncNow rejects malformed pull responses before pushing` | `SyncState.error` | `SyncState.protocolError` |
| `successful push leaves a stable success note for the UI` | `SyncState.synced` | `SyncState.idle` |
| `accepted push preserves local edits made while pushing` | `SyncState.synced` | `SyncState.idle` |
| `approved 2FA credential push only sends encrypted payload` | `SyncState.synced` | `SyncState.idle` |

---

## Risk Notes

- **Breaking UI contract**: Any external code relying on `SyncState.error` or `SyncState.synced` will fail at compile time. The only consumer in-tree was `sync_settings_view.dart`, which was updated.
- **State exhaustion**: The UI uses exhaustive `switch` on `SyncState`. Adding a new state in the future will produce a compile-time error until the UI is updated — this is intentional.
- **Diagnostic detail loss**: `syncErrorMessage` is still exposed via `ServiceManager` for logging, but the UI no longer routes by it. This means new error types not yet mapped to a typed state will fall through to a generic error description. Future error kinds should add new `SyncState` values rather than new message strings.

---

## Follow-ups

- Consider adding `SyncState.setupRequired` for "sync server URL not configured" to distinguish it from "configured but unreachable". Currently both map to `networkUnreachable`.
- Consider adding `SyncState.rateLimited` if the server ever returns 429 with structured retry-after info.
- Add a small architecture note to `docs/sync/sync-protocol.md` documenting the state machine contract.
