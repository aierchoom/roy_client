# Code Scan Global Roadmap Refresh

**Status**: Completed
**Date**: 2026-04-30
**Scope**: Code-derived global roadmap refresh across client, sibling sync server, product docs, and security risk register

## Goal

Refresh the global roadmap from the actual code state instead of continuing from older architecture notes. The scan focused on what has already landed, what still creates product/security risk, and which roadmap items should become explicit `T12+` tasks.

## Scan Scope

Client code:

- `lib/services/**`
- `lib/sync/**`
- `lib/system/**`
- `lib/views/**`
- `lib/widgets/**`
- `test/**`

Sibling server code:

- `../roy_server/index.js`
- `../roy_server/system/**`
- `../roy_server/test/index.test.js`
- `../roy_server/README.md`

Docs:

- `docs/todo.md`
- `docs/product/application-characteristics.md`
- `docs/product/iteration-tasks.md`
- `docs/product/ui-quality-convergence-plan.md`
- `docs/security/beta-risk-register.md`

## Findings

- The old global TODO still listed several foundations as future work even though T0-T11 have already delivered identity, vault-scoped sync metadata, AEAD sync payloads, conflict recovery, crash recovery, two-device tests, and TOTP phase 1.
- The next execution work should continue through `T9` sync state cleanup and `T10` server persistence semantics before broad feature expansion.
- New roadmap pressure points came from code, not wishlist text:
  - raw sensitive clipboard paths still exist outside TOTP;
  - vault dump import needs product-level backup/restore/test-restore semantics;
  - biometric/no-password key custody needs a security pass;
  - server auth/transport remains a Beta blocker;
  - several views and services are now large enough to justify planned decomposition;
  - TOTP QR/recovery-code work should wait behind security and restore convergence.

## Changes

- Updated `docs/todo.md` with a 2026-04-30 code-scan section and refreshed P0/P1/P2 priorities.
- Added `T12` through `T18` to `docs/product/iteration-tasks.md`.
- Added a code-scan roadmap table to `docs/product/application-characteristics.md`.
- Linked the global roadmap from `docs/product/README.md`.
- Updated `docs/security/beta-risk-register.md` so sync payload AEAD is no longer listed as unresolved, and moved the external Beta blockers to server auth/transport and key custody.

## Validation

Passed:

```text
Markdown relative links OK (80 files)
git diff --check
```

`git diff --check` only reported the repository's usual CRLF warnings.

No Dart code was changed by this roadmap refresh.

## Follow-ups

- When implementation resumes, start from `T9` or `T10` unless the user explicitly chooses a later `T12+` item.
- If the next task touches `roy_server`, update both server docs and client product docs in the same pass.
