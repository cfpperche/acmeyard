#!/usr/bin/env bash
# Scenario: unknown top-level and nested metadata fields both trigger advisories
# ("typo guard"). Valid required fields are still present so only the unknown-
# field advisories fire; no missing-field advisories should appear.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.agent0/hooks/memory-frontmatter-validate.sh"

TMPDIR_T="$(mktemp -d -t mfv-06-XXXXXX)"
trap 'rm -rf "$TMPDIR_T"' EXIT

mkdir -p "$TMPDIR_T/.agent0/tools"
mkdir -p "$TMPDIR_T/.agent0/memory"
ln -s "$AGENT0_ROOT/.agent0/tools/memory-maintain.sh" "$TMPDIR_T/.agent0/tools/memory-maintain.sh"

entry="$TMPDIR_T/.agent0/memory/extra-fields.md"
cat >"$entry" <<'EOF'
---
name: Extra fields entry
description: Tests that unknown fields are flagged.
author: someone
metadata:
  type: project
  created_at: '2026-01-01'
  priority: high
---
# Extra fields entry

Body content.
EOF

payload="$(jq -n \
  --arg fp "$entry" \
  --arg cwd "$TMPDIR_T" \
  '{tool_name: "Edit", cwd: $cwd, tool_input: {file_path: $fp, new_string: "update"}}')"

stderr_capture="$(mktemp)"
exit_code=0
printf '%s' "$payload" | bash "$HOOK" 2>"$stderr_capture" || exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  printf 'FAIL: hook exited %d (expected 0 — advisory-only)\n' "$exit_code"
  exit 1
fi

# Both the top-level unknown field and the nested unknown metadata field should be flagged.
if ! grep -qF "unknown field 'author'" "$stderr_capture"; then
  printf 'FAIL: expected advisory for unknown top-level field "author", got:\n'
  cat "$stderr_capture"
  rm -f "$stderr_capture"
  exit 1
fi

if ! grep -qF "unknown field 'metadata.priority'" "$stderr_capture"; then
  printf 'FAIL: expected advisory for unknown nested field "metadata.priority", got:\n'
  cat "$stderr_capture"
  rm -f "$stderr_capture"
  exit 1
fi

# Verify required fields are NOT flagged as missing.
if grep -qF "missing required field" "$stderr_capture"; then
  printf 'FAIL: unexpected missing-field advisory for a complete entry:\n'
  cat "$stderr_capture"
  rm -f "$stderr_capture"
  exit 1
fi

rm -f "$stderr_capture"
echo "PASS: 06-unknown-fields-flagged"
