#!/usr/bin/env bash
# --remote (fake fal, dummy key) -> cost printed before, ok, manifest cost fields + stayed_local false.
source "$(dirname "$0")/_lib.sh"; echo "04-paid-fal"
export FAL_KEY="test-dummy-key"   # fake-fal ignores it; never the real key
OUT="$(bash "$TOOL" "speak this remotely" --remote)"; RC=$?
assert_eq "$RC" "0" "exit 0"
assert_contains "$OUT" "printed BEFORE the call" "cost printed before call"
assert_contains "$OUT" "status=ok" "status ok"
assert_contains "$OUT" "stayed_local=false" "paid lane stayed_local false"
M="$(cat "$WORK/m.jsonl")"
assert_contains "$M" "\"lane\":\"paid\"" "manifest lane paid"
assert_contains "$M" "\"provider\":\"fal\"" "manifest provider fal"
assert_contains "$M" "\"request_id\":\"req-test-123\"" "manifest request id"
assert_contains "$M" "\"cost_estimate_usd\":" "manifest cost field"
assert_contains "$M" "\"stayed_local\":false" "manifest stayed_local false"
assert_not_contains "$M" "test-dummy-key" "manifest never records the key"
finish
