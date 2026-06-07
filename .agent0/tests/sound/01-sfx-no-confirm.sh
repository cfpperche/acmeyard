#!/usr/bin/env bash
# cheap sfx flows without --confirm-cost-usd: cost printed, draft mp3, manifest.
source "$(dirname "$0")/_lib.sh"; echo "01-sfx-no-confirm"
OUT="$(bash "$TOOL" "door creak" --kind sfx)"; RC=$?
assert_eq "$RC" "0" "exit 0"
assert_contains "$OUT" "printed BEFORE the call" "cost printed before call"
assert_contains "$OUT" "status=ok" "status ok"
assert_contains "$OUT" "kind=sfx" "kind sfx"
assert_contains "$OUT" "stayed_local=false" "paid lane stayed_local false"
assert_eq "$(ls "$WORK/draft" | grep -c '\.mp3$')" "1" "one draft mp3 written"
# body shape: sfx uses prompt_field=text + duration_field=duration_seconds
B="$(cat "$WORK/body.json")"
assert_contains "$B" '"text":"door creak"' "body uses text field (sfx)"
assert_contains "$B" '"duration_seconds":5' "body carries default 5s duration"
M="$(cat "$WORK/m.jsonl")"
assert_contains "$M" '"kind":"sfx"' "manifest kind sfx"
assert_contains "$M" '"provider":"fal"' "manifest provider fal"
assert_contains "$M" '"cost_estimate_usd":0.01' "manifest cost field (0.002*5)"
assert_contains "$M" '"stayed_local":false' "manifest stayed_local false"
assert_contains "$M" '"request_id":"req-el-1"' "manifest request id"
assert_not_contains "$M" "test-dummy-key" "manifest never records the key"
finish
