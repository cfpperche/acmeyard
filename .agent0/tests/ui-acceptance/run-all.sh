#!/usr/bin/env bash
# Run every ui-acceptance scenario; aggregate pass/fail (spec 206).
# Tests are discovered by GLOB (NN-*.sh) so a new scenario is picked up
# automatically (anti vacuous-green). All scenarios are offline & deterministic.
set -uo pipefail
cd "$(dirname "$0")"

TOTAL_FAIL=0
shopt -s nullglob
for t in [0-9][0-9]-*.sh; do
  if bash "$t"; then :; else TOTAL_FAIL=$((TOTAL_FAIL+1)); fi
  echo
done

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo "=== ui-acceptance: ALL SCENARIOS PASS ==="
else
  echo "=== ui-acceptance: $TOTAL_FAIL scenario file(s) FAILED ==="
  exit 1
fi
