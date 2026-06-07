---
paths:
  - ".agent0/tools/agent-browser.sh"
  - ".agent0/browser-policy.json"
  - ".agent0/browser-policy.json.example"
  - ".agent0/.runtime-state/agent-browser/**"
---

# Browser primitive

`agent-browser` (vercel-labs) is Agent0's **sole, runtime-neutral agent browser primitive** — the "eyes + hands" an agent drives against a web UI: navigate/control via CDP, accessibility-tree snapshot with stable LLM-friendly refs (`@e1`), click/fill/wait/drag, annotated screenshot + PDF, read text/HTML, cookies/storage/network/tabs/frames/dialogs, persistent auth, vitals, React introspection, JSON output. It is a native-Rust **CLI** (client-daemon over CDP), so Claude Code and Codex both invoke it through plain shell — **no per-runtime MCP wiring, no session restart**. This consolidates what used to be split across Playwright MCP + Chrome DevTools MCP. (spec 152, graduated from the accepted meeting `agent-browser-visual-inspection`.)

**No MCP fallback (spec 153).** Playwright MCP + Chrome DevTools MCP are **not** a harness path the routing degrades to — they survive only as opt-in `.mcp.json.example` / `.codex/config.toml.example` templates a consumer may wire up by hand for their own use. When `agent-browser` is unavailable, first-party browser work **fails closed** (rc 4) rather than silently switching stacks. Keep-the-template ≠ keep-the-harness-dependency.

## The wrapper — `.agent0/tools/agent-browser.sh`

First-party browser work goes through the wrapper, not the raw binary. It adds the operational envelope: detection, routing, a policy guard, per-command audit, and a fail-readable JSON contract.

```
agent-browser.sh caps [--json]                       binary + chrome + pinned-version (tri-state)
agent-browser.sh route [task]                         → primary | unavailable:<reason>
agent-browser.sh policy-eval <action> <target> [--confirm]   → allow|deny|confirm ; reason
agent-browser.sh run [--confirm] -- <agent-browser args...>   policy-gated, audited passthrough (fail-closed if unavailable)
agent-browser.sh verify-contract <url> <fixture.json> <outdir>   bounded visual-contract verify
agent-browser.sh audit <base-url> (--paths a,b,c|--paths-file f) [--out d] [--max-console N] [--structure strict|optional]   multi-page structural+console+vitals+overflow sweep (spec 152.1; structure modes + responsive overflow spec 153)
agent-browser.sh adopt <host> [--port 9222] [--detect-only]   attach to a human-logged-in CDP Chrome + save state (spec 152.2)
agent-browser.sh reset                                tear down the daemon (rebind launch options)
agent-browser.sh audit-tail [N]                       recent audit lines
```

The human-run launcher `.agent0/tools/browser-login.sh <host>` pairs with `adopt` (see § Human-in-the-loop auth).

The raw `agent-browser` CLI is fine for read-only ad-hoc inspection; route mutating/interactive flows through `run` so they are policy-gated and audited.

## Routing — agent-browser or fail-closed (spec 153)

`route` is deterministic and has **no MCP lane**. It prints `primary` when agent-browser is usable, else `unavailable:<reason>`:

1. **`unavailable:no-binary`** — `agent-browser` is not on PATH.
2. **`unavailable:no-chrome`** — no usable browser even via agent-browser's bundled Chrome-for-Testing (signalled by `AGENT0_BROWSER_NO_CHROME=1`; a missing *system* Chrome alone is NOT a reason — agent-browser self-provides one).
3. **`unavailable:mcp-removed`** — the legacy `AGENT0_BROWSER=mcp` override is now an **explicit unsupported error**, not an alternate route (MCP routing was removed in spec 153).

On any `unavailable:*`, explicit commands (`run`/`verify-contract`/`audit`/`adopt`) **fail closed** — rc 4 with an install/`doctor`/`caps` message (rc 3 for the `mcp-removed` override) — they never degrade to Playwright/Chrome DevTools MCP. A reserved `capability-gap` slot exists but the v1 gap list is empty (agent-browser is a superset of the old MCP surface). This single rule keeps "agent-browser is the only path" unambiguous.

## Attempt-before-handoff — try the primitive, don't punt to the human by reflex

**The failure this prevents (real, cognixse spec 020):** an agent that *had* `agent-browser` available and *knew* it existed still told the human _"abra essa URL e confira — não dá pra automatizar daqui"_ for a form smoke test — an assertion of incapability with **zero evidence**, emitted **before** running `route`/`caps` or driving anything. It only tried after the human pushed back. This is the same anti-pattern `runtime-capabilities.md` already forbids in another domain (*never assert a capability does not exist without verifying — hedge and verify*), here in the browser domain. The fix extends that discipline; it is not a new capability.

**The discipline.** Before telling a human to do browser work themselves — _"abra essa URL"_, _"confira no browser/backoffice"_, _"envie um teste no form"_, _"não dá pra automatizar daqui"_ — you MUST first either **drive it via agent-browser** or **prove a real, observed unavailability/blocker**. A handoff to the human is legitimate only when it carries that evidence and is scoped to the **smallest sub-step that is genuinely human-only**.

**"Really tried" — the cheap, bounded stop criterion** (not "fight a CAPTCHA for 10 turns"):

1. Run `bash .agent0/tools/agent-browser.sh route "<task>"` (or `caps --json`).
2. If `unavailable:*` → that IS the evidence; hand off (or ask to install) naming the reason. Done.
3. If `primary` → load the URL and attempt the relevant action **up to the first concrete blocker**. Respect the policy: mutating/sensitive flows go through `policy-eval` / `run --confirm` (don't treat a `confirm` decision as a dead end — confirm and proceed when the human asked for the outcome).
4. **Auth wall** → emit the existing bounded signal `BROWSER_LOGIN_REQUIRED: <host>` → `browser-login.sh` / `adopt` (§ Human-in-the-loop auth). That is the sanctioned human handoff — a specific host login, **not** "do the whole task for me".
5. **Turnstile / CAPTCHA / 2FA / payment / irreversible action** → this is a legitimate human-only step, but only once you have **observed the blocker in the browser** — never inferred it from the theoretical presence of the widget. Then hand off only the blocked sub-step.

**Anti-overcorrection — this is NOT "never delegate to the human".** Some handoffs are correct (the cognixse Turnstile *managed* challenge genuinely blocks automation). The bug was reaching that conclusion *speculatively, first*. The corrective shape of a legitimate handoff carries the attempt + the evidence + the minimal ask, e.g.:

> _"Carreguei o form com `agent-browser`, preenchi e tentei submeter; o Turnstile managed bloqueou a submissão automatizada (observado). Preciso só do **submit humano** — eu confirmo o lead via `supabase db query --linked` / backoffice depois."_

**Why rule-only (no hook).** The punt is plain assistant **text output** — there is no tool-call to intercept, so `PreToolUse` never fires (unlike an `Agent` dispatch). This is the exact precedent of `user-prompt-framing.md`: when the actor to discipline is the one composing the next message and there is no reliable pre-submit blocker, Agent0 uses **rule-only self-discipline** and does not fake enforcement. A natural-language output-linter is deferred behind a rule-of-three reopen-trigger: if ≥3 *new* speculative punts with a similar textual pattern recur after this rule, and last-message+audit can be exposed stably with low false-positives, reconsider a `Stop`/output-lint hook. (Graduated from the decision-grade meeting `.agent0/meetings/browser-attempt-before-handoff-2026-06-06T17-40-20Z/`.)

## Security — auditable hands

The bar for granting an agent "hands" is not *can it click* but **can a later human reconstruct WHY it clicked and WHICH guard allowed it**. The wrapper enforces a policy-as-file with safe built-in defaults (no file required); override via `.agent0/browser-policy.json` (template: `.agent0/browser-policy.json.example`):

- **Read-only** (`snapshot/screenshot/console/vitals/get/...`) → allowed + audited.
- **Same-origin interactive** (`click/fill/type/...` against an allowlisted host; `localhost`/`127.0.0.1`/`file://` are local) → allowed + audited.
- **External / sensitive** (cross-origin navigation; `upload/download/eval/cookies/storage/network/pdf`) → blocked unless the host is allowlisted or `--confirm` is passed (raw `eval` always needs `--confirm`). 

Every `run` appends a JSONL audit line (`ts/cmd/action/target/class/decision/guard`) under `.agent0/.runtime-state/agent-browser/` (gitignored). Profiles / saved `state` JSON under `.agent0/.runtime-state/agent-browser/{profiles,state}/` are **credential-class** (gitignored — see `secrets-scan.md`).

## Human-in-the-loop auth (spec 152.2 — the headed-login flow)

The headed human-login step **cannot be agent-spawned reliably** in this class of environment: WSLg drops the window surface and the harness reaps agent-spawned process trees (the Chrome process survives but the visible window dies). The robust, secure model is **the human owns the browser; the agent attaches over CDP**:

1. **Human runs one memorable command** — `bash .agent0/tools/browser-login.sh <host>` (`github` / `x` / `linkedin`, or any login URL). It launches a **dedicated, isolated, detached** Chrome with a CDP debug port (`9222`) at the login page. Detached so it survives the launching shell (terminal OR Claude `!`); dedicated profile (`.agent0/.runtime-state/agent-browser/profiles/login-<host>`) so only the account the human logs into is exposed — **never the human's main Chrome** (`--auto-connect` to the main profile is forbidden; see `browser-auth.md`).
2. **Human logs in** in that window. The agent never sees or handles credentials.
3. **Agent adopts** — `agent-browser.sh adopt <host> [--port 9222] [--timeout S]` polls the CDP `/json` endpoint (plain HTTP — **non-disruptive**, it never navigates the human's tab while they type) until a page on the host **leaves the login flow** (denylist: `login|signin|session|oauth|sso|challenge|checkpoint|authwall|i/flow`), then saves the session state (credential-class) over CDP. `--detect-only` reports completion without saving ("is the human logged in yet?"). After adopt, headless reuse via `--state`/`state load` works (§ Persistent auth).

The agent signals the start with `BROWSER_LOGIN_REQUIRED: <host>` naming the exact `browser-login.sh` command (spec 153 — renamed from the legacy `BROWSER_AUTH_REQUIRED`, since the remedy is now `browser-login.sh` → `adopt`, no MCP). This is the agent-browser-native auth flow, with the CDP-attach twist the environment forces. See `browser-auth.md`.

## Persistent auth

agent-browser's native `state save <file>` / `--state <file> open` (or `state load`) is the auth-reuse mechanism. The saved JSON (under `.agent0/.runtime-state/agent-browser/state/<host>.json`) holds cookies + localStorage and is credential-class. For an auth-gated flow: log in once (interactively or via `auth login`/the `browser-login.sh`→`adopt` flow above), `state save`, then reuse with `--state` on later runs.

## Visual-contract verification

`verify-contract <url> <fixture.json> <outdir>` is the bounded loop for verifying a `/product`→`/sdd` visual contract: it opens the URL, captures a11y snapshot + annotated screenshot + console + vitals, and asserts a fixture-spec (`{ "required": [{role,name}...], "max_console_errors": N }`) → a `PASS/FAIL` `report.json` + artifacts. The model reasons only over the residual, not over whether the page loaded. The fixture-spec extends past the `render` floor with optional `interactions` and `flow` arrays (named-control exercise + ordered route traversal with per-step assertions), so a contract covers navigation/interaction/flow, not just static render — the depth tiers and the `UI impact` acceptance gate they feed live in `.agent0/context/rules/visual-contract.md` (spec 155).

## Structural audit (spec 152.1 — demand-validated by the real site-audit dogfood)

`audit <base-url> --paths a,b,c [--out dir] [--max-console N] [--structure strict|optional]` sweeps a page set and emits `report.{md,json}` + per-page screenshots. Per page it parses the rendered a11y tree for **structure** (exactly one level-1 heading + a `main` landmark + `nav`), counts console errors, records vitals (advisory), and probes **horizontal overflow** at 375 px and 1280 px (`scrollWidth > clientWidth`, advisory — captured via a fixed internal read-only `eval`, spec 153). Two structure modes: **`strict`** (default) gates `h1 != 1` / no `main` / console `> max` (the 152.1 site-audit semantics, unchanged); **`optional`** makes `h1`/`main` advisory and gates on console only — for landmark-less fragments like `/product` hi-fi mood screens. The sweep owns daemon lifecycle + aggregation so callers don't hand-roll it.

The primitive owns the structural parsing because **hand-rolling it is error-prone**: the naive `grep -c 'level=1'` over the snapshot text ALSO matches `listitem [level=1]` (nesting depth), so a clean page with one `<h1>` and seven list items mis-reports as `h1=8`. `parse-structure` parses heading lines only (`heading … [level=1[,\]]`). This bug was hit for real auditing `site/dist/` by hand — the `audit` command exists so nobody repeats it. Vitals are meaningful only against a deployed/throttled target (on local static, LCP is always ~20ms).

## Activation (opt-in)

Opt-in, like the MCP recipes / `/image` / `/video`. Install once per machine:

```bash
npm install -g agent-browser        # or: brew install agent-browser / cargo install agent-browser
agent-browser install               # download Chrome-for-Testing (skip if a system Chrome exists)
```

The wrapper defaults the browser executable to the system Chrome via `AGENT_BROWSER_EXECUTABLE_PATH` when present. `bash .agent0/tools/doctor.sh` reports availability (tri-state under `=== browser primitive ===`). When the binary is absent, first-party browser work **fails closed** (rc 4) — there is no MCP fallback (spec 153); install agent-browser to restore the capability.

## Gotchas (verified empirically, spec 152 build)

- **`close --all` HANGS when no daemon is running.** The wrapper's `reset` guards this (only calls it when a daemon exists, with a timeout). Never call `agent-browser close --all` blind in a script.
- **The daemon is global and ignores launch options** (`--profile`/`--state`/`--session-name`) if already running. Use `agent-browser.sh reset` to rebind, or use **isolated `--session <name>`** (independent cookies within one daemon) to avoid restarts.
- **Kill the daemon surgically**: match processes whose argv[0] ends in `agent-browser-linux*`, never `pkill -f agent-browser` (that also kills the calling shell whose command line contains the pattern).
- **`agent-browser wait <ms>` is not a reliable settle in fast scripts** — prefer `wait <selector>` for presence, or a shell `sleep` for navigation settle.
- The JSON envelope is `{success, data, error}`; `snapshot --json` → `.data.refs` keyed by ref (`{name, role}`). Pinned version: see `PINNED_VERSION` in the wrapper.

## Cross-references

- `.agent0/context/rules/browser-auth.md` — the agent-browser-native auth-gated read flow (`browser-login.sh` → `adopt`; `BROWSER_LOGIN_REQUIRED` signal).
- `.agent0/context/rules/secrets-scan.md` — credential-class framing for profiles/state files.
- `.agent0/context/rules/runtime-capabilities.md` — runtime-neutral capability matrix.
- `docs/specs/152-browser-primitive-consolidation/` — the spec; `.agent0/tests/agent-browser/` — the suite.
