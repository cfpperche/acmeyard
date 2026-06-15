# The craft loop

The "artist" is a **loop**, not a one-shot generator and not a persona. Taste is produced by *grounding* + *iterating against what you actually see*. This file is the detail behind SKILL.md § The craft loop.

```
ground → resolve stack → research references → set direction
      → implement → DRIVE & SEE → critique vs references → refine
                         ↑__________________________________|
                            (until stop criteria OR max iterations)
```

## Imagery decision (during "set direction" / "implement")

If the surface needs imagery (hero, empty-state, decorative avatar, og-image), make an explicit **imagery decision** — authored tracked neutral by default, with an optional generated draft as a *progressive override*:

- Author the **tracked neutral** layer first (CSS/SVG/solid) so the surface ships and the contract passes with zero key/credits.
- Only if the user opted in for this surface AND there's no suitable existing asset: attempt **exactly one** `/image --tier=draft` call (outside the critique loop). On any failure (no key / no credits / 402 / network / timeout) → `image-fallback:<reason>` → keep the neutral. Never `import` the gitignored draft as a build dependency.
- `brand-text`/`brand-photo` and brand assets (logo/wordmark) are out of scope — that's `/product`.

Full rules + the degradation ladder + the safe CSS/`<img>` patterns: **references/imagery.md**.

## Why "drive and see" is non-negotiable

An agent can convince itself a screen looks good without ever rendering it. The loop forces the opposite: after each implement pass, actually run the surface and **look at the rendered output** (via `agent-browser.sh run -- open/screenshot/snapshot`), then compare it to the references and the direction. The gap between "what I wrote" and "what renders" is where craft happens.

## Explicit stop criteria (declare them up front, in design-direction.md)

The refine loop stops on a **declared** bar, not on exhaustion or vibes. Good stop criteria are observable:

- the done-proof passes (a green project UI test covering the surface, or the honest native-evidence path);
- the surface visibly matches the design direction's tokens/feel and the borrowed reference patterns;
- a11y baseline holds (required roles/names present; console errors within budget; keyboard/focus sane);
- no remaining item on the surface's punch-list from the last critique.

## Max-iteration bound

Default **4** implement→see→critique iterations. Hitting the bound is a stop, not a failure: record the remaining gaps in the design doc and surface them. Tunable per surface, but always bounded — an unbounded loop is how a "refine" becomes a sprawling rewrite.

## Per-mode loop shape

- **create** — full loop from an empty/greenfield surface; stop on done-proof + direction match.
- **refine** — the loop operates on an existing surface; additionally enforce a **bounded diff** and **preserved behavior**, and keep **before/after evidence** from the first and last "see" steps.
- **explore** — loop stops after *research + direction*; steps implement→see→critique are skipped (no code). If you reach for code, you're in the wrong mode.

## What "critique" means here

Concrete, reference-anchored deltas — "the card spacing is half what reference #2 uses; the primary button doesn't use the DS accent token; the heading hierarchy skips h2." Not "make it nicer." Each critique item becomes a punch-list entry for the next implement pass.
