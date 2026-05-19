# Artifact budgets

When a sub-agent dispatch produces an artifact with a declared size budget, the budget is a **scope proxy, not a byte cap**. A budget of 30 KB means "an artifact whose job fits in ~30 KB"; an overshoot is a signal that the artifact's scope drifted, not an invitation to compress. The recurrence pattern this rule exists to prevent: sub-agent generates oversized output → enters a silent trim-loop → burns tokens compressing what should have been re-scoped → ships either a smaller-but-bloated artifact or never converges. Spec: `docs/specs/065-artifact-budget-discipline/`.

The discipline is **rule-only** by design in v1. No hook intercepts, no validator enforces — the sub-agent reads this rule (via the brief CONSTRAINTS that inline its cascade) and decides. If sub-agents ignore the rule ≥3 times in dogfood, the next step is a PostToolUse(Write) detector hook (deferred per `.claude/memory/feedback_speculative_observability.md`'s rule-of-three demand-test).

## Summary

A budget is the **scope proxy**, not the artifact. Three zones of overshoot, each with a deterministic response:

| Zone | Range | Response |
|---|---|---|
| **DONE** | `output ≤ target_max × 1.2` | Ship as DONE. The 20% tolerance absorbs honest variance against the declared `target_max`. |
| **Soft overshoot** | `target_max × 1.2 < output ≤ target_max × 1.8` | Emit partial-result with `oversize_reason`. Sub-agent has agency to keep producing IF the partial would be useful to downstream — but trim-loop and re-emit-at-smaller-scope are forbidden. |
| **Hard abort** | `output > target_max × 1.8` | STOP immediately. Emit partial-result with `oversize_reason`. No further production regardless of downstream usefulness. The scope is wrong; orchestrator surfaces. |

Between 1.2× and 1.8× the sub-agent is in the soft zone — it must decide whether to wrap up cleanly as partial-result or push toward 1.8× hard-abort. The decision is the sub-agent's, but the floor on `oversize_reason` exists in both. **Trim-loop and re-emit-at-smaller-scope are forbidden in every zone above 1.2×.**

The multipliers (`soft_overshoot_multiplier = 1.2`, `hard_abort_multiplier = 1.8`) are declared per-step in `.claude/skills/product/references/pipeline-coverage.md` § Per-step table and inlined into each brief's CONSTRAINTS at dispatch time. v1 uses uniform values across all `/product` steps; per-step calibration is deferred until empirical data justifies (see spec 056 for the calibration discipline).

## Forbidden antipatterns

Two failure modes the rule explicitly bans. Both share the same shape: "redo to fit the budget" instead of "stop and report".

### Trim-loop

Sub-agent produces an oversized artifact, then writes the same artifact path again with content compressed (smaller CSS, shorter prose, condensed sections). The pattern is mechanically observable: same `Write` / `Edit` call against the same file path, multiple times in one session, with each version smaller than the previous. Empirical example: mei-saas 2026-05-19 `/product` Step 02 produced `direction-a.html` at 69 KB, then 46.6 KB, then 43.8 KB, then 42.7 KB, then 41.8 KB — 6+ iterations against a 30 KB target. The compression converged sub-linearly (each iteration saved less) and the CSS bloat that was the actual cause was diagnosed only at iteration 6.

### Re-emit at smaller scope

Sub-agent receives the brief, produces an oversized artifact, then re-executes the brief from scratch with a narrower self-imposed scope. Mechanically distinct from trim-loop (full re-execution, not incremental compression) but the failure mode is identical: the sub-agent treats the overshoot as a "redo" cue rather than a "stop and report" cue. This pattern previously shipped in Step 01 (Ideation) brief language as `"going over by ≥50% means re-emit at smaller scope"` and is being removed per spec 065 Acceptance Criterion #3.

### Why both are banned

A budget overshoot above 1.0× is information the orchestrator and the user need. Trim-loop and re-emit hide that signal — the sub-agent absorbs the failure into its own session and ships a smaller-but-still-misshaped artifact, or burns tokens until it gives up. Partial-result with `oversize_reason` makes the signal visible: the orchestrator records, the next step downstream notes the gap, and at gate time the user can choose `iterate` knowing what bloated and why.

## `oversize_reason` field

When emitting partial-result, the sub-agent includes a one-sentence `oversize_reason` naming the **dimension** that caused the bloat — not just "too big". Free prose in v1; structured shape deferred.

Worked phrasings:

- `oversize_reason: "CSS reached 16 KB covering light+dark+5 components; mood board needs 1 mode + 3 components"`
- `oversize_reason: "fixture data (mock customer records) consumed 12 KB; example with 1-2 records is sufficient"`
- `oversize_reason: "prose verbosity in § Hook and § Mechanics — explanatory paragraphs that belong in functional-spec.md, not concept-brief"`
- `oversize_reason: "screen count: produced 8 mood screens when killer flow needs 3-5"`

Bad phrasings (do not use):

- `oversize_reason: "too big"`
- `oversize_reason: "exceeded budget"`
- `oversize_reason: "tried to trim but couldn't"`

The signal value is in **which dimension** drifted, because that dimension is what the next iteration needs to re-scope. "CSS bloated covering modes the artifact doesn't need" is actionable; "too big" forces a re-investigation.

## Override marker

Reuses the project's `# OVERRIDE: <reason ≥10 chars>` grammar (same shape as `.claude/rules/delegation.md`, `.claude/rules/tdd.md`, `.claude/rules/secrets-scan.md`, `.claude/rules/supply-chain.md`). Convention: prefix the reason with `budget-exempt:` for greppability, mirroring `tdd-exempt:`:

```
# OVERRIDE: budget-exempt: PRD includes legally-required disclosures from Step 09 that push to 9 KB
```

The marker on a brief lets the sub-agent ship an artifact above the hard-abort threshold without partial-result semantics. The reason text is the documentation — write something a future reader can grep. "skip", "bypass", "ok for now" are not reasons.

The marker does NOT skip the `oversize_reason` field — it skips the partial-result/stop discipline. An overridden overshoot ships as DONE, but still annotates which dimension bloated and why the override was legitimate.

## Worked example — mei-saas Step 02 trim-loop (2026-05-19)

Empirical case the rule was written to address.

**Setup.** `/product` Step 02 dispatched the direction-writer sub-agent with brief CONSTRAINTS declaring `Size budget: per schema.md § Target (currently 10-30 KB for direction-a.html; soft overshoot trigger at max × 1.2 → partial-result with oversize_reason)`. Target_max = 30 KB; soft trigger = 36 KB.

**What happened.** Sub-agent produced `direction-a.html` at 69 KB (2.3× target). Instead of emitting partial-result at 36 KB (soft) or aborting hard at 54 KB (hard, per the rule shipping now), it entered a trim-loop: 69 → 46.6 → 43.8 → 42.7 → 41.8 KB across 6+ iterations. The CSS (16 KB covering light+dark+5 components, against a mood board that needs 1 mode + 3 components) was the actual bloat dimension but was diagnosed only at iteration 6. Sub-agent burned ~20K output tokens compressing what should have been re-scoped.

**What should have happened under this rule.**

1. At ~36 KB (1.2× = soft trigger), sub-agent emits partial-result: `oversize_reason: "CSS at 16 KB covering 2 modes + 5 components against mood-board need of 1 mode + 3 components; trimming sections to fit would discard the lineage information"`. Sub-agent has agency here — may continue if the partial covers a useful subset of the 8 mandatory sections, or may stop. Cannot trim, cannot re-emit smaller.
2. At ~54 KB (1.8× = hard abort), sub-agent stops regardless. Returns partial-result with the same `oversize_reason`. No agency.
3. Orchestrator records the partial-result in `.state.json.blocked_steps` (per `state-machine.md` § Failure handling: Step 02 BLOCKED → "degrade gracefully"). REPORT.md `## Blocked steps` notes the bloat dimension. Phase 1 gate surfaces it; user can pick `iterate` knowing CSS scope was wrong.

**The behavioral fix is the no-trim-loop + no-re-emit sentence in the brief**, not the multiplier values. The mei-saas brief already had the 1.2× partial-result language. What was missing was the explicit prohibition on trim-loop as a response.

## Where this rule applies

- **`/product` skill** — 15 step briefs in `.claude/skills/product/references/delegation-briefs.md`, the per-step table in `.claude/skills/product/references/pipeline-coverage.md`, and the per-stack screen-writer brief. Currently the only consumer.
- **Future skills with budgeted artifacts** — when a second skill grows budgets, the rule applies by reference. The brief inlines the cascade language; the rule is the canonical reference.

State-file budgets (`SESSION.md` ≤4KB, `COMPACT_NOTES.md` 12 turns, `MEMORY.md` ~200 lines) are runtime/script limits, not scope-proxy budgets — they're enforced by harness behavior (truncation) and don't follow this cascade.

## Cross-references

- `docs/specs/065-artifact-budget-discipline/` — spec source for this rule
- `docs/specs/056-pipeline-size-reconciliation/` — empirical calibration discipline for budget *values*; this rule owns the *semantics*
- `docs/specs/002-delegation/` — `# OVERRIDE: <reason ≥10 chars>` grammar lineage
- `.claude/rules/delegation.md` § The 5-field handoff — briefs producing budgeted artifacts inline the cascade in CONSTRAINTS
- `.claude/rules/tdd.md` — `tdd-exempt:` prefix convention precedent for `budget-exempt:`
- `.claude/skills/product/references/pipeline-coverage.md` § Per-step table — the canonical multiplier values
- `.claude/skills/product/references/delegation-briefs.md` — the 15 step briefs that inline this discipline
- `.claude/memory/feedback_speculative_observability.md` — rule-of-three demand-test gating the deferred trim-loop detector hook
