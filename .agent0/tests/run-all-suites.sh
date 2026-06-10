#!/usr/bin/env bash
# .agent0/tests/run-all-suites.sh
# Global orchestrator: discovers every suite dir containing a run-all.sh,
# runs each, and prints a one-line-per-suite summary table.
# Exits 0 only if every executed suite passes.
#
# Usage:
#   bash run-all-suites.sh             # quiet — per-suite status + summary
#   bash run-all-suites.sh -v          # verbose — pass through suite output
#
# Env:
#   AGENT0_SUITE_SKIP   comma-separated suite dir names to skip (recorded as
#                       SKIP in the table, never counted as failure). For
#                       environments missing optional binaries a suite needs.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
export AGENT0_ROOT

VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

IFS=',' read -r -a SKIP_LIST <<< "${AGENT0_SUITE_SKIP:-}"

is_skipped() {
  local name="$1" s
  for s in "${SKIP_LIST[@]:-}"; do
    [ -n "$s" ] && [ "$s" = "$name" ] && return 0
  done
  return 1
}

pass=0; fail=0; skip=0
failed_names=""
results=""

for runner in "$SCRIPT_DIR"/*/run-all.sh; do
  [ -f "$runner" ] || continue
  suite="$(basename "$(dirname "$runner")")"

  if is_skipped "$suite"; then
    results="${results}  ${suite}  SKIP\n"
    skip=$((skip + 1))
    continue
  fi

  start=$(date +%s)
  if [ "$VERBOSE" = 1 ]; then
    echo "=== suite: $suite ==="
    bash "$runner" -v
    rc=$?
  else
    out="$(bash "$runner" 2>&1)"
    rc=$?
  fi
  dur=$(( $(date +%s) - start ))

  if [ "$rc" -eq 0 ]; then
    results="${results}  ${suite}  PASS  (${dur}s)\n"
    pass=$((pass + 1))
  else
    results="${results}  ${suite}  FAIL  (${dur}s)\n"
    fail=$((fail + 1))
    failed_names="${failed_names} ${suite}"
    if [ "$VERBOSE" != 1 ]; then
      echo "--- failing suite output: $suite ---"
      printf '%s\n' "$out" | tail -40
      echo "--- end: $suite ---"
    fi
  fi
done

echo
echo "=== harness suite results ==="
printf '%b' "$results"
echo "============================="
echo "suites: $pass pass, $fail fail, $skip skip"

if [ "$fail" -gt 0 ]; then
  echo "FAILED:${failed_names}"
  exit 1
fi
echo "All executed suites PASS."
exit 0
