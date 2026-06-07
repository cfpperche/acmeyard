#!/usr/bin/env bash
# premium music above $0.25 refused without --confirm-cost-usd, proceeds with it.
source "$(dirname "$0")/_lib.sh"; echo "02-music-above-threshold"
# premium @ $0.80/min, 60s -> $0.80 > 0.25 -> refused
OUT="$(bash "$TOOL" "lofi hip hop" --kind music --tier premium --duration 60)"; RC=$?
assert_eq "$RC" "0" "default exit 0 even when refused"
assert_contains "$OUT" "~\$0.8000 for 60s" "cost printed (0.80*60/60)"
assert_contains "$OUT" "exceeds the \$0.25 confirm threshold" "refused above threshold"
assert_contains "$OUT" "--confirm-cost-usd" "hint names the flag"
assert_eq "$(ls "$WORK/draft" 2>/dev/null | wc -l | tr -d ' ')" "0" "nothing generated when refused"
# now with confirmation >= estimate
OUT2="$(bash "$TOOL" "lofi hip hop" --kind music --tier premium --duration 60 --confirm-cost-usd 0.80)"
assert_contains "$OUT2" "status=ok" "proceeds with sufficient --confirm-cost-usd"
assert_eq "$(ls "$WORK/draft" | grep -c '\.mp3$')" "1" "music draft written after confirm"
# exit-code mapping: refused is an error status -> exit 3 with --exit-code
bash "$TOOL" "x" --kind music --tier premium --duration 60 --exit-code >/dev/null 2>&1; assert_eq "$?" "3" "--exit-code maps refused(error)=3"
finish
