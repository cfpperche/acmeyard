#!/usr/bin/env bash
# policy-eval: read-only/same-origin allow; external + sensitive need confirm.
source "$(dirname "$0")/_lib.sh"
echo "03-policy"

pe() { bash "$TOOL" policy-eval "$@"; }   # prints "decision reason"; rc 0 allow / 2 not

OUT="$(pe snapshot "")"; RC=$?
assert_contains "$OUT" "allow" "read-only snapshot allowed"; assert_rc "$RC" 0 "read-only rc 0"

OUT="$(pe click "http://localhost:8080/x")"; RC=$?
assert_contains "$OUT" "allow" "same-origin (localhost) interactive allowed"; assert_rc "$RC" 0 "same-origin rc 0"

OUT="$(pe open "https://example.com")"; RC=$?
assert_contains "$OUT" "confirm" "external nav needs confirm"; assert_rc "$RC" 2 "external nav rc 2"

OUT="$(pe open "https://example.com" --confirm)"; RC=$?
assert_contains "$OUT" "allow" "external nav allowed with --confirm"; assert_rc "$RC" 0 "confirmed rc 0"

OUT="$(pe eval "file:///x")"; RC=$?
assert_contains "$OUT" "deny" "raw eval denied without confirm"; assert_rc "$RC" 2 "eval rc 2"

OUT="$(pe eval "file:///x" --confirm)"; RC=$?
assert_contains "$OUT" "allow" "eval allowed with --confirm"; assert_rc "$RC" 0 "eval confirmed rc 0"

# a consumer policy file overrides the allowlist
POL="$AGENT0_PROJECT_DIR/.agent0/browser-policy.json"
printf '{"allowlist":["example.com"]}' > "$POL"
OUT="$(AGENT0_BROWSER_POLICY="$POL" pe open "https://example.com")"; RC=$?
assert_rc "$RC" 0 "policy-file allowlist promotes example.com to same-origin"

finish
