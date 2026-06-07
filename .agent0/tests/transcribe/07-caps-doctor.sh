#!/usr/bin/env bash
# Scenario: caps emits JSON with the injected engine; doctor is human-readable + exit 0.
source "$(dirname "$0")/_lib.sh"
echo "07-caps-doctor"

CAPS="$(bash "$TOOL" caps)"
assert_contains "$CAPS" "\"engine\"" "caps has engine field"
assert_contains "$CAPS" "fake-whisper" "caps reports the injected engine"

DOC="$(bash "$TOOL" doctor)"; RC=$?
assert_eq "$RC" "0" "doctor exits 0"
assert_contains "$DOC" "capability check" "doctor prints a report"
assert_contains "$DOC" "whisper engine" "doctor reports the engine line"

finish
