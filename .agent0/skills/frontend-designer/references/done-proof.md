# Done-proof — a green project UI test, fail closed, be honest about native

`frontend-designer` invents **no** acceptance gate. "Done" is **a green project UI test** — the stack's idiomatic e2e/runner — covering the changed surface (`.agent0/context/rules/ui-acceptance.md`). UI is proven by *driving* it, not by static review. This is the anti-drift anchor: no new "design quality score", no bespoke verifier, no frozen acceptance bundle.

## Browser-renderable surfaces (web, and any surface with a web harness)

1. Declare in `design-direction.md`: `**UI impact:** ui` (any UI-producing surface; `none` when it produces no UI).
2. Write/extend the project's UI test so it **covers this surface** — name the changed route/surface and make at least one semantic assertion after render (not a bare page load), exercise the changed interaction/state when applicable, and carry no `skip`/`only`. See `ui-acceptance.md` § "Covering the surface".
3. Run it and confirm it is green:
   ```bash
   bash .agent0/skills/frontend-designer/scripts/frontend-designer.sh verify <project>
   ```
   `verify` runs the project's declared `.agent0/ui-test.json` command if one exists; otherwise it reports whether a runner is present and tells you to run the project's UI test covering the surface (no runner = BLOCKER, never a pass). A green run is the proof. Link it from `design-direction.md` § Acceptance.

## Fail closed — no UI test runner is a BLOCKER, never a pass

The harness **requires** a real UI test runner; it ships no substitute bundle. `verify` detects the runner via `.agent0/tools/ui-runner-detect.sh`. If no runner is declared it exits **rc 4** with a `BLOCKER` message and produces no proof. A missing runner does **not** become a pass, an "advisory skip", or an assumed-green. Provision the stack's idiomatic UI/e2e runner (or declare one via `.agent0/ui-test.json`), or take the native-evidence path below — but never claim a UI-test proof you didn't produce.

## Native-only surfaces (no web harness)

For native mobile/desktop surfaces with no browser-renderable harness:

1. **Prefer a project-provided web harness** if one exists — `react-native-web` / Expo web, Storybook/Ladle, a web preview. `detect` reports `browser_renderable: yes (expo-web|storybook)` when present. If so, verify through it like any web surface.
2. **Otherwise, ship honest evidence:** the code plus the project's native build/test output (typecheck, component tests, a native build that compiles), **explicitly labeled** in `design-direction.md` § Acceptance as *"native build/test evidence — NOT a UI-test proof."*
3. **Do not add new native visual tooling** (simulator screenshot pipelines, native pixel-diff harnesses). That is deferred behind the repo's rule-of-three demand test — it needs 3+ real demands before it's built, not a speculative dependency here.

The honest-evidence path proves *the code is real and builds*; it does **not** claim a UI test covered the surface. Say which one you have.

## Animated / WebGL / 3D surfaces (motion has a proof boundary)

Motion libraries (Three.js, GSAP, Framer Motion, Lottie, Lenis, …) are fine to use — free, local+remote, **detect-don't-impose** (add one only when the researched direction calls for motion). But a UI test is an interaction trace, **not** a pixel/frame diff, so motion has a boundary you must declare honestly:

1. **What the UI test PROVES:** the surrounding **semantic + interaction surface** — heading/controls present and named, click/type post-state, console within budget. Assert *that*, not the animation.
2. **A live WebGL `<canvas>` is NOT in the a11y tree while painting** (correct browser behavior — its fallback subtree is hidden once it has a context). So don't assert the canvas as a `role:img`; mark it **decorative (`aria-hidden="true"`)** and carry the meaning in real text (the `<h1>`, a caption). The UI test verifies the text/controls.
3. **Prove "it renders and animates" programmatically, separately from the UI test:** drive the page and `eval` real signals — e.g. `!!canvas.getContext('webgl')`, a `window.__sceneReady` flag, and a frame counter / object rotation sampled at two times (frames must advance). Record this in `design-direction.md` § Acceptance as **build/runtime evidence — NOT a UI-test proof of motion fidelity.**
4. **Motion *fidelity* (easing, smoothness, fps quality) is out of scope** — a dedicated "motion gate" is deferred behind the rule-of-three demand test. Screenshots are one frame = review artifacts, never motion proof.
5. **Accessible motion is part of the craft:** honor `prefers-reduced-motion` as the default, and give an explicit **opt-in control** (Play/Pause with `aria-pressed`) so motion is available to everyone without forcing it on users who asked for less. Also handle the no-WebGL fallback.

Same honesty posture as the native-only path: build it, show evidence, and label what is vs isn't UI-test-verified.
