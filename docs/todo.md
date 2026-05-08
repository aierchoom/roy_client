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
| Last Updated | 2026-05-07 |

## Source Conclusion

This TODO is derived from the architecture conclusion:

- SecretRoy is a valuable architecture prototype worth continued investment.
- SecretRoy is not yet a directly product-ready security system.

The work below should therefore prioritize correctness, security, recovery, architecture clarity, and testability before broad feature expansion.

## 2026-04-30 Code Scan Update

This roadmap was refreshed after scanning the current client code, the sibling
sync server layout, the active product docs, the security risk register, and the
test inventory.

Current implemented baseline:

- Sync payloads use `sroy-sync:` AES-256-GCM + HKDF envelopes through
  `SyncPayloadCodec`.
- Vault/device identity, vault-scoped sync metadata, explicit conflict types,
  conflict recovery, CRDT regression coverage, crash recovery, and minimal
  two-device sync tests have landed.
- The first TOTP authenticator phase has landed: algorithm service,
  independent TOTP credentials, template-level 2FA link fields, account UI,
  outbox/sync/conflict regression, list non-disclosure, and sensitive clipboard
  cleanup for TOTP codes.
- The sync server has been split into `system/` modules with atomic JSON vault
  writes, request limits, body validation, rate limits, security headers,
  request IDs, and pairing lifecycle tests.

Current code-derived pressure points:

- `SecuritySettingsView`, `BiometricAuthService`, and no-password mode still
  need a stronger key-custody design before external security claims.
- `VaultDumpCoordinator` validates encrypted dumps, but restore confidence,
  test-restore UX, and import sync/outbox semantics need a product-level route.
- Large feature files such as `account_edit_view.dart`, `sync_settings_view.dart`,
  `secure_storage_service.dart`, and `sync_service.dart` remain active
  architecture debt.

Execution queue alignment:

- Near-term execution follows stage-based steps in `docs/product/iteration-tasks.md`.
- Stage 1: T9 sync status cleanup + T12 sensitive clipboard policy.
- Stage 2: T15 key custody ✅ + T16 server auth ✅ + T10 server persistence.
- Stage 3: T14 backup/restore consistency + T13 Vault Health.
- Stage 4: T17 UI architecture（token-based design system、SyncService 拆分已提前落地）+ EA 后模板系统增强（preset groups、字段级 CRDT merge ✅、内置模板入库 ✅）+ T18 2FA next phase.
- New global roadmap items should be tracked as stage steps in
  `docs/product/iteration-tasks.md` rather than scattered in feature notes.

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

- Keep the completed local encrypted TOTP authenticator as the first phase.
- Preserve the current rule: TOTP secrets live in encrypted account data and use
  existing outbox review, AEAD sync payloads, CRDT merge, and conflict inbox.
- TOTP QR import has landed for mobile camera scan, active QR image paste, and
  clipboard text fallback. Next TOTP work should focus on recovery-code
  templates, QR export decisions, device time drift hints, and broader
  sensitive clipboard policy after the security and restore roadmap is clear.

## P0 - Security And Correctness (Stage 2)

- ~~Replace biometric/no-password plaintext master-password storage with a
  stronger key-custody strategy.~~ ✅ Completed 2026-05-01: biometric storage now
  uses AES-256-GCM encrypted envelope; no-password mode auto-disables biometric.
- ~~Add server authentication and authorization for sync routes.~~ ✅ Completed
  2026-05-01: vault-level API token (`X-Vault-Token`) now required for
  pull/push on existing vaults; legacy vaults remain compatible.
- Define transport hardening expectations: HTTPS/TLS setup, local-network
  warnings, and client diagnostics for insecure or unreachable endpoints.
- Keep improving local database encryption around unlock order, runtime
  plaintext lifetime, corruption checks, backup, and recovery.
- Preserve local-only operation while refactoring security, sync, and service
  boundaries.
- Keep AEAD payload, vault identity, conflict recovery, and two-device baselines
  under regression so these completed foundations do not drift.

## P1 - Runtime Robustness (Stage 1, Stage 3)

### Stage 1 ✅ 已完成
- Clean up sync status semantics so UI consumes stable states instead of
  inferring internal failures.
- Extend sensitive clipboard cleanup beyond TOTP codes to generated passwords,
  account detail copy, pairing codes, and recovery codes where appropriate.
- 结果：`flutter test` 120 passed / 1 skipped；`dart analyze` 0 issues。

### Stage 3
- Add structured diagnostics for unlock, encryption, sync, conflict recovery,
  server health, and import/export flows.
- Build a visible vault health surface for encryption state, backup age,
  restore-test status, weak/reused/stale credentials, incomplete records, TOTP
  coverage, and unsynced changes.
- Add encrypted export/import, restore preview, and test-restore flows as
  visible product capabilities.
- Rebuild import/outbox semantics so vault dump restore does not silently mark
  unsafe local state as synchronized when the source state should remain
  reviewable.
- Strengthen server persistence semantics for validation, atomic writes,
  duplicate requests, idempotency, and error classification.
- Add sync server setup guidance in the client: URL validation, health result, data safety notes, and first-sync confirmation.
- Add server-side diagnostics that are safe to display or copy without leaking vault secrets.
- Keep reducing oversized service and view files into focused modules where
  responsibility boundaries are clear.
- Add architecture README files for new subsystem folders when they become canonical extension points.

## P2 - Product And Feature Evolution (Stage 4)

- Add TOTP QR export decisions, recovery-code templates, and device time drift
  hints after the completed manual and QR-import TOTP paths remain stable.
- Add local import strategy for browser CSV, generic CSV, and common password
  manager exports without weakening local encryption.
- Converge localization so newly touched screens stop mixing `_text(...)`,
  direct Chinese strings, and generated localization resources.
- Continue UI quality convergence around flatter account, template, settings,
  sync, and search surfaces.
- Build data repair tooling for damaged sync metadata, conflict logs, tombstones, and version drift.
- Introduce property-based or model-based tests for sync state transitions and
  merge invariants once the state model is cleaner.
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
