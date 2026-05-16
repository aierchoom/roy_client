# Execution Reports

This directory stores one Markdown execution report per client feature,
hardening task, or architecture refactor.

Use this naming pattern:

```text
YYYY-MM-DD-feature-slug.md
```

Each report should include:

- `Status`
- `Goal`
- `Scope`
- `Changes`
- `Validation`
- `Risk Notes`
- `Follow-ups`

## Active Reports

High-value reports containing **architecture decisions, security protocols, or design contracts** that cannot be directly derived from code.

| Date | Report | Scope |
|---|---|---|
| 2026-05-06 | [2026-05-06-smoke-automation-full-run.md](2026-05-06-smoke-automation-full-run.md) | Windows desktop smoke execution and coverage gap review |
| 2026-05-06 | [2026-05-06-vault-health.md](2026-05-06-vault-health.md) | Vault Health panel: 13 metrics, scoring algorithm, risk grading |
| 2026-05-01 | [2026-05-01-sync-state-machine-cleanup.md](2026-05-01-sync-state-machine-cleanup.md) | Sync state machine: 5→10 typed states with full transition map |
| 2026-05-01 | [2026-05-01-vault-level-authentication.md](2026-05-01-vault-level-authentication.md) | Vault-level token auth protocol (`X-Vault-Token`) |
| 2026-05-01 | [2026-05-01-stage-1-implementation-plan.md](2026-05-01-stage-1-implementation-plan.md) | Stage 1 design contract: state machine + clipboard + UI |
| 2026-05-01 | [2026-05-01-sensitive-clipboard-policy-convergence.md](2026-05-01-sensitive-clipboard-policy-convergence.md) | Sensitive clipboard policy with risk levels |
| 2026-05-01 | [2026-05-01-biometric-encryption-no-password-convergence.md](2026-05-01-biometric-encryption-no-password-convergence.md) | Biometric and passwordless master key escrow |
| 2026-04-30 | [2026-04-30-vault-device-identity.md](2026-04-30-vault-device-identity.md) | Vault/device identity lifecycle hardening |
| 2026-04-30 | [2026-04-30-sync-payload-aead.md](2026-04-30-sync-payload-aead.md) | Sync payload AEAD/E2EE boundary (`sroy-sync:` envelope) |
| 2026-04-30 | [2026-04-30-sync-metadata-vault-scope.md](2026-04-30-sync-metadata-vault-scope.md) | Sync metadata vault scoping isolation |
| 2026-04-30 | [2026-04-30-sync-conflict-types.md](2026-04-30-sync-conflict-types.md) | Sync conflict type protocol |
| 2026-04-30 | [2026-04-30-sync-conflict-recovery-paths.md](2026-04-30-sync-conflict-recovery-paths.md) | Sync conflict recovery paths |
| 2026-04-30 | [2026-04-30-crdt-merge-invariants.md](2026-04-30-crdt-merge-invariants.md) | CRDT merge invariant tests (long-term regression guardrails) |
| 2026-04-30 | [2026-04-30-crash-recovery-loop.md](2026-04-30-crash-recovery-loop.md) | Crash recovery semantics (incremental pull, atomic write) |
| 2026-04-30 | [2026-04-30-2fa-feasibility-plan.md](2026-04-30-2fa-feasibility-plan.md) | 2FA/TOTP feasibility and sync strategy |
| 2026-04-29 | [2026-04-29-local-outbound-sync-review.md](2026-04-29-local-outbound-sync-review.md) | Local outbound sync review queue |
| 2026-04-29 | [2026-04-29-key-linking-quality-convergence.md](2026-04-29-key-linking-quality-convergence.md) | Key linking: receiver-side pubkey encryption, LAN pairing rules |
| 2026-04-28 | [2026-04-28-client-service-manager-system-refactor.md](2026-04-28-client-service-manager-system-refactor.md) | ServiceManager → `lib/system/` refactor |

## Archived Reports

Execution records with historical trace value but no active decision relevance.
See [`archived/`](archived/).

---

*Last updated: 2026-05-16*
