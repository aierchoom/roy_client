# SecretRoy

SecretRoy is a Flutter password manager prototype with local SQLite storage,
basic auto-locking, optional biometric unlock, and a lightweight sync server.

## Repository layout

- `lib/`: Flutter application code.
- `sync_server/`: local Node.js sync server used for development.
- `docs/`: project notes and architecture documents.
- `test/`: lightweight regression tests.

## Current state

- Storage and sync are intentionally simplified for development.
- Security hardening and end-to-end encryption are not implemented yet.
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
