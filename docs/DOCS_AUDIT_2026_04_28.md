# SecretRoy Documentation Audit - 2026-04-28

## Scope

Scanned all Markdown documentation under `roy_client/docs`, root project Markdown files, `.claude/memory` notes, and platform README files. The project-wide rescan covered 61 Markdown files after excluding `.git`, build output, Flutter ephemeral folders, and dependency folders.

## Current Canonical References

| Area | Canonical document |
|---|---|
| Documentation index | `docs/README.md` |
| Wiki entry | `docs/wiki/Home.md` |
| Key sync and vault linking implementation | `docs/07_Key_Sync_Implementation.md` |
| Local database encryption | `docs/08_Local_Database_Encryption.md` |
| Vault linking design | `docs/06_Vault_Linking_Design.md` |
| Public API notes | `docs/wiki/API_Reference.md` |
| User-facing sync guidance | `docs/wiki/User_Manual.md` |

## 2026-04-28 Updates

- Added the current key-sync implementation reference for `sroy-secure-v2:` secure link codes.
- Documented PBKDF2-HMAC-SHA256 master password verification and legacy `master_password_v1` migration.
- Documented AES-GCM-256 secure vault link export/import.
- Updated LAN pairing documentation from numeric-only codes to 8 readable pairing characters.
- Updated wiki API, architecture, testing, troubleshooting, and user manual content to match the current implementation.
- Marked older technical reports and quality convergence documents as historical where they still describe pre-hardening behavior.
- Refreshed root `README.md` and `SECURITY_FEATURES.md` so project entry points match the current secure key-sync implementation.
- Updated last-modified dates on wiki and implementation notes changed during this audit.
- Added the local database encryption reference for the `secret_roy_vault.db.enc`
  AES-GCM-256 file envelope, wrapped random DB data key, runtime working
  database cleanup, and no-compatibility handling of the old intermediate
  plaintext SQLite file.

## Historical Documents

The following documents are intentionally retained as historical snapshots. They now contain top-level current-delta notes when their original content mentions obsolete security or pairing behavior:

- `docs/AI_HANDOVER_NOTES.md`
- `docs/TECHNICAL_DOCUMENTATION.md`
- `docs/STORAGE_AND_SYNC_ARCHITECTURE_REPORT.md`
- `docs/quality_convergence/01_Execution_Report.md`
- `docs/quality_convergence/02_Convergence_Plan.md`

## Known Follow-Up

Local SQLite at-rest encryption is now implemented separately from the key-sync hardening described in `docs/07_Key_Sync_Implementation.md`; see `docs/08_Local_Database_Encryption.md`. Remaining security follow-up covers runtime hardening while the vault is unlocked, production remote authentication/authorization, certificate pinning, and transport hardening.
