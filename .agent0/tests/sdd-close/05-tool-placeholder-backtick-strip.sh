#!/usr/bin/env bash
# Scenario: a shipped spec that DISCUSSES template syntax (`{{SLUG}}` inside
# backticks) is NOT a placeholder false positive. The closed spec is otherwise
# clean → tool exits 0, no `placeholders` finding.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/sdd-close.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
spec="$tmp/docs/specs/906-discuss"; mkdir -p "$spec"
printf '# 906 — discuss\n**Status:** shipped\n**Closure:** 2026-06-09 — done\n\n## Intent\n\nThe scaffolder substitutes `{{SLUG}}` and `{{NNN}}` at create time.\n\n## Acceptance criteria\n\n- [x] a\n' > "$spec/spec.md"
printf '## Implementation\n\n- [x] 1. a\n' > "$spec/tasks.md"

out="$(bash "$TOOL" "$spec" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: expected exit 0 (no findings), got $rc — $out"; exit 1; }
if printf '%s' "$out" | grep -q 'placeholders'; then
  echo "FAIL: backticked {{SLUG}} wrongly flagged as a placeholder — $out"; exit 1
fi
echo "ok"
