#!/usr/bin/env bash
# Scenario: a shipped spec with a surviving placeholder AND no **Closure:** line
# → tool reports both `placeholders` and `missing-closure`.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/sdd-close.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
spec="$tmp/docs/specs/903-holes"; mkdir -p "$spec"
# bare-prose placeholder (not in backticks) + no Closure line
printf '# 903 — holes\n**Status:** shipped\n\n## Intent\n\n{{intent}}\n\n## Acceptance criteria\n\n- [x] a\n' > "$spec/spec.md"
printf '## Implementation\n\n- [x] 1. a\n' > "$spec/tasks.md"

out="$(bash "$TOOL" "$spec" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL: expected exit 1, got $rc — $out"; exit 1; }
printf '%s' "$out" | grep -q 'placeholders' || { echo "FAIL: placeholders not reported — $out"; exit 1; }
printf '%s' "$out" | grep -q 'missing-closure' || { echo "FAIL: missing-closure not reported — $out"; exit 1; }
echo "ok"
