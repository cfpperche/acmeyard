#!/usr/bin/env bash
# no usable chrome -> validation-only degrade: source kept, status unavailable.
source "$(dirname "$0")/_lib.sh"; echo "02-no-chrome-degrade"
OUT="$(DIAGRAM_CHROME_BIN="" bash "$TOOL" "sequenceDiagram
  A->>B: hi" --kind sequence)"; RC=$?
assert_eq "$RC" "0" "default exit 0 even when degraded"
assert_contains "$OUT" "status=unavailable" "render unavailable without chrome"
assert_contains "$OUT" "VALIDATED" "structural validation ran (degraded teeth)"
assert_contains "$OUT" "Install google-chrome" "install hint present"
assert_eq "$(ls "$WORK/out" | grep -c '\.mmd$')" "1" "source preserved (not a dead capacity)"
assert_eq "$(ls "$WORK/out" | grep -c '\.svg$')" "0" "no svg rendered"
M="$(cat "$WORK/m.jsonl")"
assert_contains "$M" '"status":"unavailable"' "manifest records the unavailable call"
assert_contains "$M" '"engine":"mermaid/validate"' "manifest engine validate (degraded)"
# --exit-code maps unavailable=2
DIAGRAM_CHROME_BIN="" bash "$TOOL" "flowchart TD
 A-->B" --exit-code >/dev/null 2>&1; assert_eq "$?" "2" "--exit-code maps unavailable=2"
finish
