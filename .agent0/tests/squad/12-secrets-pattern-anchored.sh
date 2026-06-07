#!/usr/bin/env bash
# 154 fix #1 — the shipped squad.json.example `secrets` forbidden_paths pattern
# must be ANCHORED: it must NOT false-match a doc like `secrets-scan.md` (which the
# old unanchored `"secrets"` did → false aborted_policy on spec 153), but MUST
# still catch a real secrets dir / `.secret(s)` file.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
EX="$AGENT0_ROOT/.agent0/skills/squad/references/squad.json.example"

jq -e . "$EX" >/dev/null 2>&1 || { echo "FAIL: squad.json.example is not valid JSON"; exit 1; }
# don't regress 11 — HANDOFF still forbidden
jq -e '.forbidden_paths | any(test("HANDOFF"))' "$EX" >/dev/null 2>&1 \
  || { echo "FAIL: HANDOFF no longer forbidden"; exit 1; }

# matches() mirrors guard: a path is forbidden iff ANY forbidden_paths pattern matches it.
matches() { # matches <path> → "yes"|"no"
  local p="$1" pat
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    printf '%s\n' "$p" | grep -qE "$pat" && { echo yes; return; }
  done < <(jq -r '.forbidden_paths[]? // empty' "$EX")
  echo no
}

fail=0
expect() { # expect <path> <yes|no>
  local got; got="$(matches "$1")"
  if [ "$got" = "$2" ]; then echo "  ✓ $1 → $got"
  else echo "  ✗ $1 → $got (want $2)"; fail=1; fi
}

# must NOT match (the spec-153 false-positive + siblings)
expect ".agent0/context/rules/secrets-scan.md" no
expect "docs/secrets-management.md"            no
expect "lib/secretsManager.ts"                 no
# MUST match (real secret-bearing paths)
expect "app/secrets/api.json"                  yes
expect "secrets/key.pem"                        yes
expect "config/app.secrets"                     yes
expect ".env.secret"                            yes

[ "$fail" -eq 0 ] && echo PASS || { echo "FAIL: anchored secrets pattern mismatch"; exit 1; }
