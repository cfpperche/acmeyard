#!/usr/bin/env bash
# Scenario: empty stdin (no JSON payload at all) must not crash the hook.
# The hook is expected to exit 0 silently — the early-exit guard at the top
# of the hook handles this case before any jq call.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.agent0/hooks/memory-frontmatter-validate.sh"

stderr_capture="$(mktemp)"
exit_code=0
printf '' | bash "$HOOK" 2>"$stderr_capture" || exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  printf 'FAIL: hook exited %d on empty stdin (expected 0)\n' "$exit_code"
  exit 1
fi

if [ -s "$stderr_capture" ]; then
  printf 'FAIL: hook produced stderr output on empty stdin:\n'
  cat "$stderr_capture"
  rm -f "$stderr_capture"
  exit 1
fi

rm -f "$stderr_capture"
echo "PASS: 04-empty-stdin-no-crash"
