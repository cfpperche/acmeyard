#!/usr/bin/env bash
# spec-152 auth-gated dogfood slice — self-contained, deterministic, no human,
# no real credentials. Proves agent-browser's native state save/load reuse path
# (the agent-browser-native equivalent of browser-auth.md's login →
# state save/load reuse), driven THROUGH the Agent0 wrapper (audited), with a
# negative control proving the saved state is load-bearing.
#
# Design: ONE daemon, THREE isolated `--session`s (auth / fresh / reuse) — no
# daemon restart dance (restarts are slow/flaky; `close --all` even HANGS with
# no daemon). Sessions are independent browsers within the live daemon.
#
# Exit 0 = PASS. Requires: agent-browser on PATH, a Chrome, node, jq.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null)"; [ -n "$ROOT" ] || ROOT="$(cd "$HERE/../../../.." && pwd)"
T="$ROOT/.agent0/tools/agent-browser.sh"
PORT="${AUTH_PORT:-8150}"
[ -n "${AGENT_BROWSER_EXECUTABLE_PATH:-}" ] || { for c in google-chrome chromium chromium-browser; do command -v "$c" >/dev/null 2>&1 && export AGENT_BROWSER_EXECUTABLE_PATH="$(command -v "$c")" && break; done; }

gettext() { agent-browser --session "$1" get text "$2" --json 2>/dev/null | jq -r '.data.text // ""' 2>/dev/null; }

AUTH_PORT="$PORT" node "$HERE/auth-server.js" >/tmp/auth-slice-server.log 2>&1 &
SRV=$!
cleanup() { kill "$SRV" 2>/dev/null; bash "$T" reset >/dev/null 2>&1; }
trap cleanup EXIT
sleep 1

STATE="$(mktemp -d)/auth.json"
bash "$T" reset >/dev/null 2>&1   # one clean reset to start

# --- A: session 'auth' logs in (audited through the wrapper), capture state ---
bash "$T" run -- --session auth open "http://localhost:$PORT/login" >/dev/null 2>&1
agent-browser --session auth wait "#submit" >/dev/null 2>&1   # settle: form is loaded
bash "$T" run -- --session auth fill "#username" demo   >/dev/null 2>&1
bash "$T" run -- --session auth fill "#password" secret >/dev/null 2>&1
bash "$T" run -- --session auth click "#submit"         >/dev/null 2>&1
sleep 2   # the submit's 302 lands on /dashboard (shell sleep settles reliably; `wait <ms>` does not)
A_H1="$(gettext auth h1)"
agent-browser --session auth state save "$STATE" >/dev/null 2>&1
A_COOKIES="$(jq '.cookies | length' "$STATE" 2>/dev/null || echo 0)"

# --- NEG control: isolated session 'fresh' (no cookies) → /dashboard bounces ---
agent-browser --session fresh open "http://localhost:$PORT/dashboard" >/dev/null 2>&1
sleep 1
NEG_H1="$(gettext fresh h1)"

# --- B: isolated session 'reuse' loads saved state → /dashboard authed ---
agent-browser --session reuse state load "$STATE" >/dev/null 2>&1
agent-browser --session reuse open "http://localhost:$PORT/dashboard" >/dev/null 2>&1
sleep 2
B_H1="$(gettext reuse h1)"

echo "A_H1='$A_H1' cookies=$A_COOKIES | NEG_H1='$NEG_H1' | B_H1='$B_H1'"
echo "state file (credential-class): $STATE"
if [ "$A_H1" = "Account" ] && [ "${A_COOKIES:-0}" -ge 1 ] && [ "$NEG_H1" = "Sign in" ] && [ "$B_H1" = "Account" ]; then
  echo "AUTH-SLICE: PASS"
  exit 0
fi
echo "AUTH-SLICE: FAIL"
exit 1
