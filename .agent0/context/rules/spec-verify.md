---
paths:
  - ".agent0/tools/spec-verify.sh"
  - ".agent0/validators/run.sh"
  - "docs/specs/*/tasks.md"
  - "docs/specs/*/spec.md"
---

# Spec verify advisory

A spec opts in to **mechanical re-verification** by declaring an executable proof command on its `tasks.md`. `.agent0/tools/spec-verify.sh <spec-dir>` runs that command from the repo root and records pass/fail to the spec's `notes.md`; the post-edit validator (`.agent0/validators/run.sh`) emits a non-blocking `spec-verify-advisory:` when a **shipped** spec that declares a verify command has no passing record. This closes a gap the ordinary `/sdd` flow had — its "done" was prose acceptance only, with no first-class "rerun this exact proof" handle (the `/squad` done-gate has the shape, but only inside the autonomous two-runtime loop). The pattern is ported from the `repository-harness` project's `story verify` (its `verify_command`/`last_verified_result`), but kept in Agent0's markdown+shell+advisory idiom — no SQLite, no compiled CLI, no blocking gate. Spec 177.

## Declaration syntax

Add one or more lines to the spec's `tasks.md` (canonical home — it is the executable "do" file; `spec.md` stays intent-pure):

```
**Verify:** `bash .agent0/tests/spec-verify/run-all.sh`
```

- The marker is a literal `**Verify:**` at line start, followed by a single backtick-fenced command.
- Multiple `**Verify:**` lines = multiple commands, run in declared order.
- Typically placed under the `## Verification` section, but any line in the file is scanned.
- `spec.md` is scanned as a fallback so a single-file spec still works; `tasks.md` wins when both declare.
- Commands must be runnable from the **repo root** and should be side-effect-free (they may run on any validator pass via the human/agent invoking the tool — they are never auto-run by the validator).

## The tool

```bash
bash .agent0/tools/spec-verify.sh docs/specs/NNN-slug          # human summary
bash .agent0/tools/spec-verify.sh docs/specs/NNN-slug --json   # machine object
bash .agent0/tools/spec-verify.sh docs/specs/NNN-slug --quiet  # records, prints nothing
```

It runs each declared command from the repo root, appends a timestamped block to the spec's `notes.md` under `## Verification log`, and prints the result. Exit codes:

| code | meaning |
| --- | --- |
| `0` | every declared command passed |
| `1` | at least one declared command failed (remaining commands still run + recorded) |
| `2` | no verify command declared — `notes.md` is **not** modified |
| `64` | usage error |

The `notes.md` record is the durable, git-tracked, human-readable proof history (Agent0's answer to the studied project's `last_verified_result` DB column):

```
## Verification log

### 2026-06-08T20:55:00Z — pass (1/1) — source: tasks.md
- `bash .agent0/tests/spec-verify/run-all.sh` — pass
```

## The advisory

On every validator run, for each `docs/specs/*/spec.md` with `**Status:** shipped`:

- if its `tasks.md` (or `spec.md`) declares a `**Verify:**` command **and** the latest tool-shaped `## Verification log` record in `notes.md` is missing or `fail` → emit one line to stderr:
  ```
  spec-verify-advisory: docs/specs/NNN-slug declares a verify command with no passing record — run bash .agent0/tools/spec-verify.sh docs/specs/NNN-slug
  ```
- a shipped spec that declares **no** verify command is never nagged (opt-in; absence of a declaration is silence).

The advisory is **non-blocking** — it never alters the validator's JSON `ok` field or exit code, exactly like `lint-advisory`/`typecheck-advisory`/`visual-contract-advisory`. It is emitted before stack detection so it fires even on a stackless harness repo (Agent0 itself emits `no-stack-detected` and would otherwise skip every advisory). On Codex CLI the validator's stderr is routed into the hook's `additionalContext` like the other advisories.

## When to override

- **Opt out of the whole scan:** `CLAUDE_VALIDATOR_SKIP_SPEC_VERIFY=1` short-circuits the advisory block.
- **Opt out per spec:** simply do not declare a `**Verify:**` line — the spec is silent.
- A declared command that has legitimately rotted (the proof is no longer the right one) should be **updated or removed**, not silenced by a stale passing record.

## Gotchas

- **Latest record wins.** The advisory keys on the *last* tool-shaped verification header in `notes.md` (`### <UTC timestamp> — pass|fail (<passed>/<total>) — source: tasks.md|spec.md`). A spec that passed once then regressed (latest `fail`) correctly re-fires the advisory. Unrelated `###` design-memory headings are ignored. Running the tool again appends a fresh block, so the freshest outcome is always the signal.
- **Opt-in, not ceremony.** The mechanism deliberately does not nag shipped specs that never opted in — both the Claude and Codex adoption reviews flagged "label everything high-risk and the signal dies." Declaring a verify command is a choice the spec author makes.
- **The validator advises, never executes.** It only reads the markdown record; it never runs the declared shell. Running is explicit (`spec-verify.sh`) or via a `/squad` gate. This avoids executing arbitrary spec-declared commands on every `SubagentStop`.
- **Append-only.** The tool only appends a `## Verification log` block; it never edits the in-flight design-memory sections of `notes.md`.
- **Status is read from `spec.md`, verify from `tasks.md`.** The two-file split is intentional (intent vs. do); the advisory reads both.

## Notes

_Consumer-extension surface — append consumer-local bullets here. Sync flags the file as `!! customized` (sha-compare is section-blind); the conflict region is mechanically this section: take new upstream verbatim, re-add consumer bullets at the end._
