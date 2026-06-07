---
paths:
  - ".agent0/skills/diagram/**"
  - ".agent0/tools/diagram.sh"
  - "assets/diagrams/**"
---

# Diagram

`/diagram` (engine `.agent0/tools/diagram.sh`) is **deterministic technical-visual generation** — architecture, flowchart, sequence, ER, class, state diagrams from a **Mermaid text source**, rendered **locally, zero-cost, git-trackable**. It is the **deterministic sibling of `/video --mode code`** and the **technical-visual counterpart to `/image`** (organic/photo/raster, paid). Following the structured-capacity contract, it is a **`/transcribe`-class LOCAL/FREE utility**: a provenance manifest (not a cost ledger), no `FAL_KEY`/tiers/`--confirm-cost-usd`, `status` decoupled from exit, `doctor`/`caps`, rule as propagation vehicle, honest degradation. Graduated from the decision-grade meeting `.agent0/meetings/diagram-capacity-technical-visuals-2026-06-06T22-34-59Z/` (blind openings converged independently; ledger 7 claims / 0 assertion-only; `synthesis: accepted`). Spec: `docs/specs/162-diagram/`.

## Why it exists (the demand)

Structural pull, honestly stated. **In-repo consumer:** `/product` emits `system-design`/`sitemap-IA`/`OST` as prose with no diagrams, and SDD specs want architecture diagrams. **Principal value (founder framing):** via consumer products — especially **cognixse, which serves software-development companies that ship diagrams as product artifacts** (mei-saas benefits too) — a product lever across a vertical, not just internal tooling. **Minority report (preserved):** there is no *measured* consumer request yet, only structural pull — so consumer harness-sync is gated on a v1 dogfood proving the asset path against real artifacts.

## Mermaid-only v1 (the source language)

Source = **Mermaid**, chosen (both runtimes converged independently) because the agent *writes* these and Mermaid is the language LLMs are most fluent in, covering all v1 families in one syntax: flowchart/architecture, sequence, ER, class, state. d2 (single Go binary, no Chrome), Graphviz (`dot`), and Kroki (multi-engine server) are **rejected for v1**: Kroki violates the local/free posture (remote = network dep; local = a server/container surface before the need is proven); d2/graphviz lose Mermaid's coverage + authoring fluency. **d2-first is a documented reopen-trigger** if dogfood shows the Chrome/Puppeteer dependency pain dominates.

## Render path + the validation-only degradation

`mmdc` (`@mermaid-js/mermaid-cli`) renders in headless Chrome via Puppeteer, acquired ephemerally through **`npx -p @mermaid-js/mermaid-cli mmdc`** (the `-p` flag because package name ≠ command; the `/video` HyperFrames-npx posture — no global install). Two acquisition-weight mitigations: the engine **reuses the system Chrome** (detects `google-chrome`/`chromium`, writes a puppeteer config with `executablePath` + `--no-sandbox`) and sets `PUPPETEER_SKIP_DOWNLOAD=1` so npx pulls only the JS package, not a second browser.

**Degradation (the meeting's key resolution) — never a dead capacity.** When no usable Chrome is found, `/diagram` does not die: it runs a **Chrome-less structural validation** (the first non-comment line must name a known Mermaid diagram type) and **preserves the tracked source**, returning `status=unavailable` for the *render step* with a one-line install hint. A garbage source is caught as `status=error` (structurally, before mmdc) with the source kept for the user to fix.

## Surface

`diagram.sh "<source.mmd | mermaid text>" [--kind flowchart|sequence|erd|class|state|architecture] [--format svg|png|pdf] [--out <dir>] [--theme default|dark|forest|neutral] [--json] [--exit-code]`, plus `doctor`/`caps`. `--kind` is advisory (Mermaid auto-detects; used for naming + manifest). Result status `ok|unavailable|error` decoupled from exit (default exit 0; `--exit-code` maps `ok=0 unavailable=2 error=3`).

## Storage — diagrams are keepers (no throwaway-draft class)

- **Default** → `assets/diagrams/` (tracked, reusable product diagrams).
- **Spec-owned** → `--out docs/specs/NNN-*/diagrams/`.
- The `.mmd` **source is always tracked** — it is the real, editable artifact (inline text is persisted as `<stem>.mmd` next to the render). Rendered SVG/PNG is tracked when embedded in docs.
- **No gitignored draft class** (the deliberate departure from `/image`'s draft-vs-asset split) — diagrams belong in git from the first render.
- **Manifest** → cumulative gitignored JSONL (`assets/generated/.diagram-manifest.jsonl`), one line per call (success AND failure): `{ts,status,source_sha256,kind,format,engine,source,output,stayed_local:true}`. No cost fields, no key.

## Boundaries

- vs **`/image`** — organic/photo/raster, paid (fal). `/diagram` is technical/deterministic/free. Don't use `/image` for a diagram or `/diagram` for a photo.
- vs **`/video --mode code`** — HTML/CSS/JS → MP4 motion (Chrome). `/diagram` is static SVG/PNG.
- vs **`/frontend-designer`** — design/styling craft. `/diagram` only does Mermaid built-in themes; custom visual identity / layout is design work, out of scope.
- vs **GitHub/GitLab native Mermaid** — `/diagram` produces a tracked **asset file** for surfaces with no live renderer (product UI/docs/slides/PDF, marketing) + `.mmd` validation + pinned reproducibility; it is NOT a README-renderer replacement.

## Non-goals & reopen-triggers

- **Second source language (d2/graphviz/Kroki)** — Mermaid only v1; **d2-first** reopens if Chrome-dep pain dominates.
- **Paid lane / cost apparatus** — free/local by nature; no key/tiers/cost gate.
- **Design / custom styling** — minimal built-in-theme passthrough only (→ `/frontend-designer`).
- **Semantic/architecture correctness** — generated documentation requiring review, never proof of truth.
- **`/product` auto-emit from system-design** — explicitly **v2**.
- **Animated/interactive diagrams** — static only (motion is `/video --mode code`).

## Family coherence

Shares the structured-capacity contract with `/transcribe` (local/free, provenance not cost, status-decoupled, `doctor`/`caps`, honest degradation) and the npx + headless-Chrome acquisition with `/video --mode code`. The split is by **output ontology**: `/diagram` compiles a text spec into a static technical visual; `/image` generates organic raster (paid); `/video` produces motion.
