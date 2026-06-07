#!/usr/bin/env bash
# run: emits a per-command audit line; denies sensitive without confirm.
source "$(dirname "$0")/_lib.sh"
echo "04-audit"

FAKE="$(fake_bin)"
export AGENT0_BROWSER_BIN="$FAKE" AB_CALLS_LOG="$WORK/ab-calls.log"

# allowed read-only ⇒ audited + passthrough executed
bash "$TOOL" run -- snapshot >/dev/null 2>&1; RC=$?
assert_rc "$RC" 0 "allowed read-only run rc 0"
AUDIT="$(bash "$TOOL" audit-tail 50)"
assert_contains "$AUDIT" '"action":"snapshot"' "snapshot audited"
assert_contains "$AUDIT" '"decision":"allow"' "allow decision recorded"
assert_contains "$(cat "$AB_CALLS_LOG" 2>/dev/null)" "snapshot" "passthrough reached the binary"

# denied sensitive ⇒ audited as deny, NOT executed, rc 2
: > "$AB_CALLS_LOG"
bash "$TOOL" run -- eval "alert(1)" >/dev/null 2>&1; RC=$?
assert_rc "$RC" 2 "denied sensitive run rc 2"
AUDIT="$(bash "$TOOL" audit-tail 50)"
assert_contains "$AUDIT" '"action":"eval"' "eval attempt audited"
assert_contains "$AUDIT" '"decision":"deny"' "deny decision recorded"
assert_eq "$(grep -c eval "$AB_CALLS_LOG" 2>/dev/null)" "0" "denied action NOT passed to the binary"

# unavailable route ⇒ explicit browser commands fail closed
OUT="$(AGENT0_BROWSER_BIN=/nonexistent/agent-browser bash "$TOOL" run -- snapshot 2>&1)"; RC=$?
assert_rc "$RC" 4 "no-binary run rc 4 (fail-closed)"
assert_contains "$OUT" "fail-closed" "refusal names fail-closed policy"

# removed MCP override ⇒ unsupported, not an alternate route
OUT="$(AGENT0_BROWSER=mcp AGENT0_BROWSER_BIN="$FAKE" bash "$TOOL" run -- snapshot 2>&1)"; RC=$?
assert_rc "$RC" 3 "MCP override run rc 3 (unsupported)"
assert_contains "$OUT" "unsupported" "MCP override refusal is explicit"

# adopt is also an explicit browser command and must fail before any CDP path
OUT="$(AGENT0_BROWSER_BIN=/nonexistent/agent-browser bash "$TOOL" adopt example.com 2>&1)"; RC=$?
assert_rc "$RC" 4 "no-binary adopt rc 4 (fail-closed)"
assert_contains "$OUT" "fail-closed" "adopt no-binary refusal names fail-closed policy"

OUT="$(AGENT0_BROWSER=mcp AGENT0_BROWSER_BIN="$FAKE" bash "$TOOL" adopt example.com 2>&1)"; RC=$?
assert_rc "$RC" 3 "MCP override adopt rc 3 (unsupported)"
assert_contains "$OUT" "unsupported" "adopt MCP override refusal is explicit"

finish
