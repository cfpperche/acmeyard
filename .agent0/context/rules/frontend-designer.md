---
paths:
  - ".agent0/skills/frontend-designer/**"
  - ".claude/skills/frontend-designer"
  - ".agents/skills/frontend-designer"
---

# Frontend designer

`/frontend-designer` is the build-time **craft loop** — the "artist" that designs or refines a *real, runnable* frontend with taste. It fills the implementation gap between `/product` (docs-first planning; no runnable app) and **UI acceptance** (built UI proven by a green project UI test — see `.agent0/context/rules/ui-acceptance.md`). It graduated from a decision-grade `/meeting` (Claude + Codex).

## When to use vs siblings

| Tool | Role |
|---|---|
| `/product` | product *planning* — concept→PRD→design-system doc→design-time visual contract (design source material); **no runnable app** |
| `/frontend-designer` | build-time *craft* — research references, ground in domain, reuse the DS, implement/refine UI, prove by driving |
| UI acceptance | *acceptance* — proves a built UI works via a green project UI test; `/frontend-designer` uses it as done-proof (`.agent0/context/rules/ui-acceptance.md`) |

## Load-bearing constraints (from the meeting synthesis)

- **Three modes, explicit contracts.** `create` (greenfield UI slice in the project's stack), `refine` (improve existing UI in its stack — bounded diff, before/after evidence, preserved behavior), `explore` (**2–3 distinct directions + tradeoffs + a decision gate, no code**; narrow — only when multiple directions are viable AND a human must choose first, else use `create`; not `/product`-lite). _(explore shape sharpened by the spec-158 dogfood E — its value is the multi-direction decision gate, not code-less create.)_
- **No frozen stack opinions.** Stack resolves via a project-derived ladder (existing stack+DS → `/product` system-design → user hint → research+record-decision); never a bundled skeleton/default. Existing design systems are reused, not reinvented. (project memory `feedback_no_shipped_stack_opinions`)
- **Reference research is mandatory + artifacted** — a git-tracked `reference-research.md` + `design-direction.md` pair per surface (active SDD spec dir, else `docs/design/<surface>/`). Mechanisms are free, local+remote: web search/fetch + `agent-browser.sh` screenshots + `rg` repo scan.
- **Done-proof is a green project UI test** — browser-renderable output ⇒ declare `UI impact: ui` and prove the surface with the project's idiomatic UI/e2e runner covering it (see `.agent0/context/rules/ui-acceptance.md`). **No declared UI test runner is a BLOCKER, never a pass** (`scripts/frontend-designer.sh verify` exits rc 4 and points at provisioning one). Native-only surfaces use a project web harness if present, else honest, **labeled** native build/test evidence — never a false UI-test claim, and **no new native visual tooling** (rule-of-three demand test).
- **The "artist" is context-engineering, not a persona** (project memory `feedback_no_persona_role_prompting`). Taste comes from grounding + the see-and-critique loop, bounded by explicit stop criteria + a max-iteration cap.
- **`/image` is an opt-in enhancement, never a hard dep** (decision-grade meeting 2026-06-06, dogfood-proven). `create`/`refine` MAY add an on-brand `/image --tier=draft` placeholder to a surface that needs imagery — behind a **tracked-neutral default** + graceful degradation (key absent / no-credits / 402 / network → `image-fallback:<reason>`, build+contract still pass). Draft-only auto; **never brand assets** (logo/wordmark = `/product`); generated image is decorative (contract asserts text, not the bitmap); one attempt per surface, outside the critique loop; never `explore`. See `references/imagery.md`.
- **Dependency footprint is tiny:** shell, `rg`, `jq`, the project package manager, `agent-browser.sh`; everything else detect-don't-impose. No global design dashboard / reference cache (harness-drift).

## Files

Skill canonical: `.agent0/skills/frontend-designer/` (`SKILL.md`, `scripts/frontend-designer.sh`, `templates/`, `references/{craft-loop,stack-ladder,reference-research,done-proof}.md`, `tests/`), discovered via `.claude/skills/frontend-designer` + `.agents/skills/frontend-designer` symlinks. Deterministic mechanics: `scripts/frontend-designer.sh` (`caps | detect | artifacts-dir | scaffold-docs | verify`).
