#!/usr/bin/env bash
# LIVE (spec 152.2): full human-in-the-loop auth loop end-to-end, synthetic host.
# browser-login.sh launches a dedicated CDP Chrome → (human login simulated via
# CDP) → adopt auto-detects + saves state → adopted state reuses authed.
source "$(dirname "$0")/_lib.sh"
echo "13-dogfood-adopt (live)"
need_live || { finish; exit 0; }

ROOT="$AGENT0_ROOT"
PORT=$(( 8320 + (RANDOM % 40) )); CDP=$(( 9240 + (RANDOM % 40) ))
LOGIN="$ROOT/.agent0/tools/browser-login.sh"
STATE="$WORK/adopt.json"

cleanup_adopt() {
  agent-browser close --all >/dev/null 2>&1
  kill "${SRV:-0}" 2>/dev/null
  pgrep -af "login-localhost" 2>/dev/null | awk '$2 ~ /chrome$/{print $1}' | xargs -r kill 2>/dev/null
  pgrep -af agent-browser-linux 2>/dev/null | awk '$2 ~ /agent-browser-linux[^ ]*$/{print $1}' | xargs -r kill 2>/dev/null
}
trap cleanup_adopt EXIT

AUTH_PORT=$PORT node "$FIXTURES/auth-server.js" >/tmp/adopt-server.log 2>&1 & SRV=$!
sleep 1

# 1) human-run launcher brings up a dedicated CDP Chrome at the login page
OUT="$(BROWSER_LOGIN_PORT=$CDP bash "$LOGIN" "http://localhost:$PORT/login" 2>&1)"
assert_contains "$OUT" "BROWSER_LOGIN_READY" "browser-login.sh brought up a CDP Chrome"

# 2) simulate the HUMAN logging in (drive the SAME chrome over CDP)
agent-browser --cdp $CDP fill "#username" demo   >/dev/null 2>&1
agent-browser --cdp $CDP fill "#password" secret >/dev/null 2>&1
agent-browser --cdp $CDP click "#submit"         >/dev/null 2>&1
sleep 2

# 3) adopt auto-detects login completion (non-disruptive) and saves state
OUT="$(bash "$TOOL" adopt localhost --domain localhost --port $CDP --timeout 30 --state "$STATE" 2>&1)"; RC=$?
assert_rc "$RC" 0 "adopt detected login + saved state"
assert_contains "$OUT" "ADOPTED localhost" "adopt reported success"
assert_eq "$(jq -r '[.cookies[]|select(.name=="session")]|length' "$STATE" 2>/dev/null)" "1" "session cookie captured in state"

# 4) the adopted state reuses authed (proven state-load + isolated-session pattern)
pgrep -af "login-localhost" 2>/dev/null | awk '$2 ~ /chrome$/{print $1}' | xargs -r kill 2>/dev/null
bash "$TOOL" reset >/dev/null 2>&1
agent-browser --session reuse state load "$STATE" >/dev/null 2>&1
agent-browser --session reuse open "http://localhost:$PORT/dashboard" >/dev/null 2>&1
sleep 2
H1="$(agent-browser --session reuse get text h1 --json 2>/dev/null | jq -r '.data.text // "?"')"
assert_eq "$H1" "Account" "adopted state reuses authed page (no re-login)"

finish
