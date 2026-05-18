# Tokens application checklist — how step 6 tokens.css + step 5 brand voice land on every screen

Step 13 inherits the step-7 token-mapping discipline (`07-prototype-v2/references/token-mapping.md`) and extends it to the full screen atlas. This page is the per-screen checklist the agent runs before submitting — confirming tokens are consumed correctly, brand voice tunes every user-facing string, and the cross-step traceability (token → step 6 / voice → step 5 / component → step 6 / audit-fix → step 4 / US-NN → step 8) holds for every screen.

## The substitution contract (inherited from step 7)

Step 6's `tokens.css` is the canonical value layer. Every color / type / spacing / radius / shadow value in step-13 screens resolves to a `var(--token)` defined there. Step 7 already established the substitution path; step 13 inherits the **same decision** (Path A direct-rename OR Path B alias-in-`:root`) without re-deciding. Read `07-prototype-v2/references/token-mapping.md` for the full mechanics.

**Inheritance discipline:** if step 7's `direction-final.html` and `screens/*.html` used Path A (direct rename of step-2 primitives to step-6 semantics), step 13's screens use Path A. Same for Path B. Mixed path is a discipline failure — engineering opening a step-13 screen with Path A and a sibling screen with Path B can't grep consistently across the atlas.

**To verify the path step 7 picked:** open any `docs/product/07-prototype-v2/screens/*.html`, look at the `:root` block. If it has `--color-canvas` / `--color-foreground` / `--color-accent` (step 6's semantic names) and CSS rules use `var(--color-*)`, Path A. If it has step-6's tokens declared PLUS a `--background: var(--color-canvas)` alias block, Path B. Inherit the same shape for step 13.

### Pattern A vs Pattern B is a continuum, not a binary

The Path A (inline-verbatim) / Path B (alias-in-`:root`) split inherited from step 7 reads as binary on first encounter but is actually a continuum calibrated to the engineering target:

- **Pattern A (inline verbatim)** — every screen's `<style>` opens with the canonical `:root { ... }` from step 6 `tokens.css`, repeated literally per screen. Optimizes for `file://` visual inspection — a reviewer opens a screen, the tokens are right there in the file; no cross-file resolution needed. Cost: token edits at step 6 must re-apply across N screens.
- **Pattern B (shared-stylesheet shape with aliases)** — the `:root` declares step 6's tokens once + a per-screen alias block (`--background: var(--color-canvas)`) that adapts the canonical tokens to per-screen semantic intent. Optimizes for the engineering shape — when step 13's atlas lands at a real CSS pipeline (Tailwind config, CSS modules, design-tokens build), the alias layer is the substrate. Cost: a `file://` reviewer needs to resolve the alias chain mentally.
- **The continuum between A and B** — most real atlases land at a *mostly-A-with-some-B* shape: tokens inline verbatim per screen (Pattern A discipline) PLUS a small alias block for screen-specific semantic adaptation (`--current-issue-bg: var(--color-canvas-elevated)` for a triage screen). The split is not 100% one pattern; it's "which pattern dominates the screen's `:root` block".

The agent's job is to inherit the dominant pattern step 7 picked, NOT to re-decide between A and B per screen. A step-13 screen with Path A dominant on screen 02 and Path B dominant on screen 03 is a discipline failure — engineering cannot grep consistently across the atlas.

### When step 7 is absent or skipped

When the product class genuinely has no step-7 prototype-v2 artifact (CLI-tool, dev-tool with no killer-flow visual surface, micro-product that skipped step 7 per the conditional-step calibration), step 13 cannot inherit a pattern from step 7. The fallback discipline:

- **Default to Pattern A (inline verbatim)** — no shared CSS pipeline exists yet, so the alias layer Pattern B optimizes for has no downstream consumer. The `file://` visual-inspection optimization Pattern A delivers IS the use case; engineering execution at `/sdd new <slug>` decides the alias shape later based on the chosen stack (Tailwind / CSS modules / vanilla / etc.).
- **Switch to Pattern B only when a real CSS pipeline lands** — if step 13 is rendered AFTER a stack decision (e.g., the spec named Tailwind upfront and the design-system was already authored as Tailwind tokens), the alias layer Pattern B requires can be authored against the named pipeline. Until then, Pattern A is the honest default.

**Worked example: CLI-tool product class (no step 7 in the pipeline).** A CLI helper with `--help` text rendering + 1 error-output surface + 1 settings-config command output has no step-7 visual lineage. Step 13 renders the 3 screens with Pattern A inline — `:root` declares the (minimal) step 6 tokens.css content verbatim in each screen; no alias layer; CSS rules use `var(--color-*)` directly. The shared-stylesheet shape Pattern B optimizes for has no downstream consumer because CLI helpers do not ship a CSS bundle. Engineering at `/sdd new <slug>` will likely never need an alias layer at all (the "screens" are HTML mockups of CLI output, not React components); Pattern A stays for the lifetime of the atlas.

**When the founder later upgrades the CLI to a desktop UI** (post-v1, separate spec), step 13 may be re-run with a real step 7 + design-system pipeline; the new pattern decision (A or B) ships at that re-run, not retroactively patched into the original step-13 artifact.

## The per-screen checklist

For every screen `docs/product/13-prototype-v3/screens/<NN>-<name>.html`, the agent runs this checklist before submitting:

### 1. `:root` block is verbatim from step 6 tokens.css

- [ ] Open `docs/product/06-design-system/tokens.css`. Copy the `:root { ... }` content verbatim into the screen's `<style>` block.
- [ ] Confirm every token category (color / type / spacing / radius / optionally shadow) is present. Token gaps surface in REPORT.md § Recommendations, not silently invented inline.
- [ ] Confirm the path (A or B) matches step 7's inherited choice.

### 2. Every value resolves to a `var(--token)`

- [ ] No bare hex literals (`#0066cc` → `var(--color-accent)`).
- [ ] No bare rem/px values for spacing — use `var(--space-N)` per step 6.
- [ ] No bare font-family declarations — use `var(--font-body)` / `var(--font-display)` / `var(--font-mono)`.
- [ ] Border-radius values: use `var(--radius-N)` per step 6 (or `var(--radius-none)` for brutalist directions).
- [ ] Shadow values (when present): use `var(--shadow-N)` per step 6; OR document the absence in step 6 if the direction is hairline-only (per step-7 token-mapping § When a screen needs a token step 6 didn't define).

### 3. Brand voice tunes every user-facing string

- [ ] Open `docs/product/05-brand/brand-book.md` § Voice samples (ON-brand and OFF-brand pairs).
- [ ] Read every user-facing string on the screen (page title, h1, h2, CTA labels, form-field labels, placeholder text, empty-state messages, error messages, success messages, tooltips, microcopy).
- [ ] For each string, ask: does it read in brand voice? If yes, ✓. If no, rewrite to match the brand-book sample.
- [ ] Concrete strings, NOT placeholders. NO `[error message]`, NO lorem ipsum, NO "Lorem ipsum dolor sit amet".
- [ ] Brand name (when step 5 picked a final name different from step 1's placeholder) propagates verbatim. Silent placeholder-name shipping is the failure mode this rule prevents.

### 4. Component composition follows step 6 components.md

- [ ] Open `docs/product/06-design-system/components.md`. For each component on the screen (button, input, modal, list, card, toast, etc.), confirm:
   - [ ] The anatomy (HTML structure) matches `components.md § <Component> § Anatomy`.
   - [ ] The variants used (primary / secondary / ghost / etc.) are declared in `components.md § <Component> § Variants`.
   - [ ] The states rendered (loading / empty / error / disabled / success) cross-reference `components.md § <Component> § States`. See `references/states-coverage.md` for the matrix discipline.
- [ ] No invented components. A screen that needs a component step 6 didn't define is a step-6 gap — back-flag in REPORT.md § Recommendations, do NOT invent inline.

### 5. Audit-fix annotation per finding

- [ ] For every step-4 finding routed to this screen (per step-13 prompt § 2 signal 3), annotate the inline fix locus with `<!-- fix(F-NN): applied at step 13 — reason: ... -->`.
- [ ] The HTML comment is the in-source audit trail. A reader of the HTML diff between step 7 and step 13 sees WHY each change happened.

### 6. Self-contained file discipline (inherited from step 7)

- [ ] No `<link rel="stylesheet" href="...">` — inline the `:root` block verbatim in `<style>`.
- [ ] No `@import url(...)` of remote fonts — system-stack fallbacks only.
- [ ] No external CSS frameworks (Tailwind, Bootstrap, etc.).
- [ ] No external JS frameworks. Interactivity is CSS-only unless an interaction is core to the screen's contract (in which case it's vanilla JS inline in `<script>`).
- [ ] The file opens via `file://` and renders fully without network access. Test by `xdg-open` / `open` / browser-open and confirm visually.

### 7. Screen header comment carries cross-step traceability

- [ ] At the top of the screen's HTML (before `<!DOCTYPE html>` or right after `<head>`), include the lineage comment:
   ```html
   <!--
     screen: 05-killer-flow.html
     covers: US-07, US-19 (step 8 PRD)
     extends: step 7 screens/05-triage-view.html
     fix: F-12 (step 4; resolved at v2 — preserved here), F-22 (step 4; deferred from v2, applied at v3)
     tokens: step 6 tokens.css v1 (Path A — direct rename)
     voice: step 5 § Voice § Direct posture
     legal: n/a (no consent / disclosure surface on this screen)
   -->
   ```
- [ ] This is the in-source audit trail; the atlas + REPORT cite it as the source-of-record per screen.

### 8. Legal-surface screens (when applicable)

- [ ] Step 12 `legal-posture.md` § Privacy Posture + § Regulated Aspects + § AI-Specific (when fires) drives mandatory legal surfaces (consent dialog, privacy notice, ToS acceptance, AI-disclosure badge, age-gate when COPPA triggered).
- [ ] On legal-surface screens, the literal posture commitments from step 12 appear verbatim. NOT placeholders, NOT generic SaaS templates.
- [ ] Example: consent dialog includes the legal-basis text from step-12 § Privacy Posture § Data categories table. The "I consent to processing my email for account creation under GDPR Art 6(1)(b) Contract" string is the literal that ships, not "I consent to terms".
- [ ] Sub-processor surfaces (when present) list the actual vendors from step-12 § Data Handling § Sub-processor disclosure table.

## Cross-step traceability (5-step chain)

A reader of any step-13 screen should be able to trace any visual choice through:

1. **The `:root` block → step 6 `tokens.css`** (the value layer)
2. **A `<!-- fix(F-NN): ... -->` HTML comment → step 4 findings** (the audit-driven changes)
3. **A user-facing string → step 5 brand-book voice samples** (the brand layer)
4. **A component structure → step 6 `components.md` § Anatomy + § States** (the system layer)
5. **A US-NN reference → step 8 PRD § User Stories + § Acceptance Criteria** (the requirements layer)

PLUS the step-13-specific 6th link:
6. **A screen filename → step 8 PRD US-NN coverage matrix in `screen-atlas.md` § PRD Coverage** (the visual-contract layer)

When any link in the chain breaks (a `var(--unknown-token)`, a string with no brand-book echo, a component shape that doesn't match `components.md`, a screen covering no US-NN, a US-NN with no screen), that's a defect to surface in REPORT.md § Recommendations.

## Self-critique 5-dim scoring (inherited from step 7 + extended)

For each screen, score 1-5 across the 5 dimensions (same as step 7):

1. **Token fidelity** — every color / type / spacing value reads from a `var(--token)`; no raw literals; the `:root` block matches step 6's `tokens.css` exactly (or with documented aliases per Path B).
2. **Brand voice in copy** — every user-facing string reads in brand voice per step 5's samples; no generic SaaS filler; no off-brand drift.
3. **Component fidelity** — components compose per step 6's `components.md` (anatomy + states + variants); no invented components; states the screen needs are present.
4. **Audit-fix coverage** — every step-4 finding routed to this screen is materially applied; the inline `<!-- fix(F-NN) -->` comment exists; the fix passes its acceptance.
5. **Brief specificity** — every word / number / label sourced from the brief or self-citable; no filler; no invented metrics.

Any dimension < 3/5 requires a fix pass before emit. Two fix passes is normal. Document the pre-emit scores in `screen-atlas.md` § Design Fidelity AND `REPORT.md` § Design Fidelity Scores. If a screen scores 5/5 across the board on the first pass, that is *also* worth noting — uniform 5s either reflect a fast convergence (good) or a bias-toward-passing (suspicious; pressure-test by spot-checking the inline tokens vs the brand voice rules).

## Atlas-level rollup (inherited from step 11 + 12 calibration)

The per-screen 5-dim table rolls up at the atlas layer in `screen-atlas.md` § Design Fidelity. The atlas table is the same shape as REPORT.md § Design Fidelity Scores BUT without the Notes column — the atlas is the navigable contract; REPORT carries the per-row reasoning.

When ≥2 screens score < 4 on the same dimension, surface a pattern in REPORT.md § Recommendations (e.g., "Recommendation 4: 3 of 8 screens scored Token = 4 because the cool-brutalist direction's hairline aesthetic doesn't fit step-6's `--shadow-md`; step 6 to add `--shadow-modal` OR document the dialog-without-shadow choice").

## Common token-application failure modes

- **Token names drifted across screens** — screen 02 uses `var(--color-foreground)`; screen 03 uses `var(--text-primary)` for the same intent. Both are valid step-6 names if step 6 declared both; if only one is canonical, the other is a drift. Cross-check the `:root` block of every screen against step 6 `tokens.css`.
- **Path A on some, Path B on others** — see § The substitution contract above. Inherit step 7's path; do not mix.
- **Bare hex literals leaked in** — `color: #0066cc;` instead of `color: var(--color-accent);`. Grep for `#[0-9a-fA-F]{3,8}` to catch.
- **Token referenced but not defined** — screen uses `var(--shadow-modal)` but `tokens.css` doesn't declare it. CSS silently falls back to initial value; visual reads broken. Token-gap audit + back-flag to step 6.
- **Voice drift on a single screen** — 7 screens read in brand voice; screen 06 reads in generic SaaS voice. Often a sub-agent didn't read step 5 brand-book carefully. Audit per-screen, re-tune the drift screen.
- **Lorem ipsum slipped through** — placeholder text never replaced. Grep for `lorem` (case-insensitive). Surface in REPORT.md § Recommendations as a blocker.
- **Brand name placeholder shipping** — step 5 picked "Octant" but screens still say "Linear-Clone". Search-and-replace at end of render pass; document the rename in REPORT.md § Run Summary.
