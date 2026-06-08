#!/usr/bin/env bash
# Scenario: no **Verify:** declared → exit 2, notes.md NOT created/modified.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/spec-verify.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
spec="$tmp/docs/specs/903-none"; mkdir -p "$spec"
printf '# 903 — none\n**Status:** draft\n' > "$spec/spec.md"
printf '## Verification\n\n- [ ] no verify command here\n' > "$spec/tasks.md"

out="$(cd "$tmp" && bash "$TOOL" "$spec" 2>&1)"; rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL: expected exit 2, got $rc — $out"; exit 1; }
[ ! -f "$spec/notes.md" ] || { echo "FAIL: notes.md must not be written when nothing is declared"; exit 1; }
echo "$out" | grep -qi 'no verify command declared' || { echo "FAIL: expected notice missing — $out"; exit 1; }
echo "ok"
