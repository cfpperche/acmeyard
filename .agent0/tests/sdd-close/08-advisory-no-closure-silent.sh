#!/usr/bin/env bash
# Scenario (opt-in / legacy-silent): a shipped spec WITHOUT a **Closure:** line,
# carrying unchecked boxes AND a placeholder, emits NO sdd-close-advisory — it
# never opted in. Proves the legacy corpus stays silent.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR_SRC="$AGENT0_ROOT/.agent0/validators/run.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.agent0/validators" "$tmp/docs/specs/908-legacy"
cp "$VALIDATOR_SRC" "$tmp/.agent0/validators/run.sh"

spec="$tmp/docs/specs/908-legacy"
# shipped, no Closure line, residual unchecked boxes + a bare placeholder
printf '# 908 — legacy\n**Status:** shipped\n\n## Intent\n\n{{intent}}\n\n## Acceptance criteria\n\n- [ ] a\n' > "$spec/spec.md"
printf '## Implementation\n\n- [ ] 1. a\n' > "$spec/tasks.md"

err="$tmp/err.txt"
( cd "$tmp" && bash .agent0/validators/run.sh >/dev/null 2>"$err" )

n="$(grep -cE '^sdd-close-advisory:' "$err" || true)"
[ "$n" -eq 0 ] || { echo "FAIL: expected 0 advisories (no Closure line = opt-out), got $n"; cat "$err"; exit 1; }
echo "ok"
