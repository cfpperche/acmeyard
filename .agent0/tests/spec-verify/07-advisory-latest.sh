#!/usr/bin/env bash
# Scenario: validator keys on the latest tool-shaped verification record.
# Passed-then-failed re-fires; failed-then-passed is silent; unrelated design
# headings do not fake a passing record; spec.md fallback declarations are honored.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR_SRC="$AGENT0_ROOT/.agent0/validators/run.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.agent0/validators" \
  "$tmp/docs/specs/908-regressed" \
  "$tmp/docs/specs/909-recovered" \
  "$tmp/docs/specs/910-noise" \
  "$tmp/docs/specs/911-spec-fallback"
cp "$VALIDATOR_SRC" "$tmp/.agent0/validators/run.sh"

s="$tmp/docs/specs/908-regressed"
printf '# 908 — regressed\n**Status:** shipped\n' > "$s/spec.md"
printf '**Verify:** `true`\n' > "$s/tasks.md"
printf '# notes\n\n## Verification log\n\n### 2026-06-08T00:00:00Z — pass (1/1) — source: tasks.md\n- `true` — pass\n\n### 2026-06-08T00:01:00Z — fail (0/1) — source: tasks.md\n- `false` — fail\n' > "$s/notes.md"

s="$tmp/docs/specs/909-recovered"
printf '# 909 — recovered\n**Status:** shipped\n' > "$s/spec.md"
printf '**Verify:** `true`\n' > "$s/tasks.md"
printf '# notes\n\n## Verification log\n\n### 2026-06-08T00:00:00Z — fail (0/1) — source: tasks.md\n- `false` — fail\n\n### 2026-06-08T00:01:00Z — pass (1/1) — source: tasks.md\n- `true` — pass\n' > "$s/notes.md"

s="$tmp/docs/specs/910-noise"
printf '# 910 — noise\n**Status:** shipped\n' > "$s/spec.md"
printf '**Verify:** `true`\n' > "$s/tasks.md"
printf '# notes\n\n## Design decisions\n\n### 2026-06-08 — parent — pass wording\nThis is not a verification record.\n' > "$s/notes.md"

s="$tmp/docs/specs/911-spec-fallback"
printf '# 911 — fallback\n**Status:** shipped\n\n**Verify:** `true`\n' > "$s/spec.md"

err="$tmp/err.txt"
( cd "$tmp" && bash .agent0/validators/run.sh >/dev/null 2>"$err" )

for slug in 908-regressed 910-noise 911-spec-fallback; do
  n="$(grep -cE "^spec-verify-advisory: docs/specs/$slug " "$err" || true)"
  [ "$n" -eq 1 ] || { echo "FAIL: expected exactly 1 advisory for $slug, got $n"; cat "$err"; exit 1; }
done

if grep -qE '^spec-verify-advisory: docs/specs/909-recovered ' "$err"; then
  echo "FAIL: advisory fired for recovered spec whose latest record passed"; cat "$err"; exit 1
fi

total="$(grep -cE '^spec-verify-advisory: ' "$err" || true)"
[ "$total" -eq 3 ] || { echo "FAIL: expected exactly 3 spec-verify advisories, got $total"; cat "$err"; exit 1; }
echo "ok"
