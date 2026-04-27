# SecretRoy Security Features

**Last updated**: 2026-04-28

This file records the security capabilities that are currently implemented in
the client. Broader storage-at-rest encryption remains a follow-up hardening
track.

## Implemented

### Master Password Verification

- `EnhancedCryptoService` stores `master_password_v2` records using
  PBKDF2-HMAC-SHA256.
- Legacy `master_password_v1` plaintext records are migrated after successful
  verification.
- The service exposes master-key session state through `hasMasterKey` and can
  update the verifier through `updateMasterPassword(...)`.

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

- SQLCipher or equivalent local SQLite at-rest encryption.
- Full account-field encryption at rest.
- Production-grade remote authentication and authorization.
- Certificate pinning and production transport hardening.

## Canonical References

- `docs/07_Key_Sync_Implementation.md`
- `docs/06_Vault_Linking_Design.md`
- `docs/wiki/API_Reference.md`
- `docs/DOCS_AUDIT_2026_04_28.md`
