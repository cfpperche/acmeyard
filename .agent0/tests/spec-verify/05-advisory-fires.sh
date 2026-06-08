#!/usr/bin/env bash
# Scenario: a SHIPPED spec that DECLARES a verify command but has no passing
# record → validator emits exactly one `spec-verify-advisory:` line, and the
# validator's JSON `ok` is unchanged (non-blocking). Runs a copy of the real
# validator in a sandbox so ROOT (= sandbox) scans fixture specs only.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR_SRC="$AGENT0_ROOT/.agent0/validators/run.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.agent0/validators" "$tmp/docs/specs/905-fires"
cp "$VALIDATOR_SRC" "$tmp/.agent0/validators/run.sh"

spec="$tmp/docs/specs/905-fires"
printf '# 905 — fires\n**Status:** shipped\n' > "$spec/spec.md"
printf '**Verify:** `true`\n' > "$spec/tasks.md"
# no notes.md → no passing record → advisory should fire

err="$tmp/err.txt"; out="$tmp/out.json"
( cd "$tmp" && bash .agent0/validators/run.sh >"$out" 2>"$err" )

n="$(grep -cE '^spec-verify-advisory: docs/specs/905-fires ' "$err" || true)"
[ "$n" -eq 1 ] || { echo "FAIL: expected exactly 1 advisory, got $n"; echo "--stderr--"; cat "$err"; exit 1; }

if command -v jq >/dev/null 2>&1; then
  jq -e '.ok==true' "$out" >/dev/null || { echo "FAIL: validator ok should stay true (non-blocking)"; cat "$out"; exit 1; }
fi
echo "ok"
