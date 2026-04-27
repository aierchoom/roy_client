# SecretRoy TODO

Navigation:
[Docs Home](README.md) |
[Executive Summary](architecture/00-executive-summary.md#decision-summary) |
[Architecture Backlog](architecture/06-distributed-system-implementation-backlog.md)

| Item | Value |
|---|---|
| Document Type | Project TODO |
| Scope | Architecture, security, sync, server hardening, testing, documentation, and candidate features |
| Source Conclusion | [Architecture decision summary](architecture/00-executive-summary.md#decision-summary) |
| Last Updated | 2026-04-28 |

## Source Conclusion

This TODO is derived from the architecture conclusion:

- SecretRoy is a valuable architecture prototype worth continued investment.
- SecretRoy is not yet a directly product-ready security system.

The work below should therefore prioritize correctness, security, recovery, architecture clarity, and testability before broad feature expansion.

## Current Product Decision

SecretRoy's current roadmap should converge on a trusted local-first sensitive
information manager.

This means:

- Local-only operation is a core product strength, not a fallback mode.
- Sync is optional convenience between user-owned devices.
- The server should remain weak, opaque, easy to run, easy to inspect, easy to
  back up, and easy to replace.
- Product work should prioritize local vault confidence, backup/restore,
  diagnostics, import/export, vault health, and self-hosted sync usability.
- Long-term surfaces such as enterprise governance, managed sync, browser
  extensions, mobile autofill, CLI, and team sharing stay out of the current
  roadmap.

## Strategic Directions

### SD-01. Local-First Personal Security Hub

Position SecretRoy first as a trustworthy local-first personal vault rather than an enterprise suite. The near-term product should help an individual safely store, find, back up, restore, and sync sensitive data across their own devices.

Primary outcomes:

- Fast unlock, search, copy, edit, backup, and restore.
- Clear safety status for local encryption, sync, backup, and device linkage.
- Low-friction migration from existing password storage.
- Local-only remains a first-class mode, not a degraded offline fallback.
- The user can understand and operate the vault even when every network feature is disabled.

### SD-02. Privacy-Preserving Multi-Device Vault

Build the sync story around user-owned devices and a weak/self-hosted server. The business value is not "cloud owns your vault"; it is "your devices stay consistent without trusting the server with plaintext."

Primary outcomes:

- Device linking that normal users can understand.
- Explicit recovery path when one device or server copy is lost.
- Sync diagnostics that explain what happened without exposing secrets.
- Sync server setup is simple enough for a weak personal machine, NAS, or small VPS.
- Client setup should guide users through server URL, health check, pairing, and first successful sync.

### SD-03. Credential Operations, Not Just Password Storage

Move beyond a flat password list into daily credential operations: health checks, rotation workflows, ownership, notes, recovery codes, API keys, license keys, and account lifecycle.

Primary outcomes:

- Users know which credentials are weak, reused, stale, incomplete, or missing recovery data.
- Templates become real workflow assets, not only custom fields.
- Sensitive notes and non-password secrets fit the same encrypted model.

### SD-04. Trust And Recoverability As Product Features

For a security tool, "I can recover safely" is as important as "I can encrypt." Make backup, restore, diagnostics, and emergency access visible product surfaces.

Primary outcomes:

- Backup status is a first-class state.
- Restore can be tested before disaster.
- Local corruption or sync drift has guided repair paths.

## Development Lanes

### Architecture Iteration

- Keep splitting oversized files by single responsibility, especially services, providers, sync orchestration, and feature views.
- Continue moving low-level reusable logic into `lib/system/` modules instead of growing UI or service facade files.
- Preserve `ServiceManager` as a facade while moving concrete responsibilities into focused collaborators.
- Separate domain models, persistence mapping, runtime orchestration, feature services, and presentation state.
- Turn implicit architecture rules into small README files near the code they govern.

### Security Foundation

- Finish the real vault/device identity lifecycle.
- Strengthen master-password, database-key, and vault-key derivation boundaries.
- Keep local encrypted database behavior binary-level and platform-independent.
- Minimize runtime plaintext database lifetime and document its remaining limits.
- Add corruption detection, encrypted backup, restore, and recovery diagnostics.

### Local Advantage Expansion

- Make local-only mode explicit in product copy, settings, diagnostics, and onboarding.
- Keep core flows fully usable without network: unlock, search, copy, edit, template management, backup, restore, and vault health.
- Add local vault status cards for encryption state, backup age, restore-test status, unsynced changes, and device identity.
- Improve local import/export as a safe migration and recovery path before adding broader online convenience.
- Add local diagnostics that can explain storage, encryption, sync metadata, and backup state without sending data anywhere.
- Keep local performance visible: fast startup, fast search, predictable lock/unlock, and no server dependency for ordinary work.

### Sync And Distributed Behavior

- Move sync payload protection toward standard AEAD/E2EE.
- Namespace all sync metadata by vault.
- Formalize conflict types, recovery branches, and conflict inbox semantics.
- Define sync invariants for `serverVersion`, HLC, dirty flags, tombstones, and merge results.
- Build a two-device integration baseline before expanding sync features.

### Sync Server Usability

- Treat the sync server as a small personal appliance: easy to start, inspect, back up, and replace.
- Provide a clear first-run path: choose data directory, print LAN URL, run health check, connect client, confirm first sync.
- Add actionable server diagnostics for data directory, writability, vault count, file limits, request limits, and recent errors.
- Make client connection testing explicit: validate URL, show server version/health, explain failed DNS/TLS/CORS/timeout cases.
- Document weak-server operations: backup `DATA_DIR`, move server to another machine, rotate pairing sessions, and recover after interrupted writes.
- Prefer simple scripts, `.env` examples, and copyable config over complex infrastructure.

### Server Runtime

- Keep the server lightweight, but make it robust under weak-server conditions.
- Improve validation, persistence semantics, error classification, and recovery after interrupted writes.
- Keep route, storage, pairing, sync, and HTTP helpers split into focused system modules.
- Add enough observability to diagnose client/server/sync/storage failures without a heavy platform stack.

### Testing And Verification

- Add invariant tests for crypto envelopes, merge behavior, sync state transitions, and vault identity.
- Add crash-recovery tests for interrupted pull, push, DB replacement, encrypted DB rewrite, and import/export.
- Keep command-level validation documented in each execution report.
- Prefer small focused regression tests over broad slow suites unless the touched behavior crosses module boundaries.

### Product And UX Quality

- Keep UI text aligned with the real security state of the product.
- Improve empty, loading, error, sync failure, and conflict states with clear next actions.
- Avoid enterprise-facing claims in the current roadmap.
- Make user-facing security decisions explicit instead of hiding them behind convenience defaults.

### Business And Product Optimization

- Define the first target segment as privacy-conscious individual users and self-hosting users.
- Build an onboarding path around import, first vault creation, first backup, first device link, and first successful restore check.
- Add a "Vault Health" surface for weak passwords, reused secrets, stale records, missing URLs, missing recovery codes, and unsynced local changes.
- Make backup/restore confidence a product feature with scheduled reminders, encrypted export packages, and test-restore guidance.
- Treat template packs as product value: website login, bank card, API key, server credential, license key, identity document, secure note, recovery code, and TOTP token.
- Plan an import strategy for browser CSV, generic CSV, and common password manager exports without weakening local encryption.
- Consider privacy-preserving diagnostics: local-only health metrics by default, explicit opt-in for shareable support bundles with secrets redacted.
- Keep the product mode clear: local-first vault with optional self-hosted sync.
- Optimize the product promise around "works locally first, syncs when you want it" rather than "requires an account or server."

### Authenticator Feature

- Start with a local encrypted TOTP authenticator MVP.
- Implement TOTP/HOTP core and `otpauth://` parsing before UI.
- Store TOTP secrets only inside the encrypted local database.
- Delay TOTP secret sync until sync payload AEAD/E2EE, identity, and recovery baselines are stronger.

## P0 - Security And Correctness

- Replace transitional identity keys with a real vault/device key lifecycle.
- Move sync payload protection from the current custom envelope toward a standard AEAD/E2EE design.
- Keep improving local database encryption around unlock order, runtime plaintext lifetime, corruption checks, backup, and recovery.
- Continue the architecture split: keep extracting focused `system/` helpers from oversized services without changing public APIs unnecessarily.
- Preserve local-only operation while refactoring security, sync, and service boundaries.
- Namespace all sync metadata by vault and remove cross-vault state leakage risks.
- Formalize sync conflict types instead of treating most protocol conflicts as a generic `409`.
- Expand conflict recovery so remote-missing, stale-base, concurrent-edit, and concurrent-delete paths are explicit.
- Add invariant tests for CRDT merge behavior and sync state transitions.
- Establish a minimal two-device sync integration baseline.
- Add server URL health-check UX before any sync write path.

## P1 - Runtime Robustness

- Strengthen server persistence semantics for validation, atomic writes, duplicate requests, and error classification.
- Add structured diagnostics for unlock, encryption, sync, conflict recovery, and import/export flows.
- Build crash-recovery tests for interrupted pull, push, database replacement, and encrypted DB rewrite.
- Clean up sync status semantics so UI consumes stable states instead of inferring internal failures.
- Keep reducing oversized service and view files into focused modules where responsibility boundaries are clear.
- Add architecture README files for new subsystem folders when they become canonical extension points.
- Add vault health checks for weak, reused, stale, incomplete, and unsynced records.
- Add encrypted export/import and test-restore flows as visible product capabilities.
- Add sync server setup guidance in the client: URL validation, health result, data safety notes, and first-sync confirmation.
- Add server-side diagnostics that are safe to display or copy without leaking vault secrets.

## P2 - Product And Feature Evolution

- Design an internal TOTP authenticator feature with encrypted secret storage, QR/manual import, countdown, copy, search, and encrypted backup/export.
- Build data repair tooling for damaged sync metadata, conflict logs, tombstones, and version drift.
- Consider a stronger server storage abstraction only after protocol, recovery, and test baselines are stable.
- Consider optional server packaging only after the one-command/manual setup path is already clear.

## Documentation Follow-Up

- Keep this TODO linked from architecture and docs indexes.
- When a TODO item becomes active work, create a dedicated execution report under `docs/reports/execution/`.
- When implementation changes architecture assumptions, update the source architecture document in the same change.

---

Navigation:
[Docs Home](README.md) |
[Executive Summary](architecture/00-executive-summary.md#decision-summary) |
[Architecture Backlog](architecture/06-distributed-system-implementation-backlog.md)
