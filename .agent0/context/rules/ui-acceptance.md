# UI acceptance

When **any change** produces UI — whether or not it carries a spec or a delegated task — "done" must be provable by **driving the UI**, not by static code review — an agent can otherwise claim a screen works without ever loading it. The proof is **a green UI test** (the project's idiomatic e2e/runner) that covers the changed surface. The obligation is independent of SDD: a UI tweak that correctly *skips* a spec (see `spec-driven.md` § When to skip) still owes a green UI test, with the run recorded outside a spec — in the PR body, CI, or the session handoff.

This rule **retires the visual contract** (spec 155 → superseded by spec 206). Agent0 no longer ships an acceptance-artifact generator: there is no `visual-contract.json` fixture, no `agent-browser verify-contract`, and no committed `agent-browser/` evidence bundle. Field evidence (the `cognixse` consumer) showed the bundle was a strict, frozen subset of the project's own e2e suite that already ran in CI — ~80% of the e2e authoring cost for ~20% of the value, plus a maintenance surface Agent0 carried. The proof of built UI belongs in a **living test**, not a frozen snapshot.

## The acceptance rule

- **Acceptance of UI work = a green run of the project's UI test covering the changed surface.** The evidence is the test output / CI run, not a bundle.
- **"Covering the surface" is real coverage, not a gameable smoke.** The test must name the changed route/surface, perform **at least one semantic assertion after render** (not a bare page load), exercise the changed interaction/state when applicable, and carry no `skip`/`only` on that test. A test that only loads `/`, is skipped, or asserts nothing does **not** satisfy acceptance.
- **CI is not required by the harness.** A local green run with recorded evidence suffices (the gate is advisory in v1 — see below). Projects that run UI tests in CI get the stronger guarantee for free.

## The `UI impact` declaration (the forcing function)

A spec declares whether it produces UI with a line adjacent to `**Status:**`:

```
**UI impact:** none | ui
```

`none` (the default when the line is absent) ⇒ no UI proof is owed. `ui` ⇒ the change produces UI and owes a green UI test covering the changed surface. The legacy tiers (`render | interaction | flow`) are **collapsed** — they existed only to size the retired fixture format; any non-`none` value now means `ui`. A task may override per-task with a `UI impact:` token in its `tasks.md` line.

## The runner is a requirement, not a fallback

UI acceptance presumes the project **declares a UI test runner**. If it does not, the harness does **not** ship a substitute — it tells you to provision one. A no-runner UI change can close with **no machine UI proof** until the runner exists; that is a deliberate, named tradeoff (we require the real mechanism rather than maintaining a weaker stand-in).

**Detection — `.agent0/tools/ui-runner-detect.sh`** (deterministic, content-free, stack-neutral; mirrors `typecheck-advisory`'s declare-the-primitive shape). A runner is **present** when any one of these holds:

1. a `test:e2e`, `e2e`, `test:ui`, `test:browser`, or `e2e:<suffix>` script key in any `package.json` (root or workspace, excluding `node_modules`), OR
2. a known e2e config outside `node_modules`: `playwright.config.{ts,js,mjs,cjs}`, `cypress.config.{ts,js,mjs,cjs}`, `wdio.conf.{ts,js}`, `nightwatch.conf.{js,ts}`, OR
3. a stack-neutral override `.agent0/ui-test.json` with a non-empty `"command"` (the escape hatch for Python/Playwright-python, Rust, Storybook-only stacks, etc.):
   ```json
   { "command": "pytest tests/e2e" }
   ```

Exit 0 = present, 1 = absent, 2 = usage error; `--json` and `--root <dir>` supported.

## The detector + validator advisory

`.agent0/tools/ui-impact-detect.sh` classifies a changed-path set: a *rendered surface* is a web component/style/template by extension or a path in a UI directory; backend/CLI/docs/tests/migrations/server-language sources are excluded. When a rendered surface changed **and** `ui-runner-detect.sh` reports `absent`, the post-edit validator (`.agent0/validators/run.sh`) emits a non-blocking `ui-runner-advisory:` prompting the author to provision the stack's idiomatic UI/e2e runner. A project that already declares a runner is silent — whether it wrote and ran the test is its own discipline and a spec's acceptance criterion; the validator cannot verify test coverage content-free. The advisory **never** fires for backend/docs/tests-only changes.

## Delegation gate (no 6th field)

A UI-producing brief maps the proof onto the existing five fields:

- `CONSTRAINTS:` — no "done" from static code review alone.
- `DELIVERABLE:` — the UI surface plus its test.
- `DONE_WHEN:` — the exact **green UI-test command**, e.g. `pnpm test:e2e notifications` (or the stack's equivalent), covering the changed surface. **Not** `verify-contract … jq .overall==pass` (removed).

`delegation-verify.sh` (the `SubagentStop` verifier) runs the project validator and surfaces its advisory family, including `ui-runner-advisory:`. There is no per-brief `report.json` check (removed with the visual contract).

## a11y / console / vitals / overflow — opt-in via `agent-browser audit`

The retired contract captured a11y-tree, console-budget, vitals, and overflow signals that a typical e2e suite omits. These are **not** required acceptance conditions. When a project wants them, the surviving home is the opt-in sweep:

```
agent-browser.sh audit <base-url> (--paths a,b,c|--paths-file f) [--max-console N] [--structure strict|optional]
```

Run it ad-hoc or wire it into CI as the project sees fit; it is a sweep, not a gate.

## Native / non-browser surfaces

For native mobile/desktop surfaces with no browser-renderable harness, `frontend-designer`'s honest-evidence path applies: ship the code plus the project's native build/test output, **explicitly labeled** as *"native build/test evidence — NOT a UI-test proof."* Do not add native visual tooling (deferred behind the rule-of-three demand test). The `ui-runner-advisory` points native surfaces at this path.

## agent-browser stays — as a dev primitive

`agent-browser` (see `browser-primitive.md`) remains Agent0's runtime-neutral eyes+hands: navigate, snapshot, click/type, auth/`adopt`, `audit`. Use it to **drive and inspect UI during development** and to **debug until the test is green** — it is no longer an acceptance-artifact generator.

## Advisory in v1; the hardening trajectory

v1 ships **non-blocking** — a `ui-runner-advisory:`, matching the `tdd-advisory` / `lint-advisory` / `typecheck-advisory` precedent. A new discipline earns a hard gate by the rule-of-three demand test, not by fiat: a mandatory gate that over-fires gets rubber-stamped or disabled, which is worse than no gate. The first hard-gate candidate is "a green UI test is required for `UI impact: ui` changes" — a separate, future, dogfood-evidence-gated spec.

## Reconcile with `/product`

`/product`'s design-time artifacts (lo-fi/hi-fi moods, screen-atlas, fixture-spec) describe the *intended* UI. They survive as **input for writing the UI tests** — design source material, never implementation-acceptance proof. There is no design-time→implementation-bundle reconciliation (that died with the visual contract).

## Notes

_Consumer-extension surface — append consumer-local bullets here. Sync flags the file as `!! customized` (sha-compare is section-blind); the conflict region is mechanically this section: take new upstream verbatim, re-add consumer bullets at the end._

- Agent0 itself ships no UI — this is a **mechanism** that activates in consumer projects that produce UI. The offline test suite (`.agent0/tests/ui-acceptance/`) exercises the detector + advisory orchestration with synthetic path sets and fixture project roots; no real browser or runner is invoked.
- Legacy `visual-contract.json` / `agent-browser/` bundles in consumer repos are **historical record** — validators ignore them and never treat them as satisfying UI acceptance; already-closed legacy specs are not retroactively nagged.
