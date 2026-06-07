#!/usr/bin/env bash
# Kokoro with no espeak-ng + no injected cmd -> unavailable + espeak hint, exit 0.
source "$(dirname "$0")/_lib.sh"; echo "05-kokoro-no-espeak"
unset AUDIO_KOKORO_CMD            # force real resolve path
export AUDIO_ESPEAK_OK=0          # simulate espeak-ng absent
OUT="$(bash "$TOOL" "olá" 2>/dev/null)"; RC=$?
assert_eq "$RC" "0" "advisory exit 0"
assert_contains "$OUT" "status=unavailable" "unavailable when espeak-ng missing"
assert_contains "$OUT" "espeak-ng" "names espeak-ng in the hint"
assert_contains "$OUT" "--engine piper" "suggests the self-contained fallback"
finish
