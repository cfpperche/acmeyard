#!/usr/bin/env bash
# browser-login — HUMAN-run launcher for the agent-browser auth flow (spec 152.2).
#
# The headed human-login step can't be agent-spawned reliably (WSLg drops the
# window; the harness reaps agent-spawned process trees). So the HUMAN owns the
# browser: this opens a dedicated, isolated, detached Chrome with a CDP debug
# port at a host's login page. The human logs in; the agent then `adopt`s the
# logged-in session over CDP (`agent-browser.sh adopt <host>`) — it never
# touches credentials. One memorable command instead of a flag string nobody
# remembers.
#
#   bash .agent0/tools/browser-login.sh github
#   bash .agent0/tools/browser-login.sh https://example.com/login   # any URL
#
# Env: BROWSER_LOGIN_PORT (default 9222).
set -uo pipefail

HOST="${1:-}"; URL="${2:-}"
PORT="${BROWSER_LOGIN_PORT:-9222}"
[ -n "$HOST" ] || { echo "usage: browser-login.sh <host|login-url> [login-url]   (hosts: github, x, linkedin)" >&2; exit 3; }

case "$HOST" in
  github)            URL="${URL:-https://github.com/login}" ;;
  x|twitter)         HOST="x"; URL="${URL:-https://x.com/login}" ;;
  linkedin)          URL="${URL:-https://www.linkedin.com/login}" ;;
  http://*|https://*) URL="$HOST"; HOST="$(printf '%s' "$HOST" | sed -E 's#^https?://##; s#[/?#].*$##; s#:[0-9]+$##')" ;;
  *) [ -n "$URL" ] || { echo "unknown host '$HOST' — pass a login URL: browser-login.sh $HOST https://…" >&2; exit 3; } ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; [ -n "$ROOT" ] || ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROFILE="$ROOT/.agent0/.runtime-state/agent-browser/profiles/login-$HOST"
mkdir -p "$PROFILE"

CHROME="${AGENT_BROWSER_EXECUTABLE_PATH:-}"
if [ -z "$CHROME" ]; then
  for c in google-chrome google-chrome-stable chromium chromium-browser; do command -v "$c" >/dev/null 2>&1 && CHROME="$(command -v "$c")" && break; done
fi
[ -n "$CHROME" ] || { echo "no Chrome/Chromium found on PATH (set AGENT_BROWSER_EXECUTABLE_PATH)" >&2; exit 4; }

if curl -s -m2 "http://localhost:$PORT/json/version" >/dev/null 2>&1; then
  echo "note: a Chrome is already listening on CDP :$PORT — reusing it (close it first if it's the wrong profile)."
else
  # Fully detached so it survives the launching shell (terminal OR Claude `!`).
  setsid nohup "$CHROME" \
    --remote-debugging-port="$PORT" \
    --user-data-dir="$PROFILE" \
    --no-first-run --no-default-browser-check \
    "$URL" >/dev/null 2>&1 & disown || true
  for _ in $(seq 1 20); do curl -s -m2 "http://localhost:$PORT/json/version" >/dev/null 2>&1 && break; sleep 0.5; done
fi

if curl -s -m2 "http://localhost:$PORT/json/version" >/dev/null 2>&1; then
  echo "BROWSER_LOGIN_READY: $HOST  (dedicated profile login-$HOST, CDP :$PORT)"
  echo "→ Log in to $HOST in the window that just opened. The agent never sees your credentials."
  echo "→ When done, the agent runs:  bash .agent0/tools/agent-browser.sh adopt $HOST --port $PORT"
  echo "   (adopt auto-detects login completion by watching the CDP tab URL — non-disruptive)."
else
  echo "FAILED to bring up Chrome with CDP on :$PORT — check the display / run from your own terminal." >&2
  exit 4
fi
