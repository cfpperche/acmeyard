# Session handoff

Read at the start of every Claude Code session and updated at the end. Captures work-in-progress context that wouldn't otherwise survive between sessions.

See `.claude/rules/session-handoff.md` for the protocol (4 KB size discipline + reader-side truncation defence).

---

## Current state

**Acme Yard project bootstrapped + first spec drafted.** Repo public at https://github.com/cfpperche/acmeyard. Laravel 13.8 scaffold + Agent0 harness fully synced (commit `cfedeb5` incorporates Agent0 fix `7ecb2c9` for `.gitignore` additive merge). Domain `acmeyard.com` purchased; DNS pointing TBD. License BSL 1.1 (Change Date 2030-05-18 → Apache 2.0). README declares brand pitch "12 ships a year. Built to be owned." + 3-tier distribution (self-host lifetime / lifetime+subscription / managed cloud).

**Spec 001 (`substrate`) — DRAFT, ready for `/sdd plan` review → Week 1 implementation.** 6-round `/sdd refine` synthesis produced `spec.md` (15 acceptance scenarios + 10 anti-goals + 6 open questions) + `plan.md` (4-week approach + 6 rejected alternatives + 10 risks + 15 sources) + `tasks.md` (57 ordered tasks + 15 verifications). Quality score 94/100.

**Decisions locked** (full reasoning in `spec.md`/`plan.md`):
- Multi-repo, package-first. 5 primitives v1: auth + pluggable billing + license-key validator (14-day grace) + row-level multi-tenant + LGPD audit. 3 transversals: Sentry+Pulse, Filament 3 panel, Prism PHP chat+structured. Distribution: Satis private repo + `composer create-project` + Stripe webhook → Mailgun `auth.json` email.

## WIP

**None.** Implementation has NOT started — only spec/plan/tasks scaffolding. Working tree clean; all commits pushed to `origin/main`.

## Next steps

1. **Pre-flight (tasks 1-4 in `docs/specs/001-substrate/tasks.md`)** — verify `github.com/orgs/acmeyard` namespace available (`gh api /orgs/acmeyard`); decide Satis vs Private Packagist (Open Q #2); decide storefront stack (Open Q #1); lock dependency versions for substrate v1.0.
2. **Week 1 (tasks 5-19)** — create `acmeyard/substrate` repo + composer.json + auth + multi-tenant + license-key validator + Filament+tenancy smoke test (risk #4).
3. **Week 2-4** — billing + audit + Filament + AI; then distribution infra; then dogfood Fluxo MEI v1.

Optional pre-Week-1: resolve open questions inline in `spec.md` or scaffold a sub-spec (e.g. `002-storefront`) for the storefront stack decision.

## Decisions & gotchas

- **acmeyard is BRAND repo, NOT substrate code repo.** This repo holds `docs/specs/` + `README.md` + `LICENSE.md` + Agent0 harness. Substrate code goes in NEW repo `acmeyard/substrate` (created in Week 1).
- **Agent0 harness sync evolved during bootstrap.** Fork's `.gitignore` got 22 Agent0 entries appended via the new merge handler (spec 016 fix). If re-syncing, `bash ~/Agent0/.claude/tools/sync-harness.sh --check --agent0-path=$HOME/Agent0 .` shows `up-to-date` for everything.
- **CLAUDE.md migrated to managed-block layout (Agent0 spec 058).** Markers `<!-- AGENT0:BEGIN -->` / `<!-- AGENT0:END -->` delimit the Agent0-owned capacity region; project sections (Overview, Stack, Build & test, Conventions, Gotchas) stay above BEGIN. Orphan `## Prototype skill` removed on first managed-block sync. Future Agent0 capacity ADDs/REMOVALs propagate symmetrically — no more append-only orphan bug. Don't put project customizations inside the markers; if you do, sync refuses with `customized-refused` and writes `.claude/CLAUDE.md.diverged-region.md`.
- **`.claude/skills/brainstorm/templates/render.html.tmpl`** in the fork is a sibling-session pre-existing dirty file from Agent0. Leave alone.
- **Acme Yard ⇄ Agent0 governance.** Every `composer require` will route through Agent0's supply-chain block; every sub-agent edit triggers post-edit validator + lint (Pint + PHPStan when declared); runtime-introspect captures phpunit/pest snapshots. PHP/Laravel-aware end-to-end via Agent0 spec 047.
- **Open questions live in `spec.md` § Open questions.** Don't make implementation decisions on them without writing the resolution back to spec.md (so the audit trail survives).

## Carryover

- `acmeyard.com` DNS — A record pending (placeholder landing or storefront)
- `packages.acmeyard.com` + GitHub org `acmeyard` provisioned in Week 3 (tasks 36-37)
