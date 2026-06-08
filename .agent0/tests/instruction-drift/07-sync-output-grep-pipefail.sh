#!/usr/bin/env bash
# Scenario: large sync-harness output containing AGENTS.md must not trip
# pipefail/SIGPIPE false negatives in check-instruction-drift.sh.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/check-instruction-drift.sh"

TMPDIR="$(mktemp -d -t instruction-drift-07-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

ROOT="$TMPDIR/root"
mkdir -p "$ROOT/.agent0/tools/lib" "$ROOT/.agent0/context/rules"

cp "$AGENT0_ROOT/.agent0/tools/lib/managed-block.sh" "$ROOT/.agent0/tools/lib/managed-block.sh"

cat > "$ROOT/.agent0/tools/sync-harness.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '= up to date AGENTS.md\n'
for _ in $(seq 1 12000); do
  printf '= up to date .agent0/tests/noisy-fixture\n'
done
EOF
chmod +x "$ROOT/.agent0/tools/sync-harness.sh"

cat > "$ROOT/CLAUDE.md" <<'EOF'
# Claude

<!-- AGENT0:BEGIN -->
See .agent0/context/rules/runtime-capabilities.md
<!-- AGENT0:END -->
EOF
cp "$ROOT/CLAUDE.md" "$ROOT/AGENTS.md"

cat > "$ROOT/.agent0/context/rules/runtime-capabilities.md" <<'EOF'
# Runtime capabilities

Vocabulary: `native`, `native-opt-in`, `convention`, `read-only`, `planned`, `unsupported`.

| Capability | Claude | Codex |
| --- | --- | --- |
| instruction entrypoints | `native` | `native` |
| session handoff | `native` | `native` |
| SDD | `native` | `native` |
| debate | `native` | `native` |
| lifecycle hooks | `native` | `native` |
| delegation/subagents | `native` | `native` |
| MCP recipes | `native-opt-in` | `native-opt-in` |
| image generation | `native-opt-in` | `native-opt-in` |
| memory | `convention` | `convention` |
| harness sync | `native` | `native` |
| customization/sync surfaces | `native` | `native` |
EOF

actual_exit=0
out="$(bash "$TOOL" --root "$ROOT" --agent0-path "$ROOT" 2>&1)" || actual_exit=$?

if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: large sync output should not hide AGENTS.md inspection\n%s\n' "$out"
  exit 1
fi

if ! grep -q 'sync-harness checks AGENTS.md on the baseline-tracked path' <<<"$out"; then
  printf 'FAIL: expected AGENTS.md inspection diagnostic\n%s\n' "$out"
  exit 1
fi

echo "PASS: 07-sync-output-grep-pipefail"
