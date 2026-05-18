# Delegation

Sub-agent dispatches via the `Agent` tool are gated. Two cooperating hooks enforce the discipline so under-specified briefs and unverified "done" claims surface immediately instead of after the fact:

- **`PreToolUse(Agent)`** → `.claude/hooks/delegation-gate.sh` validates a 5-field handoff, honours an `# OVERRIDE:` marker, appends an audit line, and may attach a complexity advisory.
- **`PostToolUse(Edit|Write|MultiEdit)`** → `.claude/hooks/post-edit-validate.sh` re-runs the project validator after a *delegated* agent edits a file. Parent edits are exempt by design.

Spec: `docs/specs/002-delegation/`.

## The 5-field handoff

Every `Agent` prompt must include four required fields and one of two outcome fields. Field names are case-insensitive; order is free; any text after the colon counts. Missing fields → `exit 2` with the canonical template printed to stderr below.

- **TASK** — one sentence stating what the sub-agent is to do. No background, no rationale; the verb and object.
- **CONTEXT** — files, paths, links, prior decisions the sub-agent should read first. This is what keeps the sub-agent from inventing its own framing.
- **CONSTRAINTS** — what NOT to do; budgets (time, file count); style; scope guardrails; "do not modify X". The negative space matters as much as the task.
- **DELIVERABLE** — concrete artifact the sub-agent produces (file path, PR, summary shape). Use this when there is a thing.
- **DONE_WHEN** — verifiable condition (tests pass, file exists, command succeeds). Use this when there is a state. Either DELIVERABLE or DONE_WHEN satisfies the outcome slot — both are accepted, neither is required alongside the other.

Canonical template (verbatim from `delegation-gate.sh` stderr):

```
  TASK: <one sentence — what to do>
  CONTEXT: <files/paths/links the sub-agent should read first>
  CONSTRAINTS: <what NOT to do; budgets; style; scope guardrails>
  DELIVERABLE: <concrete artifact — file path, PR, summary shape>
  DONE_WHEN: <verifiable condition — tests pass, file exists, etc.>
```

**Spec-scoped delegations and `notes.md`** — when `CONTEXT` references a spec dir (`docs/specs/NNN-*`), `DELIVERABLE` SHOULD include the phrase "append any in-flight decisions/deviations/tradeoffs/open-questions to `docs/specs/NNN-*/notes.md`" (verbatim or equivalent). This gives the sub-agent a sanctioned surface for judgment calls that weren't pre-empted by spec/plan — the parent reviews the appended entries rather than reverse-engineering decisions from the diff. Author each entry as the dispatched `subagent_type`. Rule-only in v1 (no gate enforcement); see `.claude/rules/spec-driven.md` § *The four artifacts* for the artifact's purpose and entry shape.

## Why DONE_WHEN exists (the /goal connection)

DONE_WHEN is the local materialization of the same primitive that Codex CLI and Claude Code (v2.1.139+, May 2026) ship as `/goal` — a done-state declared up front so the agent works toward a contract instead of a sequence of prompts. The frame is **contract, not promise**: a goal statement without a verifier is just a fancier prompt.

The verifier in this project is `.claude/hooks/post-edit-validate.sh` plus the runtime-introspect probe (`bash .claude/tools/probe.sh last-run`, see `.claude/rules/runtime-introspect.md`). A sub-agent's self-report — "tests pass", "build succeeded" — is never the final signal. The validator running the actual command and emitting the real exit code is. Same discipline `/goal` enforces upstream via its evaluator model; here it runs through hooks instead of a separate judge, but the contract semantics are the same — and they compose. A parent that submits `/goal` to itself can still dispatch `Agent` calls during the loop, and each of those still passes through the 5-field handoff and the post-edit validator. The two primitives layer rather than compete.

## Override marker

Same shape as the governance gate (see `docs/specs/001-governance-gate/`): a line `# OVERRIDE: <reason ≥10 chars>`, case-sensitive, terminated by end-of-line. The reason is the audit trail — write something a future maintainer can grep for. "skip", "bypass", "n/a" are not reasons. A reason shorter than 10 chars after trimming is rejected and the gate blocks as if no marker were present (with a hint that the reason is too short).

The marker skips ONLY the 5-field validation. It does NOT skip the audit append (the marker reason is recorded in the `override` field) and does NOT skip the escalation-advisory pass. There is no silent bypass.

## Post-edit validator loop

When a delegated sub-agent edits a file, the post-edit hook runs the project validator (`.claude/validators/run.sh` by default, auto-detecting bun / pnpm / npm / python / go / rust). The validator emits a JSON object with an `ok` field. Fail → `exit 2` with the validator stdout/stderr tail surfaced to the sub-agent, which then has to fix the failing checks and re-edit.

Counters are per-`agent_id` under `.claude/.delegation-state/agents/`. After `CLAUDE_DELEGATION_LOOP_BUDGET` consecutive failures (default 5), stderr switches to `LOOP BUDGET EXCEEDED` and the sub-agent is directed to **stop editing and report a partial result** describing what worked, what failed validation, and what remains for a fresh delegation or a human to finish. A passing validation resets the counter — recovery in-flight is fine; the cap exists to stop fix-loops that aren't converging.

Parent agents do NOT trigger the validator (actor detection keys on the `agent_id` payload field, which is absent for parent edits). This is by design — the parent is expected to be running tests directly.

Tuning:

- `CLAUDE_DELEGATION_VALIDATOR=/abs/path/to/script` — override the validator path. The script must emit a JSON `{ ok, command, exit, duration_ms, stdout, stderr }` object on stdout.
- `CLAUDE_DELEGATION_LOOP_BUDGET=N` — change the consecutive-failure cap. Default 5.

If the validator is missing, non-executable, or emits unparseable output, the hook fails open (no block). A broken validator must never permanently lock the agent out of editing.

The validator may also append a `warnings` array to its JSON output on stack-detected paths. The post-edit hook reads any warnings and echoes each one to stderr with a `tdd-advisory:` prefix on the exit-0 path — non-blocking advisories that surface to the agent on its next turn. This is how TDD test-coverage advisories reach the agent today; see `.claude/rules/tdd.md` for the warning shape and the response convention.

## Audit log

`.claude/delegation-audit.jsonl` (gitignored, append-only). One JSON object per line, eleven fields: `ts`, `session_id`, `subagent_type`, `model`, `model_specified`, `formatted`, `override`, `advisory_emitted`, `advisory_kind`, `escalation_signals`, `task_summary`. `advisory_kind` is one of `"model-discipline"`, `"escalation"`, or `null` when no advisory fired — the bool `advisory_emitted` answers "did anything fire", the string `advisory_kind` answers "which one". Read with `jq -c .` or `tail -f`. Blocked calls are NOT logged — only allowed dispatches reach the audit phase.

## Advisories

The gate scores 5 signals against the prompt: `large-fileset`, `multi-integration`, `cross-domain`, `schema-data`, `security`. Two distinct advisories may attach to the call's `additionalContext` — both are informational, the call is always allowed.

**`model-discipline`** — fires when the parent did NOT pass an explicit `model` field AND at least one signal fires. Inlines the task-fit table so the parent can declare a model without re-deriving it: mechanical implementation → `sonnet`; schema/protocol lookup → `haiku`/`sonnet`; multi-source comparative research → `opus` if ≥2 signals (cross-domain + security/schema), else `sonnet`; architecture review or exploratory debugging → `opus`. The advisory exists because an unspecified model means the harness default runs, which may not match the task — declaring a model is the prerequisite for any subsequent escalation discussion.

**`escalation`** — fires when ≥2 signals fire AND the parent specified a non-opus model. Suggests re-issuing with `model: "opus"` for stronger reasoning. Does NOT fire on `model_specified=false` — that branch is already covered by `model-discipline`, which takes priority.

Treat either advisory as a nudge to reconsider, not a verdict. The audit log's `advisory_kind` field records which (if any) fired, so post-hoc analysis can distinguish discipline drift (parent kept dispatching without declaring a model) from undercommitment (parent picked a small model for a complex task).

## Gotchas (for hook maintainers)

- **`jq '.field // empty'` collapses `false` and missing into the same empty string.** When reading the validator's `ok`, use `if type=="object" and has("ok") then (.ok|tostring) else "" end` so `false` (real failure) and missing (broken validator → fail open) stay distinguishable.
- **`exec 9>file 2>/dev/null` is a sticky redirect.** A bare `exec` with no command applies the redirections to the current shell — `2>/dev/null` would permanently silence stderr for the rest of the script and eat every block message. Probe writability in a subshell (`( : >>"$path" ) 2>/dev/null || exit 0`) before the bare `exec`.
