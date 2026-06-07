#!/usr/bin/env bash
# default lands in gitignored draft; --asset promotes to the tracked dir. No auto-done.
source "$(dirname "$0")/_lib.sh"; echo "04-draft-vs-asset"
OUT="$(bash "$TOOL" "whoosh" --kind sfx)"
assert_contains "$OUT" "class=draft" "default class draft"
assert_contains "$OUT" "promote a keeper with --asset" "draft nudges taste-judge promotion"
assert_eq "$(ls "$WORK/draft" | grep -c '\.mp3$')" "1" "draft dir has the clip"
assert_eq "$(ls "$WORK/asset" 2>/dev/null | grep -c '\.mp3$')" "0" "asset dir empty by default"
OUT2="$(bash "$TOOL" "whoosh" --kind sfx --asset)"
assert_contains "$OUT2" "class=asset" "--asset class asset"
assert_eq "$(ls "$WORK/asset" | grep -c '\.mp3$')" "1" "asset dir now has the keeper"
M="$(cat "$WORK/m.jsonl")"
assert_contains "$M" '"class":"draft"' "manifest records draft class"
assert_contains "$M" '"class":"asset"' "manifest records asset class"
finish
