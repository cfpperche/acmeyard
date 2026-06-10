#!/usr/bin/env bash
# .agent0/tests/shipped-integrity/run-all.sh
# Orchestrator: runs all scenario scripts in order and prints a summary table.
# Covers the doctor "shipped integrity" section (baseline-backed verification
# of the executable shipped surface). Exits 0 if all pass, 1 if any fail.
#
# Usage:
#   bash run-all.sh        # quiet — only summary table
#   bash run-all.sh -v     # verbose — pass through each script's output

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
export AGENT0_ROOT
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

pass=0; fail=0; rows=""
for script in "$SCRIPT_DIR"/[0-9][0-9]-*.sh; do
  name="$(basename "$script")"
  if [ "$VERBOSE" = 1 ]; then
    echo "=== $name ==="
    if bash "$script"; then rc=0; else rc=$?; fi
  else
    out="$(bash "$script" 2>&1)" && rc=0 || rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    rows="${rows}  ${name}  PASS\n"; pass=$((pass + 1))
  else
    rows="${rows}  ${name}  FAIL\n"; fail=$((fail + 1))
    [ "$VERBOSE" = 1 ] || printf '%s\n' "$out" | sed 's/^/    /'
  fi
done

echo
echo "=== shipped-integrity scenario results ==="
printf '%b' "$rows"
echo "=========================================="
if [ "$fail" -gt 0 ]; then echo "One or more scenarios FAILED."; exit 1; fi
echo "All scenarios PASS."
