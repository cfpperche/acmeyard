# Visual contract acceptance

When a spec or a delegated task produces UI, "done" must be provable by **driving the UI**, not by static code review — an agent can otherwise claim a screen works without ever loading it. A **visual contract** makes that proof a first-class acceptance artifact in both SDD and the delegation gate. It is the spec-152 follow-up #2, built on the fail-closed `agent-browser` primitive (spec 152/153) and reusing the existing 5-field delegation gate (spec 119/delegation.md). (Spec 155.)

The contract is an **interaction trace**, not a screenshot/pixel diff. It asserts *semantic* conditions — DOM roles/names, a11y, console budget, route/URL, post-action state. Screenshots are review artifacts, never the bar.

## The `UI impact` declaration (the trigger)

Declaration is the source of truth; detection only *suggests*. A spec declares its level with a line adjacent to `**Status:**`:

```
**UI impact:** none | render | interaction | flow
```

`none` (the default when the line is absent) ⇒ no contract is owed. A task may override per-task with a `UI impact:` token in its `tasks.md` line. The four values are **cumulative tiers** of how deep the visual contract must go:

- **`render`** — the screen mounts; required a11y roles/names are present; console errors within budget; responsive overflow sane.
- **`interaction`** — *render* **plus** named controls respond: click/type/select/press a target, assert the expected post-action role/name appears (validation, focus, dialogs, state).
- **`flow`** — *interaction* **plus** ordered traversal from a start route under a fixture/auth precondition: each step asserts the expected URL and/or screen state, ending in a terminal assertion, with per-step evidence.

## The contract format (extends `agent-browser verify-contract`)

There is no parallel format. The existing fixture-spec consumed by `agent-browser.sh verify-contract <url> <fixture.json> <outdir>` is the `render` tier verbatim, extended with two optional arrays for the deeper tiers. `verify-contract` writes `<outdir>/report.json` = `{ "url", "overall":"pass"|"fail", "checks":[{name,ok,warn,detail}] }`.

```jsonc
{
  "required": [ { "role": "heading", "name": "Dashboard" } ],   // render tier
  "max_console_errors": 0,

  "interactions": [                                              // interaction tier
    { "action": "click", "target": { "role": "button", "name": "Create project" },
      "expect": { "role": "dialog", "name": "New project" } },
    { "action": "type",  "target": { "role": "textbox", "name": "Project name" }, "value": "Acme",
      "expect": { "role": "button", "name": "Save" } }
  ],

  "flow": [                                                      // flow tier
    { "goto": "http://localhost:3000/login", "expect_url": "/login",
      "expect": { "role": "heading", "name": "Login" } },
    { "action": "click", "target": { "role": "button", "name": "Sign in" },
      "expect_url": "/dashboard", "expect": { "role": "heading", "name": "Dashboard" } }
  ]
}
```

- `action` ∈ `click | type | select | press`. `target` is resolved to a snapshot ref; `value` feeds `type`/`select`/`press`.
- A step may carry `"flaky": true`. A flaky step that fails is recorded as a non-fatal `warn` check — it does **not** flip `overall` to fail. Because v1 is non-blocking (below), flakiness cannot break a build; `flaky` plus sane per-step timeouts/retries is the whole flakiness story for v1.
- A malformed fixture is a usage error (exit 3); an **unavailable** `agent-browser` is exit 4 / `unavailable` — **never a pass** (fail-closed, spec 152/153). A green gate from an absent browser would be a false acceptance.

## Where it plugs in

**SDD acceptance.** A UI-producing spec carries visual acceptance authored at `plan`/`tasks` time (like fixtures): the contract/fixture path, base URL, routes, states, viewports, named flows, auth/fixture preconditions, and the evidence outdir. `plan.md` names how the app is served and how fixture/auth state is created; `tasks.md` verification tasks run `agent-browser.sh verify-contract …` and record `report.json` + screenshots + the flow transcript.

**Delegation gate (no 6th field).** A UI-producing brief maps the proof onto the existing five fields:

- `CONSTRAINTS:` — no "done" from static code review alone.
- `DELIVERABLE:` — the evidence-bundle path.
- `DONE_WHEN:` — the exact command, e.g. `bash .agent0/tools/agent-browser.sh verify-contract <url> <fixture> <outdir> && jq -e '.overall=="pass"' <outdir>/report.json`.

`delegation-verify.sh` (the `SubagentStop` verifier) surfaces the validator's `visual-contract-advisory:` and, when the closing brief declared UI, checks the named bundle's `report.json` for `.overall=="pass"`, surfacing an advisory if it is absent or not green. Non-blocking.

**The detector + validator advisory.** `.agent0/tools/ui-impact-detect.sh` classifies a changed-path set: a *rendered surface* is a web component/style/template by extension or a path in a UI directory; backend/CLI/docs/tests/migrations/server-language sources are excluded. When surfaces changed but the declared/effective level is `none`, the post-edit validator (`.agent0/validators/run.sh`) emits a non-blocking `visual-contract-advisory:` prompting the author to declare `UI impact`. When surfaces changed and the spec declares `render|interaction|flow`, the validator expects a changed `report.json` with `.overall=="pass"` as evidence; if absent, it emits a non-blocking evidence advisory. The detector only *suggests* a level — it never sets the declaration.

## Advisory in v1; the hardening trajectory

v1 ships **non-blocking** — a `visual-contract-advisory`, matching the `tdd-advisory` / `lint-advisory` / `typecheck-advisory` precedent. A new discipline earns a hard gate by the rule-of-three demand test, not by fiat: a mandatory browser-verification gate that over-fires gets rubber-stamped or disabled, which is worse than no gate.

The **first hard-gate candidate** (preserved from the spec-149 decision-grade `/meeting` minority report) is declared `UI impact: flow` tasks — lowest false-positive rate, highest cost of a missed proof. Hardening is a separate, future, dogfood-evidence-gated spec; it is explicitly **not** part of spec 155.

## Reconcile with `/product`

`/product`'s visual-contract phase produces a **design-time** contract (lo-fi/hi-fi moods, screen-atlas, fixture-spec) — the *intended* UI. The SDD visual contract here is the **implementation-evidence** counterpart — proof the *built* UI satisfies that intent. They are distinct artifacts: the design-time contract is source material the implementation evidence is checked against, not a duplicate.

## Notes

_Consumer-extension surface — append consumer-local bullets here. Sync flags the file as `!! customized` (sha-compare is section-blind); the conflict region is mechanically this section: take new upstream verbatim, re-add consumer bullets at the end._

- Agent0 itself ships no UI — this capability is a **mechanism** that activates in consumer projects that produce UI. The offline test suite (`.agent0/tests/visual-contract/`) exercises the orchestration via a fake `agent-browser` stub; a real browser run is a `need_live` skip-with-pass.
