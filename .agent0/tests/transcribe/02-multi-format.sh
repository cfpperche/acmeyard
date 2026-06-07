#!/usr/bin/env bash
# Scenario: --format txt,srt,json -> all three produced, manifest outputs has 3, thin passthrough.
source "$(dirname "$0")/_lib.sh"
echo "02-multi-format"

IN="$(mkinput talk.m4a)"
OUT="$(bash "$TOOL" "$IN" --format txt,srt,json)"; RC=$?

assert_eq "$RC" "0" "exit 0"
assert_contains "$OUT" "status=ok" "status ok"
assert_file "$WORK/out/talk.txt" "txt produced"
assert_file "$WORK/out/talk.srt" "srt produced"
assert_file "$WORK/out/talk.json" "json produced"
MANI="$(cat "$WORK/manifest.jsonl")"
assert_contains "$MANI" "talk.txt" "manifest outputs include txt"
assert_contains "$MANI" "talk.srt" "manifest outputs include srt"
assert_contains "$MANI" "talk.json" "manifest outputs include json"

finish
