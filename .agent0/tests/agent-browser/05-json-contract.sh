#!/usr/bin/env bash
# LIVE: pin the agent-browser JSON contract the wrapper depends on.
source "$(dirname "$0")/_lib.sh"
echo "05-json-contract (live)"
need_live || { finish; exit 0; }

bash "$TOOL" reset >/dev/null 2>&1
agent-browser open "file://$FIXTURES/screen.html" >/dev/null 2>&1
SNAP="$(agent-browser snapshot --json 2>/dev/null)"
agent-browser close --all >/dev/null 2>&1

assert_contains "$SNAP" '"success":true' "snapshot envelope: success"
assert_eq "$(printf '%s' "$SNAP" | jq -r 'has("data") and has("error")')" "true" "envelope has data+error"
assert_eq "$(printf '%s' "$SNAP" | jq -r '.data.refs | type')" "object" "data.refs is an object keyed by ref"
assert_eq "$(printf '%s' "$SNAP" | jq -r '[.data.refs[] | select(.role=="heading" and .name=="Dashboard")] | length')" "1" "ref carries role+name"

finish
