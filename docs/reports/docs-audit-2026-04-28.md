# SecretRoy Documentation Audit - 2026-04-28

## Scope

Scanned all Markdown documentation under `roy_client/docs`, root project Markdown files, `.claude/memory` notes, and platform README files. The project-wide rescan covered 61 Markdown files after excluding `.git`, build output, Flutter ephemeral folders, and dependency folders.

## Current Canonical References

| Area | Canonical document |
|---|---|
| Documentation index | `docs/README.md` |
| Wiki entry | `docs/wiki/home.md` |
| Key sync and vault linking implementation | `docs/security/key-sync-implementation.md` |
| Local database encryption | `docs/security/local-database-encryption.md` |
| Vault linking design | `docs/sync/vault-linking-design.md` |
| Public API notes | `docs/wiki/api-reference.md` |
| User-facing sync guidance | `docs/wiki/user-manual.md` |

## 2026-04-28 Updates

- Added the current key-sync implementation reference for `sroy-secure-v2:` secure link codes.
- Documented PBKDF2-HMAC-SHA256 master password verification and legacy `master_password_v1` migration.
- Documented AES-GCM-256 secure vault link export/import.
- Updated LAN pairing documentation from numeric-only codes to 8 readable pairing characters.
- Updated wiki API, architecture, testing, troubleshooting, and user manual content to match the current implementation.
- Marked older technical reports and quality convergence documents as historical where they still describe pre-hardening behavior.
- Refreshed root `README.md` and `docs/security/security-features.md` so project entry points match the current secure key-sync implementation.
- Updated last-modified dates on wiki and implementation notes changed during this audit.
- Added the local database encryption reference for the `secret_roy_vault.db.enc`
  AES-GCM-256 file envelope, wrapped random DB data key, runtime working
  database cleanup, and no-compatibility handling of the old intermediate
  plaintext SQLite file.

## Historical Documents

The following documents are intentionally retained as historical snapshots. They now contain top-level current-delta notes when their original content mentions obsolete security or pairing behavior:

- `docs/reports/ai-handover-notes.md`
- `docs/guides/technical-documentation.md`
- `docs/architecture/storage-and-sync-architecture-report.md`
- `docs/reports/quality-convergence/execution-report.md`
- `docs/reports/quality-convergence/convergence-plan.md`

## Known Follow-Up

Local SQLite at-rest encryption is now implemented separately from the key-sync hardening described in `docs/security/key-sync-implementation.md`; see `docs/security/local-database-encryption.md`. Remaining security follow-up covers runtime hardening while the vault is unlocked, production remote authentication/authorization, certificate pinning, and transport hardening.
