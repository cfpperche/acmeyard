# Session handoff

Canonical runtime-neutral handoff for Acmeyard agent sessions.

---

## Current State

- Agent0 harness bootstrap sync applied and committed on branch `chore/agent0-harness-sync`.
- Legacy `.claude` harness residues were removed: old hooks/rules/tests/tools/validators/runtime state and the obsolete `prototype` skill are gone.
- `.claude` now matches the current consumer shape: `settings.json`, `agents/`, and current skills including `skills/product`.
- Sync baseline created at `.agent0/harness-sync-baseline.json`; final `sync-harness --check --agent0-path=/home/goat/Agent0` is clean.
- Harness health is green: `doctor.sh` reports 22 ok, 0 advisory, 0 broken.
- `check-instruction-drift.sh --agent0-path=/home/goat/Agent0` still reports `managed blocks differ`; this is inherited from the current Agent0 source, which has the same CLAUDE/AGENTS managed-block drift at `b90b836`.

## Active Work

- Housekeeping changes are ready to review on branch `chore/agent0-harness-sync`.

## Next Actions

- Review/push branch `chore/agent0-harness-sync` when ready.
- Separately fix the upstream Agent0 `CLAUDE.md`/`AGENTS.md` managed-block drift if instruction-drift green is required.

## Decisions & Gotchas

- Acmeyard had no `.agent0/harness-sync-baseline.json` or legacy `.claude/harness-sync-baseline.json`, so the first sync required `--force` to seed the baseline.
- Root `main` was clean but one commit ahead of `origin/main`; this sync branch was created from that local state.
- `.agent0/project-core.md` was added so both Claude and Codex entrypoints see Acme Yard project identity while preserving Agent0-managed blocks.
