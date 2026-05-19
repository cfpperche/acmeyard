# States coverage — the loading / empty / error / disabled / success matrix

Every interactive screen at step 13 must render its component states explicitly — not just declared in CSS, but visible in the HTML so a reader opening the file via `file://` can verify the state without triggering it. This page documents the 5 canonical states, the per-state rendering discipline, the cross-reference to step 6 `components.md`, and the states-coverage matrix shape that lands in `screen-atlas.md` § States Coverage + `REPORT.md` § States Coverage Matrix.

## The 5 canonical states

Step 6 `components.md` establishes the per-component states vocabulary. Step 13 cashes it in at the atlas layer by ensuring every screen with interactive components covers all 5 applicable states. The canonical 5:

1. **`[Loading]`** — the component is waiting for data. Skeleton UI, spinner, progress indicator, or "fetching..." text. Required when the component reads from the network OR from disk; absent only when the component is pure-presentation (e.g., a static marketing-section heading).

2. **`[Empty]`** — the component has rendered but has no data to display. "No issues to triage", "Inbox is clear", "Start by importing your workspace". Required for any list/table/dashboard surface; absent only when the component cannot be empty by construction (e.g., a privacy notice always has content).

3. **`[Error]`** — the component failed to load or operate. Error message + retry CTA + "what went wrong" context. Required for any component that reads from network OR triggers an action; absent only for pure-presentation components.

4. **`[Disabled]`** — the component is rendered but interaction is suppressed (permission denied, plan-tier insufficient, dependency-not-met). Greyed-out CTA, lock icon, plan-upsell affordance. Required for any component whose interactivity is conditional (e.g., a "Bulk action" button disabled until ≥1 issue is selected); absent for unconditional components.

5. **`[Success]`** — the component completed its action successfully. Confirmation toast, success badge, "Done" state. Required for any component that triggers an action; absent for pure-read components.

The bracket form (`[Loading]` etc.) is the canonical literal that the schema enforces — it only appears in real markdown table column headers OR as inline code-fenced state labels in HTML annotations. Cosmetic variants (`Loading State`, `LOADING`, `loading`) do NOT satisfy the schema check.

## Per-state rendering discipline (in the screen's HTML)

Each state must be **visible in the HTML when the file is opened via `file://`** — not hidden behind a JavaScript trigger, not commented out, not described only in REPORT.md. Three valid rendering patterns:

### Pattern A — Sectioned demonstration

```html
<section class="state-demo" data-state="loading" aria-label="Loading state">
  <h3 class="state-label">[Loading]</h3>
  <article class="issue-card" data-loading="true">
    <div class="skeleton-line skeleton-title"></div>
    <div class="skeleton-line skeleton-meta"></div>
    <div class="skeleton-line skeleton-body"></div>
  </article>
</section>

<section class="state-demo" data-state="empty" aria-label="Empty state">
  <h3 class="state-label">[Empty]</h3>
  <div class="issue-list-empty">
    <p class="empty-title">Inbox is clear.</p>
    <p class="empty-body">All 25 issues triaged. Press <kbd>n</kbd> to start a new triage session.</p>
  </div>
</section>

<section class="state-demo" data-state="error" aria-label="Error state">
  <h3 class="state-label">[Error]</h3>
  <div class="issue-list-error" role="alert">
    <p class="error-title">Something didn't load.</p>
    <p class="error-body">Try again, or check your connection.</p>
    <button class="retry-button">Retry</button>
  </div>
</section>
```

This pattern works for screens that demonstrate per-component states explicitly — typical for dashboard / list / detail surfaces. Each `<section data-state="...">` is a self-labeled demonstration; the screen reads as a state-gallery for its main component.

### Pattern B — Inline annotation

```html
<article class="issue-card" data-active-state="success">
  <div class="issue-title">SWF-247 — Triage queue processing</div>
  <div class="issue-meta">High · @senior.ic · just now</div>
  <!--
    States demonstrated:
      [Loading] — replace data-active-state="success" with "loading"; renders skeleton-* classes (see <style> block § 4)
      [Empty]   — see the empty-card variant at the end of the file
      [Error]   — see the error-card variant at the end of the file
      [Disabled] — add data-disabled="true"; greys out + suppresses pointer events
      [Success] — current state (data-active-state="success"); the action just completed
  -->
</article>
```

This pattern works for screens with one dominant component where the states are CSS-variant-only — the HTML comment lists the states + how to trigger them; the variants live in the `<style>` block. A reader opening the file sees the active state; reading the HTML comment + scrolling to the `<style>` block reveals the other 4. Less visually dense than Pattern A; appropriate for screens where the state-gallery would dominate the screen layout.

### Pattern C — Mixed (recommended for killer-flow screens)

Killer-flow screens are dense — the primary surface is the killer-flow demonstration (Pattern A inappropriate for it; would dominate the screen) but per-component state-galleries are valuable. Use Pattern B for the primary killer-flow surface + Pattern A for the secondary components (notifications, modals, toasts).

```html
<!-- Primary surface: killer-flow demo (Pattern B for state coverage) -->
<main class="triage-mode">
  <!-- Active issue render (data-active-state="loading" → "success" → ...) -->
</main>

<!-- Secondary: notification toast (Pattern A for state-gallery demonstration) -->
<aside class="toast-demo">
  <section data-state="success"><div class="toast toast-success">25 issues triaged · 4:12 elapsed</div></section>
  <section data-state="error"><div class="toast toast-error">Triage save failed · <button>Retry</button></div></section>
  <section data-state="loading"><div class="toast toast-loading">Saving triage...</div></section>
</aside>
```

The choice is the agent's — pick the pattern that makes the screen most readable to engineering AND covers all 5 applicable states verifiably.

## Cross-reference to step 6 `components.md`

Step 6's `components.md` § Patterns documents the per-component state vocabulary at the design-system layer. Step 13's states-coverage matrix is downstream — every state in step 6's `components.md` for a component on a screen must appear in the screen's HTML render.

Example: step 6 `components.md` § Button § States declares `default / hover / focus / active / disabled / loading`. Step 13's screen 05 (which uses the Button component) must render at least `default + disabled + loading` (the 3 visible-distinct states; `hover / focus / active` are CSS pseudo-state-only and the screen doesn't need to fake them; `loading` is the in-action state for async buttons).

When step 6's component declares a state the screen doesn't render, that's a **states-coverage gap** — surface in the matrix cell as `[gap]` and document in REPORT.md § Recommendations + § States Coverage Matrix summary.

When the screen needs a state step 6 didn't declare for the component, that's a **step-6 gap** — back-flag in REPORT.md § Recommendations as a step-6 next-iteration addition (e.g., "Recommendation: step 6 `components.md` § Button to add `success` state; screen 05 needs the post-bulk-action confirmation").

## Matrix shape — atlas vs REPORT

### Atlas `## States Coverage`

Per-screen rollup (NOT per-component); fits in one table at atlas-readable density:

```markdown
| Screen | [Loading] | [Empty] | [Error] | [Disabled] | [Success] |
|---|:---:|:---:|:---:|:---:|:---:|
| 02-signup | ✓ | — | ✓ | ✓ | ✓ |
| 03-onboarding | ✓ | ✓ | ✓ | — | ✓ |
| 04-dashboard | ✓ | ✓ | ✓ | — | ✓ |
| 05-killer-flow | ✓ | ✓ | ✓ | ✓ | ✓ |
| 06-detail-view | ✓ | [gap] | ✓ | — | ✓ |
| 07-settings | ✓ | — | ✓ | ✓ | ✓ |
| 08-empty-error-consent | ✓ | ✓ | ✓ | ✓ | ✓ |
```

Cell semantics:
- **✓** — state is rendered visibly in the screen (Pattern A, B, or C per above)
- **—** — state is N/A for the screen (e.g., `01-landing.html` has no [Empty] state because marketing copy is always present)
- **`[gap]`** — screen needs the state but step 13 didn't render it; surfaces in REPORT.md § Recommendations

### REPORT.md `## States Coverage Matrix`

Same matrix as atlas + a summary count line:

```markdown
## States Coverage Matrix

(same per-screen table as atlas § States Coverage)

**Summary:** All 8 screens cover [Loading] + [Error]. 6/8 screens cover [Empty]; the 2 gaps are `01-landing.html` (N/A — marketing always has content) and `06-detail-view.html` (`[gap]` — escalated; see § Recommendations item 3). [Disabled] applies to 5 screens; all 5 cover it. [Success] applies to 7 screens; all 7 cover it.
```

The summary count is a single paragraph; longer summaries split by state. The literal `[Loading]`, `[Empty]`, `[Error]` substrings in the summary are the load-bearing schema anchors per `schema.md` REPORT.md `contains` list.

## When a state is N/A for a screen (the `—` cell)

`—` is valid when the screen genuinely cannot exercise the state. Three valid reasons:

1. **Pure-presentation screens** — `01-landing.html`, brochure pages, privacy notice. No [Loading] / [Empty] / [Error] / [Disabled] / [Success] because there is no interactive component.
2. **Always-present content** — privacy notice has no [Empty] state because the notice text always exists. ToS acceptance has no [Empty] state because the ToS is always rendered.
3. **Component composition** — a screen whose components are all always-present (no async, no conditional rendering) legitimately has — for [Loading] across the board.

**`—` is NOT valid as "I didn't render it, but it's not really N/A"** — that's `[gap]`. The difference: `—` means "the state CANNOT happen by construction"; `[gap]` means "the state CAN happen, but I didn't render it". A reviewer (engineering, designer) should be able to look at the cell and verify the difference without re-reading the screen's HTML.

## States-coverage discipline at the screen level

Per-screen, the agent's responsibility before submitting:
1. **Enumerate the screen's interactive components** (button, input, modal, list, card, toast, etc.).
2. **Cross-reference each component against step 6 `components.md` § Patterns** for its declared states.
3. **Render each applicable state in the HTML** per Pattern A, B, or C above.
4. **Annotate any `[gap]` cell** in the matrix with one line in REPORT.md § Recommendations naming the gap + escalation target (engineering or step 6).
5. **Verify the `[Loading]`, `[Empty]`, `[Error]` literals appear** in the matrix column headers (the schema anchors).

The states-coverage matrix is the engineering-facing audit trail — engineering reads it during `/sdd new <slug>` to discover which states the design has committed to + which gaps need engineering decisions. Silent omission is the regression mode; explicit `[gap]` is the discipline.

## Why the 8 KB floor matters (the state-gallery forcing function)

The schema declares `per_match_min_size: 8192` (8 KB) for every `screens/[0-9][0-9]-*.html` file. The number reads as arbitrary on first encounter — it isn't. **The 8 KB per-screen floor is the forcing function for the state-gallery section.**

Without the floor, a screen collapses to a single ~5-6 KB happy-path: the `:root` token block (~1.5-2 KB) + the primary surface render (~3-4 KB) + minimal CSS. The agent ships the happy-path, declares victory, moves on. The state-gallery — the `[Loading] / [Empty] / [Error] / [Disabled] / [Success]` per-component state coverage that this entire reference page exists to enforce — gets silently dropped because the screen "looks done" at 5-6 KB.

The 8 KB floor closes that regression. To clear 8 KB on a real product screen, the agent MUST render the state-gallery — Pattern A (sectioned demonstration), Pattern B (inline annotation + variants in `<style>`), or Pattern C (mixed) per the patterns above. The math: happy-path (3-4 KB) + state-gallery for 1 dominant component covering 4-5 states (3-4 KB) + token block + minor structural HTML lands the file at 8-12 KB. A screen that lands at 7 KB is signalling the state-gallery is incomplete; a screen at 12-15 KB is signalling the state-gallery is honest.

**The discipline, not the number.** The forcing function is the discipline of "render every applicable state explicitly, not just declare them in CSS"; the number (8 KB) is the floor that catches the most common regression of state-gallery omission. A screen that genuinely has no interactive components (a pure-presentation marketing one-pager) may legitimately land at 8 KB through richer marketing-section content (hero + value props + pricing + FAQ + footer); the floor doesn't force state-gallery on screens that don't need it, but it does prevent the lazy happy-path collapse on screens that do.

Cross-references:
- The states-coverage matrix in `screen-atlas.md` § States Coverage (this page § Matrix shape — atlas vs REPORT) is the per-screen rollup.
- The 5 canonical states (this page § The 5 canonical states) are the per-component vocabulary.
- The 3 rendering patterns (this page § Per-state rendering discipline) are HOW to land the state-gallery in the HTML.
- The 8 KB floor is the schema-level enforcement that the discipline above actually ships, not silently drops.

## Common per-screen state-coverage profiles

For agent quick reference. The profile is illustrative; the screen's actual interactive-component inventory drives the per-state cells.

| Screen archetype | Typical state profile (Loading / Empty / Error / Disabled / Success) |
|---|---|
| Marketing landing | — / — / — / — / — (pure presentation) |
| Sign-up / auth | ✓ / — / ✓ / ✓ / ✓ (form has Loading / Error / Disabled / Success; Empty N/A) |
| Onboarding wizard | ✓ / ✓ / ✓ / — / ✓ (step progress can be empty at first, has loading per step) |
| Dashboard / list view | ✓ / ✓ / ✓ / — / — (read-only list; Disabled / Success rarely apply to the list itself) |
| Killer flow (interactive) | ✓ / ✓ / ✓ / ✓ / ✓ (all 5 — the screen has every state) |
| Detail view | ✓ / [gap or ✓] / ✓ / — / — (detail rarely Empty unless the resource is missing) |
| Settings / preferences | ✓ / — / ✓ / ✓ / ✓ (forms with Save action) |
| Empty-error-consent combo | ✓ / ✓ / ✓ / ✓ / ✓ (deliberately exercises all 5; that's the screen's purpose) |
| Privacy notice / ToS | — / — / — / — / — (always-present; pure presentation) |
| Consent dialog | ✓ / — / ✓ / — / ✓ (modal with Accept action; Loading during save) |

The profile is per-screen rollup; the per-component states-coverage is what step 6 `components.md` documents. Step 13's matrix is the per-screen aggregation.
