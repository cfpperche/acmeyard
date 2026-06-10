#!/usr/bin/env bash
# Scenario: an Edit to a file outside the .agent0/memory/ or .claude/memory/
# tree is silently ignored — the hook exits 0 and emits nothing on stderr.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.agent0/hooks/memory-frontmatter-validate.sh"

TMPDIR_T="$(mktemp -d -t mfv-03-XXXXXX)"
trap 'rm -rf "$TMPDIR_T"' EXIT

mkdir -p "$TMPDIR_T/.agent0/tools"
mkdir -p "$TMPDIR_T/.agent0/context/rules"
ln -s "$AGENT0_ROOT/.agent0/tools/memory-maintain.sh" "$TMPDIR_T/.agent0/tools/memory-maintain.sh"

# A rules file with intentionally broken frontmatter — should NOT be flagged
# because the hook only validates .agent0/memory/ entries.
rulefile="$TMPDIR_T/.agent0/context/rules/some-rule.md"
cat >"$rulefile" <<'EOF'
# Not a memory entry

This file has no frontmatter at all, but that is irrelevant.
EOF

payload="$(jq -n \
  --arg fp "$rulefile" \
  --arg cwd "$TMPDIR_T" \
  '{tool_name: "Edit", cwd: $cwd, tool_input: {file_path: $fp, new_string: "update"}}')"

stderr_capture="$(mktemp)"
exit_code=0
printf '%s' "$payload" | bash "$HOOK" 2>"$stderr_capture" || exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  printf 'FAIL: hook exited %d (expected 0)\n' "$exit_code"
  exit 1
fi

if [ -s "$stderr_capture" ]; then
  printf 'FAIL: expected silent stderr for non-memory file, got:\n'
  cat "$stderr_capture"
  rm -f "$stderr_capture"
  exit 1
fi

rm -f "$stderr_capture"
echo "PASS: 03-non-memory-file-ignored"
