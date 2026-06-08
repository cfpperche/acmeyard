#!/usr/bin/env bash
# Scenario: a declared command fails → exit 1, remaining commands still run and
# are recorded, notes.md logs the fail.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/spec-verify.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
spec="$tmp/docs/specs/902-fail"; mkdir -p "$spec"
printf '# 902 — fail\n**Status:** draft\n' > "$spec/spec.md"
# two commands: first fails, second passes — both must be recorded.
printf '## Verification\n\n**Verify:** `false`\n**Verify:** `true`\n' > "$spec/tasks.md"

out="$(cd "$tmp" && bash "$TOOL" "$spec" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL: expected exit 1, got $rc — $out"; exit 1; }
grep -qE '^- `false` — fail$' "$spec/notes.md" || { echo "FAIL: fail line missing"; cat "$spec/notes.md"; exit 1; }
grep -qE '^- `true` — pass$'  "$spec/notes.md" || { echo "FAIL: second command not run/recorded"; cat "$spec/notes.md"; exit 1; }
grep -qE '^### .* — fail \(1/2\)' "$spec/notes.md" || { echo "FAIL: header should be fail (1/2)"; cat "$spec/notes.md"; exit 1; }
echo "ok"
