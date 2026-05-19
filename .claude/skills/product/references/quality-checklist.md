# Quality checklist — `/product` v0.3.0

Materializes the spec 036 § Quality bar into a checklist the skill enforces in Phase 4 (stitch + verify + REPORT.md). Each item maps to a REPORT.md section.

## 1. Per-step gate criteria (NEW in v2)

For each of the 13 pipeline steps, before marking it `completed` in `.state.json`, verify the per-step gate. Failure → mark BLOCKED with reason; degrade per `delegation-briefs.md § Failure handling`.

| # | Step | Gate criteria (skill checks before marking complete) |
|---|---|---|
| 01 | Ideation | `<out>/concept-brief.md` exists; size 4-10 KB; ≥ 8 H2 sections; ≥ 5 `[N]` citations |
| 02 | Prototype v1 | `<out>/direction-a.html` ≥ 6 KB + `<out>/screens/*.html` × ≥ 3, each ≥ 4 KB; direction-a.html contains `:root` + `--background` + `--foreground` + `--primary` + `Most Popular` + `<svg`; cites ≥ 1 OD vendor in HTML comment header |
| 03 | Spec | `<out>/functional-spec.md` 8-12 KB; contains `**Given**` + `**When**` + `**Then**` + "Pages & Surfaces" + "Features" + "Preliminary Architecture" headers; ≥ 3 Gherkin scenarios |
| 04 | UX Testing | `<out>/validation-report.md` 5-8 KB; contains `Nielsen` + `WCAG`; contains `validation_mode: <tested\|intuition\|not-applicable>` line; YAML frontmatter `findings[]` parses with ≥ 3 entries; each entry has `severity` + `fix_skill_hint` |
| 05 | Brand | `<out>/brand-book.md` 4-8 KB; contains `**Version:**` + `**Date:**` + `**We are**` + `**We are not**` (≥ 1 pair); ≥ 3 voice samples; visual-direction posture (named feel + ≥ 2 posture decisions) |
| 06 | Design System | `<out>/tokens.css` ≥ 1.5 KB valid CSS with `:root` block; `<out>/components.md` ≥ 3 KB; `<out>/design-system.md` ≥ 8 KB + contains "Audit Response" section header; if catalog path: cites OD vendor name + vendor_path in design-system.md |
| 07 | Prototype v2 | `<out>/direction-final.html` ≥ 8 KB; references tokens.css via `@import` OR inline `var(--color-*)`; cites step-06 design-system.md in HTML comment header; brand-name from step-05 propagates; `<out>/screens/*.html` count matches step-02 count (inheritance discipline) |
| 08 | PRD | `<out>/prd.md` 6-10 KB; contains literal table-row `\| US-NN \|` (≥ 1); contains "Success Metric" section header; ONE primary metric named; P0/P1/P2 tiers visible in table |
| 09 | System Design | `<out>/system-design.md` ≥ 12 KB + 6 section headers (Stack / Integrations / Data Model / Decisions / Security / Observability); `<out>/security.md` ≥ 3 KB + "Threat Model" + "Auth" + "Data Classification" + "Secrets" headers |
| 10 | Cost Estimate | `<out>/cost-estimate.md` 5-8 KB; contains "Assumptions" + "Run Cost" + "Recommendations" headers; run-cost vendor count matches system-design integration count (audit discipline) |
| 11 | Roadmap | `<out>/roadmap.md` 5-8 KB; 3 phase headers + each phase has 1-3 milestones + deliverables table referencing US-NN; `§ Open Decisions` section |
| 12 | Legal | `<out>/legal-posture.md` 4-7 KB; escape clause at TOP (line 1-5); contains "Terms" + "Privacy" + "Licensing" + "Sub-Processor" + "Open Decisions" headers; sub-processor count matches system-design integration count |
| 13 | Prototype v3 | `<out>/screen-atlas.md` ≥ 8 KB + 7 section headers (Overview / Screens Index / PRD Coverage / Design Fidelity / States Coverage / User Flow / Open Decisions); PRD coverage matrix lists every US-NN from prd.md (covered → screen file OR deferred → reason); design-fidelity table has 4-dim Min column |

## 2. Sitemap completeness (steps 02 / 07 / 13)

Inherited from v1 — applies to each prototype pass's screen set:

- All 5 `required_categories` present (marketing / auth / primary / admin / error) → ✓ otherwise gap-audit entry per missing category
- Per-route fields complete per `sitemap-schema.md` Rules 4-6 → ✓ otherwise REPORT.md flags malformed routes
- Minimum screen count by product class met (Micro ≥ 6 / Mobile ≥ 12 / Dev Tool ≥ 12 / SMB SaaS ≥ 12 / Venture ≥ 20) → standard tier RELAXES this for steps 02 + 07 (killer-flow only — 3-5 screens acceptable). Step 13 atlas MUST hit full PRD coverage.

## 3. Design fidelity (4-dim per-screen scoring; steps 02 / 07 / 13)

Each generated screen file gets a 1-5 score on each of 4 dimensions. **Specificity from the original 5-dim rubric (spec 026 task 22) is dropped — it correlated too tightly with the other 4 to add signal.**

| Dimension | What 5 looks like | What 1 looks like |
|---|---|---|
| **Token** | Every color / spacing / radius / font reads from `tokens.css` (or NativeWind tailwind config); zero hard-coded `#3B82F6` or `12px` (1px borders are idiomatic exception) | Hard-coded values throughout; tokens.css ignored |
| **Voice** | All copy strings (headings, microcopy, CTA labels, empty-state text) match brand-book ON-brand sample | Generic "Welcome to our app" copy that any product could use |
| **Component** | Each screen uses components named in `sitemap.yaml` `components` list; composition coherent | Random component choices; one giant inline JSX block |
| **Brief-fit** | Renders ALL declared `states` for the route; `covers_us` user-stories visibly addressed | Only happy-path; states ignored; user-story intent missed |

**Threshold:** Primary screens (`category: primary` and `category: auth`) MUST score ≥ 3/5 on each of the 4 dims. Marketing / admin / error screens are advisory-only — flagged in REPORT.md but don't fail the build.

**Computation:** Skill (Phase 4, inline) reads each screen file + matched sitemap entry + tokens.css + brand-voice.md; scores by inspection per dim; records the 4-dim score in REPORT.md per-screen table.

## 4. States coverage matrix (steps 02 / 07 / 13)

For each route in `sitemap.yaml`, build a matrix:

```
                  default  loading  empty  error
/                   ✓         ·        ·       ·
/login              ✓         ✓        ·       ✓
/dashboard          ✓         ✓        ✓       ✓
...
```

**Rule:** every state declared in the route's `states` field must be implemented. Primary-category routes MUST have at least `default + loading + empty + error` regardless of what the sitemap declared (skill auto-augments; gap-audit logs the augmentation).

## 5. Monorepo runs (binary; Phase 4)

- `pnpm install --frozen-lockfile` (or `bun install` for Expo) exits 0 — Phase 2 Sub-C verified at scaffold; Phase 4 re-verifies after Phase 3 screen-writes land. **Use OVERRIDE marker for supply-chain hook.**
- Dev server starts via `pnpm dev` (Next.js) / `bunx expo start --web` (Expo for web preview) without errors in first 10 seconds (OPTIONAL at standard tier — skipped if not invoked).
- `tsc --noEmit` (typecheck) exits 0 — REQUIRED ship gate.
- `biome check .` (lint) exits 0 — REQUIRED ship gate.

If any of the above fails, REPORT.md `## Build health` marks the prototype `BUILD_BROKEN` and the skill exits with a stderr block describing the failure + which Phase produced the bad output. The 13 step artifacts ARE still preserved (user can iterate the build manually).

## 6. Skill-self compliance (gate; non-skippable)

`bash .claude/skills/skill/scripts/validate.sh .claude/skills/product` exits 0 — this is the spec 033 gate, NOT optional.

## 7. PRD coverage (NEW in v2; step 13 atlas)

For step 13 atlas to pass:

- Every US-NN from `prd.md` user-story table appears in `screen-atlas.md` PRD coverage matrix as ONE OF:
  - `covered → <screen-filename>` (the screen file exists in `<out>/screens/`)
  - `deferred — <reason>` (legal-mandatory or out-of-scope at standard tier with explicit one-line reason)
- Silent omission of a US-NN is a step-13 gate failure (the matrix exists exactly to prevent it).

## 8a. Step 15b fan-out fallback (NEW in spec 057; orchestration discipline)

The per-route screen-writer fan-out at Step 15b runs in waves of cap=5. Spec 057 defines two mechanisms the orchestrator MUST apply:

- **Between-wave biome sweep (MANDATORY).** Before dispatching wave K+1, the orchestrator runs `cd <out> && node_modules/.bin/biome check --write .` (parent-side, validator-exempt). NOT conditional — runs always. Cost is ~25ms; benefit is each wave starts clean, breaking the validator-cascade.
- **Degrade-to-parent-write at N=1 same-wave (MANDATORY).** If ANY sub-agent in the current wave hits `CLAUDE_DELEGATION_LOOP_BUDGET` exhaustion, the orchestrator cancels in-flight siblings + switches remaining routes to parent-write (same brief verbatim). Threshold is N=1 (NOT N=2) because sub-agents in the same wave share lint state; first failure strongly predicts siblings will also fail.

**Gate criterion for spec 057 compliance:** if ≥1 route degraded during a run, REPORT.md `## Build health § Fan-out degradations` MUST list each degraded route with `{route, wave, reason, attempts, recovery}`. Silent degradation (parent-wrote a route without logging it) is a 057 gate failure. Degradation itself is EXPECTED behavior — the fallback works as designed; the discipline is making the recovery legible.

> **What this enables.** Repeated degradations on similar routes or briefs signal either (a) the brief needs structural attention OR (b) a fork-specific Biome rule is firing that brief-time enforcement misses. Watch the trend across dogfoods — single-route degradation is normal noise; ≥30% degradation rate is a design alarm.

## 8b. Step 15 screen-writer additions (NEW in spec 053; per-route page.tsx)

Per `delegation-briefs.md § Per-stack screen-writer CONSTRAINTS`, every Step 15 (hi-fi) route file MUST satisfy:

- **Metadata export** — `page.tsx` exports `export const metadata: Metadata = { title, description }` with route-specific title (matches sitemap display name) AND on-brand description. Exception: root marketing `/` may inherit from `app/layout.tsx`. Skill self-check: `grep -L "export const metadata" <out>/app/**/page.tsx` returns only `<out>/app/page.tsx`.
- **States implementation evidence** — for every state in the route's `sitemap.routes[i].states[]`, evidence exists: `loading` → sibling `loading.tsx`; `error` → sibling `error.tsx`; `empty` → page-internal render branch (presence of `<EmptyState`, `length === 0`, or equivalent guard). States in `deferred_states[]` are skipped. Skill self-check: per route, intersect declared states with file/grep evidence; any unmatched state = REPORT.md `## Build health § States gaps`.
- **Biome anti-pattern checklist** — `biome check` on the produced file passes WITHOUT relaxing `biome.json` rules. Specifically: no `key={i}` in `.map`, no `<div role="status|article|region">`, no `dangerouslySetInnerHTML`, no `<button>` without `type`, no `<img>` without `alt`. Skill self-check: `biome check <out>/app/` exits 0; if non-zero, the listed violations are the gap (do NOT auto-relax config to "fix").
- **Primary metric prominence** — for every route with `sitemap.routes[i].primary_metric` declared, the page renders the metric as `<MetricTile …/>`-or-equivalent hero element (full-width or major-column placement), NOT as a small badge. Skill self-check: grep the produced `page.tsx` for the metric label string; verify it appears inside a component named `MetricTile`, `Stat`, `KPI`, `Hero`, or equivalent (regex against the design-system's tile components in `<out>/docs/design-system/components.md`).

Failures here populate REPORT.md `## Build health § Step 15 brief adherence`. They do NOT block the build (validator-cascade risk per spec 057), but they DO appear in REPORT so the founder + reviewer see them.

> **Note on staleness:** the per-step table in § 1 above still references the v2 13-step pipeline ("13 — Prototype v3 / screen-atlas"). v0.3.0 (current) is 15 steps with atlas at 15a + per-route writers at 15b. The table is preserved as-is for spec 053 scope; full migration is a separate spec (058+ candidate).

## REPORT.md section mapping

Each checklist item lands in REPORT.md:

| Checklist | REPORT.md section |
|---|---|
| 1 — Per-step gate criteria | `## Pipeline coverage` (per-step status table: pass / blocked + reason) |
| 2 — Sitemap completeness | `## Coverage scorecard` (X/Y routes wired, per-category counts, gap-audit) |
| 3 — Design fidelity 4-dim | `## Fidelity scorecard` (per-screen table: route × Token / Voice / Component / Brief-fit) |
| 4 — States coverage matrix | `## States matrix` (the ASCII table above, per-route) |
| 5 — Monorepo runs | `## Build health` (install / dev-server / typecheck / lint stamps with durations) |
| 6 — Skill compliance | (not in REPORT.md — verified via `/skill validate prototype` separately, but skill prints the result in Phase 5 handoff) |
| 7 — PRD coverage | `## PRD coverage matrix` (US-NN × screens; deferred items with reasons) |
