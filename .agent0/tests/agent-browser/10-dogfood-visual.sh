#!/usr/bin/env bash
# LIVE dogfood slice 1: verify-contract against a generated screen + fixture-spec.
source "$(dirname "$0")/_lib.sh"
echo "10-dogfood-visual (live)"
need_live || { finish; exit 0; }

OUT="$WORK/vc"
bash "$TOOL" reset >/dev/null 2>&1
RES="$(bash "$TOOL" verify-contract "file://$FIXTURES/screen.html" "$FIXTURES/fixture-spec.json" "$OUT")"; RC=$?
echo "$RES" | sed 's/^/    /'
assert_rc "$RC" 0 "verify-contract overall PASS"
assert_contains "$RES" "PASS" "report says PASS"
assert_eq "$(jq -r '.overall' "$OUT/report.json" 2>/dev/null)" "pass" "report.json overall=pass"
assert_eq "$(jq -r '[.checks[] | select(.ok==false)] | length' "$OUT/report.json" 2>/dev/null)" "0" "no failed checks"
[ -s "$OUT/screen.png" ] && { PASS=$((PASS+1)); echo "  ✓ annotated screenshot artifact produced"; } || { FAIL=$((FAIL+1)); echo "  ✗ screenshot missing"; }

# negative: a fixture requiring an absent element must FAIL (the gate is real)
printf '{"required":[{"role":"button","name":"Nonexistent CTA"}],"max_console_errors":0}' > "$WORK/bad-spec.json"
bash "$TOOL" verify-contract "file://$FIXTURES/screen.html" "$WORK/bad-spec.json" "$WORK/vc2" >/dev/null 2>&1; RC=$?
assert_rc "$RC" 1 "missing required element ⇒ verify FAILS (gate is load-bearing)"

finish
