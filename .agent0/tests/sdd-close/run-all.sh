#!/usr/bin/env bash
# .agent0/tests/sdd-close/run-all.sh
# Orchestrator for spec-179 (sdd-close-advisory) scenarios. Discovers every
# NN-*.sh scenario by glob (NOT a hardcoded list), runs each, prints a summary,
# exits 0 if all pass else 1.

set -uo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
export AGENT0_ROOT
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

shopt -s nullglob
scripts=("$SCRIPT_DIR"/[0-9][0-9]-*.sh)
shopt -u nullglob

if [ "${#scripts[@]}" -eq 0 ]; then
  printf 'run-all.sh: no scenario scripts (NN-*.sh) found in %s\n' "$SCRIPT_DIR" >&2
  exit 1
fi

any_fail=0
for script in "${scripts[@]}"; do
  name="$(basename "$script")"
  if bash "$script" >/tmp/sdd-close-$$.out 2>&1; then
    printf '  [ PASS ] %s\n' "$name"
  else
    printf '  [ FAIL ] %s\n' "$name"
    sed 's/^/      /' /tmp/sdd-close-$$.out
    any_fail=1
  fi
done
rm -f /tmp/sdd-close-$$.out

if [ "$any_fail" -eq 0 ]; then
  printf 'sdd-close: all %d scenario(s) passed\n' "${#scripts[@]}"
  exit 0
fi
printf 'sdd-close: FAILURES present\n' >&2
exit 1
