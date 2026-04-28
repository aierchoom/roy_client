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
- The LAN pairing code is not a 6-digit numeric code.
- LAN discovery broadcasts endpoint metadata only; the pairing code is checked
  during the HTTP claim step.
- The LAN transfer bundle exists only while the 8-character code window is open.
- Successful claim, timeout, manual stop, or too many failed code attempts
  destroys the hosted transfer bundle.
- Current clients send a temporary requester public key during LAN claim, so the
  host can return an encrypted `wrapped_transfer_code`.
- The UI warns users to avoid LAN direct pairing on public Wi-Fi.

### Server-Mediated Pairing

- The sync server supports short-lived pairing sessions.
- The joining device submits a temporary X25519 public key when it enters the
  pairing code.
- The trusted device encrypts the vault bundle to that public key and uploads a
  `sroy-pairing-v2:` AES-GCM bundle.
- The server rejects legacy plaintext `sroy-link-v1:` bundles on approval.
- The server stores and relays only the encrypted wrapped vault bundle.
- The trusted device approves the join request before the new device can fetch
  the bundle.

## Not Yet Implemented

- SQLCipher/page-level SQLite encryption; current protection is file-envelope
  encryption around SQLite snapshots.
- Runtime memory hardening against malware active during an unlocked session.
- Production-grade remote authentication and authorization.
- Certificate pinning and production transport hardening.

## Canonical References

- `docs/security/key-sync-implementation.md`
- `docs/security/local-database-encryption.md`
- `docs/sync/vault-linking-design.md`
- `docs/wiki/api-reference.md`
