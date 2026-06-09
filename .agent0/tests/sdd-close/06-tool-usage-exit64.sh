#!/usr/bin/env bash
# Scenario: usage errors → exit 64 (unknown flag, nonexistent spec dir, extra arg).
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/sdd-close.sh"

bash "$TOOL" --bogus >/dev/null 2>&1; [ "$?" -eq 64 ] || { echo "FAIL: unknown flag should exit 64"; exit 1; }
bash "$TOOL" docs/specs/000-does-not-exist >/dev/null 2>&1; [ "$?" -eq 64 ] || { echo "FAIL: missing spec dir should exit 64"; exit 1; }
bash "$TOOL" a b >/dev/null 2>&1; [ "$?" -eq 64 ] || { echo "FAIL: extra positional arg should exit 64"; exit 1; }
# -h is exit 0
bash "$TOOL" -h >/dev/null 2>&1; [ "$?" -eq 0 ] || { echo "FAIL: -h should exit 0"; exit 1; }
echo "ok"
