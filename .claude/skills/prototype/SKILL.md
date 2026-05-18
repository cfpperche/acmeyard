---
name: prototype
description: Agile frontend to the 15-step industry-aligned product pipeline. Covers all planning steps (ideation / spec / UX audit / PRD-1pager / OST / sitemap-IA / system design / legal / roadmap / cost / GTM-launch / brand / design system) PLUS 2 prototype passes (lo-fi mood + hi-fi screen-atlas absorbing brand+tokens) in fluid agile mode at "standard" tier. Output is a monorepo at user-specified path with all 15 artifacts under `<out>/docs/NN-*`. 4 phases - Discovery / Specification / Identity / Visual-contract - with 3 AskUserQuestion gates after steps 4 / 12 / 14. Standalone (no MCP dep, templates bundled). Flags - `<idea>` `--stack=<next|expo>` `--out=<path>` `--from-step=NN` `--skip-prd` `--skip-brand`. See `references/{pipeline-coverage,state-machine,delegation-briefs,quality-checklist}.md`. v3 per spec 045 (industry-realign — sitemap-IA + legal-shift-left + PRD-1pager + GTM + OST + collapsed prototype passes). Supersedes spec 036's v2.
license: MIT
compatibility: Designed for Claude Code. Body references `.claude/` conventional paths, dispatches Agent tool with 5-field handoffs (delegation-gate), uses AskUserQuestion at phase gates, optionally uses Playwright MCP for screenshots. Not portable to runtimes that lack these surfaces.
metadata:
  agent0-portability-tier: cc-native
  skill-version: "0.2.0"
argument-hint: "<idea>" --out=<path> [--stack=<next|expo>] [--from-step=NN] [--skip-prd] [--skip-brand]
---

# /prototype — 15-step agile industry-aligned pipeline

Takes a founder's one-line idea and produces a complete v1-ready product package at `<--out>`: concept brief (with market sizing) → lo-fi prototype (mood + killer flow) → functional spec (with problem-validation interviews) → UX audit → PRD 1-pager → OST (Opportunity Solution Tree) → sitemap-IA (full screen inventory with required_categories enforcement) → system design (with RACI + risk + data-flow inventory) → legal posture (DPIA-triggered by data-flow, NOT end-of-pipeline) → roadmap (defines phases) → cost estimate (per-phase using roadmap) → GTM-launch → brand book → design system → hi-fi screen-atlas (absorbs brand+tokens, full PRD coverage). 4 fluid phases with 3 condensed user gates instead of the heavy pipeline's 3 Layer-3 checkpoints.

**v3 — spec 045 industry-realign** — see `docs/specs/045-prototype-skill-pipeline-realign/` for the design + 17 decisions ported from spec 032 (PRD-first ordering, legal shift-left, sitemap-IA root-cause fix for atlas under-coverage, 3-prototype collapsed to 2, GTM step added, cost↔roadmap swap). v2 (spec 036, 13-step shape) is superseded.

**Required reading before execution:**
- `references/pipeline-coverage.md` — what each of the 15 steps produces at standard tier
- `references/state-machine.md` — `.state.json` v3 shape + 4-phase progression + resume support
- `references/delegation-briefs.md` — 5-field briefs for all 16 sub-agent dispatches (15 step-specific + 1 per-stack screen-writer)
- `references/quality-checklist.md` — per-step gate criteria the skill checks before declaring a step complete
- `references/sitemap-schema.md` — `required_categories` enforcement + per-route field set (load-bearing — orchestrator BLOCKS Step 07 if uncovered category found without `deferred_categories` declaration)

## Argument parsing

User invokes as `/prototype "<idea>" --out=<path> [flags]`. The raw argument string is `$ARGUMENTS`. Parse it yourself:

1. First quoted-token is `<idea>` — refuse with `usage: /prototype "<idea>" --out=<path> [flags]` if missing.
2. `--out=<path>` is REQUIRED — refuse if missing. Resolve to absolute path.
3. Optional flags (any order after idea): `--stack=<name>` (next | expo; default: web stack inferred from idea → next), `--from-step=NN` (resume from step N in range 1-15), `--skip-prd` (omit Step 05 dispatch — degenerate; PRD feeds Steps 06-15), `--skip-brand` (omit Step 13 + fall back to `templates/default-tokens.css`).
4. Compute `slug` = kebab-case from idea (lowercase, alphanumeric + hyphens, max 40 chars).

## Phase 0 — Setup + idempotency check + resume detection

1. **Idempotency check** — if `<out>` exists and is non-empty:
   - If `--from-step=NN` was passed AND `<out>/docs/.state.json` exists: read state, validate (a) `version == 3` — if v2 found, abort with `state v2 found — pre-spec-045 run; clear --out dir or run fresh /prototype`; (b) `slug`/`idea`/`flags.stack` match the invocation; if mismatch, abort with `state mismatch — clear --out dir or pick different --from-step`. If both pass, jump to step NN.
   - Else (no `--from-step` OR no `.state.json`): prompt `<out> exists and is non-empty. Overwrite? (y/N) ▷`. On `y` → `rm -r <out>` (NOT `rm -rf` — governance-gate blocks combined flags). On `n` / no answer → abort cleanly with `aborted; pick a different --out or rm the existing dir yourself`. Exit 0.
2. **Init** — `mkdir -p <out>/docs/02-screens`; write fresh `<out>/docs/.state.json` per `state-machine.md` v3 shape with `version=3, phase="discovery", step=0, started_at=<ISO>, gates_passed=[], completed_steps=[], blocked_steps=[], iterations={discovery:0, specification:0, identity:0}, completed_at=null`. **Artifact layout discipline:** EVERY skill-produced output writes under `<out>/docs/` — pipeline deliverables as `<out>/docs/NN-<slug>.<ext>` (NN = zero-padded step number 01-15), the run report as `<out>/docs/REPORT.md`, the state file as `<out>/docs/.state.json`, the generated tokens as `<out>/docs/14-tokens.css` (note: Step 14 in v3, was Step 06 in v2). The `<out>/` root holds ONLY the runtime tree (`app/`, `lib/`, `node_modules/`) and build config (`package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `next.config.ts`, `biome.json`, `tsconfig.json`, `postcss.config.mjs`, `.gitignore`). Rule: if the founder didn't write it and Next.js / Expo doesn't expect it at root, it lives under `docs/`. Spec-036 finding #7 (iter-2 layout) preserved.

## Phase 1 — Discovery (pipeline steps 01-04)

**Read `references/delegation-briefs.md` § "Phase 1 — Discovery" BEFORE dispatching.** Each Agent call uses the 5-field template there.

1. **Step 01 — Ideation** (BLOCKING) — dispatch Sub-agent A per § Step 01 brief. **model: opus.** Returns `<out>/docs/01-concept-brief.md` (includes market sizing TAM/SAM/SOM section per Decision 6). If BLOCKED: ABORT the entire run.
2. **Step 02 — Prototype v1 (lo-fi)** — dispatch direction-writer per § Step 02 brief. Returns `<out>/docs/02-direction-a.html` + 3-5 killer-flow HTML mood screens at `<out>/docs/02-screens/NN-<name>.html`. Note: sitemap is NO LONGER produced at Step 02 (moved to its own Step 07 — sitemap-IA). Step 02 outputs are pure mood/visual exploration of the killer flow.
3. **Steps 03 + 04 — parallel fan-out** — once Step 02 returns (both need `02-direction-a.html` + `02-screens/`), dispatch TWO sub-agents in ONE MESSAGE (parallel tool calls) per § Step 03 + § Step 04 briefs. All `sonnet`. Step 03 (functional-spec) extends with § Problem-Validation Interviews per Decision 6.
4. **Update `.state.json`** — append to `completed_steps`; any BLOCKED to `blocked_steps`.
5. **Gate — `gate_discovery`** — `AskUserQuestion` with 3 options:
   - `continue` → proceed to Phase 2 — Specification (append `discovery` to `gates_passed`).
   - `iterate` → user names which step(s) to re-dispatch (sub-prompt). Re-dispatches with augmented brief. Increment `iterations.discovery`. Re-gate after.
   - `abort` → exit cleanly; set `flags.from_step = current_step`; print resume command.

## Phase 2 — Specification (pipeline steps 05-12)

The biggest phase (8 steps). Internal dispatch DAG follows dependency order; some parallelize, others are strictly serial.

1. **Step 05 — PRD 1-pager** (BLOCKING; downstream depends on US-NN stable IDs). Dispatch per § Step 05 brief. Returns `<out>/docs/05-prd.md` in Lenny 1-pager hybrid shape (Problem · Why now · Success metrics with NSM slot · Solution sketch · User stories · Anti-goals + 3 our-specific: Release scope · NSM-dedicated-slot · Upstream/downstream refs). 4-7 KB tight target.
2. **Steps 06 + 07 — parallel fan-out** — dispatch TWO sub-agents in ONE MESSAGE per § Step 06 (OST) + § Step 07 (sitemap-IA) briefs. Both read Step 05 PRD. Step 06 = Opportunity Solution Tree (Teresa Torres methodology). Step 07 = full screen inventory YAML with schema-bound `required_categories`.
3. **Step 07 acceptance check** — orchestrator parses returned `<out>/docs/07-sitemap.yaml` and enforces `references/sitemap-schema.md` § required_categories: every category in `[marketing, auth, primary, admin, error]` must have ≥1 route OR be explicitly listed in top-level `deferred_categories: [{name, reason}]`. **If any required category has 0 routes AND no deferral, BLOCK Step 07 + re-dispatch with augmented brief naming the missing category(ies).** This is the load-bearing mechanical fix for the Pass-E silent-undercover bug.
4. **Step 08 — System design** (depends on Step 05 PRD + Step 07 sitemap). Dispatch per § Step 08 brief. Returns `<out>/docs/08-system-design.md` + `<out>/docs/08-security.md` + `<out>/docs/08-data-flow.json` (the data-flow inventory consumed by Step 09 legal for DPIA trigger). Extended with § RACI Matrix + § Risk Register per Decision 10.
5. **Step 09 — Legal posture** (depends on Step 08 data-flow inventory — shift-left per Decision 4). Dispatch per § Step 09 brief. Reads `<out>/docs/08-data-flow.json` for DPIA trigger; if data-flow includes sensitive categories (PII / health / minors / financial), DPIA section becomes mandatory. Returns `<out>/docs/09-legal-posture.md`.
6. **Step 10 — Roadmap** (depends on Step 05 PRD priorities + Step 08 dependencies). Dispatch per § Step 10 brief. Returns `<out>/docs/10-roadmap.md` with phase definitions that **drive** the next step's cost calculation. **Cost↔roadmap swap per spec 045 — roadmap dispatches BEFORE cost so cost calculates per-phase from real phase boundaries instead of inventing implicit ones.**
7. **Steps 11 + 12 — parallel fan-out** — dispatch TWO sub-agents in ONE MESSAGE per § Step 11 (cost) + § Step 12 (gtm-launch) briefs. Step 11 reads Step 10 roadmap (for phase boundaries) + Step 09 legal (for review budget) + Step 08 system-design (for integration line items). Step 12 reads Step 10 (for launch timing) + Step 09 (for compliance signals).
8. **Update `.state.json`**.
9. **Gate — `gate_specification`** — `AskUserQuestion` (same 3-option shape).

## Phase 3 — Identity (pipeline steps 13-14)

Strictly serial — design system depends on brand.

1. **Step 13 — Brand book.** Dispatch per § Step 13 brief. Returns `<out>/docs/13-brand-book.md`. If `--skip-brand`: skip dispatch, `cp templates/default-tokens.css <out>/docs/14-tokens.css` + write minimal `<out>/docs/13-brand-book.md` with neutral tone. **Brand moves to Phase 3 per Decision 3 (PRD-first ordering)** — brand-book now consumes a finalized PRD + sitemap + system-design, NOT a half-formed concept brief.
2. **Step 14 — Design system.** Dispatch per § Step 14 brief. Reads brand-book + audit findings (Step 04) + sitemap inventory (Step 07). Returns 3 files: `docs/14-tokens.css`, `docs/14-components.md`, `docs/14-design-system.md`.
3. **Update `.state.json`**.
4. **Gate — `gate_identity`** — `AskUserQuestion`.

## Phase 4 — Visual contract (pipeline step 15)

NO GATE — Phase 4 closes the pipeline; the `/sdd new <slug>` handoff is the implicit "next" gate.

1. **Step 15 — Screen atlas** (Sub-agent (a)) — dispatch per § Step 15 brief. Returns `<out>/docs/15-screen-atlas.md` with PRD coverage matrix + design-fidelity scores + states-coverage matrix + sitemap coverage cross-check. **Absorbs the responsibilities of deleted Step 7 (prototype-v2 brand-tuned)** per Decision 8 + 14 — the atlas IS the brand+tokens-applied hi-fi pass; there is no separate intermediate prototype.
2. **Step 15 — Per-route screen writers** (Sub-agent (b)) — dispatch N screen-writers in parallel (cap=5) per § Per-stack screen-writer. N = full sitemap inventory at standard tier (covers all `required_categories` routes plus legal-mandatory surfaces from Step 09 — consent dialog if applicable from DPIA-trigger).
3. **Stitch step — wire token import + verify.** Stack-specific:
   - **Next.js:** Verify `<out>/app/globals.css` contains the token import via strict regex: `grep -qE '^@import.*docs/.*tokens\.css' <out>/app/globals.css`. The bundled `templates/monorepo-skeleton/next/app/globals.css` SHIPS this line as line 1 (`@import "../docs/14-tokens.css";` — relative path to the Step-14 deliverable; **note path change vs v2** which had `../docs/06-tokens.css`) — if missing, prepend via `sed -i '1i @import "../docs/14-tokens.css";' <out>/app/globals.css`. DO NOT use a loose-substring `grep -q 'tokens.css'` (matched comments — root cause of 2026-05-17 dogfood render-raw bug).
   - **Expo:** Tokens consumed via `tailwind.config.js` → no inline import needed.
4. **Build verification:**
   - Install: `cd <out> && pnpm install --frozen-lockfile` (next) or `bun install` (expo). MUST include OVERRIDE marker for supply-chain hook:
     ```
     # OVERRIDE: /prototype Phase 4 build verification — bundled-template install per spec 045
     cd <out> && pnpm install --frozen-lockfile
     ```
   - Typecheck: `cd <out> && node_modules/.bin/tsc --noEmit` (direct bin path; pnpm v11 deps-status can block `pnpm typecheck`).
   - Lint: `cd <out> && node_modules/.bin/biome check .` (same reason).
   - Capture per-step exit codes + durations for `<out>/docs/REPORT.md` `## Build health` section. Do NOT fail the build on typecheck/lint non-zero — record and continue.
5. **Author `<out>/docs/REPORT.md` inline.** Read `templates/report.md.tmpl`, substitute placeholders from `<out>/docs/.state.json` + Phase outputs. See `quality-checklist.md` for the per-step gate criteria scoring.

## Phase 5 — Handoff message

Print to chat:

```
Prototype ready at <out>/.

  Pipeline coverage: 15/15 steps completed (or N/15 if any BLOCKED — see docs/REPORT.md § Blocked steps).
  Run: cd <out> && pnpm dev   (open http://localhost:3000)
  Report: <out>/docs/REPORT.md
  Concept brief: <out>/docs/01-concept-brief.md
  PRD: <out>/docs/05-prd.md
  Sitemap: <out>/docs/07-sitemap.yaml
  Atlas: <out>/docs/15-screen-atlas.md
  Full pipeline artifacts: <out>/docs/ (01..15 enumerated)

  Phase wall-clock: <total elapsed from started_at to completed_at>
  Gate iterations: discovery=<n> specification=<n> identity=<n>

  Engineering handoff: /sdd new <slug>
```

Then update `<out>/docs/.state.json` with `completed_at` ISO timestamp.

## Worked example — parallel dispatch in a single message

True parallelism (no FS race) happens at: Phase 1 Step 03+04 (both read Step 02 output that's already on disk), Phase 2 Step 06+07 (both read Step 05 PRD), Phase 2 Step 11+12 (both read Step 09 legal + Step 10 roadmap). Steps with strict serial dependencies (05 → 06+07 → 08 → 09 → 10 → 11+12) must NOT be dispatched together — they'd race the FS.

Example (4 calls, Phase 2 Step 11+12 plus Step 15 per-route screen-writers):

```
[single assistant message with four <tool_use> blocks]:
  <tool_use name="Agent" id="A1">
    subagent_type: general-purpose
    model: sonnet
    description: Step 11 — cost-writer
    prompt: <TASK + CONTEXT + CONSTRAINTS + DELIVERABLE + DONE_WHEN per delegation-briefs.md § Step 11>
  </tool_use>
  <tool_use name="Agent" id="A2">
    subagent_type: general-purpose
    model: sonnet
    description: Step 12 — gtm-launch-writer
    prompt: <... per § Step 12>
  </tool_use>
  ...
```

Dispatching serially (one Agent call per message) is a v1 orchestration bug. Wall-time penalty alone (~3x for a quad) makes parallel-where-safe critical.

**Anti-pattern**: do NOT dispatch Step 02 + Step 03 + Step 04 in one message (spec 036 SKILL.md had this false-positive worked example). Step 03 and Step 04 CONTEXT both reference `<out>/docs/02-direction-a.html` + `<out>/docs/02-screens/` — those files don't exist when Step 02 hasn't returned. The de-facto-correct dispatch is Step 02 alone first, then Step 03+04 parallel.

## Unknown / extra subcommand

This skill does not have subcommands beyond the initial invocation. If `$ARGUMENTS` starts with an unrecognized token (not a quoted idea and not a flag), refuse with the usage hint:

```
/prototype "<idea>" --out=<path> [--stack=<name>] [--from-step=NN] [--skip-prd] [--skip-brand]
```

## Notes

- **Spec 033 compliance is non-skippable.** Run `bash .claude/skills/skill/scripts/validate.sh .claude/skills/prototype` before commit; exit 0 required.
- **Validator scope is REPO-WIDE, not per-edited-file.** The post-edit validator (delegation-gate hook) runs Biome over the WHOLE prototype dir, not just the sub-agent's edited file — one bad Biome format error blocks ALL subsequent sub-agents until cleaned. **Mitigation:** the orchestrator runs `node_modules/.bin/biome check --write .` (parent-side) between EVERY phase boundary (NOT just before Phase 4 as v2 said — Pass E finding #1 showed 4 of 4 Phase-3 sub-agents burned loop budget on accumulated TSX lint errors from Phase 2 page.tsx output). This compresses worst-case wall-time from ~11hr to ~90-120min.
- **Concurrency cap 5** for screen-writer fan-outs (Steps 02 / 15). Proven non-OOM on 17-route dogfood. Re-evaluate if Phase 4 with 12+ atlas screens surfaces context pressure.
- **Output dir is `--out=<path>`**, NOT hardcoded `/tmp/`.
- **No MCP product-pipeline calls.** Skill is standalone — bundled templates at `templates/pipeline/01-ideation/` … `15-screen-atlas/` (derived from spec 032's 17 decisions, NOT re-copied from `packages/mcp-product-pipeline/src/templates/` which is mid-realign via spec 032's child specs 037-044). Quarterly REMINDERS check (due 2026-08-18) for drift sync when spec 032 lands.
- **`--skip-prd` is degenerate.** PRD feeds Steps 06-15 (OST/sitemap/system-design/legal/roadmap/cost/GTM/brand/design-system/atlas all reference US-NN). Skipping produces a partial pipeline with downstream gaps marked in REPORT.md. Not recommended.
- **OD vendor index at `references/od-catalog-index.json`** snapshot from 2026-05-18 (72 vendors). Step 14 design-system brief reads this to pick 1-2 catalog vendors. Full per-vendor `DESIGN.md` files are NOT bundled (size budget) — Step 14 brief reads them from `packages/mcp-product-pipeline/design-systems/<vendor>/DESIGN.md` if the package is present; falls back to mood-only inheritance if absent.
- **Spec 034 + 036 superseded.** Both stay shipped in git history; v3 (spec 045) becomes the active shape.
- **Sub-agent oversize discipline (spec 036 finding #3).** Many sub-agents produce files materially over the standard-tier size target. Each step's brief CONSTRAINTS line now treats size as a HARD CEILING — if a sub-agent goes over, it should ABORT and re-emit at smaller scope rather than ship oversized.
- **Sitemap schema enforcement is mechanical** (per spec 045 Decision 5 + 13). Orchestrator parses `<out>/docs/07-sitemap.yaml` after Step 07 returns; if any `required_categories` member has 0 routes AND no `deferred_categories: [{name, reason}]` declaration, Step 07 is BLOCKED. This is the load-bearing fix for the "atlas under-cover" bug Pass E demonstrated (Steward shipped without auth/admin/error screens silently).
