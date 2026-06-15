# Quality judge — `/product` v0.6.0

The quality judge is an independent-context sub-agent dispatched **once per phase, after the phase's producers return** — one batched call grading every judge-unit in the phase against its own rubric, writing one verdict file per unit. It is the replacement for the retired size-budget instrument: it answers *"is this artifact correctly scoped, complete, and coherent for its declared job?"* — the question the KB ceiling was a poor proxy for. Batching (v0.6.0, replacing the v0.5.0 one-call-per-step shape) cuts dispatch overhead — judge calls were ~50% of total run tokens in the 2026-05-23 baseline — and buys the cross-document consistency check a per-step judge structurally cannot make.

This doc is the judge's operational contract: when it runs, how its rubric is assembled, the verdict it returns, how a verdict routes. The judge's 5-field dispatch brief lives in `delegation-briefs.md § quality-judge`; the rubric content lives in `quality-checklist.md`.

## What the judge is

- **Independent context.** A fresh sub-agent per phase-batch — it does not share context with the steps' producers. Generation and evaluation are separate (LLM-as-judge best practice: a producer grading its own work is biased toward its own choices).
- **Model per phase-batch (provisional mix — § Cost & model mix).** Phases 1 + 3 (light artifacts) dispatch on `sonnet`; Phases 2 + 4 (heavy artifacts: system design, legal, cost, the visual contract) dispatch on `opus`. The mix is provisional until a dogfood run confirms detection quality holds (§ Measurement protocol); the all-`opus` revert is one line.
- **Pointwise per unit, chain-of-thought.** Within the batch, the judge grades each judge-unit's artifact-set against that unit's own rubric, reasoning criterion-by-criterion (G-Eval style). It never compares or ranks two artifacts for quality — pointwise grading sidesteps position bias and makes self-preference bias bland. The one cross-unit read it DOES make is consistency: contradictions between the phase's artifacts (a number, date, name, or claim asserted differently in two documents) are reported as a `cross-consistency` criterion on the offending unit's verdict — checking agreement is not ranking.
- **Advisory, never a hard gate.** Its strongest action is to pre-populate a phase gate's `iterate` recommendation (§ Verdict → gate routing). It never autonomously BLOCKs or aborts — deterministic structural BLOCK/abort stays the `schema.md` Layer 1 job.

The step producers' briefs deliberately do **not** mention the judge. The judge evaluates after the fact; telling a producer it will be judged invites writing-to-the-judge bias.

## When the judge runs — and when it is skipped

After a step's producer returns, the orchestrator (`SKILL.md`):

1. **Anti-stub pre-filter.** `wc -c` each artifact against the step's `schema.md § Size floor` `min_size`. If any required artifact is below its floor it is a **stub** — the producer did not try. The orchestrator excludes that judge-unit from the batch (judging a stub wastes judge tokens) and re-dispatches the producer with a brief naming the stubbed artifact; the unit is judged with the next batch or a follow-up call once un-stubbed.
1b. **Craft-floor pre-check (judge-units `02-prototype` + `15b-hifi-mood` only).** The orchestrator runs the deterministic anti-slop check (`scripts/craft-floor-check.ts`) over the unit's HTML artifacts and passes its JSON into the judge brief (`SKILL.md § Quality judge` step 1b). The judge's `craft-floor` criterion (`quality-checklist.md`) reads `summary.active_p0` — `fail` iff `> 0` — rather than re-discovering tells; this keeps deterministic detection out of the LLM grader (mirrors the Layer-1-at-submit boundary). The judge still weighs the two judge-only guidance tells (`references/craft-floor.md`) semantically. No other judge-unit runs this.
2. **Dispatch the batched judge** — ONE `Agent` call for the phase, covering every judge-unit whose artifacts cleared the floor. The brief enumerates the units, each unit's artifact paths + rubric section + verdict path; the judge writes one verdict file per unit (same paths as the per-step shape — the merge path is unchanged).
3. **Record the verdicts** — read each per-unit verdict file into `.state.json` `quality_verdicts` under its own key and route (§ Verdict → gate routing). Per-unit granularity is fully preserved; an `iterate` re-judge re-dispatches a batch containing only the re-run units, overwriting their keys.

The catastrophe cap (200 KB, `artifact-budgets.md`) sits upstream of all this: a runaway producer is circuit-broken mid-flight and emits a partial-result — the judge never receives a 200 KB artifact.

## Judge-units

The judge runs once per **judge-unit**:

- **Steps 01-14** — one judge-unit per step, keyed by step label (`01-ideation` … `14-design-system`).
- **Step 15** — three judge-units, `15a-screen-atlas` / `15b-hifi-mood` / `15c-fixture-spec`, dispatched after their three sub-agents return. They already carry separate gates (`quality-checklist.md § Visual-contract rubric criteria`), so they are judged separately.

## Rubric assembly

For a judge-unit the rubric is **assembled, not authored** authors no new rubric. Three sources:

1. **`quality-checklist.md` per-step criteria** — the gradeable semantic criteria, each with a stable `id`. The judge grades each as a *semantic* read — "is this section substantive and load-bearing", not "does the string exist". Some steps (e.g. 07 Sitemap-IA) have no semantic criterion; their rubric is right-sizing + schema context only.
2. **`schema.md` — as context, not a re-graded checklist.** The judge reads the step's `schema.md` (required sections, `contains`-anchors, `§ Size floor`) and `prompt.md` to know the artifact's required shape and job. The deterministic "does the anchor exist" check is already enforced at submit by `schema.md` Layer 1 — the judge does **not** re-run it. Schema is the judge's *brief*: the source of "what this artifact is for".
3. **The right-sizing criterion** (below) — appended to every judge-unit's rubric.
4. **The cross-consistency criterion** (batch-level) — appended to a unit's verdict ONLY when the batched judge finds a contradiction between that unit's artifact and another artifact in the same phase (a value, date, name, or claim asserted differently in two places). `id: cross-consistency`; the `note` MUST name both artifacts and quote the contradiction. Units with no contradiction simply omit the criterion — absence means clean, not unchecked.

So a verdict's `criteria[]` = the step's `quality-checklist.md` criteria + `right-sizing` (+ `cross-consistency` when a contradiction was found).

## The right-sizing criterion

`id: right-sizing`. Appended to every judge-unit. This is the criterion that replaces the size budget — it judges *scope fit*, not bytes.

> **right-sizing** — Is every section of the artifact pulling weight for the artifact's declared job at *this run's* product scope? Judge against the run's **declared scope** — the `idea`, the invocation flags, and (where the step has it as input) the roadmap's phase count — **not** a fixed size. Return:
> - `pass` — the artifact's depth matches its declared scope. **A correctly-scoped large artifact for a large declared product is a `pass`.**
> - `concern` / `fail` — a section covers detail the job does not require (genuine **bloat** — name the section and why it is surplus), OR a section is too thin to do its job (**under-developed** — name the gap).
>
> **Do not reward length.** A longer artifact is not a better artifact. A padded artifact for a small product is a `fail`; a lean artifact that fully covers a small product is a `pass`. The `note` MUST name the specific section and dimension — never just "too long" or "too short".

The "do not reward length" line is the verbosity-bias mitigation: an ungoverned LLM judge tends to score longer outputs higher. The criterion is scope-aware *by construction* — it has no constant to compare against, only the run's declared scope — which is exactly why it cannot rot the way the fixed KB ceiling did.

## The verdict

The judge returns one verdict object per judge-unit:

```json
{
  "step": "08-system-design",
  "judged_at": "2026-05-22T16:40:00Z",
  "model": "opus",
  "criteria": [
    { "id": "structure",    "verdict": "pass",    "note": "all 8 required H2 present incl RACI + Risk Register" },
    { "id": "security-doc", "verdict": "pass",    "note": "security.md present and substantive" },
    { "id": "data-flow",    "verdict": "pass",    "note": "data-flow.json valid, 5 flows" },
    { "id": "right-sizing", "verdict": "concern", "note": "§ Risk Register restates the security.md threat model — ~2 KB duplication" }
  ],
  "scope_assessment": "Correctly scoped for a full multi-phase ERP; the lone concern is internal duplication, not over-scope.",
  "outcome": "concern"
}
```

| Field | Meaning |
|---|---|
| `step` | judge-unit label (`01-ideation` … `15c-fixture-spec`) |
| `judged_at` | UTC ISO-8601 |
| `model` | judge model actually used — per the phase-batch mix (§ Cost & model mix): `sonnet` for Phases 1/3, `opus` for Phases 2/4. The per-verdict record is the measurement surface for the mix. |
| `criteria[]` | one row per assembled rubric criterion — `id` + `verdict` ∈ `pass`/`concern`/`fail` + a one-line `note`. On `concern`/`fail` the `note` MUST name the section + dimension (the actionable signal). |
| `scope_assessment` | top-level one-line whole-artifact scope headline — lands in `REPORT.md § Quality concerns` and the gate summary |
| `outcome` | max-severity rollup: `fail` if any criterion `fail`, else `concern` if any `concern`, else `pass` |

A judge `fail` is **not** a BLOCKED. BLOCKED is deterministic — DELIVERABLE not met, or the producer explicitly couldn't proceed (`state-machine.md § Failure handling`). A judge `fail` means the artifact is *present and DELIVERABLE-complete* but quality-deficient. The two tracks are orthogonal: a step in `completed_steps` can carry a `fail` verdict; that does NOT move it to `blocked_steps`. `completed_steps` / `blocked_steps` / `quality_verdicts` are three independent records.

## Verdict → gate routing

Routing is a **global rule**, tied to the `state-machine.md` phase→gate progression — not per-step opt-in.

- **`outcome: pass`** — recorded to `quality_verdicts`. No further action.
- **`outcome: concern`** — *advisory*. Recorded; surfaced in `REPORT.md § Quality concerns`. No gate action — a `concern` is a note for the human, not a recommendation to iterate.
- **`outcome: fail`** — *gate-flag*. Recorded; surfaced in `REPORT.md § Quality concerns`; AND routed to the phase's downstream gate:

| Phase | Steps | Gate | A `fail` here … |
|---|---|---|---|
| 1 discovery | 01-04 | `gate_discovery` | pre-populates the gate's recommended option as **`iterate`**, citing the failed step + criterion |
| 2 specification | 05-12 | `gate_specification` | same |
| 3 identity | 13-14 | `gate_identity` | same |
| 4 visual-contract | 15a/15b/15c | *(no gate)* | surfaced in the terminal handoff message + `REPORT.md § Quality concerns` |

At a phase gate the orchestrator collects every `quality_verdicts` entry for that phase's steps. If any has `outcome: fail`, the `AskUserQuestion` gate's **recommended** option is `iterate`, pre-filled with the failed steps and their failed criteria; the human still chooses `continue` / `iterate` / `abort` — the judge never decides (`state-machine.md § Gate UX`). If none failed, the recommended option stays `continue`. The existing iteration soft-cap (`state-machine.md § Gate UX` — warn at `iterations.<phase> >= 3`, force-abort at `>= 5`) still applies: a judge that keeps flagging `fail` cannot drive an infinite iterate loop.

Phase 4 (step 15) has no gate — a `15a/15b/15c` `fail` cannot pre-populate anything, so it surfaces in the Phase 5 terminal handoff message and the `REPORT.md § Quality concerns` section, where the human sees it before acting on the SDD handoff.

## What the judge never does

- **Never autonomously BLOCKs or aborts.** Its ceiling is the gate `iterate` recommendation. Deterministic structural BLOCK/abort is `schema.md` Layer 1's job; run-aborting on a Step 01 / 15a block is the orchestrator's (`state-machine.md § Failure handling`).
- **Never grades size in bytes.** `min_size` is the `wc -c` anti-stub pre-filter; the 200 KB catastrophe cap is a runaway circuit-breaker. The judge grades scope fit (`right-sizing`), never byte count.
- **Never authors rubric.** It grades the assembled rubric (§ Rubric assembly). If a step's rubric feels wrong, fix `quality-checklist.md` / `schema.md` — not the judge.

## Cost & model mix

The 2026-05-23 baseline measured 17 per-step `opus` judge calls at ~1.6M of ~3.1M total run tokens (~50% of spend) for 8 pass / 9 concern / 0 fail — a high price for verdicts that changed nothing that run. v0.6.0 attacks the cost on two axes:

1. **Batching** — 4 judge calls per full run (one per phase) instead of 17. Dispatch overhead and repeated rubric/context preamble collapse; the cross-consistency check comes free.
2. **Model mix (PROVISIONAL — adoption pending § Measurement protocol):**

| Phase batch | Judge-units | Model | Rationale |
|---|---|---|---|
| Phase 1 — discovery | 01-04 | `sonnet` | short, structurally simple artifacts |
| Phase 2 — specification | 05-12 | `opus` | the heavy reasoning surface (system design, legal, cost) |
| Phase 3 — identity | 13-14 | `sonnet` | brand/design checks are mostly coherence reads |
| Phase 4 — visual contract | 15a/15b/15c | `opus` | the contract the SDD build runs against |

## Measurement protocol (the mix is provisional)

The mix adopts permanently only if detection quality holds. On the next full dogfood run:

1. Run with the mix above; every verdict records `model` (the recording surface — no new field needed).
2. **Detection bar:** the `sonnet`-judged batches must still catch real semantic inconsistencies of the class the baseline validated — the fixture-spec "Persona streak=17 vs derivation streak=8" internal-contradiction catch. Plant-or-find: if the run surfaces no natural inconsistency in a sonnet-judged phase, compare its notes' specificity against the baseline's opus notes for the same steps (vague "looks fine" notes = complacency signal).
3. **Verdict:** detection holds → keep the mix, record the run in `.agent0/memory/product-pipeline-empirical-baseline.md`. Detection degrades → revert that phase batch to `opus` (one line in the table above) or re-split; record why.

Until the protocol runs, treat the mix as a hypothesis carried by this contract, not a validated saving.

## Cross-references

- `quality-checklist.md` — the per-step semantic rubric criteria the judge grades
- `delegation-briefs.md § quality-judge` — the judge sub-agent's 5-field dispatch brief
- `state-machine.md` — `.state.json` `quality_verdicts`, the phase→gate progression the routing feeds, `§ Gate UX`, `§ Failure handling`
- `templates/pipeline/<NN-step>/schema.md` — the per-step structural context + `§ Size floor` `min_size`
- `.agent0/context/rules/artifact-budgets.md` — the retired size budget + the 200 KB catastrophe cap
- `templates/report.md.tmpl § Quality concerns` — where `concern` / `fail` verdicts surface
