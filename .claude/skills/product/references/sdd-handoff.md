# SDD handoff — the Phase 5 contract

`/product` does **not** generate a runnable app. It ends at the **visual contract** (Phase 4 — `screen-atlas.md` + the hi-fi killer-flow mood + `fixture-spec.md`) and then, in Phase 5, **scaffolds the SDD specs the engineering build runs as**. This doc is the contract the orchestrator (`SKILL.md` § Phase 5) executes.

The motivating evidence: the deleted v2/v3 per-route screen-writer fan-out tried to generate ~36 Next.js `page.tsx` files in a blind parallel pass and the output quality collapsed (2026-05-19/20 dogfood). Making a blind fan-out produce responsive, consistent, visually-verified UI is a hard problem the original `/product` design lost. The fix is not a better fan-out — it is to stop fanning out: hand a *contract* to SDD, which is built for deliberate, harness-disciplined, visually-fed implementation. `/product` keeps what it does well (design synthesis → a visual contract) and stops doing what it does badly (generating screens).

## What Phase 5 produces

Two spec directories under `<out>/docs/specs/`, written **directly** (NOT via a `/sdd new` skill-to-skill call — `/sdd new` only does mkdir + template-copy + placeholder substitution; it deliberately does not *fill* `spec.md`, and `/product` must fill from pipeline artifacts):

| Dir | Role | What `/product` fills |
|---|---|---|
| `<out>/docs/specs/001-<slug>/` | **umbrella spec** — tracks the whole v1 build | `spec.md` filled (`**Type:** umbrella` + child-spec matrix + standing constraints); `plan.md` / `tasks.md` / `notes.md` left as `.agent0/skills/sdd/templates/*.tmpl` scaffolds (an umbrella ships no code — the matrix in `spec.md` IS its tracking surface) |
| `<out>/docs/specs/002-foundation/` | **child #1 — foundation** (skeleton + tooling + route-group dirs + thin layout shells) | `spec.md` filled (ready to start); `plan.md` / `tasks.md` / `notes.md` left as scaffolds (the founder runs `/sdd plan` then `/sdd tasks` on it) |

Children #2..N are **matrix rows in the umbrella's `spec.md` only** — NOT pre-scaffolded. Eight empty child dirs that sit untouched for months are clutter; the founder materializes each via `/sdd new <phase-slug>` when reaching it (the spec-060 umbrella pattern).

When `docs/system-design.md § Stack` declares non-trivial backend services or a monorepo, Phase 5 emits additional **infra children** between child #2 component-library and the per-phase visual children — one per `docs/roadmap.md` Fase 1 deliverable that has no owner among the per-phase visual children. Children #3..M are infra (block-precede); children #(M+1)..N are the per-phase visual children, renumbered accordingly.

Use `.agent0/skills/sdd/templates/{spec,plan,tasks,notes}.md.tmpl` as the base for every file. Substitute `{{NNN}}` / `{{SLUG}}` / `{{DATE}}` as `/sdd new` would; then overwrite the body sections `/product` fills.

## The umbrella spec — `001-<slug>/spec.md`

Header: `# 001 — <slug>`, `**Status:** draft`, `**Type:** umbrella` (the `Type:` line per `.agent0/context/rules/spec-driven.md` § The four artifacts).

Fill each section from the pipeline artifacts:

- **Intent** — one paragraph: this umbrella tracks building the `<product>` v1 app from the `/product` visual contract. Name the inputs by path: `docs/screen-atlas.md` (the navigable contract), `docs/prd/v1.md` (US-NN scope), `docs/sitemap.yaml` (route inventory), `docs/design-system/` (tokens + components), `docs/fixture-spec.md` (shared mock-data contract), `docs/roadmap.md` (the phases this matrix is sliced by). State that the umbrella ships nothing itself — acceptance is the closure of every child row.
- **Acceptance criteria** — the umbrella is `shipped` when every child-matrix row has a `→ NNN` link to a created child spec OR a `closed: <reason>` marker. One plain-bullet criterion per `required_categories` group from the sitemap is a good shape ("every `auth` route from `docs/sitemap.yaml` is owned by a child spec").
- **Non-goals** — implementing any screen in this spec (child specs do that); re-running the `/product` pipeline; shipping v2 surfaces flagged in the atlas § Open Decisions.
- **Open questions** — carry forward the atlas § Open Decisions rows (they are integration-shape decisions the build resolves).
- **Context / references** — links to the five contract artifacts above + `docs/REPORT.md` + this skill's spec lineage.
- **Child-spec matrix** — see below. This is the load-bearing section.
- **Standing constraints** — see below.

### Child-spec matrix

A markdown table, one row per child spec. Child #1 + #2 are fixed; children #3..N are **sliced by the phases in `docs/roadmap.md`** (one child per roadmap phase, scoped to the screens that phase's user stories touch).

```markdown
## Child-spec matrix

| # | Child spec | Scope | Roadmap phase | Status |
|---|---|---|---|---|
| 1 | `002-foundation` | App skeleton + tooling (Biome, tsc, Tailwind + tokens.css wiring) + route-group dirs per sitemap `chrome` + thin `layout.tsx` shells | (pre-phase — unblocks all) | scaffolded → `002-foundation/` |
| 2 | component-library | Build the shared component set from `docs/design-system/components.md` + `tokens.css`; wire components into the foundation's `layout.tsx` shells | (pre-phase — unblocks all) | matrix-only — `/sdd new component-library` |
| 3 | monorepo-backbone | Turborepo + Bun workspaces + 9 packages per `docs/system-design.md § Stack` (shared, db, core, integrations, llm, notifications, api, workers, web) | Fase 1 — infra | matrix-only — `/sdd new monorepo-backbone` |
| 4 | schema-rls | Postgres schema + RLS policies per `docs/system-design.md § Services` | Fase 1 — infra | matrix-only |
| 5 | auth-foundation | Auth flow (provider + session) per `docs/system-design.md § Services` | Fase 1 — infra | matrix-only |
| 6 | brasilapi-integration | BrasilAPI client + caching layer per `docs/roadmap.md` Fase 1 | Fase 1 — infra | matrix-only |
| 7 | <roadmap phase 1 title> | Screens for the user stories in roadmap phase 1 | Phase 1 | matrix-only — `/sdd new <slug>` |
| … | … | … | … | … |
```

Infra children are derived from `docs/roadmap.md § Phases § Fase 1 | Deliverable | Owner | Status |` rows that don't map to any per-phase visual child. Their slugs are short kebab-case names extracted from the deliverable prose (e.g. "Monorepo Turborepo + Bun workspaces" → `monorepo-backbone`). One infra child per unmatched deliverable; no granularity cap (the founder can dismiss-or-merge rows in the umbrella before starting per OQ#1 default).

- **Child #1 = foundation** — always. Scaffolded by `/product`.
- **Child #2 = component-library** — always. Its input spec is `docs/design-system/components.md` + `tokens.css` (so `components.md` becomes a real upstream spec, not a decorative doc — this closes F5). It wires the components into child #1's `layout.tsx` shells, so the shared chrome (sidebar, topbar, marketing header) lives in ONE child rather than being re-invented per screen (closes F4).
- **Children #3..M = infra children** — one per `docs/roadmap.md` Fase 1 deliverable that doesn't map to a per-phase visual child. Zero when the system-design declares a simple single-app frontend with no backend services (visual-only product). Block-precede the per-phase visual children because every infra child unblocks downstream visual work.
- **Children #(M+1)..N = per-phase visual children** — one per `docs/roadmap.md` phase. Each owns the screens whose `covers_us` (from `docs/sitemap.yaml`) maps to that phase's user stories.

### Standing constraints

Every child spec inherits these — state them once in the umbrella's `## Standing constraints` section so each `/sdd new <child>` reads them as the build contract:

- **Styling.** The styling system is whatever `docs/system-design.md § Stack` declares. If Tailwind, then v4 with `@theme` from `docs/design-system/tokens.css` (Next: `app/globals.css` `@import`s `tokens.css` directly; Expo/NativeWind v4: translate to `tailwind.config.js` `theme.extend` because NativeWind 4 cannot consume a v4 `@theme` file directly — NativeWind v5 / Tailwind v4 is pre-release as of 2026-05). If styled-components / vanilla-extract / Panda CSS / etc., the foundation child's `/sdd plan` researches the canonical token-binding pattern for that system and cites sources per `.agent0/context/rules/research-before-proposing.md`. **No inline `style={{}}` for layout or positioning** regardless of styling system — inline style cannot carry a breakpoint and is how mobile-first dies. (A single dynamic value — a computed bar width — is the lone exception.) This closes F1 (mobile-first) and F2 (sanctioned inline style) at the build layer.
- **Mobile-first.** Author for the 375 px viewport; layer wider layouts via Tailwind responsive prefixes (`sm:` / `md:` / `lg:`). Every screen reflows with no horizontal overflow at 375 px. The hi-fi mood screens at `docs/screens/hifi/` are the rendered mobile-first reference.
- **Fixture coherence.** Every screen imports the ONE shared fixture set the foundation child implements as `lib/mock-data.ts` from `docs/fixture-spec.md`. No screen invents its own mock data (closes F9).
- **UI acceptance.** A child that produces UI declares `UI impact: ui` and is accepted by a **green project UI test** covering the changed surface, authored *from* the atlas + hi-fi mood + fixture-spec (those are the test-writing input, not the acceptance proof). See `.agent0/context/rules/ui-acceptance.md`. The `agent-browser` primitive (`agent-browser.sh audit … --structure optional` over `file://`; no MCP, spec 153; screenshot 375 px + 1280 px, check horizontal overflow) is a dev-time aid for driving and debugging the UI until the test is green — it is not an acceptance artifact.

## Child #1 — `002-foundation/spec.md`

Header: `# 002 — foundation`, `**Status:** draft` (no `Type:` line — it is a normal feature spec).

- **Intent** — scaffold the runnable skeleton so the component-library and per-phase children have a place to land: the app skeleton for the stack declared in `docs/system-design.md § Stack`, the tooling (typechecker + linter the stack uses + the styling system declared in § Stack wired to `docs/design-system/tokens.css`; see § Standing constraints), the route-group directories (one per distinct `chrome` value in `docs/sitemap.yaml`), and **thin** layout shells per route group (structural placeholders — the real shared chrome components are child #2's job; child #2 wires them into these shells).
- **Acceptance criteria** — Given/When/Then scenarios + static facts:
  - Dev server starts clean per the declared stack's canonical command (researched at `/sdd plan` time and recorded in `plan.md`).
  - Typecheck exits 0 (the typechecker the declared stack uses).
  - Lint exits 0 (the linter the declared stack uses).
  - A token utility (`bg-primary` or the styling-system equivalent identified during research) resolves to the value in `docs/design-system/tokens.css`.
  - One route-group directory exists per distinct `chrome` value in `docs/sitemap.yaml`; each has a thin layout shell appropriate to the declared stack.
  - `lib/mock-data.ts` (or the stack-equivalent location identified during research) implements the `docs/fixture-spec.md` entity set.
- **Non-goals** — the shared chrome *components* (sidebar, topbar, marketing header) — those belong to child #2; the feature screens — those belong to children #3..N.
- **Context / references** — `docs/system-design.md § Stack` (the binding stack contract — read it BEFORE planning), `docs/sitemap.yaml`, `docs/design-system/tokens.css`, `docs/fixture-spec.md`. **The foundation child's `/sdd plan` runs web research per `.agent0/context/rules/research-before-proposing.md`** to determine the current canonical setup (package manager, framework version pins, config files, dev scripts) for the declared stack; cites sources in `plan.md § Research / citations`. No Agent0-bundled template is consumed — none ships. Scaffold the app at the `<out>/` root (sibling to `docs/`) so the styling system's relative imports of `docs/design-system/tokens.css` resolve.

`plan.md` / `tasks.md` / `notes.md` for child #1 stay as template scaffolds — the founder runs `/sdd plan` then `/sdd tasks` to fill them. (`/product` fills `spec.md` only because intent is the part that derives mechanically from the pipeline artifacts; the *how* is the founder's engineering judgment.)

## Open questions migration

Phase 5 copies every row from `docs/system-design.md § Trade-off Triggers → Open Decisions` into the umbrella `spec.md § Open questions`, prefixed `**Architecture — <topic>:**`, so undecided architectural choices surface before any child consumes them. The umbrella's existing OQs from `docs/screen-atlas.md § Open Decisions` remain (integration-shape decisions); the two sources interleave by topic. No de-duplication — if the same decision appears in both, leave both rows so the build sees both surfaces.

## Fallback — roadmap has no usable phase structure

`docs/roadmap.md` normally defines 3 phases (MVP / Growth / Polish) with user-flow-shaped titles — those become children #3, #4, #5. If the roadmap is degenerate (no phases, or one undifferentiated blob), do NOT invent phases. Emit a **single** child #3 named `app-build` scoping every non-foundation, non-component-library screen, and note in the umbrella `## Child-spec matrix` that the roadmap lacked phase structure so the build is one child. The founder can split it later via `/sdd new`.

## Numbering

`<out>/docs/specs/` is a fresh tree (created by Phase 0). The umbrella is `001-<slug>`, foundation is `002-foundation`. Children #3..N are matrix rows — when the founder runs `/sdd new <slug>` for one, `/sdd` assigns the next `NNN` automatically. The matrix rows do not need pre-assigned numbers; they carry slugs.

## Cross-references

- `SKILL.md` § Phase 5 — the orchestration body that executes this contract
- `.agent0/context/rules/spec-driven.md` § The four artifacts — the `**Type:** umbrella` convention
- `.agent0/skills/sdd/templates/` — the four template files used as the scaffold base
