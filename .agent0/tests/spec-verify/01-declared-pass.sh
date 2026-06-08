#!/usr/bin/env bash
# Scenario: declared commands pass → exit 0 + `## Verification log` records pass.
# Also covers command extraction for spaces/flags and first-backtick-span only,
# plus append safety when notes.md already has content.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/spec-verify.sh"
export AGENT0_ROOT

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
spec="$tmp/docs/specs/901-pass"; mkdir -p "$spec"
printf '# 901 — pass\n**Status:** draft\n' > "$spec/spec.md"
printf '## Verification\n\n**Verify:** `true`\n**Verify:** `test "$(pwd)" = "$AGENT0_ROOT"` `false`\n' > "$spec/tasks.md"
printf '# existing notes\n\n## Design decisions\n\nkeep-me\n' > "$spec/notes.md"

out="$(cd "$tmp" && bash "$TOOL" "$spec" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: expected exit 0, got $rc — $out"; exit 1; }
grep -qE '^## Verification log' "$spec/notes.md" || { echo "FAIL: notes.md has no Verification log section"; exit 1; }
grep -q 'keep-me' "$spec/notes.md" || { echo "FAIL: existing notes content was clobbered"; cat "$spec/notes.md"; exit 1; }
grep -qE '^### .* — pass \(2/2\)' "$spec/notes.md" || { echo "FAIL: notes.md missing a pass (2/2) record"; cat "$spec/notes.md"; exit 1; }
grep -qE '^- `true` — pass$' "$spec/notes.md" || { echo "FAIL: per-command pass line missing"; cat "$spec/notes.md"; exit 1; }
grep -qF -- '- `test "$(pwd)" = "$AGENT0_ROOT"` — pass' "$spec/notes.md" || { echo "FAIL: command with spaces/quotes was not recorded as pass"; cat "$spec/notes.md"; exit 1; }
if grep -qF -- '- `false`' "$spec/notes.md"; then
  echo "FAIL: extraction captured beyond the first backtick span"; cat "$spec/notes.md"; exit 1
fi

out="$(cd "$tmp" && bash "$TOOL" "$spec" --quiet 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: second quiet run expected exit 0, got $rc — $out"; exit 1; }
headers="$(grep -cE '^## Verification log' "$spec/notes.md")"
[ "$headers" -eq 1 ] || { echo "FAIL: Verification log header should be appended once, got $headers"; cat "$spec/notes.md"; exit 1; }
echo "ok"
