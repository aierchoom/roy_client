# SecretRoy

SecretRoy is a Flutter password manager prototype with encrypted local SQLite
storage, basic auto-locking, optional biometric unlock, secure vault onboarding,
and optional sync through the sibling `roy_server` project.

## Repository Layout

- `lib/`: Flutter application code.
- `docs/`: normalized project documentation index and execution records.
- `test/`: lightweight regression tests.
- `../roy_server/`: optional Node.js sync and pairing server used with this
  client during local development.

## Current State

- Storage and sync are still intentionally simplified for development.
- Master password verification uses PBKDF2-HMAC-SHA256 and migrates legacy
  plaintext verifier records after successful verification.
- Secure vault link codes use `sroy-recovery:` with PBKDF2-HMAC-SHA256 and
  AES-GCM-256; legacy recovery protocols are not kept as compatibility entry
  points.
- LAN pairing uses 8 readable characters from
  `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`, not a 6-digit numeric code.
- Local SQLite is encrypted at rest through a binary AES-GCM-256 envelope
  (`secret_roy_vault.db.enc`); SQLite is decrypted only into a temporary runtime
  working file while the vault is unlocked.
- Sync server runtime files belong to `../roy_server/data/` and should not be
  committed.

## Documentation

Start from [docs/README.md](docs/README.md). The documentation set is organized
by area:

- [Architecture](docs/architecture/README.md)
- [Beginner docs](docs/beginner/app_flow.md)
- [Security](docs/security/README.md)
- [Sync](docs/sync/README.md)
- [Guides](docs/guides/README.md)
- [Reports](docs/reports/README.md)

## Local Development

```bash
flutter pub get
flutter run
```

On Windows, prefer the local wrapper when tests touch SQLite or native assets:

```powershell
.\tool\flutter_test.ps1 test\sync
.\tool\flutter_test.ps1 test\services\secure_storage_service_sync_outbox_test.dart
```

The wrapper keeps Flutter/Dart state under `.dart_appdata` and temporarily
points sqlite3 native asset hooks at Windows' built-in `winsqlite3.dll`, so
local test startup does not depend on downloading sqlite3 binaries from GitHub.

For optional sync server development:

```bash
cd ../roy_server
npm install
npm start
```
