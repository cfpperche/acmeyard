#!/usr/bin/env bash
# Piper local lane -> ok, file in draft dir, manifest stayed_local true engine piper.
source "$(dirname "$0")/_lib.sh"; echo "01-piper-local"
OUT="$(bash "$TOOL" "hello world" --engine piper)"; RC=$?
assert_eq "$RC" "0" "exit 0"
assert_contains "$OUT" "status=ok" "status ok"
assert_contains "$OUT" "engine=piper" "used piper"
assert_contains "$OUT" "stayed_local=true" "local stayed local"
assert_eq "$(ls "$WORK/draft" | wc -l | tr -d ' ')" "1" "one file in draft dir"
M="$(cat "$WORK/m.jsonl")"
assert_contains "$M" "\"engine\":\"piper\"" "manifest engine piper"
assert_contains "$M" "\"stayed_local\":true" "manifest stayed_local true"
finish
