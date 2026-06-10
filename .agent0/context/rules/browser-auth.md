---
paths:
  - ".agent0/.runtime-state/agent-browser/state/**"
  - ".agent0/tools/browser-login.sh"
  - ".agent0/tools/agent-browser.sh"
---

# Browser auth

> **agent-browser-native.** Authenticated-content reads run **exclusively** through the `agent-browser` primitive — the human-in-the-loop `browser-login.sh` → `adopt` flow below. There is **no Playwright/Chrome DevTools MCP path**: those survive only as opt-in `.mcp.json.example` / `.codex/config.toml.example` templates a consumer may wire up for their own use, never a harness fallback. See `.agent0/context/rules/browser-primitive.md`.

Authenticated reads use a **headed-login → save state → headless-reuse** pattern, where the **human owns the browser and the agent attaches over CDP** (the environment can't reliably keep an agent-spawned headed window alive — see browser-primitive.md § Human-in-the-loop auth). This rule documents the signaling convention (`BROWSER_LOGIN_REQUIRED: <host>`), the per-host state directory (`.agent0/.runtime-state/agent-browser/state/<host>.json`), and the X/Twitter shortcut that avoids the full flow for a common case.

## X/Twitter shortcut (try first)

Before invoking the full auth flow for an X/Twitter URL of the form `x.com/<user>/status/<id>` or `twitter.com/<user>/status/<id>`, try the public thread-reader services first. Nitter is dead in 2026; use:

1. **Primary:** `https://unrollnow.com/status/<id>` — fetch via `WebFetch`. If the body is non-empty and contains the thread text, the read succeeds without any auth step.
2. **Backup:** `https://threadreaderapp.com/thread/<id>.html` — same `WebFetch` approach. Use when unrollnow returns empty or an error.

Only if both fail (empty body, HTTP error, or no thread content) fall back to the `BROWSER_LOGIN_REQUIRED` signal below. **The shortcut covers the original-poster's thread continuation only** — NOT replies from other users, quote-tweets, or any sub-thread by a different author. If the request needs replies ("read post AND replies"), the shortcut is insufficient and the auth flow is required even for public posts. Other gaps: locked accounts, DM-only content, threadreaderapp returning a login page for threads it has not indexed yet (verified empirically 2026-05).

**Reply-set virtualization gotcha (auth flow path).** Once authenticated, X.com renders the reply list with virtualized scrolling — a single `agent-browser snapshot` captures only the ~10 replies in the current viewport, NOT the full reply set (a post showing `37 replies` may surface only 8-10 per snapshot). To collect all replies, drive `agent-browser.sh run -- press PageDown` (or `run -- scroll down 2000`) in a loop and snapshot between scrolls until no new article refs appear. Same shape applies to the quote-tweet feed.

## Signaling convention — `BROWSER_LOGIN_REQUIRED: <host>`

When the agent encounters a URL that requires authentication and no saved state exists for that host, it emits this phrase to the chat:

```
BROWSER_LOGIN_REQUIRED: <host>
```

where `<host>` is the bare hostname (e.g. `x.com`, `linkedin.com`). The agent follows the phrase with a one-line next step naming the exact `browser-login.sh` command. Example:

```
BROWSER_LOGIN_REQUIRED: x.com
Next step: run  bash .agent0/tools/browser-login.sh x  — log in at x.com in the window
  that opens, then I'll attach over CDP with `agent-browser.sh adopt x` and save state.
See .agent0/context/rules/browser-auth.md.
```

The phrase is all-caps with a colon-space separator — agents and humans alike can grep for it (and `context-inject.sh` auto-selects this rule on `*login*`/`*browser*`/`*auth*` prompts). The agent does NOT retry the same host until the human signals login is done (by replying, or by the agent's `adopt --detect-only` confirming, or by the state file existing on disk). _(Renamed from the legacy `BROWSER_AUTH_REQUIRED` — the remedy is now `browser-login.sh` → `adopt`, not an MCP session.)_

## The flow — `browser-login.sh` → `adopt` → reuse

**Step 1 — human launches the login browser (one command).**

```bash
bash .agent0/tools/browser-login.sh <host>     # github | x | linkedin | or any login URL
```

This launches a **dedicated, isolated, detached** Chrome with a CDP debug port (`9222`) at the login page. Detached so it survives the launching shell (a terminal OR a Claude `!` command); a dedicated profile (`.agent0/.runtime-state/agent-browser/profiles/login-<host>`) so only the account the human logs into is exposed — **never the human's main Chrome**. The human logs in; the agent never sees or handles credentials.

**Step 2 — the agent adopts the session over CDP.**

```bash
bash .agent0/tools/agent-browser.sh adopt <host> [--port 9222] [--timeout 300]
```

`adopt` polls the CDP `/json` HTTP endpoint (**non-disruptive** — it never navigates the human's tab while they type) until a page on the host **leaves the login flow** (denylist: `login|signin|session|oauth|sso|challenge|checkpoint|authwall|i/flow`), then saves the session state over CDP to `.agent0/.runtime-state/agent-browser/state/<host>.json` (credential-class). `adopt <host> --detect-only` reports completion without saving ("is the human logged in yet?").

**Step 3 — headless reuse.**

```bash
agent-browser --state .agent0/.runtime-state/agent-browser/state/<host>.json open https://<host>/
# or through the wrapper:  agent-browser.sh run -- --state <file> open https://<host>/
```

The saved JSON holds cookies + localStorage (including `httpOnly` cookies like `li_at` / `auth_token`). Reuse is silent: when the state file exists and is loaded, the agent navigates as authenticated and `BROWSER_LOGIN_REQUIRED` is NOT emitted.

## Storage state — `.agent0/.runtime-state/agent-browser/state/<host>.json`

Session state is stored one file per host under `.agent0/.runtime-state/agent-browser/state/`. Individual state files are gitignored because they contain session cookies + localStorage — equivalent blast radius to a leaked password. Convention:

- Filename: lowercase hostname, `.json` extension. Examples: `x.com.json`, `linkedin.com.json`, `github.com.json` (the wrapper also accepts the short aliases `github`/`x`/`linkedin`).
- Path: `.agent0/.runtime-state/agent-browser/state/<host>.json` relative to the project root.
- Never commit these files (the whole `.agent0/.runtime-state/` tree is gitignored). See `.agent0/context/rules/secrets-scan.md` for the credential-class framing.

## Expired-state recovery

Storage state expires when the site rotates session tokens — typically days to weeks. The agent recognises expiry when a navigation that previously succeeded now returns 401/403 or redirects to a login page. On detection:

1. Archive or remove the stale state file (`.agent0/.runtime-state/agent-browser/state/<host>.json`).
2. Re-emit `BROWSER_LOGIN_REQUIRED: <host>` to the chat.
3. Repeat the `browser-login.sh` → `adopt` cycle.

The agent does NOT retry silently or guess at token refresh; re-authentication requires the human. By design — session cookies are credentials, not config.

## Cross-references

- `.agent0/context/rules/browser-primitive.md` § Human-in-the-loop auth — the mechanism this rule's flow is built on.
- `.agent0/context/rules/secrets-scan.md` § *Soft advisory* — `.agent0/.runtime-state/agent-browser/state/*.json` are credential-class files; gitleaks treats high-entropy strings inside them as real findings.
- `.agent0/.runtime-state/README.md` — index of project-local state directories.
