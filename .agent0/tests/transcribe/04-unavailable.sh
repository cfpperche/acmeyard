#!/usr/bin/env bash
# Scenario: no engine + no acquire -> status=unavailable, honest hint, exit 0 (advisory).
source "$(dirname "$0")/_lib.sh"
echo "04-unavailable"

unset TRANSCRIBE_WHISPER_BIN   # no injected engine; NO_ACQUIRE=1 kills the uvx ladder
IN="$(mkinput call.mp3)"
OUT="$(bash "$TOOL" "$IN")"; RC=$?

assert_eq "$RC" "0" "advisory: exit 0 even when unavailable"
assert_contains "$OUT" "status=unavailable" "status unavailable"
assert_contains "$OUT" "could not be auto-acquired" "honest degrade message"
assert_contains "$(cat "$WORK/manifest.jsonl")" "\"status\":\"unavailable\"" "failure recorded in manifest"

finish
