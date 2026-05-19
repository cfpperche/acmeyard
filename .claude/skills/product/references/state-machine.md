# State machine — `/product` v0.3.0 (`.state.json` v4)

Defines `.state.json` shape, phase/step progression, gate semantics, and resume support via `--from-step=NN`. Spec source: `docs/specs/048-product-skill-foundation/` (v0.3.0, state v4) — supersedes spec 045 (v0.2.0, state v3). v2 + v3 shapes preserved for compatibility detection (orchestrator aborts cleanly when older state file found, rather than silently corrupting it).

## `.state.json` shape (v4)

Written at `<out-dir>/docs/.state.json`. Initialized by Phase 0, updated at each step boundary, finalized at Phase 4 close.

```json
{
  "version": 4,
  "slug": "erp-saloes-beleza",
  "idea": "ERP para salões de beleza",
  "flags": {
    "stack": "next",
    "out": "/tmp/dogfood-erp",
    "from_step": null,
    "skip_brand": false,
    "skip_prd": false
  },
  "phase": "specification",
  "step": 9,
  "step_label": "09-legal",
  "started_at": "2026-05-18T14:30:00Z",
  "gates_passed": ["discovery"],
  "completed_steps": [
    "01-ideation",
    "02-prototype",
    "03-spec",
    "04-ux-testing",
    "05-prd",
    "06-ost",
    "07-sitemap-ia",
    "08-system-design"
  ],
  "blocked_steps": [],
  "iterations": {
    "discovery": 0,
    "specification": 0,
    "identity": 0
  },
  "completed_at": null
}
```

Field semantics:

- **`version`** — schema version of `.state.json` itself. Current: `4`. Increments when shape changes.
  - v1 (spec 034) — single `phase` int 0-5, no step tracking.
  - v2 (spec 036) — 13-step tracking, `phase` int 0-5, `iterations` keyed by `discovery`/`identity`/`specification`.
  - v3 (spec 045) — 15-step tracking, `phase` string enum, NN-flat artifact paths under `docs/`.
  - v4 (spec 048) — same 15-step pipeline as v3; artifact paths refactored to semantic-named (no `NN-` prefix); PRD release-scoped via `docs/prd/v1.md`; design system grouped at `docs/design-system/`; `step_label` enum unchanged from v3 (`06-ost`, `07-sitemap-ia`, etc. — these are STEP names, not artifact names).
- **`slug`** — kebab-case product slug derived from `idea`. Computed once at Phase 0; immutable thereafter.
- **`idea`** — verbatim user input from `/product "<idea>"`. Immutable.
- **`flags`** — captured from invocation; `out` is required, others default. Immutable post-Phase 0 except `from_step` (cleared after resume completes).
- **`phase`** — current phase as string enum. One of `discovery | specification | identity | visual-contract`. Updated at phase boundary.
- **`step`** — current step number, int 1-15 (or 0 during Phase 0 setup).
- **`step_label`** — human-readable step name matching bundled template dir name (e.g. `09-legal`, `12-gtm-launch`, `15-screen-atlas`).
- **`started_at`** — UTC ISO-8601 timestamp from Phase 0.
- **`gates_passed`** — list of phase names with `continue` choice at gate. Order matters (cannot be in `specification` if `discovery` not first). Valid values: `discovery`, `specification`, `identity`.
- **`completed_steps`** — list of step labels that finished cleanly. Append-only.
- **`blocked_steps`** — list of objects `{step_label, reason, artifacts_partial?}` for steps that returned BLOCKED. Empty list when no blocks.
- **`iterations`** — count of `iterate` gate-pass choices per phase. Each `iterate` increments; `continue` does not. Used to cap runaway iteration (soft cap = 3 per phase; warn at 3, soft-abort at 5).
- **`completed_at`** — UTC ISO-8601 set when Phase 4 closes successfully. Null otherwise.

## Phase progression (v3)

```
Phase 0 (setup) → step 0
  ↓
Phase 1 (discovery) → steps 01-04
  steps 01 (blocking, opus) → 02 alone → 03+04 parallel
  ↓
  gate_discovery [AskUserQuestion: continue / iterate / abort]
    continue → Phase 2
    iterate  → re-dispatch failing step(s) within Phase 1, then re-gate
    abort    → exit; .state.json preserved for later resume
  ↓
Phase 2 (specification) → steps 05-12
  steps 05 (blocking, PRD) → 06+07 parallel (OST + sitemap-IA)
    → schema enforcement on docs/sitemap.yaml (BLOCK if required_categories not covered)
    → 08 (system-design + data-flow) → 09 (legal + DPIA from data-flow)
    → 10 (roadmap defines phases) → 11+12 parallel (cost + GTM)
  ↓
  gate_specification [AskUserQuestion: continue / iterate / abort]
  ↓
Phase 3 (identity) → steps 13-14
  steps 13 (brand) → 14 (design-system, depends on brand) — strict serial
  ↓
  gate_identity [AskUserQuestion: continue / iterate / abort]
  ↓
Phase 4 (visual-contract) → step 15
  step 15 atlas-writer + per-route screen-writers (parallel cap=5)
    + stitch step (token import verify) + build verification
  ↓
  Phase 5 (handoff message)
  ↓
  completed_at set
```

Phase 0 has no gate (idempotency check is local). Phase 4 has no gate (final synthesis; `/sdd new` handoff is the implicit "next" gate). Note phase ORDER CHANGED vs v2: Specification (was Phase 3 in v2) is now Phase 2 (PRD-first per spec 045 Decision 3); Identity (was Phase 2) is now Phase 3.

## Step ordering within Phase 2 — Specification (most complex)

Phase 2's 8 steps follow a DAG (not strictly serial, not fully parallel):

```
05 PRD (blocking)
  ├──────► 06 OST   ┐
  └──────► 07 sitemap-IA   ┘ ──► 08 system-design ──► 09 legal
                                       │                  │
                                       ▼                  ▼
                                  10 roadmap     11 cost + 12 GTM (parallel)
```

Dispatch sequence (orchestrator follows literally):
1. Step 05 alone (blocking; downstream depends on US-NN)
2. Steps 06+07 parallel (both consume Step 05's PRD)
3. **Step 07 schema enforcement check** (orchestrator parses sitemap.yaml; BLOCK Step 07 + re-dispatch if `required_categories` not covered without `deferred_categories` declaration)
4. Step 08 alone (needs Step 07 sitemap routes for system-design integration list)
5. Step 09 alone (needs Step 08 data-flow inventory for DPIA trigger)
6. Step 10 alone (defines phases for cost calculation)
7. Steps 11+12 parallel (cost reads Step 09 legal budget + Step 10 roadmap; GTM reads Step 09 + Step 10)

## Gate UX

At end of Phase 1, 2, 3:

1. Skill prints a per-phase summary: artifacts produced (file paths + sizes), blocked steps if any, iteration count if any.
2. Skill invokes `AskUserQuestion` with 3 options:
   - **`continue`** → next phase. Appends phase name to `gates_passed`.
   - **`iterate`** → user names which step(s) to re-dispatch (sub-prompt). Re-dispatches with augmented brief. Increments `iterations.<phase>` counter. Re-prompts gate after re-dispatch.
   - **`abort`** → exit cleanly. Sets `flags.from_step` = current step for resume hint. Prints `Run /product "<idea>" --from-step=<NN> --out=<same-path>` to resume.

Iteration soft cap: warn at `iterations.<phase> >= 3`, force-abort at `>= 5`. Prevents infinite loops.

## Resume via `--from-step=NN`

```bash
/product "ERP para salões de beleza" --from-step=09 --out=/tmp/dogfood-erp
```

Behavior:

1. Phase 0 reads `.state.json` from `<out-dir>/docs/`.
2. **Validates `version`** — must be `4`. If `version == 3` (pre-spec-048 from spec 045 run), abort with `state v3 found — pre-spec-048 run; clear --out dir or run fresh /product`. If `version < 3` (v1 or v2 from older runs), abort with `state v<N> found — pre-spec-045 run; clear --out dir or run fresh /product`. Conservative: refuse to silently upgrade an older state file, because (1) v3→v4 changes artifact paths (NN-prefix dropped); (2) v2→v3 changed step numbering (v2's `08-prd` is v3's `05-prd`).
3. Validates: `slug` matches argument-derived slug; `idea` matches verbatim (case-sensitive); `flags.stack` matches; if mismatch, abort with `state mismatch — clear --out dir or pick different --from-step`.
4. Jumps to step NN. All `completed_steps` entries with step number < NN remain trusted (artifacts on disk are used as inputs to downstream).
5. Continues from there through remaining steps + phases.
6. On clean completion, `flags.from_step` set back to `null` for next invocation.

**Edge case:** `--from-step=NN` where NN is past the user's actual progress. Skill detects (NN > current `step` value), warns, falls back to `step = current` (the actual current step, not requested).

## Failure handling

Sub-agent dispatch returns BLOCKED (DELIVERABLE not met OR sub-agent explicit can't-do):

- **Step 01 (concept brief) or Step 15 (screen-atlas) blocks** → ABORT the run. These steps are upstream-of-everything (01) or final-deliverable (15); continuing without them produces incomplete artifacts the rest of the pipeline can't reason about.
- **Step 07 (sitemap-IA) blocks via schema-enforcement** → AUTO-RETRY with augmented brief naming the uncovered category(ies). Up to 2 retries before falling through to user `iterate` choice at Phase 2 gate.
- **Any other step blocks** → degrade gracefully:
  - Append `{step_label, reason, artifacts_partial: <list>}` to `blocked_steps`.
  - Log to REPORT.md `## Blocked steps` section.
  - Continue to next step. Downstream steps that depend on this one note the gap.

## Output dir collision

Phase 0 checks if `<out-dir>` exists and is non-empty (any file present):

```
<out-dir> exists and is non-empty. Overwrite? (y/N) ▷
```

- `y` → `rm -r <out-dir>` (NOT `rm -rf` — governance-gate blocks combined flags); then `mkdir -p <out-dir>/docs/screens` + init `<out-dir>/docs/.state.json`.
- `n` / no answer / anything else → abort with `aborted; pick a different --out or rm the existing dir yourself`. Exit 0.

No `--force` flag; the prompt is the gate.

## Migration from v2 (spec 036) to v3 (spec 045)

The shape change is breaking:
- `phase` int → string enum
- step numbering shift (8 vs 5 for PRD; 13 vs 15 for atlas; new steps 06/07/12; deleted step 7)
- `iterations` keys reordered

No automatic migration. Founders with in-flight v2 prototypes must complete those runs before upgrading the skill (or accept rm + restart). New runs after upgrade always start at v3.

## Cross-references

- `pipeline-coverage.md` — what each step produces at standard tier
- `delegation-briefs.md` — sub-agent dispatch shape per step
- `quality-checklist.md` — per-step gate criteria
- `sitemap-schema.md` — Step 07's required_categories binding
- `SKILL.md` — orchestration body that operates this state machine
- `.claude/rules/delegation.md` — 5-field handoff discipline
- `docs/specs/045-prototype-skill-pipeline-realign/` — spec source
