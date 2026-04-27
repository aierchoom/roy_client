# SecretRoy

SecretRoy is a Flutter password manager prototype with encrypted local SQLite
storage, basic auto-locking, optional biometric unlock, secure vault onboarding,
and a lightweight sync server.

## Repository layout

- `lib/`: Flutter application code.
- `sync_server/`: local Node.js sync server used for development.
- `docs/`: project notes and architecture documents.
- `test/`: lightweight regression tests.

## Current state

- Storage and sync are still intentionally simplified for development.
- Master password verification is hardened with PBKDF2-HMAC-SHA256 and legacy
  plaintext verifier migration.
- Secure vault link codes use `sroy-secure-v2:` with PBKDF2-HMAC-SHA256 and
  AES-GCM-256; legacy `sroy-secure-v1:` imports remain supported.
- LAN pairing uses 8 readable characters instead of 6 numeric digits.
- Local SQLite is encrypted at rest through a binary AES-GCM-256 envelope
  (`secret_roy_vault.db.enc`); SQLite is decrypted only into a temporary runtime
  working file while the vault is unlocked.
- The sync server stores runtime data locally and should not commit generated
  files such as `node_modules/` or `sync_server/data/`.

## Local development

```bash
flutter pub get
flutter run
```

For the sync server:

```bash
cd sync_server
npm install
node index.js
```
