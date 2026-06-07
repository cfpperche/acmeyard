---
name: frontend-designer
description: Design or refine a real frontend with taste — the build-time "artist" that researches references, grounds in the product domain, reuses the project's design system, and proves the result by driving it. Use when creating or refining UI (web, mobile, desktop, any platform) and you want design-led, evidence-backed implementation — not planning (that is /product), not just an acceptance check (the visual-contract gate). Three modes - create (greenfield UI slice in the project stack), refine (improve existing UI in its stack), explore (research + direction only, no code). Always researches references first, writing a git-tracked reference-research.md + design-direction.md pair. Adapts to the project's stack via a project-derived ladder — never a frozen default; reuses an existing design system before inventing. Done reuses agent-browser verify-contract (spec 155); unavailable is a blocker, never a pass. Helper - scripts/frontend-designer.sh.
license: MIT
compatibility: Compatible with any agentskills.io-compatible runtime (Claude Code, OpenAI Codex, Cursor, Goose, OpenCode, and others). Uses only universal primitives — file IO, shell, and web research — plus the in-repo agent-browser.sh for reference capture and visual proof. No Claude-only primitive in the core loop.
metadata:
  agent0-portability-tier: agentskills-portable
  version: "0.1"
argument-hint: <create <surface> | refine <surface> | explore <surface>> [--platform <p>] [--spec NNN] [--from <path>]
---

# /frontend-designer — the frontend artist

Design or refine a **real, runnable frontend** with taste. This skill is the build-time **craft loop** that sits in the gap between Agent0's two adjacent UI capacities:

- **`/product`** does docs-first product *planning* (concept brief → PRD → design-system doc → design-time visual contract) and **does not generate a runnable app**.
- The **visual-contract acceptance gate** (spec 155) *proves* a built UI by driving it (`agent-browser.sh verify-contract` → `report.json`).

`frontend-designer` is what turns intent + references + (optional) design system into **good-looking, working UI with evidence**. It never re-does `/product`'s planning, invents no new acceptance gate (it reuses spec 155), and ships **zero frozen stack opinions** — it detects and adapts. The "artist" is a context-engineered *loop*, not a persona: research → direction → implement → drive-and-see → critique → refine.

> Graduated from a decision-grade `/meeting` (Claude + Codex): `.agent0/meetings/frontend-designer-skill-design-2026-06-06T01-30-48Z/meeting.md`. Spec: `docs/specs/158-frontend-designer-skill/`.

## Argument parsing

User invokes as `/frontend-designer <subcommand> <surface> [flags]`. The raw argument string is `$ARGUMENTS` — parse it yourself (positional substitution differs across runtimes). First token = mode (`create` / `refine` / `explore`); second = a kebab `<surface>` name (e.g. `dashboard`, `checkout`, `settings-screen`). Flags: `--platform <web|expo|react-native|tauri|electron|...>` (a hint, not an override of the ladder), `--spec NNN` (write design docs into that SDD spec dir), `--from <path>` (target project root; default `.`). Unknown mode → refuse with the argument-hint line.

The deterministic mechanics live in `scripts/frontend-designer.sh` (`caps | detect | artifacts-dir | scaffold-docs | verify`). The *craft* — taste, design judgment, code — is yours. The references carry the depth: `references/{craft-loop,stack-ladder,reference-research,done-proof,imagery}.md`. **Read the relevant reference before the step that needs it.**

## The craft loop (all modes share it; see references/craft-loop.md)

1. **Ground.** Run `scripts/frontend-designer.sh detect <project>` to learn framework / design-system / `/product` artifacts / browser-renderable harness / package manager. Read any `/product` design-system doc, brand, fixture-spec, and the relevant SDD spec. Build the domain brief: who is the user, what is the task, what platform.
2. **Resolve the stack** via the ladder (references/stack-ladder.md) — never a frozen default. Record which rung decided it.
3. **Research references (mandatory).** Web-search domain patterns, platform conventions, and accessibility norms; use `agent-browser.sh run -- ...` to visit and screenshot real exemplars; `rg` the repo for existing tokens/components. Write `reference-research.md` (every row: source · domain relevance · pattern borrowed · pattern **rejected** · implementation consequence). See references/reference-research.md.
4. **Set direction.** Write `design-direction.md` — domain-grounded tokens (reuse the existing design system; only *propose* when none exists), the feel, the surfaces. Scaffold both docs with `scripts/frontend-designer.sh scaffold-docs <project> --surface <s> [--spec NNN]`.
5. **Implement** the UI in the resolved stack, reusing detected DS primitives. If the surface needs imagery, author a tracked **neutral** default first; an on-brand `/image --tier=draft` is an opt-in *override* with graceful degradation (references/imagery.md) — never brand assets, never a hard dep.
6. **Drive and see.** Run the surface; capture it with `agent-browser.sh` and look at the actual rendered result against your references.
7. **Critique → refine.** Compare to the references and the direction; fix the gaps. Loop steps 5–7 until the **explicit stop criteria** are met or the **max-iteration bound** (default 4) is hit (references/craft-loop.md). Stopping is a declared decision, not exhaustion.
8. **Prove done** (references/done-proof.md) — see § Done-proof.

## Modes

### `create <surface>` — greenfield UI slice
Build a new UI surface (screen / component / flow) **in the project's resolved stack**. Not a whole app — a coherent, runnable slice. Requires: a target project (even an empty one), a domain brief. Produces: runnable UI code + the `reference-research.md`/`design-direction.md` pair + done-proof evidence. **Acceptance:** the surface renders, reuses (or explicitly proposes) the design system, and passes its done-proof.

### `refine <surface>` — improve existing UI
Operate on an existing codebase's UI **in its current stack** (never re-platform silently). Requires: the existing surface + a stated intent (what's wrong / the goal). Produces: a **bounded diff** that preserves behavior, plus **before/after evidence** and the design-doc pair (one compact pair per surface; update, don't duplicate). **Acceptance:** before/after evidence shows the improvement, behavior is preserved, the diff is bounded, and the critique loop stopped on explicit criteria — not a sprawling rewrite.

### `explore <surface>` — design direction only (no code)
Narrow, opt-in. **Use it only when (a) multiple visual directions are genuinely viable AND (b) the choice belongs to a human/stakeholder before any code** — e.g. an undecided audience or brand language. If the direction is already implicit, skip `explore` and use `create` (whose research phase already produces one direction) — otherwise `explore` is just `create` without the commit.

The defining shape (what makes it *not* a code-less `create`): produce **2–3 distinct directions** with proposed token seeds + honest tradeoffs, a recommendation, and an explicit **decision gate** that stops and hands the choice back — **no code**. Requires: a domain brief. Produces: `reference-research.md` + a `design-direction.md` presenting the N directions + tradeoffs + decision gate. **Acceptance:** a human can pick a direction (or hybrid) from it and that choice feeds a later `create`/`refine`. This is **not** `/product`-lite — no PRD, no moodboard pipeline, no image generation. If you find yourself planning the *product*, stop: that's `/product`.

## Stack stance — detect and adapt, never impose (see references/stack-ladder.md)

Resolution ladder, in order; the first that resolves wins, and you **record which rung decided**:
1. existing project stack + design system (from `detect`);
2. `/product` system-design stack, if `/product` artifacts are present;
3. explicit user `--platform`/stack hint;
4. otherwise **research current canonical options and record an open decision / ask** before writing code.

Never consume a bundled skeleton or a hardcoded default (repo rule: no shipped stack opinions). Detected, free, local+remote tools (Tailwind, shadcn, Radix, Style Dictionary, Fontsource/Google Fonts, lucide icons, Storybook, Vite, Expo, Tauri, …) are **detect-don't-impose** — add one only when the project stack or the researched plan justifies it.

## Done-proof — reuse spec 155, fail closed (see references/done-proof.md)

- **Browser-renderable output:** declare `**UI impact:** render|interaction|flow` in `design-direction.md`, write a `fixture-spec.json` (template in `templates/`), and run `scripts/frontend-designer.sh verify <url> fixture-spec.json <outdir>` → a green `report.json`. **`agent-browser` unavailable is a BLOCKER (rc 4), never a pass.**
- **Native-only surfaces** (no Expo-web/Storybook/web-preview harness): use a project-provided browser-renderable harness if one exists; otherwise ship code + native build/test evidence **explicitly labeled "not visual-contract proof."** Do **not** add new native visual tooling — that is deferred behind the rule-of-three demand test.
- **Animated / WebGL / 3D surfaces:** the gate proves the semantic+interaction surface, **not motion fidelity**. A painting WebGL canvas isn't in the a11y tree → mark it decorative (`aria-hidden`), meaning in real text; prove "renders & animates" programmatically (`eval` of a frame counter), labeled build/runtime evidence. Honor `prefers-reduced-motion` with an explicit Play/Pause opt-in. See references/done-proof.md § Animated.

## Dependencies

Hard deps (tiny, all free, local+remote): shell, `rg`, `jq`, the project's package manager, and `agent-browser.sh` (machine-opt-in; check `scripts/frontend-designer.sh caps`). Everything else is detect-don't-impose. **`/image` (fal, paid+remote-only) is never a hard dep** — but it's an opt-in *enhancement* for on-brand draft imagery on a built surface, behind a tracked-neutral default and graceful degradation (see references/imagery.md). The skill works fully at zero key/credits/cost via the neutral path.

## Artifacts & locations

- `reference-research.md` + `design-direction.md` — **git-tracked decision records**, one compact pair per surface, in the active SDD spec dir (`--spec NNN`) if SDD-driven, else `docs/design/<surface>/`. Resolve with `scripts/frontend-designer.sh artifacts-dir`.
- `agent-browser` screenshots / `report.json` — gitignored runtime **evidence**, linked from the docs, not committed.
- No global reference cache or "design dashboard" — that would be harness-drift.

## Eval scenarios

### Eval 1: create on a project with a design system
**Input:** `/frontend-designer create dashboard --from ./app` where `./app` is Next + Tailwind + shadcn.
**Expected:** `detect` reports the stack; references researched + `reference-research.md` written; `design-direction.md` **reuses** the shadcn/Tailwind tokens (proposes nothing new); runnable dashboard built; `verify` returns a green `report.json`. Stack ladder rung 1 recorded.
**Failure:** invented a new token set despite an existing DS; no reference research; claimed done without a green report; introduced a framework the project doesn't use.

### Eval 2: refine an existing surface
**Input:** `/frontend-designer refine checkout --from ./shop` with intent "the form feels cramped and fails a11y."
**Expected:** bounded diff in the existing stack; before/after evidence; preserved behavior; critique loop stops on the stated criteria; design-doc pair updated, not duplicated.
**Failure:** re-platformed; unbounded rewrite; no before/after evidence; loop ran to exhaustion with no stop criterion.

### Eval 3: native surface, no design system, agent-browser path
**Input:** `/frontend-designer create profile-screen --from ./mobile --platform expo`, no DS present.
**Expected:** ladder proposes a minimal token set (records "proposing — none exists"); if `react-native-web`/Storybook exists, real render evidence via that harness; otherwise code + native build/test evidence **labeled "not visual-contract proof."** No new native visual tooling added.
**Failure:** claimed visual-contract proof for a native-only surface; added a bespoke screenshot tool; froze a default stack.

### Eval 4: agent-browser unavailable
**Input:** `verify` on a machine without agent-browser/Chrome.
**Expected:** `scripts/frontend-designer.sh verify` exits rc 4 with a `BLOCKER` message; done is **not** claimed.
**Failure:** treated unavailability as a pass.

## Notes

- The "artist" is **context-engineering, not role-play** (repo rule: no persona/role-prompting). Taste comes from grounding + the see-and-critique loop, not a SOUL.md.
- This skill produces UI in *consumer* projects; this skill's own files are not a UI surface.
- Run `bash .agent0/skills/skill/scripts/validate.sh .agent0/skills/frontend-designer` before committing.
- _Consumer-extension surface — append consumer-local bullets here; sync flags this file as `!! customized` if edited, conflict region is mechanically this section._
