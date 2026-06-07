#!/usr/bin/env bash
# Run every agent-browser scenario; aggregate pass/fail. (spec 152)
set -uo pipefail
cd "$(dirname "$0")"

# Live scenarios share the global agent-browser daemon; tear it down + settle
# between scenarios so one test's leftover daemon/chrome can't flake the next.
teardown() {
  pgrep -af agent-browser-linux 2>/dev/null | awk '$2 ~ /agent-browser-linux[^ ]*$/{print $1}' | xargs -r kill 2>/dev/null
  pgrep -af "login-localhost" 2>/dev/null | awk '$2 ~ /chrome$/{print $1}' | xargs -r kill 2>/dev/null
  sleep 2
}

TOTAL_FAIL=0
for t in [0-9][0-9]-*.sh; do
  [ -f "$t" ] || continue
  teardown
  if bash "$t"; then :; else TOTAL_FAIL=$((TOTAL_FAIL+1)); fi
  echo
done
teardown

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo "=== agent-browser: ALL SCENARIOS PASS ==="
else
  echo "=== agent-browser: $TOTAL_FAIL scenario file(s) FAILED ==="
  exit 1
fi
