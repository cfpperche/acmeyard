#!/usr/bin/env bash
# Scenario: a SHIPPED spec that declares NO verify command → no advisory (opt-in,
# absence is never nagged). Also asserts that a shipped spec WITH a passing
# latest record in notes.md is silent. Sandboxed validator copy as in 05.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR_SRC="$AGENT0_ROOT/.agent0/validators/run.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.agent0/validators" "$tmp/docs/specs/906-silent" "$tmp/docs/specs/907-verified"
cp "$VALIDATOR_SRC" "$tmp/.agent0/validators/run.sh"

# 906: shipped, NO verify declared → must be silent
s1="$tmp/docs/specs/906-silent"
printf '# 906 — silent\n**Status:** shipped\n' > "$s1/spec.md"
printf '## Verification\n\n- [ ] nothing declared\n' > "$s1/tasks.md"

# 907: shipped, verify declared, latest record passed → must be silent
s2="$tmp/docs/specs/907-verified"
printf '# 907 — verified\n**Status:** shipped\n' > "$s2/spec.md"
printf '**Verify:** `true`\n' > "$s2/tasks.md"
printf '# notes\n\n## Verification log\n\n### 2026-06-08T00:00:00Z — pass (1/1) — source: tasks.md\n- `true` — pass\n' > "$s2/notes.md"

err="$tmp/err.txt"
( cd "$tmp" && bash .agent0/validators/run.sh >/dev/null 2>"$err" )

if grep -qE '^spec-verify-advisory: docs/specs/906-silent ' "$err"; then
  echo "FAIL: advisory fired for a spec with no verify declared (should be silent)"; cat "$err"; exit 1
fi
if grep -qE '^spec-verify-advisory: docs/specs/907-verified ' "$err"; then
  echo "FAIL: advisory fired for a spec with a passing latest record"; cat "$err"; exit 1
fi
echo "ok"
