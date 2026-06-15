# State machine — `/product` v0.6.0 (`.state.json` v6)

Defines `.state.json` shape, phase/step progression, gate semantics, and resume support via `--from-step=NN`. Current shape is v6 (v0.6.0). v2 / v3 / v4 / v5 shapes are preserved for compatibility detection (orchestrator aborts cleanly when an older state file is found, rather than silently corrupting it).

## `.state.json` shape (v6)

Written at `<out-dir>/docs/.state.json`. Initialized by Phase 0, updated at each step boundary, finalized at Phase 5 close.

```json
{
  "version": 6,
  "slug": "erp-saloes-beleza",
  "idea": "ERP para salões de beleza",
  "flags": {
    "stack": "next",
    "out": "/tmp/dogfood-erp",
    "from_step": null,
    "skip_brand": false,
    "skip_prd": false
  },
  "product_form": "screen-app",
  "phase": "specification",
  "step": 9,
  "step_label": "09-legal",
  "started_at": "2026-05-18T14:30:00Z",
  "gates_passed": ["concept", "discovery"],
  "completed_steps": [
    "01-ideation",
    "02-prototype",
    "03-spec",
    "04-validation",
    "05-prd",
    "06-ost",
    "07-sitemap-ia",
    "08-system-design"
  ],
  "blocked_steps": [],
  "iterations": {
    "concept": 0,
    "discovery": 0,
    "specification": 0,
    "identity": 0
  },
  "quality_verdicts": {
    "01-ideation": {
      "step": "01-ideation", "judged_at": "2026-05-18T14:35:00Z", "model": "opus",
      "criteria": [
        { "id": "structure", "verdict": "pass", "note": "9 H2 incl § Market Sizing" },
        { "id": "right-sizing", "verdict": "pass", "note": "depth matches the declared MVP scope" }
      ],
      "scope_assessment": "Correctly scoped for the declared MVP.", "outcome": "pass"
    }
  },
  "completed_at": null
}
```

Field semantics:

- **`version`** — schema version of `.state.json` itself. Current: `6`. Increments when a resume across the change would **mis-orchestrate** — a behavioral phase/step break, or a non-back-compatible field change. A purely additive field that an older reader can ignore and a newer reader can treat as absent does NOT bump: `quality_verdicts` was added and the schema stayed v5, because the resume gate trusts `completed_steps`, never the verdicts, so there is no mis-orchestration risk. The version-history below records past bumps — each was a mis-orchestration break, not a mere field touch.
  - v1 — single `phase` int 0-5, no step tracking.
  - v2 — 13-step tracking, `phase` int 0-5, `iterations` keyed by `discovery`/`identity`/`specification`.
  - v3 — 15-step tracking, `phase` string enum, NN-flat artifact paths under `docs/`.
  - v4 — same 15-step pipeline as v3; artifact paths refactored to semantic-named (no `NN-` prefix); PRD release-scoped via `docs/prd/v1.md`; design system grouped at `docs/design-system/`.
  - v5 — same 15-step pipeline; Phase 4 reshaped (no per-route screen-writer fan-out — Step 15 is atlas + hi-fi mood + fixture-spec); Phase 5 is now the mandatory SDD handoff; `phase` enum gains `sdd-handoff`. The v4→v5 break is behavioral (Phase 4/5 produce different artifacts), not a field-shape change — but resume across the break would mis-orchestrate, so v4 is refused.
  - v6 — same 15-step pipeline; Phase 1 gains the **concept gate** (`gate_concept`, after Step 01), so `gates_passed` gains `concept` (ordered first) and `iterations` gains `concept`; new `product_form` field (set after Step 01; drives Step 02/07/14/15 form variants per `product-forms.md`); quality judge dispatches per phase-batch instead of per step. The v5→v6 break is behavioral (gate order + judge dispatch), so v5 is refused at resume.
- **`slug`** — kebab-case product slug derived from `idea`. Computed once at Phase 0; immutable thereafter.
- **`idea`** — verbatim user input from `/product "<idea>"`. Immutable.
- **`flags`** — captured from invocation; `out` is required, others default. Immutable post-Phase 0 except `from_step` (cleared after resume completes).
- **`phase`** — current phase as string enum. One of `discovery | specification | identity | visual-contract | sdd-handoff`. Updated at phase boundary. `sdd-handoff` is Phase 5 — set when the run scaffolds the umbrella + foundation child; `step` stays `15` through it (Phase 5 has no step number).
- **`step`** — current step number, int 1-15 (or 0 during Phase 0 setup). Stays `15` during Phase 5.
- **`step_label`** — human-readable step name matching bundled template dir name (e.g. `09-legal`, `12-gtm-launch`, `15-screen-atlas`).
- **`started_at`** — UTC ISO-8601 timestamp from Phase 0.
- **`product_form`** — the product's declared form factor, mirrored from the concept brief's `§ Product Form` after Step 01 returns. One of `screen-app | headless-service | cli | bot | embedded` (see `product-forms.md`). `null` at Phase 0 init; immutable once set (a different form means a different product — fresh run). Downstream form-variant surfaces (Step 02 mood, Step 07 category set, Step 14 scope, Phase 4 contract) read this value at dispatch time.
- **`gates_passed`** — list of phase names with `continue` choice at gate. Order matters (cannot be in `specification` if `discovery` not first). Valid values, in order: `concept`, `discovery`, `specification`, `identity`. `concept` is the mid-Phase-1 kill-gate after Step 01 — the cheapest redirect point.
- **`completed_steps`** — list of step labels that finished cleanly. Append-only.
- **`blocked_steps`** — list of objects `{step_label, reason, artifacts_partial?}` for steps that returned BLOCKED. Empty list when no blocks.
- **`iterations`** — count of `iterate` gate-pass choices per gate (`concept` counts Step 01 re-dispatches from the concept gate's `adjust` choice). Each `iterate`/`adjust` increments; `continue` does not. Used to cap runaway iteration (soft cap = 3 per gate; warn at 3, soft-abort at 5).
- **`quality_verdicts`** — map keyed by judge-unit label (`01-ideation` … `15c-fixture-spec`) → the quality judge's verdict object for that step. Each verdict carries `step` / `judged_at` / `model` / `criteria[]` (per-criterion `pass`/`concern`/`fail` + one-line `note`) / `scope_assessment` / `outcome` (the max-severity rollup `fail` > `concern` > `pass`). A map, not a list — a re-judged step (gate `iterate`) overwrites its key; a missing key = not yet judged. Initialized `{}` by Phase 0. **Additive in v5** — see `version` above. Full verdict shape + the verdict→gate routing: `quality-judge.md`.
- **`completed_at`** — UTC ISO-8601 set when Phase 5 (the SDD handoff) closes successfully. Null otherwise.

## Phase progression (v6)

```
Phase 0 (setup) → step 0
  ↓
Phase 1 (discovery) → steps 01-04
  step 01 (blocking, opus) → product_form captured to .state.json
  ↓
  gate_concept [AskUserQuestion: continue / adjust / abort]
    continue → Step 02
    adjust   → re-dispatch Step 01 with the user's correction; re-gate
    abort    → exit; .state.json preserved for later resume
  ↓
  steps 02 alone → 03 alone → 04 alone
    (Steps 03 and 04 are NOT parallel — Step 04 reads functional-spec.md,
     Step 03's deliverable)
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
Phase 4 (visual-contract) → step 15 (two waves)
  wave A: 15a atlas-writer + 15c fixture-spec writer
    — dispatched in parallel (one message); no shared input, distinct outputs
  wave B: 15b hi-fi mood-writers (cap=5) — after 15c returns
    — hi-fi Mood-screen-writer reads fixture-spec.md (15c's deliverable),
      so 15b CANNOT share a message with 15c
  NO per-route fan-out, NO app/ tree, NO build verification
  + best-effort agent-browser visual check + author REPORT.md
  ↓
Phase 5 (sdd-handoff)
  scaffold docs/specs/001-<slug>/ (umbrella) + docs/specs/002-foundation/ (child #1)
  print handoff message
  ↓
  completed_at set
```

**Quality judge.** After each phase's steps complete — and before the phase gate — the orchestrator runs the quality judge over that phase's steps as **one batched dispatch per phase** (`SKILL.md § Quality judge`; per-unit verdict granularity is preserved — the batch writes one verdict file per judge-unit). Verdicts land in `.state.json` `quality_verdicts`. A `fail` verdict pre-sets the phase gate's recommended option to `iterate`; Phase 4 (no gate) surfaces a `fail` in the terminal handoff + `REPORT.md § Quality concerns`. The judge never autonomously BLOCKs or aborts — see `quality-judge.md`.

Phase 0 has no gate (idempotency check is local). The concept gate (`gate_concept`) sits mid-Phase-1, immediately after Step 01 and before any judge run — it gates on the founder's own read of the concept brief, not on a verdict. Phase 4 + Phase 5 have no gate (Phase 5's SDD-spec scaffold is the terminal handoff). Note phase ORDER vs v2: Specification (was Phase 3 in v2) is Phase 2 (PRD-first); Identity (was Phase 2) is Phase 3.

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

**Concept gate (mid-Phase-1, after Step 01):** one lightweight `AskUserQuestion` — "Did the concept brief capture your idea?" — with `continue` / `adjust` (re-dispatch Step 01 with the user's correction; increments `iterations.concept`) / `abort`. No judge verdict feeds it (the judge has not run yet); the founder's own read of `docs/concept-brief.md` is the input. Appends `concept` to `gates_passed` on `continue`.

At end of Phase 1, 2, 3:

1. Skill prints a per-phase summary: artifacts produced (file paths + sizes), blocked steps if any, iteration count if any.
1b. **Review agenda** — before the question, the skill distills the 3-5 decisions actually worth the human's attention this phase: load-bearing choices the artifacts made (e.g. pricing model, deferred categories, stack pins) + every judge `concern`/`fail` note. Assembled from already-generated material (artifact contents + `quality_verdicts`); the REPORT.html link remains for deep review. The agenda is presentation only — it never blocks, and `continue` without reading remains possible.
2. Skill invokes `AskUserQuestion` with 3 options:
   - **`continue`** → next phase. Appends phase name to `gates_passed`.
   - **`iterate`** → user names which step(s) to re-dispatch (sub-prompt). Re-dispatches with augmented brief. Increments `iterations.<phase>` counter. Re-prompts gate after re-dispatch.
   - **`abort`** → exit cleanly. Sets `flags.from_step` = current step for resume hint. Prints `Run /product "<idea>" --from-step=<NN> --out=<same-path>` to resume.

**Quality-judge pre-set:** if any of the phase's `quality_verdicts` has `outcome: "fail"`, the gate's recommended option is `iterate`, pre-filled with the failed steps + their failed criteria — the human still chooses. See `quality-judge.md § Verdict → gate routing`.

Iteration soft cap: warn at `iterations.<phase> >= 3`, force-abort at `>= 5`. Prevents infinite loops.

## Resume via `--from-step=NN`

```bash
/product "ERP para salões de beleza" --from-step=09 --out=/tmp/dogfood-erp
```

Behavior:

1. Phase 0 reads `.state.json` from `<out-dir>/docs/`.
2. **Validates `version`** — must be `6`. If `version == 5`, abort with `state v5 found — older /product run; clear --out dir or run fresh /product`. If `version == 4`, abort with `state v4 found — older /product run; clear --out dir or run fresh /product`. If `version == 3`, abort with `state v3 found — older /product run; clear --out dir or run fresh /product`. If `version < 3` (v1 or v2), abort with `state v<N> found — older /product run; clear --out dir or run fresh /product`. Conservative: refuse to silently upgrade an older state file, because (1) v5→v6 adds the concept gate + form-variant dispatch (a v5 resume would mis-track gates/iterations); (2) v4→v5 reshapes Phase 4/5 (a v4 resume into Phase 4 would expect the deleted screen-writer fan-out); (3) v3→v4 changed artifact paths (NN-prefix dropped); (4) v2→v3 changed step numbering.
3. Validates: `slug` matches argument-derived slug; `idea` matches verbatim (case-sensitive); `flags.stack` matches; if mismatch, abort with `state mismatch — clear --out dir or pick different --from-step`.
4. Jumps to step NN. All `completed_steps` entries with step number < NN remain trusted (artifacts on disk are used as inputs to downstream).
5. Continues from there through remaining steps + phases.
6. On clean completion, `flags.from_step` set back to `null` for next invocation.

**Edge case:** `--from-step=NN` where NN is past the user's actual progress. Skill detects (NN > current `step` value), warns, falls back to `step = current` (the actual current step, not requested).

## Failure handling

Sub-agent dispatch returns BLOCKED (DELIVERABLE not met OR sub-agent explicit can't-do):

- **Step 01 (concept brief) or Step 15a (screen-atlas) blocks** → ABORT the run. Step 01 is upstream-of-everything; Step 15a IS the visual contract — Phase 5's SDD handoff has nothing to hand off without it. Step 15b (hi-fi mood) or 15c (fixture-spec) blocking does NOT abort — those degrade gracefully (the atlas alone is a usable contract; a missing hi-fi mood or fixture-spec is a documented gap, logged to `blocked_steps` + REPORT.md, and Phase 5 still runs).
- **Step 07 (sitemap-IA) blocks via schema-enforcement** → AUTO-RETRY with augmented brief naming the uncovered category(ies). Up to 2 retries before falling through to user `iterate` choice at Phase 2 gate.
- **Any other step blocks** → degrade gracefully:
  - Append `{step_label, reason, artifacts_partial: <list>}` to `blocked_steps`.
  - Log to REPORT.md `## Blocked steps` section.
  - Continue to next step. Downstream steps that depend on this one note the gap.

**Quality-judge `fail` is not BLOCKED.** A judge `fail` means the artifact is present and DELIVERABLE-complete but quality-deficient — the step stays in `completed_steps`, not `blocked_steps`. It routes to the phase gate's `iterate` recommendation, never to a BLOCK or abort. `completed_steps` / `blocked_steps` / `quality_verdicts` are three independent records. See `quality-judge.md`.

## Output dir collision

Phase 0 checks if `<out-dir>` exists and is non-empty (any file present):

```
<out-dir> exists and is non-empty. Overwrite? (y/N) ▷
```

- `y` → `rm -r <out-dir>` (NOT `rm -rf` — governance-gate blocks combined flags); then `mkdir -p <out-dir>/docs/screens/hifi <out-dir>/docs/prd <out-dir>/docs/design-system <out-dir>/docs/specs` + init `<out-dir>/docs/.state.json`.
- `n` / no answer / anything else → abort with `aborted; pick a different --out or rm the existing dir yourself`. Exit 0.

No `--force` flag; the prompt is the gate.

## Migration to v6

The v5→v6 change is breaking at the behavioral level: Phase 1 gains the concept gate (`gates_passed`/`iterations` gain `concept`), Step 01 now writes `product_form` that downstream form-variant surfaces read, and the quality judge dispatches per phase-batch. A v5 state file resumed under v6 would mis-track gate order and lack `product_form`, so v5 is refused at resume (as v4 was before it — the v4→v5 break reshaped Phase 4/5).

No automatic migration. Founders with an in-flight v5 (or older) run must complete it on the prior skill version, or `rm -r <out>` and restart. New runs after the upgrade always start at v6.

## Cross-references

- `pipeline-coverage.md` — what each step produces at standard tier
- `delegation-briefs.md` — sub-agent dispatch shape per step (Step 15 = 15a/15b/15c)
- `sdd-handoff.md` — the Phase 5 umbrella + foundation-child scaffold contract
- `quality-checklist.md` — the quality judge's semantic rubric (per-step + visual-contract criteria) + the deterministic orchestrator gates
- `quality-judge.md` — the quality judge: when it runs, rubric assembly, the verdict shape, the verdict→gate routing
- `sitemap-schema.md` — Step 07's required_categories binding
- `product-forms.md` — the form-factor taxonomy + per-form variant surfaces (`product_form` consumer map)
- `SKILL.md` — orchestration body that operates this state machine
- `.agent0/context/rules/delegation.md` — 5-field handoff discipline
