# SecretRoy Security Features

**Last updated**: 2026-04-28

This file records the security capabilities that are currently implemented in
the client.

## Implemented

### Master Password Verification

- `EnhancedCryptoService` stores `master_password_v2` records using
  PBKDF2-HMAC-SHA256.
- Legacy `master_password_v1` plaintext records are migrated after successful
  verification.
- The service unwraps the random local DB data key after successful unlock and
  exposes master-key session state through `hasMasterKey`.
- `updateMasterPassword(...)` updates the verifier and re-wraps the DB data key
  with a new password-derived wrapping key.

### Local Database At-Rest Encryption

- `SecureStorageService` persists the vault as `secret_roy_vault.db.enc`.
- The encrypted file uses a Dart-managed binary AES-GCM-256 envelope implemented
  by `DatabaseFileCipher`; this avoids SQLCipher platform coupling.
- The database uses a random 32-byte DB data key. That key is stored as
  `database_file_key_envelope_v1` and wrapped with a PBKDF2-HMAC-SHA256 key
  derived from the master password and `database_key_salt_v1`.
- SQLite is opened only after master-password verification succeeds.
- While unlocked, SQLite runs against `secret_roy_vault.runtime.db` in the
  temporary directory. The runtime file and sidecars are removed on lock/close.
- Legacy intermediate plaintext `secret_roy_vault.db` is not imported as a
  valid vault and is cleaned after encrypted initialization.

### Secure Vault Link Codes

- `IdentityService.exportSecureLinkCode(...)` emits `sroy-secure-v2:` codes.
- `sroy-secure-v2:` uses PBKDF2-HMAC-SHA256 with a random salt and AES-GCM-256
  with a random nonce.
- Secure link imports preserve the receiving device's `deviceId` and replace
  only shared vault identity material.
- `sroy-secure-v1:` import remains available for legacy compatibility.

### LAN Pairing

- LAN pairing codes are 8 readable characters.
- Allowed alphabet: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`.
- Ambiguous characters and invalid lengths are rejected during normalization.

### Server-Mediated Pairing

- The sync server supports short-lived pairing sessions.
- The server stores and relays the wrapped vault bundle as opaque data.
- The trusted device approves the join request before the new device can fetch
  the bundle.

## Not Yet Implemented

- SQLCipher/page-level SQLite encryption; current protection is file-envelope
  encryption around SQLite snapshots.
- Runtime memory hardening against malware active during an unlocked session.
- Production-grade remote authentication and authorization.
- Certificate pinning and production transport hardening.

## Canonical References

- `docs/07_Key_Sync_Implementation.md`
- `docs/08_Local_Database_Encryption.md`
- `docs/06_Vault_Linking_Design.md`
- `docs/wiki/API_Reference.md`
- `docs/DOCS_AUDIT_2026_04_28.md`
