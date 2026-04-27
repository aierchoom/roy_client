# Project TODO Linkage Execution Report

| Item | Value |
|---|---|
| Status | Completed |
| Date | 2026-04-28 |
| Scope | Documentation |
| Related Docs | [Project TODO](../../todo.md), [Executive Summary](../../architecture/00-executive-summary.md#decision-summary) |

## Goal

Create a canonical project TODO document and link it to the architecture conclusion so follow-up work is not scattered across separate notes.

## Changes

- Added `docs/todo.md` as the project-level TODO.
- Linked the TODO back to the architecture decision summary.
- Linked the executive summary conclusion forward to the TODO.
- Added the TODO to the docs home index and architecture index.
- Expanded the TODO into development lanes for architecture iteration, security, sync, server runtime, testing, UX quality, and the authenticator feature.
- Added strategic directions for local-first positioning, privacy-preserving sync, credential operations, and recoverability.
- Added business/product optimization lanes for onboarding, vault health, backup confidence, template packs, import strategy, and privacy-preserving diagnostics.
- De-scoped long-term items such as team sharing, enterprise governance, browser extensions, mobile autofill, CLI, passkeys/WebAuthn, managed sync, and business packaging from the current TODO.
- Added current-roadmap focus on expanding local-first advantages and making the self-hosted sync server easier to set up, inspect, back up, and replace.
- Added an explicit current product decision: SecretRoy should converge on a trusted local-first sensitive information manager with optional self-hosted sync.
- Included the TOTP authenticator idea as a candidate feature after the current security, sync, and robustness priorities.

## Validation

- Verified the new TODO references with `rg`.
- Checked `git diff` for the touched documentation files.

## Risk Notes

- This is documentation-only and does not change runtime behavior.
- TODO priorities should be kept aligned with implementation reports as work lands.

## Follow-Ups

- Convert active TODO items into dedicated execution reports when implementation begins.
- Update architecture docs in the same change whenever a TODO item changes system assumptions.
