#!/usr/bin/env bash
# --json structured output; --format wav passthrough (no ffmpeg); caps/doctor.
source "$(dirname "$0")/_lib.sh"; echo "06-json-format-wav"
J="$(bash "$TOOL" "rain" --kind sfx --json)"
assert_contains "$J" '"status":"ok"' "json status ok"
assert_contains "$J" '"stayed_local":false' "json stayed_local false"
assert_contains "$J" '"kind":"sfx"' "json kind"
# wav passthrough: even with a fake ffmpeg present, wav must not be transcoded path
W="$(bash "$TOOL" "rain" --kind sfx --format wav)"
assert_contains "$W" "status=ok" "wav status ok"
assert_eq "$(ls "$WORK/draft" | grep -c '\.wav$')" "1" "wav file written"
# caps reports paid-only + threshold
C="$(bash "$TOOL" caps)"
assert_contains "$C" '"paid_only":true' "caps paid_only"
assert_contains "$C" '"confirm_threshold_usd":0.25' "caps threshold"
# doctor never fails the harness
bash "$TOOL" doctor >/dev/null 2>&1; assert_eq "$?" "0" "doctor exit 0"
# threshold env override flips a normally-cheap call into needing confirm
OV="$(AGENT0_SOUND_CONFIRM_THRESHOLD=0.001 bash "$TOOL" "tick" --kind sfx)"
assert_contains "$OV" "exceeds the \$0.001 confirm threshold" "env threshold override honored"
finish
