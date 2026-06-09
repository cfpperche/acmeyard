#!/usr/bin/env bash
# Scenario: --json emits a single well-formed JSON object with the expected keys.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/sdd-close.sh"
command -v jq >/dev/null 2>&1 || { echo "ok (jq absent — skipped)"; exit 0; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
spec="$tmp/docs/specs/904-json"; mkdir -p "$spec"
printf '# 904 — json\n**Status:** shipped\n\n## Acceptance criteria\n\n- [ ] a\n' > "$spec/spec.md"
printf '## Implementation\n\n- [ ] 1. a\n' > "$spec/tasks.md"

json="$(bash "$TOOL" "$spec" --json 2>/dev/null)"
printf '%s' "$json" | jq -e '.specs_with_findings==1' >/dev/null || { echo "FAIL: specs_with_findings != 1 — $json"; exit 1; }
printf '%s' "$json" | jq -e '.specs[0].findings | map(.type) | index("acceptance-unchecked")' >/dev/null || { echo "FAIL: acceptance-unchecked finding missing — $json"; exit 1; }
printf '%s' "$json" | jq -e '.specs[0].findings | map(.type) | index("tasks-unchecked")' >/dev/null || { echo "FAIL: tasks-unchecked finding missing — $json"; exit 1; }
echo "ok"
