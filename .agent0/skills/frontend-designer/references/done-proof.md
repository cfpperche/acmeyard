# Done-proof — reuse spec 155, fail closed, be honest about native

`frontend-designer` invents **no** acceptance gate. "Done" reuses the spec-155 visual-contract gate (`.agent0/context/rules/visual-contract.md`) — UI is proven by *driving* it, not by static review. This is the anti-drift anchor: no new "design quality score", no bespoke verifier.

## Browser-renderable surfaces (web, and any surface with a web harness)

1. Declare the tier in `design-direction.md`: `**UI impact:** render | interaction | flow`.
   - **render** — mounts; required a11y roles/names present; console errors within budget.
   - **interaction** — render + named controls respond (click/type/select/press → expected post-action role/name).
   - **flow** — interaction + ordered traversal from a start route, each step asserting URL/state.
2. Write a `fixture-spec.json` from `templates/fixture-spec.json.tmpl` with the surface's real assertions.
3. Run the surface (dev server / preview) and verify:
   ```bash
   bash .agent0/skills/frontend-designer/scripts/frontend-designer.sh verify \
     "http://localhost:<port>" path/to/fixture-spec.json <gitignored-out-dir>
   ```
   A green `report.json` (`overall: pass`) is the proof. Link it from `design-direction.md` § Acceptance.

## Fail closed — agent-browser unavailable is a BLOCKER, never a pass

The `verify` wrapper checks `agent-browser route` first. If it isn't `primary`, it exits **rc 4** with a `BLOCKER` message and produces no report. Unavailability does **not** become a pass, an "advisory skip", or an assumed-green. Install agent-browser + Chrome (`scripts/frontend-designer.sh caps` to check), or take the native-evidence path below — but never claim browser visual proof you didn't produce.

## Native-only surfaces (no web harness)

For native mobile/desktop surfaces with no browser-renderable harness:

1. **Prefer a project-provided web harness** if one exists — `react-native-web` / Expo web, Storybook/Ladle, a web preview. `detect` reports `browser_renderable: yes (expo-web|storybook)` when present. If so, verify through it like any web surface.
2. **Otherwise, ship honest evidence:** the code plus the project's native build/test output (typecheck, component tests, a native build that compiles), **explicitly labeled** in `design-direction.md` § Acceptance as *"native build/test evidence — NOT visual-contract proof."*
3. **Do not add new native visual tooling** (simulator screenshot pipelines, native pixel-diff harnesses). That is deferred behind the repo's rule-of-three demand test — it needs 3+ real demands before it's built, not a speculative dependency here.

The honest-evidence path proves *the code is real and builds*; it does **not** claim the visual contract was met. Say which one you have.

## Animated / WebGL / 3D surfaces (motion has a proof boundary)

Motion libraries (Three.js, GSAP, Framer Motion, Lottie, Lenis, …) are fine to use — free, local+remote, **detect-don't-impose** (add one only when the researched direction calls for motion). But the spec-155 gate is an interaction trace, **not** a pixel/frame diff, so motion has a boundary you must declare honestly:

1. **What the gate PROVES:** the surrounding **semantic + interaction surface** — heading/controls present and named, click/type post-state, console within budget. Assert *that*, not the animation.
2. **A live WebGL `<canvas>` is NOT in the a11y tree while painting** (correct browser behavior — its fallback subtree is hidden once it has a context). So don't assert the canvas as a `role:img`; mark it **decorative (`aria-hidden="true"`)** and carry the meaning in real text (the `<h1>`, a caption). The contract verifies the text/controls.
3. **Prove "it renders and animates" programmatically, separately from the contract:** drive the page and `eval` real signals — e.g. `!!canvas.getContext('webgl')`, a `window.__sceneReady` flag, and a frame counter / object rotation sampled at two times (frames must advance). Record this in `design-direction.md` § Acceptance as **build/runtime evidence — NOT visual-contract proof of motion fidelity.**
4. **Motion *fidelity* (easing, smoothness, fps quality) is out of scope** — a dedicated "motion gate" is deferred behind the rule-of-three demand test. Screenshots are one frame = review artifacts, never motion proof.
5. **Accessible motion is part of the craft:** honor `prefers-reduced-motion` as the default, and give an explicit **opt-in control** (Play/Pause with `aria-pressed`) so motion is available to everyone without forcing it on users who asked for less. Also handle the no-WebGL fallback.

Same honesty posture as the native-only path: build it, show evidence, and label what is vs isn't contract-verified.
