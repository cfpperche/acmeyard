#!/usr/bin/env bash
# 154 fix #3 — `squad.sh resume` is a NON-DESTRUCTIVE recovery from a false-positive
# / reconciled abort: it re-baselines the boundary to the current tree and returns
# status to running WITHOUT discarding uncommitted work (unlike `rollback`). It
# refuses to launder a genuine forbidden-path change unless --force.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SQ="$AGENT0_ROOT/.agent0/skills/squad/scripts/squad.sh"
T="$(mktemp -d -t sq-14-XXXXXX)"; trap 'rm -rf "$T"' EXIT
git -C "$T" init -q; mkdir -p "$T/docs/specs/199-demo"
printf '%s\n' '{"spec":"199-demo","roster":["claude","codex"],"max_rounds":20,"max_repair_attempts":3,"gate":["true"],"forbidden_paths":["\\.env"]}' > "$T/docs/specs/199-demo/squad.json"
R="$(bash "$SQ" init --spec 199-demo --repo "$T")"

# drive into aborted_conflict (an out-of-turn change with no open turn)
bash "$SQ" turn-start --run "$R" --speaker claude >/dev/null
printf 'work\n' > "$T/a.txt"
bash "$SQ" turn-end --run "$R" --speaker claude >/dev/null
printf 'sneaky\n' > "$T/out_of_turn.txt"
bash "$SQ" guard --run "$R" >/dev/null 2>&1 || true
[ "$(bash "$SQ" status --run "$R" | jq -r .status)" = "aborted_conflict" ] || { echo "FAIL: setup did not reach aborted_conflict"; exit 1; }

# resume recovers non-destructively
bash "$SQ" resume --run "$R" >/dev/null 2>&1 || { echo "FAIL: resume returned non-zero on a benign tree"; exit 1; }
[ "$(bash "$SQ" status --run "$R" | jq -r .status)" = "running" ] || { echo "FAIL: resume did not restore running"; exit 1; }
[ -f "$T/out_of_turn.txt" ] && [ -f "$T/a.txt" ] || { echo "FAIL: resume discarded uncommitted work (not non-destructive)"; exit 1; }
bash "$SQ" guard --run "$R" >/dev/null 2>&1 || true
[ "$(bash "$SQ" status --run "$R" | jq -r .status)" = "running" ] || { echo "FAIL: guard not clean after resume"; exit 1; }
echo "  ✓ resume recovered aborted_conflict → running, tree intact, guard clean"

# a GENUINE forbidden-path change must not be laundered by resume
printf 'SECRET=1\n' > "$T/.env"
bash "$SQ" guard --run "$R" >/dev/null 2>&1 || true
[ "$(bash "$SQ" status --run "$R" | jq -r .status)" = "aborted_policy" ] || { echo "FAIL: .env change did not trip aborted_policy"; exit 1; }
if bash "$SQ" resume --run "$R" >/dev/null 2>&1; then echo "FAIL: resume laundered a forbidden-path change without --force"; exit 1; fi
[ "$(bash "$SQ" status --run "$R" | jq -r .status)" = "aborted_policy" ] || { echo "FAIL: refused resume should leave status aborted"; exit 1; }
echo "  ✓ resume refuses a genuine forbidden-path change (no --force)"

# --force overrides (operator's explicit call)
bash "$SQ" resume --run "$R" --force >/dev/null 2>&1 || { echo "FAIL: resume --force did not succeed"; exit 1; }
[ "$(bash "$SQ" status --run "$R" | jq -r .status)" = "running" ] || { echo "FAIL: resume --force did not restore running"; exit 1; }
echo "  ✓ resume --force overrides"

echo PASS
