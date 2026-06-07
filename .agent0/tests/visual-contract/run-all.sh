#!/usr/bin/env bash
# Run every visual-contract scenario; aggregate pass/fail. (spec 155)
# Tests are discovered by GLOB (NN-*.sh), never a hardcoded list, so a new
# scenario file is picked up automatically (anti vacuous-green, squad finding F1).
set -uo pipefail
cd "$(dirname "$0")"

teardown() {
  pgrep -af agent-browser-linux 2>/dev/null | awk '$2 ~ /agent-browser-linux[^ ]*$/{print $1}' | xargs -r kill 2>/dev/null
  sleep 1
}

TOTAL_FAIL=0
shopt -s nullglob
for t in [0-9][0-9]-*.sh; do
  teardown
  if bash "$t"; then :; else TOTAL_FAIL=$((TOTAL_FAIL+1)); fi
  echo
done
teardown

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo "=== visual-contract: ALL SCENARIOS PASS ==="
else
  echo "=== visual-contract: $TOTAL_FAIL scenario file(s) FAILED ==="
  exit 1
fi
