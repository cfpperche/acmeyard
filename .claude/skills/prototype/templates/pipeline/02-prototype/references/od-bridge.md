# OD Bridge — grounding step 2 directions in the vendored Open Design bundle

This document teaches the agent how to consume the vendored **Open Design (OD)** bundle that ships *inside* the `agent0-mcp-product-pipeline` package (spec 027). It is the grounded replacement for `pipeline.md`'s inline 5-school description: instead of inventing palette/typography from training data, the agent reads a pinned, vendored `DESIGN.md` per direction and cites it by name in `REPORT.md`.

Ported from anthill's `anthill-prototype/references/od-bridge.md`. Anthill injected the vendor via symlink, so it used relative `.anthill/vendor/...` paths. This package ships inside `node_modules/` of an arbitrary consumer project — **the agent never hardcodes vendor paths. It asks the MCP for absolute paths.**

## The two MCP tools

| Tool | Returns | When |
|------|---------|------|
| `product_design_systems_index` | The full 72-system index (`{name, mood, palette_summary}` each) **plus** a `vendor_paths` map of absolute roots (`design_systems`, `skills`, `prompts`, `frames`, `templates`) | Once, at the start of step 2 — to pick which systems ground which direction, and to learn where the vendor tree lives |
| `product_design_system_path` | `{name, path}` — the absolute path to one system's `DESIGN.md` | Per chosen system — feed `path` straight to your `Read` tool |

If either tool returns `code: "od-vendor-missing"`, the vendor bundle is absent (broken install); if it returns `code: "od-disabled"`, OD grounding was deliberately switched off via `PRODUCT_PIPELINE_OD=off`. In both cases: do **not** silently fall back — surface the error, then consult the "Manual escape" section of `pipeline.md` (the pre-OD inline 5-school method).

## Pre-flight reads (do once, before writing any HTML)

Run in order. Reading these *before* writing prevents re-deriving defaults the vendored assets already encode.

```
1. product_design_systems_index
   → the 72-system catalogue + vendor_paths (absolute roots)
   → scan moods/palettes; shortlist 1-4 systems per direction (a/b/c)

2. product_design_system_path("<system>")  — for each shortlisted system
   → Read the returned DESIGN.md path
   → this is the compositional source for that direction: palette roles,
     typography rules, component stylings, layout principles, do's/don'ts

3. <vendor_paths.prompts>/directions.extracted.md
   → the 5 canonical visual schools, full specs — map each direction to one
     school (or justify a blend, citing both)

4. <vendor_paths.prompts>/discovery.extracted.md
   → discovery-form structure, if step 2's discovery turn needs one

5. <vendor_paths.skills>/web-prototype/SKILL.md
       + assets/template.html  (seed: token system + class inventory)
       + references/layouts.md  (paste-ready section skeletons)
       + references/checklist.md  (P0/P1/P2 self-review)
   → for a marketing-led brief, use saas-landing/ instead of web-prototype/
```

OD skill selection heuristic:
- Multi-screen app prototype → `web-prototype`
- Primarily a marketing landing → `saas-landing`
- Both → `web-prototype` (covers landing + app screens in one file)

## The 5 canonical schools

Source of truth: `<vendor_paths.prompts>/directions.extracted.md`. Each direction the agent emits maps to ONE school, or explicitly justifies a blend in `REPORT.md`.

| id | Label | Mood |
|----|-------|------|
| `editorial-monocle` | Editorial — Monocle / FT magazine | Print-magazine feel, serif, off-white + ink + warm rust |
| `modern-minimal` | Modern minimal — Linear / Vercel | Dark or near-white, system fonts, cobalt accent, content-led |
| `warm-soft` | Warm & soft — Stripe pre-2020 / Headspace | Cream bg, serif display, terracotta accent, fintech-friendly |
| `tech-utility` | Tech / utility — Datadog / GitHub | Data-dense, monospace, dark or light + grid, ops-focused |
| `brutalist-experimental` | Brutalist / experimental — Are.na / Yale | Loud type, visible grid, hot-red accent |

The `directions.extracted.md` vendored file carries the full per-school spec (palette families, type stacks, school-specific OpenType tells). Read it — do not work from this table alone.

## Grounding rule — DS citation is mandatory

Each direction (`direction-{a,b,c}.html`) must be composed from **1-4 named vendored design systems**, and `REPORT.md` must cite them by name with the path that grounded them:

```
### Direction A — <codename>
School: modern-minimal
Design systems consulted:
  - linear-app  (design-systems/linear-app/DESIGN.md) — palette roles, cv01/ss03 OpenType
  - vercel      (design-systems/vercel/DESIGN.md)     — hairline borders, weight-300 display
```

This is the citation chain that makes 3 directions genuinely distinct: their grounding sources are distinct, not their prompt-engineered variety. `schema.md` enforces a `Design systems consulted` section in `REPORT.md`.

## Build phase

Follow `pipeline.md` § *Build phase* for the per-direction HTML scaffold, the 8 required surfaces, the token-system enrichment guidance, and the hard rules. The OD bridge adds two grounding obligations on top of that playbook:

1. **Seed from the vendored template, not from scratch.** Copy `<vendor_paths.skills>/web-prototype/assets/template.html` as the starting token system + class inventory. Replace the `:root` tokens with palette values *taken from the consulted DESIGN.md files* — verbatim, not improvised.
2. **Apply the school-specific tells from `directions.extracted.md`** — e.g. the Linear-anchored direction carries `font-feature-settings: "cv01", "ss03"` on body.

Frames (`<vendor_paths.frames>/{iphone-15-pro,macbook,browser-chrome}.html`) are optional device-chrome wrappers for screen mocks.

## Anti-AI-slop hard rules

Unchanged from `pipeline.md` § *Anti-AI-slop hard rules* — that P0 gate still applies. The vendored `checklist.md` (`<vendor_paths.skills>/web-prototype/references/checklist.md`) carries the OD project's own P0/P1/P2 list; run both.

## PT-BR product considerations

When the brief indicates a Brazilian product:

- All copy in PT-BR (landing, onboarding labels, dashboard states, error messages)
- Currency: `R$ 19,90`, not `$19.90`
- Payment surface: Pix-first (QR Code prominent), cartão and boleto secondary
- Token-economy UX: saldo visible in header, cost badge on action buttons (`Otimizar CV · 3🪙`), double-confirm for ≥ 5 tokens
- Mobile-first layouts; contrast AAA for primary text; 44px minimum touch targets
- LGPD privacy link in footer — required, not optional
