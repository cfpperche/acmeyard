#!/usr/bin/env bash
# Scenario: default run -> status=ok, txt written + echoed, manifest line w/ stayed_local.
source "$(dirname "$0")/_lib.sh"
echo "01-ok-txt"

IN="$(mkinput call.mp3)"
OUT="$(bash "$TOOL" "$IN")"; RC=$?

assert_eq "$RC" "0" "default exit is 0"
assert_contains "$OUT" "status=ok" "status ok"
assert_file "$WORK/out/call.txt" "txt transcript written to gitignored dir"
assert_contains "$OUT" "hello world this is a test transcript" "txt echoed to stdout"
assert_contains "$(cat "$WORK/manifest.jsonl")" "\"status\":\"ok\"" "manifest records ok"
assert_contains "$(cat "$WORK/manifest.jsonl")" "\"stayed_local\":true" "manifest records stayed_local"

finish
