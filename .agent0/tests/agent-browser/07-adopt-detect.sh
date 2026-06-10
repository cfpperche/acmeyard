#!/usr/bin/env bash
# adopt detection logic (spec 152.2): non-disruptive CDP /json poll detects when
# a host's tab leaves the login flow. Tested against a fake CDP endpoint — no
# real browser needed. Uses --detect-only (no state save) so it's deterministic.
source "$(dirname "$0")/_lib.sh"
echo "07-adopt-detect"

command -v node >/dev/null 2>&1 || { echo "  ⓘ SKIP (no node)"; finish; exit 0; }
command -v agent-browser >/dev/null 2>&1 || { echo "  ⓘ SKIP (no agent-browser binary) — adopt fail-closes without it; CDP-detect logic needs the real route"; finish; exit 0; }
FCDP=9231

start_fake() { # start_fake <url>
  FAKE_CDP_PORT=$FCDP CDP_URL="$1" node "$FIXTURES/fake-cdp.js" >/dev/null 2>&1 &
  FAKE_PID=$!; sleep 1
}
stop_fake() { kill "${FAKE_PID:-0}" 2>/dev/null; }

# 1) tab still on the login flow → adopt times out (returns non-zero), saves nothing
start_fake "https://github.com/login"
bash "$TOOL" adopt github --port $FCDP --domain github.com --detect-only --timeout 3 >/dev/null 2>&1; RC=$?
assert_rc "$RC" 1 "still on /login ⇒ adopt times out (no false detection)"
stop_fake

# 2) tab left the login flow → adopt detects, returns 0
start_fake "https://github.com/dashboard"
OUT="$(bash "$TOOL" adopt github --port $FCDP --domain github.com --detect-only --timeout 6 2>&1)"; RC=$?
assert_rc "$RC" 0 "authed dashboard ⇒ adopt detects"
assert_contains "$OUT" "DETECTED github" "detection reported"
stop_fake

# 3) the login denylist covers oauth/2fa/checkpoint, not authed paths
start_fake "https://x.com/i/flow/login"
bash "$TOOL" adopt x --port $FCDP --domain x.com --detect-only --timeout 3 >/dev/null 2>&1
assert_rc "$?" 1 "x.com/i/flow/login still counts as login flow"
stop_fake

# 4) no CDP server on the port → clear error, rc 4
bash "$TOOL" adopt github --port 9239 --detect-only --timeout 3 >/dev/null 2>&1
assert_rc "$?" 4 "no CDP endpoint ⇒ rc 4 (points at browser-login.sh)"

finish
