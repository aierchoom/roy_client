# T16 Vault-level Authentication

**Status**: Completed  
**Date**: 2026-05-01  
**Scope**: Client + Server; vault API token generation, transmission, and verification  
**Baseline**: `EA` tag on both repos; Stage 2 Step 2

---

## Goal

Add vault-level authentication to sync endpoints so that only devices possessing the vault's pre-shared API token can read from or write to a vault. New vaults generate a token on first server access; the token is returned to the creator and can be passed to paired devices via the existing encrypted pairing bundle.

---

## Scope

- `roy_server/system/vault/auth.js` — new vault access assertion middleware
- `roy_server/system/vault/document.js` — token generation in `createEmptyVault`
- `roy_server/system/ids.js` — SHA256 token hash helper
- `roy_server/system/sync/state_transition.js` — `_meta` preservation through mutations
- `roy_server/system/routes/vault_routes.js` — `X-Vault-Token` header validation and issuance
- `roy_server/test/index.test.js` — integration tests for auth behavior
- `roy_client/lib/services/identity_service.dart` — token storage, import/export via transfer code
- `roy_client/lib/sync/sync_service.dart` — token transmission on pull/push, capture from responses
- `roy_client/test/services/identity_service_test.dart` — token persistence and transfer code round-trip tests

---

## Changes

### Server

#### 1. `system/vault/auth.js` (new)

```javascript
function assertVaultAccess(vault, providedToken)
```

- If `vault._meta.apiTokenHash` is absent → no-op (backward compat for legacy vaults)
- If `vault._meta.apiTokenHash` exists and no token provided → throws `RequestValidationError` with status 401
- If `vault._meta.apiTokenHash` exists and token hash mismatch → throws `RequestValidationError` with status 403

#### 2. `system/vault/document.js`

`createEmptyVault()` now generates a 32-char hex token and stores both:
- `_meta.apiTokenHash` — SHA256 hash, persisted in the vault file
- `_meta._apiToken` — ephemeral raw token, returned once to the first caller, stripped by `normalizeVault()` before persistence

#### 3. `system/routes/vault_routes.js`

Both `GET` and `POST /vaults/:vaultId/sync`:
1. Extract `X-Vault-Token` header
2. Call `assertVaultAccess()` **only if the vault is not new** (i.e., `_meta._apiToken` is absent)
3. If the vault **is** new, skip auth and return the ephemeral token in the `X-Vault-Token` response header, then persist the vault (stripping `_apiToken`)

This means:
- **First access** (vault does not exist on disk): no auth required, token returned
- **Subsequent accesses**: token required

#### 4. `system/sync/state_transition.js`

`buildNextVaultState()` now copies `vault._meta` into `nextVault` so that `apiTokenHash` and idempotency keys survive mutations.

### Client

#### 1. `IdentityService`

New fields:
- `_vaultApiToken` / `vaultApiToken` getter
- `setVaultApiToken(String?)` — persists to secure storage under `vault_api_token` key
- `exportTransferCode()` now includes `vault_api_token` in the payload when set
- `previewTransferCode()` / `_importVaultIdentityPayload()` now parse and return `vaultApiToken`
- `_applyVaultIdentityImport()` saves the token to secure storage
- `initialize()` restores the token from secure storage

#### 2. `SyncService`

- `_fetchRemoteChanges()` sends `X-Vault-Token` header when `identityService.vaultApiToken` is non-null; captures `x-vault-token` from responses and stores it via `identityService.setVaultApiToken()`
- Push phase likewise sends the token and captures new tokens from responses

---

## Validation

### Server

```bash
npm test  # 39 passed
```

New tests added:

| Test | Behavior verified |
|------|-------------------|
| `new vault GET sync returns x-vault-token and does not require auth` | New vault pull issues token without auth |
| `new vault POST sync returns x-vault-token and does not require auth` | New vault push issues token without auth |
| `sync push on existing vault requires x-vault-token` | Subsequent accesses require correct token (401/403/200) |
| `legacy vault without apiTokenHash allows anonymous access` | Old vaults without token hash remain accessible |

Updated existing tests:
- `sync push with idempotency key returns cached result on retry` — now captures and reuses the token from the first response
- `sync push with different idempotency keys advances version normally` — same token handling

### Client

```bash
flutter analyze --no-pub  # 0 issues
flutter test --no-pub       # 123 passed / 1 skipped
```

New tests added:

| Test | Behavior verified |
|------|-------------------|
| `setVaultApiToken persists and initialize restores it` | Token round-trip through secure storage |
| `exportTransferCode includes vaultApiToken when set` | Transfer code carries token |
| `exportTransferCode omits vaultApiToken when unset` | Backward compat for codes without token |

---

## Risk Notes

- **Token loss**: If the creator's first access is a `GET /sync?since=0` and the response is cached or lost, the token could be lost. The current implementation returns the token on both GET and POST for new vaults, so either path works.
- **Legacy vaults**: Vaults created before this change have no `apiTokenHash` and remain open. There is no automatic migration path to add tokens to old vaults — this would require a new endpoint or manual admin action.
- **Pairing bundles**: The token travels inside the existing encrypted `sroy-pairing:` bundle, so it inherits the same X25519+AES-GCM protection as the vault keys.
- **Token rotation**: Not implemented. If a token is compromised, the only remediation currently is server-side manual vault file editing to remove `apiTokenHash`.

---

## Follow-ups

- Consider adding a server endpoint for token rotation (e.g., `POST /vaults/:vaultId/token/rotate`) callable only with the current token
- Consider requiring `X-Vault-Token` on pairing bundle approval so that the host must already possess the token before it can share it
- Document the vault auth contract in `docs/sync/sync-protocol.md`
