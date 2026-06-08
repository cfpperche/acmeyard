# Session handoff

Canonical runtime-neutral handoff for Acmeyard agent sessions.

## Current State

- Repo: `/home/goat/acmeyard`, branch `main`.
- Acme Yard is a portfolio of focused microSaaS products on a shared Laravel + Filament substrate, with Brazilian-context product workflows and Agent0 governance.
- Harness synced from Agent0 through project-core specs 173/174/175/176 plus `agent-browser verify-contract` hardening.
- Project-core bootstrap completed: `.agent0/project-core.md` carries template marker `2026-06-08-1`, includes Agent0/CognixSE-style Language & Locale guidance, and remains the consumer-owned source truth.
- `.agent0/project-core.md.example` is present as the Agent0 template reference.
- `CLAUDE.md` and `AGENTS.md` project-core mirrors are hydrated from `.agent0/project-core.md`.
- Validation passed: `sync-harness --check` exit 0, `project-core-sync --check`, `doctor` OK with 24 ok / 0 advisory / 0 broken, `status` has no project-core advisory, `check-instruction-drift.sh`, and `git diff --check`.

## Active Work

- Harness sync/bootstrap is committed locally as `403521b chore(harness): sync and bootstrap project core`.
- No product spec is active.
- No local dev server is intentionally running.

## Next Actions

1. Push the harness sync/bootstrap commit when ready.
2. When product implementation resumes, start from `docs/specs/001-substrate/` and keep Laravel/Filament conventions intact.

## Decisions & Gotchas

- Language policy: follow the user's language for conversation; repo artifacts default to English; preserve existing file language; ask before choosing locale for ambiguous user-facing/external text. Brazilian context matters when the active spec targets Brazil, but it does not make all product copy pt-BR by default.
- Do not overwrite `.agent0/project-core.md` during future syncs; sync owns `.agent0/project-core.md.example` and mirrors only derived entrypoint regions.
- Bootstrap/template-review alerts should not appear while `.agent0/project-core.md` keeps marker `2026-06-08-1`.
- Product work belongs under specs in `docs/specs/`; harness files are governance/tooling, not product code.
- License posture is BSL 1.1 with Apache 2.0 conversion; preserve the commercial managed-service boundary.
