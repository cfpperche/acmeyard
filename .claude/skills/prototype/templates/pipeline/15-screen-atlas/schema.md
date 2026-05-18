# Step 13 — Schema (prototype-v3: screen-atlas + screens + REPORT + optional flow)

The submitted `screen-atlas.md` MUST contain the level-2 markdown headings below + meet the Layer 1 size/content floor in the JSON fenced block. All listed files must be persisted via the `extra_files` parameter on `product_step_submit`. Both checks fire on submit; missing sections OR Layer 1 failures produce `code: "schema-incomplete"` with the failure list.

## Required sections (screen-atlas.md markdown headings)

Section names slugify by lowercasing + dashing — `## PRD Coverage` → `prd-coverage`, `## Open Decisions` → `open-decisions`, `## v2-Vision` → `v2-vision`. Cosmetic variants accepted (trailing punctuation, em-dashes, etc.); slugifier strips them.

- `overview`
- `screens-index`
- `prd-coverage`
- `design-fidelity`
- `states-coverage`
- `user-flow`
- `open-decisions` (the deciding-signal-bearing decision-surface; mirrors step-9 / 10 / 11 / 12)
- `v2-vision`

## Conditional / optional sections

- `audit-response` — optional dedicated H2; the audit-response narrative may live inline in `REPORT.md § Run Summary` OR as its own atlas H2. Surface as its own H2 only when ≥3 step-4 findings landed at step 13.
- `token-gaps` — optional; surfaces when step-13 screens needed a token step 6 didn't define. Flagged back to step 6 in the next iteration. Mirrors step 7 § Token Gaps.

The schema does NOT structurally enforce the product-class calibration (Micro / Mobile / Dev Tool / SMB SaaS / Venture). The prompt's § 3 enforces it discursively — a Venture-Scale product with only 4 screens (well below the 10-15 typical range) is the regression mode the discipline catches at review time, not at submit time.

## Layer 1 — file-level floor

```required_files
{
  "required_files": [
    {
      "path": "screen-atlas.md",
      "min_size": 10240,
      "contains": [
        "## Overview",
        "## Screens Index",
        "## PRD Coverage",
        "## Design Fidelity",
        "## States Coverage",
        "## User Flow",
        "## Open Decisions",
        "## v2-Vision",
        "| Screen | Covers (US-NN) |",
        "| US-NN |",
        "| Screen | Token Hygiene | Voice Match | Component Reuse | Brief Fit |",
        "Deciding signal",
        "Closed-beta partner"
      ]
    },
    {
      "path": "REPORT.md",
      "min_size": 6144,
      "contains": [
        "## Run Summary",
        "## PRD Coverage",
        "## Design Fidelity Scores",
        "## States Coverage Matrix",
        "## Recommendations",
        "[Loading]",
        "[Empty]",
        "[Error]"
      ]
    }
  ],
  "required_glob": [
    {
      "pattern": "screens/[0-9][0-9]-*.html",
      "min_count": 3,
      "per_match_min_size": 8192,
      "per_match_contains": ["<html", "<style"]
    }
  ]
}
```

### Notes on the floors

- **`screen-atlas.md` `min_size: 10240` (10 KB)** — anchored against the 8 required sections at honest depth. A SMB SaaS atlas with 8 screens (PRD coverage matrix at ~12 rows, design-fidelity table at 8 rows × 5 dims, states coverage matrix at 8×5, user-flow walkthrough at ~300 LOC, open decisions at 3 rows, v2-vision at 4 bullets) lands at 11-14 KB. Venture-scale with 12-15 screens expands to ~16-20 KB. Micro-products with 3-4 screens may legitimately land near the 10 KB floor — that floor is the universal sanity line. Step-13 floor is slightly higher than step-12's 9 KB because the atlas carries 3 dense matrices (PRD coverage + design fidelity + states coverage) on top of the narrative sections; matrix substrate is heavier than narrative.

- **The literal `## Screens Index` substring** — proves the screens-index section exists as an H2. The screens-index is the visual contract's table-of-contents; without an H2 anchor, the reader has no scan target. Mirrors step-7's `## Screen-by-Screen` discipline at the atlas layer.

- **The literal `| Screen | Covers (US-NN) |` substring** — proves the screens-index table exists as a structured markdown table (NOT prose). Each row of the table maps one screen to its PRD US-NN(s). Without this anchor, the index silently degrades to prose ("screen 01 is the landing, screen 02 is signup, …") which breaks the engineering-facing navigation discipline. Literal table-header substring only appears as a real markdown table header.

- **The literal `| US-NN |` substring** — proves the § PRD Coverage matrix exists as a structured markdown table with the `US-NN` column header. Mirrors step-11's `| Deliverable | Owner | Status |` literal-anchor pattern + step-12's `| Regulation | Trigger | Applicable? |`. The `US-NN` literal is the load-bearing column header for PRD coverage; without it, the matrix silently degrades to a "we covered everything" prose statement, which is the regression mode the discipline catches.

- **The literal `| Screen | Token Hygiene | Voice Match | Component Reuse | Brief Fit |` substring** — proves the design-fidelity 4-dim scoring table exists with all 4 dimension columns. **Calibrated 2026-05-16:** step 13 drops the standalone `Specificity` dim that step 7's 5-dim model carried (gameable in dogfood — most screens scored 4-5 on Specificity without distinguishing it from Voice or Component depth). The 4-dim model folds Specificity-as-language-precision into **Voice Match** and Specificity-as-component-precision into **Component Reuse** — both grains captured at the dimension that actually exercises them. **Audit-fix** is dropped as a standalone dim too (always `n/a` on screens with no routed finding — pure noise on the rollup table); audit-fix coverage is now narrative-only in REPORT.md § Recommendations. The full pipe-delimited fragment only appears as a real markdown table header — bare dimension words appear in prose discussion throughout the atlas, so the original substrings would be silently fakeable.

- **The literal `Deciding signal` substring** — proves at least one § Open Decisions row carries a deciding signal that closes the deferral. Mirrors step-9 / 10 / 11 / 12 § Open Decisions § Deciding signal column at the visual-contract layer — every deferred atlas decision either HOLDS or FLIPS on a measurable signal. Inherits the discipline anchor unchanged.

- **The literal `Closed-beta partner` substring** — proves the § User Flow section carries a real-human acceptance clause (mirrors step-11 KEEP 3 + step-12 inheritance). The canonical phrasing is `Closed-beta partner #N navigates the atlas unassisted and reproduces the killer flow in <5 minutes`. Cosmetic variants (`closed-beta partner #1`, `Closed-beta partner #2 walks the atlas`, etc.) all carry the literal substring `Closed-beta partner`. A user-flow section that omits this anchor is one of two things: (a) CI-only acceptance ("Atlas opens in browser without errors" — necessary-but-not-sufficient, regression mode), or (b) silently dropped the named-human acceptance discipline. Layer 1 catches both.

- **`REPORT.md` `min_size: 6144` (6 KB)** — covers the 5 required sections at honest depth. Run Summary (~1 KB) + PRD Coverage score + per-PRD-section breakdown (~1 KB) + Design Fidelity Scores table with notes (~1.5 KB) + States Coverage Matrix with summary count (~1 KB) + Recommendations (~1.5 KB) lands at 6-8 KB on a real SMB SaaS atlas. Venture-scale expands to ~10 KB.

- **REPORT.md `contains` list** — the 5 H2 anchors + 3 state-coverage column literals (`[Loading]`, `[Empty]`, `[Error]`). The bracket-named state literals only appear as real markdown table column headers (or as inline code-fenced state labels in the matrix); bare words "Loading" / "Empty" / "Error" appear in prose discussion throughout REPORT.md, so the original substrings would be silently fakeable. The bracket form restores the structural anchor.

- **`screens/[0-9][0-9]-*.html` glob** — the `01-`, `02-`, ..., `NN-` shape inherited from step 2 + step 7 (numbered-prefix discipline preserves cross-step traceability). `min_count: 3` is the **universal sanity floor** matching step 2 + step 7; the actual N is product-calibrated per `prompt.md` § 3 (Micro 3-5 / Mobile 4-7 / Dev Tool 4-8 / SMB SaaS 6-10 / Venture 10-15). The schema enforces the floor; the prompt enforces the calibration. **The floor is NOT 8** (the pre-Gap-D number) — Gap D from spec 026 calibrated screen-count to product class, and step 13 inherits the calibration discipline; below 3 is "I didn't try", above 3 is the agent's responsibility per the calibration table.

- **`per_match_min_size: 8192` (8 KB)** — bumped from step 2 / step 7's 4 KB. Step 13 screens carry the full PRD-acceptance-criterion coverage + ALL states (loading / empty / error / disabled / success) explicitly rendered + brand voice on every user-facing string + legal-surface posture commitments where applicable. The 8 KB floor matches step 2's `direction-{a,b,c}.html` floor — step 13 screens are at-direction-richness because each one is a fully-fleshed-out product surface, not a screen-sketch.

- **`per_match_contains: ["<html", "<style"]`** — the minimal HTML-shape anchors. Every screen MUST be a real HTML document (`<html` tag — the canonical full-HTML-document signal; note the loose match accepts `<html lang="en">` / `<html>` / `<!DOCTYPE html><html ...>`) with an inline `<style` block (per the self-contained-via-file:// discipline inherited from step 2 + step 7; no `<link rel="stylesheet">` to external files, NO external CSS framework references). This per_match_contains is intentionally minimal — token coverage (`:root`, `--color-`, `var(--`) is the agent's discipline per `prompt.md` § 4 step 1, not a schema enforcement here. Adding `:root` to per_match_contains would over-constrain when a screen legitimately inherits via an alias-shape (Path B from step-7 token-mapping); the prompt enforces the alias-or-direct decision, the schema enforces the HTML-shape floor.

## Section content guidance (depth, not just presence)

The schema enforces presence + floor; *depth* is the agent's responsibility, reinforced by `references/screen-atlas-format.md` + `references/states-coverage.md` + `references/prd-coverage-rubric.md` + `references/tokens-application-checklist.md`.

### `screen-atlas.md`

- **Overview** — short paragraph + 3 load-bearing one-liners (PRD coverage X/Y, visual lineage from step 7, deciding signal for engineering handoff). Names product class + chosen N + rationale up front so calibration is visible. Mirrors step-9 / 10 / 11 / 12 § Overview shape.
- **Screens Index** — markdown table (`| # | Screen | Covers (US-NN) | Extends | Concern |`) with one row per screen. The visual-contract's table-of-contents. Concern tags inherit step-11 + 12 allow-list. Source paths are `screens/NN-name.html` shape.
- **PRD Coverage** — markdown table (`| US-NN | Title (short) | Priority | Screen(s) | Acceptance Source | Status |`) with one row per US-NN from step 8 PRD. **Every US-NN appears OR is documented as deferred with reason.** Section ends with `## PRD coverage: X/Y` summary line.
- **Design Fidelity** — markdown table (`| Screen | Token Hygiene | Voice Match | Component Reuse | Brief Fit | Min |`) with one row per screen; Min column = gate indicator (✓ if ≥ 3 across all four dims). Any score < 3 should have been fixed in a pre-emit pass. **4-dim model (calibrated 2026-05-16):** Token Hygiene (formerly Token), Voice Match (absorbs Voice + Specificity-as-language-precision), Component Reuse (absorbs Component + Specificity-as-component-precision), Brief Fit (every label / number / handle sourced from the brief, not invented). Standalone Audit-fix dim is dropped — narrative-only in REPORT.md § Recommendations.
- **States Coverage** — markdown matrix (`| Screen | [Loading] | [Empty] | [Error] | [Disabled] | [Success] |`) with cells ✓ / — / `[gap]`. Per-component states-of-record live in step 6 `components.md`; matrix collapses to per-screen for atlas readability.
- **User Flow** — narrative walkthrough anchored to a real persona, traces an end-to-end session through the screens. Real-human acceptance clause (`Closed-beta partner #N navigates ...`) is mandatory.
- **Open Decisions** — markdown table (`| # | Decision | Default if no decision by | Deciding signal | Concern |`) with 2-5 rows. Decisions the atlas surfaces for `/sdd new <slug>` to resolve. Mirrors step-9 / 10 / 11 / 12 § Open Decisions discipline.
- **v2-Vision** — 3-5 bullets sketching post-v1 screen evolution. Each carries a "drives v1 atlas decision" clause. Mirrors step-11 § v2-Vision shape at the screen-atlas layer.

### `REPORT.md`

- **Run Summary** — atlas product class + chosen N + rationale; picked-direction inherited from step 7; design-system + brand-book versions; audit findings inventory; legal-driven surfaces; output paths as `file://` URLs.
- **PRD Coverage** — `X/Y` score visible at section open. Per-priority-tier breakdown (P0: 5/5; P1: 3/4; P2: 0/2). Lists deferred US-NNs with reasons.
- **Design Fidelity Scores** — same per-screen 5-dim table as atlas § Design Fidelity, plus a `Notes` column when any dimension scored < 4.
- **States Coverage Matrix** — same matrix as atlas § States Coverage, plus a summary count line ("All screens cover Loading + Error; 2 screens have `[Empty]` gaps — escalated to engineering").
- **Recommendations** — numbered list of actionable items for `/sdd new <slug>`. Each item carries a concern tag from the step-11 + 12 allow-list.

### Operating mode (declared inline; NOT a separate section)

The agent declares product class + chosen N at top of `screen-atlas.md` in § Overview opening sentence: `**v1 screen atlas for an SMB SaaS — N=8 screens covering 12 PRD user-stories (10 covered, 2 deferred to Phase 3 per step-11).**` Visible to downstream consumers (engineering opens the atlas in `/sdd new <slug>`).

## Atomic write semantics

`product_step_submit` validates ALL files in the bundle (primary `screen-atlas.md` + `extra_files` REPORT.md + screens + optional flow.html) before writing any. On any failure (missing section, undersized file, missing substring, glob count below floor) the response is `{ code: "schema-incomplete", failures: [...] }` and NOTHING is written. On success, all files persist atomically via mktemp+rename — the bundle is consistent or absent, never partial.

## Pipeline-complete behavior (step 13 closes the pipeline)

Step 13 is NOT a gate-closer (GATE_AFTER is `[4, 7, 12]` — the specification gate already fired after step 12). Per `src/pipeline.ts` § comment: "Step 13 (prototype-v3) does NOT close a phase — it's the in-phase final deliverable of specification. product_advance after step 13 fires product_done (pipeline-complete) and surfaces the /sdd handoff."

After a clean `product_step_submit` for step 13, calling `product_advance` returns:

```json
{
  "code": "pipeline-complete",
  "slug": "<slug>",
  "message": "Product planning complete. The comprehensive screen atlas at docs/product/13-prototype-v3/screen-atlas.md is the visual contract for engineering. Execution starts via /sdd new <slug> populating docs/specs/NNN-*/.",
  "next_action": "call product_done for the full handoff summary"
}
```

`product_done` then emits the per-phase deliverable inventory + the literal `/sdd new <slug>` handoff command, naming `screen-atlas.md` explicitly as the visual contract engineering builds against. Engineering opens the atlas first when starting `/sdd new <slug>`.
