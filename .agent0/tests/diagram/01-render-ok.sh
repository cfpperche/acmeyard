#!/usr/bin/env bash
# valid mermaid + chrome present -> ok, tracked svg, source persisted, manifest.
source "$(dirname "$0")/_lib.sh"; echo "01-render-ok"
OUT="$(bash "$TOOL" "flowchart TD
  A --> B" --kind flowchart --json)"; RC=$?
assert_eq "$RC" "0" "exit 0"
assert_contains "$OUT" '"status":"ok"' "status ok"
assert_contains "$OUT" '"stayed_local":true' "local utility stayed_local true"
assert_contains "$OUT" '"engine":"mermaid/mmdc"' "engine mmdc"
assert_eq "$(ls "$WORK/out" | grep -c '\.svg$')" "1" "one svg written"
assert_eq "$(ls "$WORK/out" | grep -c '\.mmd$')" "1" "inline source persisted as tracked .mmd"
M="$(cat "$WORK/m.jsonl")"
assert_contains "$M" '"status":"ok"' "manifest ok"
assert_contains "$M" '"format":"svg"' "manifest format svg"
assert_contains "$M" '"stayed_local":true' "manifest stayed_local true"
assert_not_contains "$M" "cost" "no cost field (free utility)"
assert_not_contains "$M" "FAL_KEY" "no key anywhere"
finish
