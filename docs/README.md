# SecretRoy Documentation

**Last updated**: 2026-04-28

This directory is the canonical documentation home for the SecretRoy client.
Project-owned Markdown files are organized by purpose, use lowercase
kebab-case names, and avoid duplicated mirror copies.

## Current Documentation

| Area | Entry | Purpose |
|---|---|---|
| Wiki | [wiki/home.md](wiki/home.md) | User and developer-facing wiki index |
| Architecture | [architecture/README.md](architecture/README.md) | Current architecture review set |
| Security | [security/security-features.md](security/security-features.md) | Implemented security capabilities |
| Sync | [sync/sync-protocol.md](sync/sync-protocol.md) | Sync protocol and vault-linking references |
| Account templates | [features/account-templates/business-analysis.md](features/account-templates/business-analysis.md) | Template feature design and test reports |
| Guides | [guides/technical-documentation.md](guides/technical-documentation.md) | Code map and implementation guides |
| TODO | [todo.md](todo.md) | Project-level TODO derived from the current architecture conclusion |
| Reports | [reports/docs-reorganization-execution-report-2026-04-28.md](reports/docs-reorganization-execution-report-2026-04-28.md) | Latest documentation execution report |
| Archive | [archive/historical-proposals/executive-summary-2026-04-18.md](archive/historical-proposals/executive-summary-2026-04-18.md) | Historical proposals and legacy reports |

## Recommended Reading

| Reader | Path |
|---|---|
| User | [wiki/user-manual.md](wiki/user-manual.md) -> [wiki/quick-start-guide.md](wiki/quick-start-guide.md) |
| Developer | [wiki/development-setup.md](wiki/development-setup.md) -> [guides/technical-documentation.md](guides/technical-documentation.md) |
| Architecture reviewer | [architecture/00-executive-summary.md](architecture/00-executive-summary.md) -> [architecture/03-risks-and-roadmap.md](architecture/03-risks-and-roadmap.md) |
| Security reviewer | [security/security-features.md](security/security-features.md) -> [security/local-database-encryption.md](security/local-database-encryption.md) |
| Sync implementer | [sync/sync-protocol.md](sync/sync-protocol.md) -> [security/key-sync-implementation.md](security/key-sync-implementation.md) |

## Directory Layout

```text
docs/
├── architecture/                 # Current architecture source of truth
├── archive/                      # Historical proposals and legacy reports
├── features/account-templates/   # Account template design and QA docs
├── guides/                       # Technical guides and tutorials
├── product/                      # Product whitepaper
├── reports/                      # Audits, handoff notes, delivery reports, dev logs
├── security/                     # Security model, risks, and encryption details
├── sync/                         # Sync and vault-linking protocol docs
└── wiki/                         # User/developer wiki
```

## Naming Rules

- Keep canonical docs under `docs/` unless a root `README.md` is required.
- Use lowercase kebab-case for Markdown filenames.
- Keep only one canonical copy of each topic.
- Move stale proposals and one-off legacy reports to `docs/archive/`.
- Keep generated dependency docs such as `node_modules/**/README.md` outside this project documentation inventory.
