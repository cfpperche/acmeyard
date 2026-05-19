---
name: product
description: Foundation generator + design partner for the product lifecycle (idea → v1 → vN). 15-step industry-aligned pipeline produces all planning artifacts (concept brief / functional spec / UX audit / PRD-1pager / OST / sitemap-IA / system design / legal / roadmap / cost / GTM-launch / brand / design system) PLUS lo-fi mood + hi-fi screen-atlas absorbing brand+tokens. Output is a monorepo at user-specified path with semantic-named artifacts at `<out>/docs/` (no NN- prefix; PRD release-scoped via `prd/v1.md`; design system grouped). 4 phases - Discovery / Specification / Identity / Visual-contract - with 3 AskUserQuestion gates after steps 4 / 12 / 14. Standalone (templates bundled). Flags - `<idea>` `--stack=<next|expo>` `--out=<path>` `--from-step=NN` `--skip-prd` `--skip-brand`. See `references/{pipeline-coverage,state-machine,delegation-briefs}.md`. v0.3.0 per spec 048 (rename + layout).
license: MIT
compatibility: Designed for Claude Code. Body references `.claude/` conventional paths, dispatches Agent tool with 5-field handoffs (delegation-gate), uses AskUserQuestion at phase gates, optionally uses Playwright MCP for screenshots. Not portable to runtimes that lack these surfaces.
metadata:
  agent0-portability-tier: cc-native
  skill-version: "0.3.0"
argument-hint: "<idea>" --out=<path> [--stack=<next|expo>] [--from-step=NN] [--skip-prd] [--skip-brand]
---

# /product — 15-step foundation generator + design partner

Takes a founder's one-line idea and produces a complete v1-ready product foundation at `<--out>`: concept brief (with market sizing) → lo-fi prototype (mood + killer flow) → functional spec (with problem-validation interviews) → UX audit → PRD 1-pager → OST (Opportunity Solution Tree) → sitemap-IA (full screen inventory with required_categories enforcement) → system design (with RACI + risk + data-flow inventory) → legal posture (DPIA-triggered by data-flow, NOT end-of-pipeline) → roadmap (defines phases) → cost estimate (per-phase using roadmap) → GTM-launch → brand book → design system → hi-fi screen-atlas (absorbs brand+tokens, full PRD coverage). 4 fluid phases with 3 condensed user gates. **The output IS production layout** — semantic naming (no NN- prefix), PRD release-scoped at `docs/prd/v1.md` from day 1, design system grouped at `docs/design-system/`. Founder reads `docs/REPORT.md` for the temporal narrative, and the structure itself supports v2/v3/vN evolution without manual reorg.

**v0.3.0 — spec 048 product-skill-foundation** — see `docs/specs/048-product-skill-foundation/` for the rename (`/prototype` → `/product`) + layout refactor (drop NN- prefix; semantic paths). Inherits the 15-step industry-aligned pipeline from spec 045 (which inherited 17 decisions from spec 032). v0.2.0 (spec 045 `/prototype` v3, NN-flat) is superseded; v0.1.0 (spec 036) was already superseded.

**Required reading before execution:**
- `references/pipeline-coverage.md` — what each of the 15 steps produces at standard tier
- `references/state-machine.md` — `.state.json` v4 shape + 4-phase progression + resume support (breaking: refuses silent v3 → v4 upgrade)
- `references/delegation-briefs.md` — 5-field briefs for all 16 sub-agent dispatches (15 step-specific + 1 per-stack screen-writer)
- `references/quality-checklist.md` — per-step gate criteria the skill checks before declaring a step complete
- `references/sitemap-schema.md` — `required_categories` enforcement + per-route field set (load-bearing — orchestrator BLOCKS Step 07 if uncovered category found without `deferred_categories` declaration)

## Argument parsing

User invokes as `/product "<idea>" --out=<path> [flags]`. The raw argument string is `$ARGUMENTS`. Parse it yourself:

1. First quoted-token is `<idea>` — refuse with `usage: /product "<idea>" --out=<path> [flags]` if missing.
2. `--out=<path>` is REQUIRED — refuse if missing. Resolve to absolute path.
3. Optional flags (any order after idea): `--stack=<name>` (next | expo; default: web stack inferred from idea → next), `--from-step=NN` (resume from step N in range 1-15), `--skip-prd` (omit Step 05 dispatch — degenerate; PRD feeds Steps 06-15), `--skip-brand` (omit Step 13 + fall back to `templates/default-tokens.css`).
4. Compute `slug` = kebab-case from idea (lowercase, alphanumeric + hyphens, max 40 chars).

## Phase 0 — Setup + idempotency check + resume detection

1. **Idempotency check (spec 059 — harness-aware)** — list files at `<out>`. Filter out the **Agent0 harness allowlist** (these are exempt; a freshly-bootstrapped Agent0 fork is "fresh" from `/product`'s perspective):

   ```
   .claude/        .githooks/         .gitignore
   .gitleaks.toml  .mcp.json.example  CLAUDE.md      .git/
   ```

   Compute `<remaining>` = files at `<out>` MINUS the harness allowlist above (recursive — `.claude/**`, `.githooks/**`, `.git/**` all count as harness).

   - **If `<remaining>` is empty** (or `<out>` doesn't exist): proceed to step 2 (Init) — no prompt, no rm, harness preserved. This is the path for `mkdir mei-saas && sync-harness mei-saas && /product --out=mei-saas`, the natural Agent0-disciplined-from-day-1 founder workflow.
   - **If `<remaining>` is non-empty:**
     - If `--from-step=NN` was passed AND `<out>/docs/.state.json` exists: read state, validate (a) `version == 4` — if v3 found, abort with `state v3 found — pre-spec-048 run; clear --out dir or run fresh /product`; if v2 found, abort with `state v2 found — pre-spec-045 run; clear --out dir or run fresh /product`; (b) `slug`/`idea`/`flags.stack` match the invocation; if mismatch, abort with `state mismatch — clear --out dir or pick different --from-step`. If both pass, jump to step NN.
     - Else (no `--from-step` OR no `.state.json`): prompt `<out> exists with prior /product artifacts. Overwrite? (y/N) ▷`. On `y` → `rm -r <out>` (NOT `rm -rf` — governance-gate blocks combined flags; note this WILL also remove any harness present — founder re-syncs via `sync-harness.sh` after). On `n` / no answer → abort cleanly with `aborted; pick a different --out or rm the existing dir yourself`. Exit 0.

   **Harness allowlist drift:** the 7-path list above mirrors `.claude/tools/sync-harness.sh`'s manifest as of spec 059 (2026-05-19). If the manifest gains a new path (e.g. `.envrc` someday), audit this list too — otherwise the new harness file would falsely trigger the overwrite prompt.

2. **Init** — `mkdir -p <out>/docs/screens <out>/docs/prd <out>/docs/design-system`; write fresh `<out>/docs/.state.json` per `state-machine.md` v4 shape with `version=4, phase="discovery", step=0, started_at=<ISO>, gates_passed=[], completed_steps=[], blocked_steps=[], iterations={discovery:0, specification:0, identity:0}, completed_at=null, target_language=null`. **Artifact layout discipline:** EVERY skill-produced output writes under `<out>/docs/` — pipeline deliverables semantic-named (`docs/concept-brief.md`, `docs/sitemap.yaml`, `docs/system-design.md`, etc. — NO `NN-` prefix per spec 048), PRD release-scoped at `docs/prd/v1.md`, design system grouped at `docs/design-system/{tokens.css, components.md, README.md}`, the run report at `docs/REPORT.md`, the state file at `docs/.state.json`. The `<out>/` root holds ONLY the runtime tree (`app/`, `lib/`, `node_modules/`) and build config (`package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `next.config.ts`, `biome.json`, `tsconfig.json`, `postcss.config.mjs`, `.gitignore`). Rule: if the founder didn't write it and Next.js / Expo doesn't expect it at root, it lives under `docs/`. Temporal ordering of pipeline steps survives via REPORT.md + .state.json; semantic naming wins for the founder's day-to-day mental model. **`.gitignore` append-aware (spec 059):** when the runtime skeleton step writes `<out>/.gitignore` and the file already exists (e.g. from an Agent0 harness bootstrap), do NOT overwrite. Read the existing file, append the Next.js (or Expo) rules under a marker line `# --- /product (<stack>) ---`, preserving everything above verbatim. On re-runs of `/product` on the same `<out>`, locate the existing marker and REPLACE the region from the marker to EOF with the fresh rules — file stays idempotent. If the marker is absent (founder edited it out), append fresh with a new marker.

## Phase 0.5 — Target language resolution (spec 054)

Resolves `target_language` BEFORE Step 01 dispatches so every downstream sub-agent generates user-facing text in the right language. Runs ONCE per fresh run (skipped on `--from-step` resume — state already carries the value).

1. **Heuristic from idea string** — scan `<idea>` for signals:
   - Portuguese cues: any of `R$` / `LGPD` / `NFS-e` / `Pix` / `CNPJ` / `CPF` / `clínica` / `salão` / `petshop`, OR pt-BR diacritics (`á é í ó ú ã õ ç`) anywhere in the string → propose `pt-BR`.
   - Spanish cues: `€` (combined with `IVA` / `S.L.` / `México` / `España`), OR es diacritics (`ñ ¿ ¡`) → propose `es-ES` or `es-MX` (favor `es-ES` if ambiguous).
   - Otherwise → propose `en` (US default; `en-GB` only if `Ltd` / `programme` / `colour` appear).
2. **`AskUserQuestion` — single question, 2-4 options**:
   - Q: `Target language for all artifacts (PRD, brand-book, screen copy, etc)?`
   - Options: `<proposed> (Recommended)` · `en` · `pt-BR` · `Other` (founder types BCP-47 tag like `es-MX`, `fr-FR`, etc).
   - The (Recommended) label uses whichever the heuristic proposed.
3. **Store** — write `target_language` into `<out>/docs/.state.json` (BCP-47 string). This is now the canonical signal for every brief substitution + brand-book Step 13 § Language section.

**On `--from-step` resume:** read `.state.json.target_language`. If null (pre-spec-054 state), run the heuristic + ask. If present, use as-is (no re-ask).

**Override:** founder can edit `.state.json.target_language` between phases — downstream sub-agents read the current value at dispatch time, so changes mid-run propagate to subsequent steps (but artifacts already written stay in their original language until re-iterated).

## Phase 1 — Discovery (pipeline steps 01-04)

**Read `references/delegation-briefs.md` § "Phase 1 — Discovery" BEFORE dispatching.** Each Agent call uses the 5-field template there.

1. **Step 01 — Ideation** (BLOCKING) — dispatch Sub-agent A per § Step 01 brief. **model: opus.** Returns `<out>/docs/concept-brief.md` (includes market sizing TAM/SAM/SOM section per Decision 6). If BLOCKED: ABORT the entire run.
2. **Step 02 — Prototype v1 (lo-fi)** — dispatch direction-writer per § Step 02 brief. Returns `<out>/docs/direction-a.html` + 3-5 killer-flow HTML mood screens at `<out>/docs/screens/NN-<name>.html`. Note: sitemap is NO LONGER produced at Step 02 (moved to its own Step 07 — sitemap-IA). Step 02 outputs are pure mood/visual exploration of the killer flow.
3. **Steps 03 + 04 — parallel fan-out** — once Step 02 returns (both need `direction-a.html` + `screens/`), dispatch TWO sub-agents in ONE MESSAGE (parallel tool calls) per § Step 03 + § Step 04 briefs. All `sonnet`. Step 03 (functional-spec) extends with § Problem-Validation Interviews per Decision 6.
4. **Update `.state.json`** — append to `completed_steps`; any BLOCKED to `blocked_steps`.
5. **Gate — `gate_discovery`** — `AskUserQuestion` with 3 options:
   - `continue` → proceed to Phase 2 — Specification (append `discovery` to `gates_passed`).
   - `iterate` → user names which step(s) to re-dispatch (sub-prompt). Re-dispatches with augmented brief. Increment `iterations.discovery`. Re-gate after.
   - `abort` → exit cleanly; set `flags.from_step = current_step`; print resume command.

## Phase 2 — Specification (pipeline steps 05-12)

The biggest phase (8 steps). Internal dispatch DAG follows dependency order; some parallelize, others are strictly serial.

1. **Step 05 — PRD 1-pager** (BLOCKING; downstream depends on US-NN stable IDs). Dispatch per § Step 05 brief. Returns `<out>/docs/prd/v1.md` in Lenny 1-pager hybrid shape (Problem · Why now · Success metrics with NSM slot · Solution sketch · User stories · Anti-goals + 3 our-specific: Release scope · NSM-dedicated-slot · Upstream/downstream refs). 4-7 KB tight target.
2. **Steps 06 + 07 — parallel fan-out** — dispatch TWO sub-agents in ONE MESSAGE per § Step 06 (OST) + § Step 07 (sitemap-IA) briefs. Both read Step 05 PRD. Step 06 = Opportunity Solution Tree (Teresa Torres methodology). Step 07 = full screen inventory YAML with schema-bound `required_categories`.
3. **Step 07 acceptance check** — orchestrator parses returned `<out>/docs/sitemap.yaml` and enforces `references/sitemap-schema.md` § required_categories: every category in `[marketing, auth, primary, admin, error]` must have ≥1 route OR be explicitly listed in top-level `deferred_categories: [{name, reason}]`. **If any required category has 0 routes AND no deferral, BLOCK Step 07 + re-dispatch with augmented brief naming the missing category(ies).** This is the load-bearing mechanical fix for the Pass-E silent-undercover bug.
4. **Step 08 — System design** (depends on Step 05 PRD + Step 07 sitemap). Dispatch per § Step 08 brief. Returns `<out>/docs/system-design.md` + `<out>/docs/security.md` + `<out>/docs/data-flow.json` (the data-flow inventory consumed by Step 09 legal for DPIA trigger). Extended with § RACI Matrix + § Risk Register per Decision 10.
5. **Step 09 — Legal posture** (depends on Step 08 data-flow inventory — shift-left per Decision 4). Dispatch per § Step 09 brief. Reads `<out>/docs/data-flow.json` for DPIA trigger; if data-flow includes sensitive categories (PII / health / minors / financial), DPIA section becomes mandatory. Returns `<out>/docs/legal-posture.md`.
6. **Step 10 — Roadmap** (depends on Step 05 PRD priorities + Step 08 dependencies). Dispatch per § Step 10 brief. Returns `<out>/docs/roadmap.md` with phase definitions that **drive** the next step's cost calculation. **Cost↔roadmap swap per spec 045 — roadmap dispatches BEFORE cost so cost calculates per-phase from real phase boundaries instead of inventing implicit ones.**
7. **Steps 11 + 12 — parallel fan-out** — dispatch TWO sub-agents in ONE MESSAGE per § Step 11 (cost) + § Step 12 (gtm-launch) briefs. Step 11 reads Step 10 roadmap (for phase boundaries) + Step 09 legal (for review budget) + Step 08 system-design (for integration line items). Step 12 reads Step 10 (for launch timing) + Step 09 (for compliance signals).
8. **Update `.state.json`**.
9. **Gate — `gate_specification`** — `AskUserQuestion` (same 3-option shape).

## Phase 3 — Identity (pipeline steps 13-14)

Strictly serial — design system depends on brand.

1. **Step 13 — Brand book.** Dispatch per § Step 13 brief. Returns `<out>/docs/brand-book.md`. If `--skip-brand`: skip dispatch, `cp templates/default-tokens.css <out>/docs/design-system/tokens.css` + write minimal `<out>/docs/brand-book.md` with neutral tone. **Brand moves to Phase 3 per Decision 3 (PRD-first ordering)** — brand-book now consumes a finalized PRD + sitemap + system-design, NOT a half-formed concept brief.
2. **Step 14 — Design system.** Dispatch per § Step 14 brief. Reads brand-book + audit findings (Step 04) + sitemap inventory (Step 07). Returns 3 files: `docs/design-system/tokens.css`, `docs/design-system/components.md`, `docs/design-system/README.md`.
3. **Update `.state.json`**.
4. **Gate — `gate_identity`** — `AskUserQuestion`.

## Phase 4 — Visual contract (pipeline step 15)

NO GATE — Phase 4 closes the pipeline; the `/sdd new <slug>` handoff is the implicit "next" gate.

1. **Step 15 — Screen atlas** (Sub-agent (a)) — dispatch per § Step 15 brief. Returns `<out>/docs/screen-atlas.md` (atlas index) AND **one `<out>/app/(<chrome>)/layout.tsx` per distinct `chrome` value with ≥1 route assigned** (per spec 055 — chrome is orthogonal to category and drives route-group placement). For a typical 4-chrome sitemap (app + marketing + booking + auth), atlas writes 4 layouts; `chrome: chromeless` routes get no layout. **Absorbs the responsibilities of deleted Step 7 (prototype-v2 brand-tuned)** per Decision 8 + 14 — the atlas IS the brand+tokens-applied hi-fi pass; there is no separate intermediate prototype. **Per spec 052, atlas MUST run BEFORE the per-route screen-writers** (they consume the layout files atlas writes; chrome inheritance is implicit via Next.js nested-layout cascade — pages no longer invent their own shell).
2. **Step 15 — Per-route screen writers** (Sub-agent (b)) — dispatch N screen-writers in parallel (cap=5) per § Per-stack screen-writer **AFTER atlas Sub-agent (a) returns** (atlas-first sequence, spec 052). N = full sitemap inventory at standard tier (covers all `required_categories` routes plus legal-mandatory surfaces from Step 09 — consent dialog if applicable from DPIA-trigger). **Path resolution per route uses `chrome` field (spec 055), NOT `category`** — writers place pages under `app/(<chrome>)/<route>/page.tsx`; routes missing `chrome` apply the default-inference table from `references/sitemap-schema.md § chrome`.

   **Fan-out execution (spec 057 — wave + cascade discipline):**

   - **Wave structure:** if sitemap has > 5 routes, fan-out is split into waves of cap=5. Wave 1 dispatches 5 screen-writers in ONE message (parallel `Agent` calls); on return, wave 2 dispatches the next 5; etc. A wave "returns" when all its sub-agents reach DONE or fail.
   - **Between-wave biome sweep (MANDATORY, always-on per spec 057 OQ-3):** before dispatching wave K+1, run `cd <out> && node_modules/.bin/biome check --write .` (parent-side, exempt from post-edit validator). Cost ~25ms per pass; benefit each wave starts from a clean lint state, breaking the validator-cascade where sub-agents in wave K+1 inherit dirty siblings from wave K. NOT conditional — runs even on clean waves to keep state hygiene uniform.
   - **Degrade-to-parent-write trigger (N=1 same-wave per spec 057 OQ-1):** if ANY sub-agent in the current wave hits `CLAUDE_DELEGATION_LOOP_BUDGET` exhaustion, the orchestrator IMMEDIATELY cancels any in-flight siblings in the SAME wave (don't wait for them to also burn budget) AND switches all remaining routes (this wave + subsequent waves) to parent-write. **Why N=1 not N=2:** sub-agents in the same wave share lint state via repo-wide `biome check`; the first failure is a strong predictor that siblings will also fail. Waiting for N=2 wastes 4 sub-agents of throughput before degrading.
   - **Parent-write fallback shape:** parent reads `delegation-briefs.md § Per-stack screen-writer` (same brief verbatim — execution-strategy-agnostic per spec 057 OQ-2) and emits `page.tsx` directly via `Write`. Parent edits are exempt from the post-edit validator (actor-detection in `.claude/hooks/post-edit-validate.sh`), so the cascade can't trip on parent-writes. Each parent-written route is recorded for the REPORT degradations section.
   - **Logging:** for each degraded route, append `{route, wave, reason, attempts}` to an in-memory list. Phase 4 § Build health authoring (step 5) populates `## Build health § Fan-out degradations` section in REPORT.md per `templates/report.md.tmpl`.

3. **Stitch step — wire token import + verify.** Stack-specific:
   - **Next.js:** Verify `<out>/app/globals.css` contains the token import via strict regex: `grep -qE '^@import.*docs/.*tokens\.css' <out>/app/globals.css`. The bundled `templates/monorepo-skeleton/next/app/globals.css` SHIPS this line as line 1 (`@import "../docs/design-system/tokens.css";` — relative path to the Step-14 deliverable; **note path change vs v2** which had `../docs/06-tokens.css`) — if missing, prepend via `sed -i '1i @import "../docs/design-system/tokens.css";' <out>/app/globals.css`. DO NOT use a loose-substring `grep -q 'tokens.css'` (matched comments — root cause of 2026-05-17 dogfood render-raw bug).
   - **Expo:** Tokens consumed via `tailwind.config.js` → no inline import needed.

3.5. **Stitch step — substitute `app/layout.tsx` placeholders** (Next.js only, spec 051 fix). The skeleton ships `title: "PROTOTYPE_SLUG"` + `<html lang="en">` as markers; both MUST be substituted or every prototype leaks the placeholder in browser tabs + ships the wrong locale.
   - **Title:** prefer `<out>/docs/brand-book.md` § `## Product Name` body line; fall back to `.state.json` `.idea`.
   - **Lang:** read `.state.json.target_language` (resolved at Phase 0.5 per spec 054). If `pt-BR` / `es-*` / non-`en` → substitute `lang="<value>"`; else keep `lang="en"`. (Heuristic + ask shifted upstream to Phase 0.5 so this step is just an apply.)
   - **Apply via python3** (not sed — idea string can contain `&|/'"$\` that break sed): read `<out>/app/layout.tsx`, `.replace('PROTOTYPE_SLUG', title)` + conditional `.replace('lang="en"', f'lang="{target_language}"')`, write back.
   - **Verify:** `grep -L PROTOTYPE_SLUG <out>/app/layout.tsx` must show no match; browser tab on hard-refresh must show the resolved title.
4. **Build verification:**
   - Install: `cd <out> && pnpm install --frozen-lockfile` (next) or `bun install` (expo). MUST include OVERRIDE marker for supply-chain hook:
     ```
     # OVERRIDE: /product Phase 4 build verification — bundled-template install per spec 048
     cd <out> && pnpm install --frozen-lockfile
     ```
   - Typecheck: `cd <out> && node_modules/.bin/tsc --noEmit` (direct bin path; pnpm v11 deps-status can block `pnpm typecheck`).
   - Lint: `cd <out> && node_modules/.bin/biome check .` (same reason).
   - **Dev-server smoke-test (spec 052 — closes spec-051's verification gap):** `pnpm dev --port 3099 &` in background; poll stdout for "Ready" (30s timeout); for each unique sitemap category (skip `error` — Next.js handles), pick ONE representative route + `curl -sS -o /tmp/probe.html -w '%{http_code} %{time_total}' http://localhost:3099<route>` (10s timeout). Mark ✓ if HTTP 200 AND body lacks `__next-dev-overlay-error` / `nextjs__container_errors`. Kill PID cleanly. Failures do NOT abort (tsc/biome posture).
   - Capture per-step exit codes + durations + smoke-test per-route results for `<out>/docs/REPORT.md` § "Build health" (new subsection § "Dev-server smoke-test" — one row per probed route: category | route | HTTP | latency_ms | result; failures additionally surface in § "Action required").
5. **Author `<out>/docs/REPORT.md` inline.** Read `templates/report.md.tmpl`, substitute placeholders from `<out>/docs/.state.json` + Phase outputs. See `quality-checklist.md` for the per-step gate criteria scoring.

## Phase 5 — Handoff message

Print to chat:

```
Prototype ready at <out>/.

  Pipeline coverage: 15/15 steps completed (or N/15 if any BLOCKED — see docs/REPORT.md § Blocked steps).
  Run: cd <out> && pnpm dev   (open http://localhost:3000)
  Report: <out>/docs/REPORT.md
  Concept brief: <out>/docs/concept-brief.md
  PRD: <out>/docs/prd/v1.md
  Sitemap: <out>/docs/sitemap.yaml
  Atlas: <out>/docs/screen-atlas.md
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

**Anti-pattern**: do NOT dispatch Step 02 + Step 03 + Step 04 in one message (spec 036 SKILL.md had this false-positive worked example). Step 03 and Step 04 CONTEXT both reference `<out>/docs/direction-a.html` + `<out>/docs/screens/` — those files don't exist when Step 02 hasn't returned. The de-facto-correct dispatch is Step 02 alone first, then Step 03+04 parallel.

## Unknown / extra subcommand

This skill does not have subcommands beyond the initial invocation. If `$ARGUMENTS` starts with an unrecognized token (not a quoted idea and not a flag), refuse with the usage hint:

```
/product "<idea>" --out=<path> [--stack=<name>] [--from-step=NN] [--skip-prd] [--skip-brand]
```

## Notes

- **Spec 033 compliance is non-skippable.** Run `bash .claude/skills/skill/scripts/validate.sh .claude/skills/product` before commit; exit 0 required.
- **Validator scope is REPO-WIDE.** One bad biome format blocks subsequent sub-agents. Mitigation: parent-side `node_modules/.bin/biome check --write .` between EVERY phase boundary (per spec 048 Pass E finding — compresses worst-case wall-time from ~11hr to ~90-120min).
- **Concurrency cap 5** for screen-writer fan-outs (Steps 02 / 15). Proven non-OOM on 17-route dogfood. Re-evaluate if Phase 4 with 12+ atlas screens surfaces context pressure.
- **Output dir is `--out=<path>`**, NOT hardcoded `/tmp/`.
- **No MCP product-pipeline calls.** Skill is standalone — bundled templates at `templates/pipeline/01-ideation/` … `15-screen-atlas/` (derived from spec 032's 17 decisions, NOT re-copied from `packages/mcp-product-pipeline/src/templates/` which is mid-realign via spec 032's child specs 037-044). Quarterly REMINDERS check (due 2026-08-18) for drift sync when spec 032 lands.
- **`--skip-prd` is degenerate.** PRD feeds Steps 06-15 (OST/sitemap/system-design/legal/roadmap/cost/GTM/brand/design-system/atlas all reference US-NN). Skipping produces a partial pipeline with downstream gaps marked in REPORT.md. Not recommended.
- **OD vendor bundled inside the skill (spec 049).** 73 named `DESIGN.md` design systems at `.claude/skills/product/design-systems/<vendor>/DESIGN.md`, 33 skill bundles + 5-school prompts + frames + templates at `.claude/skills/product/vendor/open-design/`, sync engine at `.claude/skills/product/scripts/sync-open-design.ts` (`--check` / `--bump` / `--apply` / `--verify`). Apache-2.0 attribution preserved in `vendor/open-design/{LICENSE,NOTICE}`. Lightweight catalogue at `.claude/skills/product/references/od-catalog-index.json` (name + mood + palette + path) — Step 14 design-system brief reads it to pick 1-2 catalog vendors, then `Read`s the chosen `DESIGN.md` path directly. No MCP tool indirection; the skill is self-contained.
- **Sub-agent oversize discipline.** Each step's brief CONSTRAINTS treats size as a HARD CEILING — if a sub-agent goes over, ABORT + re-emit at smaller scope rather than ship oversized.
- **Sitemap schema enforcement is mechanical** (per spec 045 Decision 5 + 13). Orchestrator parses `<out>/docs/sitemap.yaml` after Step 07 returns; if any `required_categories` member has 0 routes AND no `deferred_categories: [{name, reason}]` declaration, Step 07 is BLOCKED. This is the load-bearing fix for the "atlas under-cover" bug Pass E demonstrated (Steward shipped without auth/admin/error screens silently).
