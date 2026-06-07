#!/usr/bin/env bash
# --kind required (usage error 64); no FAL_KEY -> unavailable, decoupled from exit.
source "$(dirname "$0")/_lib.sh"; echo "05-kind-required-and-no-key"
# --kind required
OUT="$(bash "$TOOL" "something" 2>&1)"; RC=$?
assert_eq "$RC" "64" "missing --kind is a usage error (64)"
assert_contains "$OUT" "music | sfx" "error names both kinds"
# bad kind
bash "$TOOL" "x" --kind voice >/dev/null 2>&1; assert_eq "$?" "64" "unknown --kind rejected"
# mismatched tier for kind
OUT2="$(bash "$TOOL" "x" --kind music --tier sfx)"
assert_contains "$OUT2" "is for kind 'sfx', not 'music'" "tier/kind mismatch caught"
# no FAL_KEY -> unavailable, default exit 0
OUTNK="$(env -u FAL_KEY bash "$TOOL" "door creak" --kind sfx)"; RCNK=$?
assert_eq "$RCNK" "0" "no-key default exit 0"
assert_contains "$OUTNK" "status=unavailable" "no-key status unavailable"
assert_contains "$OUTNK" "FAL_KEY" "no-key hint names FAL_KEY"
# no FAL_KEY with --exit-code -> 2
env -u FAL_KEY bash "$TOOL" "door creak" --kind sfx --exit-code >/dev/null 2>&1; assert_eq "$?" "2" "--exit-code maps unavailable=2"
# manifest still records the failed call (one line per call incl. failure)
M="$(cat "$WORK/m.jsonl" 2>/dev/null)"
assert_contains "$M" '"status":"unavailable"' "manifest records the unavailable call"
finish
