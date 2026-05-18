# Pipeline coverage — 15 steps × 4 phases at "standard" tier (v3)

How `/prototype` v3 (spec 045) maps the 15-step industry-aligned product pipeline onto the 4 agile phases. **Single tier — "standard".** Lightening per step is fixed by this doc; no `--fast`/`--deep` flag soup.

Industry-aligned per spec 032's 17 decisions ported via spec 045 (Cagan/SVPG · Teresa Torres OST · GDPR Art 25 shift-left · Stage-Gate · Lenny Rachitsky 1-pager · April Dunford positioning). For the heavy canonical pipeline at full rigor, invoke `mcp__product-pipeline__*` tools directly (out of scope for `/prototype` — that's spec 032's MCP scope).

## Phase ↔ step map

| Phase | Pipeline steps | Gate at end? | Bulk wall-clock target |
|---|---|---|---|
| **Phase 1 — Discovery** | 01-ideation · 02-prototype (lo-fi) · 03-spec · 04-ux-testing | ✓ AskUserQuestion (`gate_discovery`) | 8-12 min |
| **Phase 2 — Specification** | 05-prd · 06-ost · 07-sitemap-ia · 08-system-design · 09-legal · 10-roadmap · 11-cost-estimate · 12-gtm-launch | ✓ AskUserQuestion (`gate_specification`) | 18-25 min |
| **Phase 3 — Identity** | 13-brand · 14-design-system | ✓ AskUserQuestion (`gate_identity`) | 6-10 min |
| **Phase 4 — Visual contract** | 15-screen-atlas | (no gate; closes with `/sdd new`) | 5-8 min |

**Total target: 35-55 min** end-to-end for a clean run (longer than v2's 30-45 min because Phase 2 grew from 5 steps → 8). Add ~5 min per gate iteration if user picks `iterate`. Realistic worst case ~90-120 min with one iteration per phase + parent-side `biome check --write` mitigation between phases.

## Per-step output + size targets (standard tier)

Sizes are TARGET CEILINGS (not minimums per spec 036 finding #3 — sub-agents tend to overshoot when treating size as "≥"; treating as hard ceiling forces concise output). Going materially under target may trigger BLOCKED; going materially over (≥1.5× ceiling) triggers a warning + sub-agent ABORT-and-re-emit suggestion.

| # | Step | Sub-agent model | Output file(s) (paths relative to `<out>/`) | Size target (standard) | Industry source |
|---|---|---|---|---|---|
| 01 | Ideation | **opus** | `docs/01-concept-brief.md` (includes § Market Sizing TAM/SAM/SOM) | 4-10 KB | extends per spec 032 Decision 6 |
| 02 | Prototype v1 (lo-fi) | sonnet × N | `docs/02-direction-a.html` (1 only at standard) + `docs/02-screens/<NN>-<name>.html` × 3-5 (killer flow) | direction ≥ 6 KB, screens ≥ 4 KB each | unchanged from v2; **sitemap moved to Step 07** |
| 03 | Spec | sonnet | `docs/03-functional-spec.md` (includes § Problem-Validation Interviews) | 8-12 KB | extends per spec 032 Decision 6 |
| 04 | UX Testing | sonnet | `docs/04-validation-report.md` (YAML frontmatter) | 5-8 KB | unchanged from v2 |
| 05 | PRD (1-pager hybrid) | sonnet | `docs/05-prd.md` (Lenny 1-pager bones + 3 our-specific sections; US-NN stable IDs; NSM slot) | 4-7 KB (TIGHTER than v2's 6-10) | spec 032 Decisions 1 + 9 + 15 |
| 06 | OST | sonnet | `docs/06-ost.md` (Opportunity Solution Tree — 1 outcome root → 3-5 opportunities → 2-3 solutions per) | 3-6 KB | spec 032 Decision 12 (Torres) |
| 07 | Sitemap-IA | sonnet | `docs/07-sitemap.yaml` (schema-bound to `references/sitemap-schema.md` — `required_categories: [marketing, auth, primary, admin, error]` enforced) | 2-5 KB | spec 032 Decisions 5 + 13 (load-bearing root-cause fix) |
| 08 | System Design | sonnet | `docs/08-system-design.md` (bridge-floor + § RACI + § Risk Register) + `docs/08-security.md` + `docs/08-data-flow.json` (consumed by Step 09) | sd ≥ 12 KB, sec ≥ 3 KB, data-flow ≥ 1 KB | spec 032 Decision 10 |
| 09 | Legal posture | sonnet | `docs/09-legal-posture.md` (DPIA-triggered by Step 08 data-flow; shift-left per Decision 4) | 4-7 KB | spec 032 Decision 4 (GDPR Art 25 + IAPP shift-left) |
| 10 | Roadmap | sonnet | `docs/10-roadmap.md` (3-phase sketch — defines phases consumed by Step 11) | 5-8 KB | **moved before cost per spec 045 cost↔roadmap swap** |
| 11 | Cost Estimate | sonnet | `docs/11-cost-estimate.md` (single-scenario; uses Step 10 phases + Step 09 legal-review budget) | 5-8 KB | **moved after roadmap per spec 045** |
| 12 | GTM-launch | sonnet | `docs/12-gtm-launch.md` (positioning canvas Dunford + launch plan 4-week sketch + pricing strategy) | 4-7 KB | spec 032 Decision 7 (Stage-Gate stage 6 + April Dunford) |
| 13 | Brand | sonnet | `docs/13-brand-book.md` | 4-8 KB (2-3 section snapshot) | spec 032 Decision 3 (moved after Specification — PRD-first) |
| 14 | Design System | sonnet | `docs/14-tokens.css` (imported by `app/globals.css` as `@import "../docs/14-tokens.css"`) + `docs/14-components.md` + `docs/14-design-system.md` | tokens ≥ 1.5 KB, components ≥ 3 KB, ds ≥ 8 KB | unchanged content; renumbered |
| 15 | Screen atlas (hi-fi) | sonnet × N (cap=5) | `docs/15-screen-atlas.md` (with sitemap coverage cross-check + PRD coverage matrix) + `app/**/*.tsx` page files for ALL sitemap routes + `app/_components/*.tsx` (legal-mandatory surfaces from Step 09) + project `REPORT.md` at `<out>/docs/REPORT.md` | atlas ≥ 8 KB, screens ≥ 6 KB each | spec 032 Decision 8 + 14 (absorbs deleted Step 7 prototype-v2 work) |

## Lightening op applied per step (single-tier "standard" decisions)

1. **01 Ideation:** 5-8 web searches (vs 15-25 canonical); ~10KB brief target; skip `critique mode`. **NEW (Decision 6):** § Market Sizing — TAM/SAM/SOM as 1-paragraph each, NOT primary research, desk research with 1-2 cited sources per number.
2. **02 Prototype v1 (lo-fi):** ONE direction only (vs 3 mood boards); 3-5 killer-flow screens; **sitemap NO LONGER produced here** (moved to dedicated Step 07).
3. **03 Spec:** Combined `functional-spec.md` (no separate architecture.md). **NEW (Decision 6):** § Problem-Validation Interviews — 3-5 summaries, synthetic OK at standard tier, seeds OST opportunities.
4. **04 UX Testing:** Heuristic-only (Nielsen 10 + WCAG 2.1 AA top issues). Projected-mode default. Validation mode declaration required.
5. **05 PRD (1-pager):** Lenny bones (Problem · Why now · Success metrics · Solution sketch · User stories · Anti-goals) + 3 our-specific (Release scope · NSM-dedicated-slot · Upstream/downstream refs). 4-7 KB TIGHT — each section ≤3 bullets to preserve 1-pager honesty. US-NN stable IDs (P0/P1/P2). ONE NSM in dedicated slot.
6. **06 OST:** 1 desired outcome (the NSM from PRD) → 3-5 opportunities (user problems discovered/inferred) → 2-3 solutions per opportunity (the "how"). Sibling artifact to PRD, NOT embedded — feeds the post-launch-review sibling tool when MCP-side ships it.
7. **07 Sitemap-IA:** YAML with schema-enforced `required_categories: [marketing, auth, primary, admin, error]`. Each route has `path / category / states / covers_us / components`. Top-level `deferred_categories: [{name, reason}]` escape clause for genuinely-out-of-v1 categories (must include reason). Orchestrator parses + BLOCKS step if uncovered category found without deferral. **Mechanical fix for atlas under-cover (Pass E silent gap on auth/admin/error).**
8. **08 System Design:** Bridge-floor (6 sections: stack, integrations, data model, decisions locked, security, observability) + **NEW (Decision 10)**: § RACI Matrix + § Risk Register. Also produces `docs/08-data-flow.json` — structured data-flow inventory consumed by Step 09 legal for DPIA trigger.
9. **09 Legal:** Brief checklist (regulations, sub-processors, IP) + DPIA section IF Step 08 data-flow includes sensitive categories (PII/health/minors/financial). Reads `docs/08-data-flow.json` to determine DPIA trigger. **Shifted left per Decision 4** — informs Step 11 cost (legal review budget) + Step 12 GTM (compliance signals).
10. **10 Roadmap:** 3-phase sketch (MVP / Growth / Polish) with user-flow-shaped titles. **Defines phases for Step 11 cost** — cost calculates per-phase using THESE phase boundaries (not implicit ones).
11. **11 Cost Estimate:** Single-scenario burn rate, per-phase from Step 10's phase boundaries + Step 09's legal-review budget. Skip bear/base/bull + sensitivity + unit economics.
12. **12 GTM-launch:** Positioning canvas Dunford-lite (2-3 lines: who-for / alternative-to / why-better) + launch plan 4-week sketch (week-by-week milestones) + pricing strategy (free/standard/pro tier shape if relevant). Skip full launch playbook (post-PMF concern).
13. **13 Brand:** 2-3 section snapshot (voice samples + visual direction posture + "we are/we are not" pair). Synthesizes from finalized PRD + sitemap + system-design (no longer from half-formed concept brief like v2). Skip founder-interview turn.
14. **14 Design System:** Catalog-path PREFERRED (1-2 vendors from `od-catalog-index.json`); custom-derive fallback. Resist token inflation (8-14 colors, 5-7 type scales).
15. **15 Screen atlas:** Full sitemap coverage (all `required_categories` routes) + legal-mandatory surfaces from Step 09 + PRD coverage matrix. **Absorbs the brand+tokens-applied work of deleted Step 7** — there is no separate intermediate prototype; this IS the hi-fi pass.

## Bundled-template provenance + drift discipline

All 15 step prompts + schemas + references live at `.claude/skills/prototype/templates/pipeline/<step>/`. **Source: spec 045 derives each template from spec 032's 17 decisions, NOT copied from `packages/mcp-product-pipeline/src/templates/`** (the MCP package is mid-realign via spec 032's child specs 037-044 — neither side is "the canonical" until both land).

**Drift sync:** `.claude/REMINDERS.md` carries a quarterly item (due 2026-08-18) to diff bundled vs canonical when both sides have landed. Currently divergent by design — spec 045 ships first as scout, spec 032 follows.

**Why bundle (not symlink or runtime-read):** the skill is standalone — must work in a fork that lacks `packages/mcp-product-pipeline/`. Bundle is the price of portability.

## Two-prototype-pass rationale (v3 — collapsed from v2's three)

Spec 032 Decision 8 collapses the 3-prototype-pass into 2. Spec 045 ports:

- **Step 02 (Pass 1 — lo-fi):** Which visual direction resonates? Pre-brand, pre-tokens. Killer flow only. Mood HTML.
- **Step 15 (Pass 2 — hi-fi):** Does the COMPLETE product surface cohere with brand + tokens + audit fixes + PRD coverage? Post-Specification + Identity. Full coverage matrix. Real Next.js / Expo screens.

The deleted v2 Step 7 (prototype-v2 brand-tuned) was a redundant mid-step (3-stage felt over-engineered per Cagan SVPG "Flavors of Prototypes"). Its work (brand + tokens applied to killer-flow surfaces) is absorbed by Step 15 — the hi-fi atlas IS the brand-tuned pass.

Tombstone: `docs/specs/045-prototype-skill-pipeline-realign/artifacts/deleted-step-7-prototype-v2.md` preserves the v2 content for rollback or reference.

## Cross-references

- `state-machine.md` — phase/step progression, `.state.json` v3 shape, resume support
- `delegation-briefs.md` — 16 sub-agent briefs (15 step + 1 per-stack screen-writer)
- `sitemap-schema.md` — required_categories enforcement (load-bearing for Step 07)
- `od-catalog-index.json` — Step 14 catalog path vendor index (72 vendors at 2026-05-18 snapshot)
- `quality-checklist.md` — per-step gate criteria + per-screen 4-dim rubric
- `docs/specs/045-prototype-skill-pipeline-realign/` — spec/plan/tasks driving this refactor
- `docs/specs/032-pipeline-industry-alignment/` — parent industry-alignment spec (the 17 decisions ported here)
