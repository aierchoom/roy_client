# Documentation Reorganization Execution Report

**Date**: 2026-04-28

## Scope

整理 SecretRoy 项目自有 Markdown 文档，排除第三方依赖与生成资源文档：

- Included: `roy_client/README.md`, `roy_client/docs/**/*.md`, root-level project reports.
- Excluded: `roy_server/node_modules/**/*.md`, Flutter generated asset README, hidden tool memory under `.claude/`.

## Actions

- Normalized documentation filenames to lowercase kebab-case.
- Removed duplicate `docs/architecture_review/` mirror documents.
- Consolidated current architecture docs under `docs/architecture/`.
- Consolidated security docs under `docs/security/`.
- Consolidated sync docs under `docs/sync/`.
- Consolidated account-template docs under `docs/features/account-templates/`.
- Consolidated technical guides under `docs/guides/`.
- Consolidated operational reports, handoff notes, dev logs, and quality reports under `docs/reports/`.
- Moved historical proposals and legacy one-off reports under `docs/archive/`.
- Rebuilt the primary documentation index at `docs/README.md`.
- Added local README files for major documentation sections.
- Updated root `README.md` to point to the normalized documentation center.

## Duplicate Handling

Removed duplicate canonical mirrors:

- `docs/architecture_review/00_Executive_Summary.md`
- `docs/architecture_review/01_System_Architecture.md`
- `docs/architecture_review/02_Runtime_and_Sync.md`
- `docs/architecture_review/03_Risks_and_Roadmap.md`
- `docs/architecture_review/ARCHITECTURE_DOCS_INDEX.md`
- `docs/architecture_review/README.md`
- `docs/architecture_review/FLUTTER_NODE_BEGINNER_TUTORIAL.md`
- `docs/architecture_review/SECRETROY_ARCHITECTURE_DEEP_DIVE.md`
- `docs/FrameworkREADME.md`

Retained unique historical context by moving it instead of deleting it:

- `docs/EXECUTIVE_SUMMARY.md` -> `docs/archive/historical-proposals/executive-summary-2026-04-18.md`
- `docs/MICROSERVICES_IMPLEMENTATION_PLAN.md` -> `docs/archive/historical-proposals/microservices-implementation-plan.md`
- `BUG_FIX_REPORT.md` -> `docs/archive/legacy-reports/bug-fix-report.md`
- `REFACTOR_LOG.md` -> `docs/archive/legacy-reports/refactor-log.md`
- `docs/architecture_review/SYNC_PROTOCOL_AND_RISK_ASSESSMENT.md` -> `docs/sync/sync-protocol-risk-assessment.md`

## Current Layout

```text
docs/
├── architecture/
├── archive/
├── features/account-templates/
├── guides/
├── product/
├── reports/
├── security/
├── sync/
└── wiki/
```

## Naming Standard

- Directory names: lowercase kebab-case.
- Markdown filenames: lowercase kebab-case, except section `README.md` files.
- Current source-of-truth docs stay in topical directories.
- Historical or superseded docs move to `docs/archive/`.
- One-off execution/audit/delivery reports move to `docs/reports/`.

## Notes

- The current local database encryption docs remain under
  `docs/security/local-database-encryption.md`.
- The latest security model uses a random DB data key wrapped by a
  master-password-derived wrapping key.
- Third-party dependency Markdown files were intentionally left untouched.
