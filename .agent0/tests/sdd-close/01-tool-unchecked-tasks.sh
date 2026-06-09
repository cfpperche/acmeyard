#!/usr/bin/env bash
# Scenario: a shipped spec with unchecked tasks → tool reports tasks-unchecked,
# exits 1, and modifies no file (read-only).
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/sdd-close.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
spec="$tmp/docs/specs/901-unchecked"; mkdir -p "$spec"
printf '# 901 — unchecked\n**Status:** shipped\n**Closure:** 2026-06-09 — done\n\n## Acceptance criteria\n\n- [x] done\n' > "$spec/spec.md"
printf '## Implementation\n\n- [x] 1. a\n- [ ] 2. b\n' > "$spec/tasks.md"

before="$(cat "$spec/tasks.md")"
out="$(bash "$TOOL" "$spec" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL: expected exit 1, got $rc — $out"; exit 1; }
printf '%s' "$out" | grep -q 'tasks-unchecked' || { echo "FAIL: tasks-unchecked not reported — $out"; exit 1; }
[ "$(cat "$spec/tasks.md")" = "$before" ] || { echo "FAIL: tool modified tasks.md (not read-only)"; exit 1; }
echo "ok"
