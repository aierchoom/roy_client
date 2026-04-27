# Security Documentation

**Last updated**: 2026-04-28

| Document | Purpose |
|---|---|
| [security-features.md](security-features.md) | Implemented client security capabilities |
| [local-database-encryption.md](local-database-encryption.md) | Local SQLite binary envelope encryption and wrapped DB data key |
| [key-sync-implementation.md](key-sync-implementation.md) | Secure vault link codes, LAN pairing, and key sync hardening |
| [beta-risk-register.md](beta-risk-register.md) | Beta security risk register and remaining blockers |

Current local database model:

- Long-term file: `secret_roy_vault.db.enc`
- File envelope: Dart AES-GCM-256 binary envelope
- DB data key: random 32-byte key
- Password role: derives the wrapping key that protects the DB data key envelope
