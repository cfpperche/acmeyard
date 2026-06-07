#!/usr/bin/env bash
# Scenario: an unknown --format value is a clean error, not a crash.
source "$(dirname "$0")/_lib.sh"
echo "06-unknown-format"

IN="$(mkinput call.mp3)"
OUT="$(bash "$TOOL" "$IN" --format txt,bogus)"; RC=$?

assert_eq "$RC" "0" "advisory exit 0"
assert_contains "$OUT" "status=error" "unknown format -> error status"
assert_contains "$OUT" "unknown --format" "names the bad format"

finish
