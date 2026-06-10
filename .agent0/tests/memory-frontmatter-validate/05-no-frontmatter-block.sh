#!/usr/bin/env bash
# Scenario: a memory entry whose first line is NOT '---' (no YAML frontmatter
# block at all) emits an advisory saying "no frontmatter block". Hook exits 0.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.agent0/hooks/memory-frontmatter-validate.sh"

TMPDIR_T="$(mktemp -d -t mfv-05-XXXXXX)"
trap 'rm -rf "$TMPDIR_T"' EXIT

mkdir -p "$TMPDIR_T/.agent0/tools"
mkdir -p "$TMPDIR_T/.agent0/memory"
ln -s "$AGENT0_ROOT/.agent0/tools/memory-maintain.sh" "$TMPDIR_T/.agent0/tools/memory-maintain.sh"

entry="$TMPDIR_T/.agent0/memory/no-fm.md"
cat >"$entry" <<'EOF'
# No frontmatter entry

This entry has no frontmatter block; the first line is not '---'.
EOF

payload="$(jq -n \
  --arg fp "$entry" \
  --arg cwd "$TMPDIR_T" \
  '{tool_name: "Edit", cwd: $cwd, tool_input: {file_path: $fp, new_string: "update"}}')"

stderr_capture="$(mktemp)"
exit_code=0
printf '%s' "$payload" | bash "$HOOK" 2>"$stderr_capture" || exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  printf 'FAIL: hook exited %d (expected 0)\n' "$exit_code"
  exit 1
fi

if ! grep -qF "no frontmatter block" "$stderr_capture"; then
  printf 'FAIL: expected "no frontmatter block" advisory, got:\n'
  cat "$stderr_capture"
  rm -f "$stderr_capture"
  exit 1
fi

rm -f "$stderr_capture"
echo "PASS: 05-no-frontmatter-block"
