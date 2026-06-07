---
name: diagram
description: Generate deterministic technical diagrams from a text source (opt-in, local, free). Use when the user wants an architecture, flowchart, sequence, ER, class, or state diagram rendered to a tracked SVG/PNG/PDF asset - for a system-design doc, spec, product UI/slide/PDF, or a README needing a real image file. Wraps .agent0/tools/diagram.sh. The deterministic sibling of /video --mode code and the technical counterpart to /image (organic/photo, paid) - a /transcribe-class LOCAL/FREE utility (provenance, no cost/key/tiers). Source is Mermaid, rendered via mmdc (npx, no global install) reusing system Chrome; degrades to validation-only when Chrome is absent (source kept, never dead). NOT organic imagery (/image), motion (/video), or design craft (/frontend-designer). Flags - "<source.mmd|mermaid text>" [--kind flowchart|sequence|erd|class|state|architecture] [--format svg|png|pdf] [--out <dir>] [--theme <builtin>] [--json] [--exit-code]; subcommands doctor / caps. See .agent0/context/rules/diagram.md.
argument-hint: "\"<source.mmd | mermaid text>\" [--kind ...] [--format svg|png|pdf] [--out <dir>] [--theme <builtin>]"
license: MIT
compatibility: Designed for Claude Code. Core logic is the runtime-neutral bash tool `.agent0/tools/diagram.sh` (mmdc via npx + system Chrome); the skill is a thin invocation wrapper. Codex CLI invokes the tool directly.
metadata:
  agent0-portability-tier: agentskills-portable
  version: "0.1"
---

# /diagram — deterministic technical-visual generation

Thin wrapper over `.agent0/tools/diagram.sh`. The tool is the engine; this skill decides when to run it and how to surface the result. See `.agent0/context/rules/diagram.md` for the full capacity contract (local/free stance, the Mermaid-only v1 decision, system-Chrome reuse, the validation-only degradation, the storage split, and the boundaries vs `/image` / `/video` / `/frontend-designer`).

## When to run

Run on demand when the user wants a **technical diagram as a real asset file** — architecture, flowchart, sequence, ER, class, or state — from a text spec: a system-design doc, an SDD spec, a product UI/slide/PDF, a marketing page, a README that needs an embedded image (not a live fenced block). It is **deterministic and free** (no paid lane). It is **not** organic/photo imagery (that's `/image`), **not** motion (`/video`), **not** visual-design craft (`/frontend-designer`), and **not** a replacement for GitHub/GitLab's native Mermaid rendering.

## What to do

1. **Parse `$ARGUMENTS`** — the source is required (a `.mmd` file path **or** inline Mermaid text):
   - `"<source>"` — a path to a `.mmd` file, or inline Mermaid (e.g. `"flowchart TD\n A-->B"`).
   - `--kind flowchart|sequence|erd|class|state|architecture` — advisory (Mermaid auto-detects from the source; used for naming + the manifest).
   - `--format svg|png|pdf` — default **svg**.
   - `--out <dir>` — output dir. Default is `assets/diagrams/` (reusable, tracked); pass `--out docs/specs/NNN-*/diagrams` for a **spec-owned** diagram.
   - `--theme default|dark|forest|neutral` — Mermaid built-in theme only (no custom styling — that's design work).

2. **Invoke the tool:**
   ```bash
   bash .agent0/tools/diagram.sh "$ARGUMENTS"
   ```

3. **Surface the result** — first line `diagram: status=<ok|unavailable|error>`:
   - **`ok`** — report the written asset path AND the tracked `.mmd` source path (the source is the durable artifact). Note it stayed local + free.
   - **`unavailable`** — no usable Chrome/Node to render. The source was still **validated (structural) and kept** — relay the install hint (`google-chrome`/`chromium`); this is a degraded success, not an empty result.
   - **`error`** — the source isn't valid Mermaid (structural check) or `mmdc` failed (syntax). Relay the diagnostic; the source is preserved for the user to fix.

4. **It's free + local, always** (`stayed_local:true`) — no cost is printed, no key needed. Don't reach for `/image` for a diagram, or `/diagram` for a photo.

5. **Diagrams are keepers** — the `.mmd` source belongs in git (it is the real, editable artifact). There is no throwaway-draft class; embed the rendered SVG in docs and commit both.

## Discipline

- Local/free by nature — never add a cost gate or paid lane (that's the `/image` class, not this).
- Mermaid only in v1 — don't reach for d2/graphviz/Kroki (d2 is a documented reopen-trigger if the Chrome dep becomes painful).
- Styling stays minimal (built-in themes) — custom visual identity / layout craft is `/frontend-designer`.
- A diagram is **generated documentation requiring review**, never proof an architecture is correct — the renderer compiles syntax, not truth.

## Notes

_Consumer-extension surface — append consumer-local bullets here._

- Render reuses the **system** Chrome via a generated puppeteer config (`PUPPETEER_SKIP_DOWNLOAD=1`) so npx pulls only the JS package, not a second browser.
- `mmdc` is acquired ephemerally via `npx -p @mermaid-js/mermaid-cli mmdc` (first run fetches + caches). Override with `DIAGRAM_MMDC` / `DIAGRAM_CHROME_BIN` if needed.
