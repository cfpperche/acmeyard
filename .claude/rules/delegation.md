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

**Budgeted artifacts and the overshoot cascade** — when a brief declares a size target for the artifact the sub-agent produces, CONSTRAINTS MUST inline the two-threshold cascade per `.claude/rules/artifact-budgets.md`: `target_max × 1.2 → partial-result with oversize_reason` (soft, sub-agent has agency); `target_max × 1.8 → STOP, emit partial-result, no further production` (hard, no agency). Trim-loop and re-emit-at-smaller-scope are forbidden in every zone above 1.0× — both are "redo to fit budget" antipatterns that hide the scope-mismatch signal. Override marker reuses the project's grammar with `budget-exempt:` prefix (mirrors `tdd-exempt:` here). Rule-only in v1.

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

`.claude/delegation-audit.jsonl` (gitignored, append-only). Read with `jq -c .` or `tail -f`. Blocked calls are NOT logged — only allowed dispatches reach the audit phase. Two row shapes coexist in the same file, distinguished by the `event` field (absent on dispatch rows, `"subagent-stop"` on close rows).

### Dispatch row (written by `delegation-gate.sh` at PreToolUse(Agent))

Twelve fields: `ts`, `session_id`, `tool_use_id`, `subagent_type`, `model`, `model_specified`, `formatted`, `override`, `advisory_emitted`, `advisory_kind`, `escalation_signals`, `task_summary`. `advisory_kind` is one of `"model-discipline"`, `"escalation"`, or `null` when no advisory fired — the bool `advisory_emitted` answers "did anything fire", the string `advisory_kind` answers "which one". `tool_use_id` is the harness-supplied `toolu_*` identifier and acts as the join key into the close row (see below) — spec 061 added this field as the prerequisite for exact dispatch↔stop correlation under parallel same-type dispatches.

### Close row (written by `delegation-stop.sh` at SubagentStop, spec 061)

Thirteen fields: `ts`, `event` (always `"subagent-stop"`), `session_id`, `agent_id`, `tool_use_id`, `agent_type`, `exit`, `duration_ms`, `edit_count`, `last_assistant_message_head`, `agent_transcript_path`, `correlation`, `stop_hook_active`. Denormalised — `agent_type` mirrors the dispatch row's `subagent_type` and the 200-char `last_assistant_message_head` is inlined so standalone `jq` queries (`select(.event == "subagent-stop" and .exit == "loop-budget-exceeded")`) work without a join.

- `exit` — `"ok"` for normal completion, `"loop-budget-exceeded"` when the per-agent `consecutive_failures` state file (maintained by the post-edit validator) ≥ `CLAUDE_DELEGATION_LOOP_BUDGET` (default 5)
- `duration_ms` — client-computed (close_ts − dispatch_ts), `null` when the dispatch row can't be located (orphan stop)
- `edit_count` — counted from the per-sub-agent transcript JSONL (`agent_transcript_path`) by filtering `assistant.message[].tool_use` blocks with `.name ∈ {Edit, Write, MultiEdit}`. `null` on any read/jq error
- `correlation` — `"tool_use_id"` when the bridge resolved via the sidecar `.meta.json.toolUseId` lookup (preferred), `"heuristic-session-type"` for the `(session_id, agent_type)` fallback under missing sidecar, `"unmatched"` when no dispatch row matched at all
- `agent_transcript_path` — pointer to the full per-sub-agent transcript for verbose forensics

### Bridge mechanism (dispatch ↔ stop)

`PreToolUse(Agent)` payload carries `tool_use_id` (no `agent_id` yet — sub-agent doesn't exist), while `SubagentStop` payload carries `agent_id` (no `tool_use_id`). The two identifiers are disjoint. Bridge: Claude Code writes a per-sub-agent transcript at `<cc-storage>/<session_id>/subagents/agent-<agent_id>.jsonl` with a sidecar `agent-<agent_id>.meta.json` that contains `{ agentType, description, toolUseId }`. The `toolUseId` field matches the dispatch row's `tool_use_id`. The close hook reads the sidecar at SubagentStop time to obtain both identifiers and joins exactly.

### Example queries

Pair every dispatch with its close row (when present):

```bash
jq -s 'group_by(.tool_use_id) | map({
  tool_use_id: .[0].tool_use_id,
  open: (.[]? | select((.event // "") == "")),
  close: (.[]? | select(.event == "subagent-stop"))
})' .claude/delegation-audit.jsonl
```

Find loop-budget exhaustions in the last 24 hours:

```bash
tail -10000 .claude/delegation-audit.jsonl | jq -c '
  select(.event == "subagent-stop" and .exit == "loop-budget-exceeded")
'
```

Find sub-agents that dispatched but never closed (orphans — session crash or hook failure):

```bash
jq -s '
  group_by(.tool_use_id)
  | map(select(length == 1 and ((.[0].event // "") == "")))
  | .[]
' .claude/delegation-audit.jsonl
```

## Advisories

The gate scores 5 signals against the prompt: `large-fileset`, `multi-integration`, `cross-domain`, `schema-data`, `security`. Two distinct advisories may attach to the call's `additionalContext` — both are informational, the call is always allowed.

**`model-discipline`** — fires when the parent did NOT pass an explicit `model` field AND at least one signal fires. Inlines the task-fit table so the parent can declare a model without re-deriving it: mechanical implementation → `sonnet`; schema/protocol lookup → `haiku`/`sonnet`; multi-source comparative research → `opus` if ≥2 signals (cross-domain + security/schema), else `sonnet`; architecture review or exploratory debugging → `opus`. The advisory exists because an unspecified model means the harness default runs, which may not match the task — declaring a model is the prerequisite for any subsequent escalation discussion.

**`escalation`** — fires when ≥2 signals fire AND the parent specified a non-opus model. Suggests re-issuing with `model: "opus"` for stronger reasoning. Does NOT fire on `model_specified=false` — that branch is already covered by `model-discipline`, which takes priority.

Treat either advisory as a nudge to reconsider, not a verdict. The audit log's `advisory_kind` field records which (if any) fired, so post-hoc analysis can distinguish discipline drift (parent kept dispatching without declaring a model) from undercommitment (parent picked a small model for a complex task).

## Gotchas (for hook maintainers)

- **`jq '.field // empty'` collapses `false` and missing into the same empty string.** When reading the validator's `ok`, use `if type=="object" and has("ok") then (.ok|tostring) else "" end` so `false` (real failure) and missing (broken validator → fail open) stay distinguishable.
- **`exec 9>file 2>/dev/null` is a sticky redirect.** A bare `exec` with no command applies the redirections to the current shell — `2>/dev/null` would permanently silence stderr for the rest of the script and eat every block message. Probe writability in a subshell (`( : >>"$path" ) 2>/dev/null || exit 0`) before the bare `exec`.
