#!/usr/bin/env bash
# Scenario: a memory entry missing all three required frontmatter fields
# (name, description, metadata.type) emits one advisory per missing field
# on stderr. Hook still exits 0 (advisory-only, never blocking).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.agent0/hooks/memory-frontmatter-validate.sh"

TMPDIR_T="$(mktemp -d -t mfv-02-XXXXXX)"
trap 'rm -rf "$TMPDIR_T"' EXIT

mkdir -p "$TMPDIR_T/.agent0/tools"
mkdir -p "$TMPDIR_T/.agent0/memory"
ln -s "$AGENT0_ROOT/.agent0/tools/memory-maintain.sh" "$TMPDIR_T/.agent0/tools/memory-maintain.sh"

entry="$TMPDIR_T/.agent0/memory/bare-entry.md"
# Frontmatter opens and closes but contains no recognised fields at all.
cat >"$entry" <<'EOF'
---
---
# Bare entry

Body only, no frontmatter fields.
EOF

payload="$(jq -n \
  --arg fp "$entry" \
  --arg cwd "$TMPDIR_T" \
  '{tool_name: "Edit", cwd: $cwd, tool_input: {file_path: $fp, new_string: "x"}}')"

stderr_capture="$(mktemp)"
exit_code=0
printf '%s' "$payload" | bash "$HOOK" 2>"$stderr_capture" || exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  printf 'FAIL: hook exited %d (expected 0 — advisory-only)\n' "$exit_code"
  exit 1
fi

# Expect all three missing-field advisories.
for field in "missing required field 'name'" \
             "missing required field 'description'" \
             "missing required field 'metadata.type'"; do
  if ! grep -qF "$field" "$stderr_capture"; then
    printf 'FAIL: expected advisory for "%s", got:\n' "$field"
    cat "$stderr_capture"
    rm -f "$stderr_capture"
    exit 1
  fi
done

rm -f "$stderr_capture"
echo "PASS: 02-missing-required-fields"
