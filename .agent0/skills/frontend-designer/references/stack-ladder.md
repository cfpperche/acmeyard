# Stack ladder — detect and adapt, never impose

Agent0 ships **no frozen stack opinions** (repo rule; project memory `feedback_no_shipped_stack_opinions`). `frontend-designer` therefore never reaches for a default framework, a starter template, or a bundled skeleton. It resolves the stack from the project, and when the project can't decide, it researches and records an open decision — it does not silently pick.

## The ladder (first rung that resolves wins)

1. **Existing project stack + design system.** `scripts/frontend-designer.sh detect <project>` reports framework, design-system, package manager, and whether the surface is browser-renderable. If the project already *is* something, that is the stack. Full stop — do not "modernize" or re-platform under the guise of design.
2. **`/product` system-design.** If `/product` artifacts are present (`detect` → `product_artifacts: present`), read the system-design doc and use its declared stack.
3. **Explicit user hint.** `--platform <web|expo|react-native|tauri|electron|...>` or a stack named in the request. A hint, applied only when rungs 1–2 are silent.
4. **Research + record an open decision.** Nothing above resolved (e.g. a truly empty greenfield with no guidance). Web-research the current canonical options for the platform/domain, present the tradeoffs, and **record an open decision in `design-direction.md`** (or ask the human). Only then write code. Never let the absence of guidance become a hidden default.

**Always record which rung decided** in `design-direction.md` § Stack & design-system resolution. A reviewer must be able to see *why* this stack, not just *which*.

## Design system: reuse before invent

When `detect` finds a design system — Tailwind config, token files, shadcn (`components.json`), Radix/MUI/Chakra deps, a `/product` design-system doc, or the open-design vendor — **read it and reuse its tokens/components**. Only *propose* new tokens when none exists, and say so explicitly in the direction doc ("proposing — no DS exists"). Reuse means the output visibly uses the existing primitives, not a parallel set.

## Detect-don't-impose tool catalog (all free, local + remote)

Add a tool **only** when the resolved stack or the researched plan justifies it — never as a default:

| Concern | Free, local+remote options (detected, not imposed) |
|---|---|
| Styling / DS | Tailwind, shadcn/ui, Radix, vanilla CSS / CSS modules, the project's existing system |
| Design tokens | Style Dictionary, the project's token files |
| Fonts | Fontsource (npm, local), Google Fonts (remote) — both free |
| Icons | lucide, Heroicons, the project's existing set |
| Preview / render harness | the project's dev server, Vite, Storybook/Ladle, Expo web, web-preview |
| Reference capture & drive | `agent-browser.sh` (in-repo), web search/fetch |

Paid services are never a hard dependency. `/image` (fal) is the one sanctioned opt-in *enhancement* — draft-tier on-brand placeholder imagery for a built surface, behind a tracked-neutral default + graceful degradation (see references/imagery.md); never brand assets (that's `/product`), never required.
