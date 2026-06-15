#!/usr/bin/env bash
# .agent0/tests/ui-acceptance/_lib.sh — shared harness for spec-206 scenarios.
#
# All cases are OFFLINE & deterministic — no browser, no runner is ever invoked.
# We test three things: (1) ui-runner-detect.sh's declarable-signal detection,
# (2) ui-impact-detect.sh's surface classification (unchanged from spec 155),
# (3) the validator's `ui-runner-advisory:` fire/no-fire, end-to-end, by copying
# the two detectors + run.sh into a throwaway git repo and running the validator.
set -uo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
DETECT="$AGENT0_ROOT/.agent0/tools/ui-impact-detect.sh"
RUNNER_DETECT="$AGENT0_ROOT/.agent0/tools/ui-runner-detect.sh"
VALIDATOR="$AGENT0_ROOT/.agent0/validators/run.sh"

PASS=0; FAIL=0
assert_eq()   { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3 (got '$1' want '$2')"; fi; }
assert_rc()   { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3 (rc got $1 want $2)"; fi; }
assert_contains()     { if printf '%s' "$1" | grep -qF -- "$2"; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3 (missing '$2')"; fi; }
assert_not_contains() { if printf '%s' "$1" | grep -qF -- "$2"; then FAIL=$((FAIL+1)); echo "  ✗ $3 (unexpected '$2')"; else PASS=$((PASS+1)); echo "  ✓ $3"; fi; }
finish() { echo "  [$PASS pass / $FAIL fail]"; [ "$FAIL" -eq 0 ]; }

# Build a throwaway git repo with the harness pieces the validator's advisory
# needs. Echoes the repo path. Caller adds files, then runs `run_validator`.
make_validator_repo() {
  local repo; repo="$(mktemp -d -t uia-repo-XXXXXX)"
  mkdir -p "$repo/.agent0/tools" "$repo/.agent0/validators"
  cp "$DETECT"        "$repo/.agent0/tools/ui-impact-detect.sh"
  cp "$RUNNER_DETECT" "$repo/.agent0/tools/ui-runner-detect.sh"
  cp "$VALIDATOR"     "$repo/.agent0/validators/run.sh"
  chmod +x "$repo/.agent0/tools/"*.sh "$repo/.agent0/validators/run.sh"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@t; git -C "$repo" config user.name t
  echo "$repo"
}

# Run the copied validator at the repo root; echo its STDERR (where advisories go).
run_validator() {
  local repo="$1"
  ( cd "$repo" && bash .agent0/validators/run.sh ) 2>&1 1>/dev/null
}
