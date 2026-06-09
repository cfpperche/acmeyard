#!/usr/bin/env bash
# Scenario: a shipped spec that DECLARES **Closure:** but has an unchecked task
# → validator emits exactly one `sdd-close-advisory:` line; JSON `ok` unchanged.
# Runs a copy of the real validator in a sandbox so ROOT = sandbox.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR_SRC="$AGENT0_ROOT/.agent0/validators/run.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.agent0/validators" "$tmp/docs/specs/907-fires"
cp "$VALIDATOR_SRC" "$tmp/.agent0/validators/run.sh"

spec="$tmp/docs/specs/907-fires"
printf '# 907 — fires\n**Status:** shipped\n**Closure:** 2026-06-09 — shipped\n\n## Acceptance criteria\n\n- [x] a\n' > "$spec/spec.md"
printf '## Implementation\n\n- [ ] 1. unfinished\n' > "$spec/tasks.md"

err="$tmp/err.txt"; out="$tmp/out.json"
( cd "$tmp" && bash .agent0/validators/run.sh >"$out" 2>"$err" )

n="$(grep -cE '^sdd-close-advisory: docs/specs/907-fires ' "$err" || true)"
[ "$n" -eq 1 ] || { echo "FAIL: expected exactly 1 advisory, got $n"; echo "--stderr--"; cat "$err"; exit 1; }
grep -qE '^sdd-close-advisory: docs/specs/907-fires declares \*\*Closure:\*\* but .*unchecked task' "$err" || { echo "FAIL: advisory text/shape wrong"; cat "$err"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  jq -e '.ok==true' "$out" >/dev/null || { echo "FAIL: validator ok should stay true (non-blocking)"; cat "$out"; exit 1; }
fi
echo "ok"
