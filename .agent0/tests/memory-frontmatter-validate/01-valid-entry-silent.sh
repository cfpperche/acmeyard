#!/usr/bin/env bash
# Scenario: an Edit to a memory entry with complete, valid frontmatter (name,
# description, metadata.type) produces no advisory output. Hook exits 0.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.agent0/hooks/memory-frontmatter-validate.sh"

TMPDIR_T="$(mktemp -d -t mfv-01-XXXXXX)"
trap 'rm -rf "$TMPDIR_T"' EXIT

# Build a minimal project scaffold: the hook resolves PROJECT_DIR from the
# payload's cwd and then looks for .agent0/tools/memory-maintain.sh.
mkdir -p "$TMPDIR_T/.agent0/tools"
mkdir -p "$TMPDIR_T/.agent0/memory"
# Symlink maintain.sh from the real harness so the fixture stays self-contained.
ln -s "$AGENT0_ROOT/.agent0/tools/memory-maintain.sh" "$TMPDIR_T/.agent0/tools/memory-maintain.sh"

entry="$TMPDIR_T/.agent0/memory/my-entry.md"
cat >"$entry" <<'EOF'
---
name: My test entry
description: A complete memory entry used in fixture tests.
metadata:
  type: project
  created_at: '2026-01-01'
  last_accessed: '2026-01-01'
  confirmed_count: 1
---
# My test entry

Some body content.
EOF

payload="$(jq -n \
  --arg fp "$entry" \
  --arg cwd "$TMPDIR_T" \
  '{tool_name: "Edit", cwd: $cwd, tool_input: {file_path: $fp, new_string: "updated"}}')"

stderr_capture="$(mktemp)"
exit_code=0
printf '%s' "$payload" | bash "$HOOK" 2>"$stderr_capture" || exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  printf 'FAIL: hook exited %d (expected 0)\n' "$exit_code"
  exit 1
fi

if [ -s "$stderr_capture" ]; then
  printf 'FAIL: expected silent stderr for valid entry, got:\n'
  cat "$stderr_capture"
  rm -f "$stderr_capture"
  exit 1
fi

rm -f "$stderr_capture"
echo "PASS: 01-valid-entry-silent"
