#!/usr/bin/env bash
# parse-structure: correct a11y metrics from the snapshot text tree (spec 152.1).
# Regression: the naive `grep -c level=1` counts `listitem [level=1]` (nesting)
# as h1s — the exact bug hit during the real site-audit dogfood. Parser must not.
source "$(dirname "$0")/_lib.sh"
echo "06-structure"

TRAP='- main
  - heading "Title" [level=1, ref=e1]
  - navigation "primary" [ref=e2]
  - list
    - listitem [level=1]
    - listitem [level=1]
    - listitem [level=1]
  - heading "Section" [level=2, ref=e3]'
OUT="$(bash "$TOOL" parse-structure "$TRAP")"
assert_contains "$OUT" "h1=1" "exactly one h1 despite 3 listitem [level=1] (no overcount)"
assert_contains "$OUT" "h2=1" "one h2"
assert_contains "$OUT" "main=1" "main landmark detected"
assert_contains "$OUT" "nav=1" "navigation detected"

# two real h1s ARE counted
TWO='- heading "A" [level=1, ref=e1]
- heading "B" [level=1, ref=e2]'
assert_contains "$(bash "$TOOL" parse-structure "$TWO")" "h1=2" "two real h1s counted as 2"

# missing landmarks reported as 0
NONE='- heading "A" [level=1, ref=e1]
- list
  - listitem [level=1]'
OUT="$(bash "$TOOL" parse-structure "$NONE")"
assert_contains "$OUT" "main=0" "absent main reported 0"
assert_contains "$OUT" "nav=0" "absent nav reported 0"
assert_contains "$OUT" "h1=1" "still exactly one h1 (listitem not counted)"

finish
