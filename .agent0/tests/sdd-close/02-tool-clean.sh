#!/usr/bin/env bash
# Scenario: a fully-closed shipped spec (all boxes checked, no placeholders,
# has **Closure:**) → tool reports no findings, exits 0.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/sdd-close.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
spec="$tmp/docs/specs/902-clean"; mkdir -p "$spec"
printf '# 902 — clean\n**Status:** shipped\n**Closure:** 2026-06-09 — shipped; tests 3/3; residual: none\n\n## Acceptance criteria\n\n- [x] a\n- [x] b\n' > "$spec/spec.md"
printf '## Implementation\n\n- [x] 1. a\n- [x] 2. b\n' > "$spec/tasks.md"

out="$(bash "$TOOL" "$spec" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: expected exit 0, got $rc — $out"; exit 1; }
printf '%s' "$out" | grep -qi 'clean' || { echo "FAIL: expected a clean report — $out"; exit 1; }
echo "ok"
