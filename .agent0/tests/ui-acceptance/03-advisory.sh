#!/usr/bin/env bash
# 03-advisory — end-to-end `ui-runner-advisory:` fire/no-fire via the real
# validator in a throwaway git repo (spec 206). The advisory fires iff a rendered
# UI surface changed AND the project declares no UI test runner.
source "$(dirname "$0")/_lib.sh"
echo "03-advisory (validator ui-runner-advisory: fire/no-fire matrix)"

ADV="ui-runner-advisory:"

# --- Case A: UI surface changed, NO runner → advisory FIRES --------------
repo="$(make_validator_repo)"
mkdir -p "$repo/src/components"; printf 'export const B = 1;\n' > "$repo/src/components/Button.tsx"
out="$(run_validator "$repo")"
assert_contains "$out" "$ADV" "A: UI surface + no runner → advisory fires"

# --- Case B: UI surface changed, runner PRESENT → no advisory -----------
repo="$(make_validator_repo)"
mkdir -p "$repo/src/components"; printf 'export const B = 1;\n' > "$repo/src/components/Button.tsx"
printf '{"scripts":{"test:e2e":"playwright test"}}' > "$repo/package.json"
out="$(run_validator "$repo")"
assert_not_contains "$out" "$ADV" "B: UI surface + runner → no advisory"

# --- Case C: backend-only change, NO runner → no advisory ---------------
repo="$(make_validator_repo)"
mkdir -p "$repo/internal/server"; printf 'package main\n' > "$repo/internal/server/handler.go"
out="$(run_validator "$repo")"
assert_not_contains "$out" "$ADV" "C: backend-only + no runner → no advisory (gaming guard)"

# --- Case D: backend-only change, runner PRESENT → no advisory ----------
repo="$(make_validator_repo)"
mkdir -p "$repo/internal/server"; printf 'package main\n' > "$repo/internal/server/handler.go"
printf '{"scripts":{"test:e2e":"playwright test"}}' > "$repo/package.json"
out="$(run_validator "$repo")"
assert_not_contains "$out" "$ADV" "D: backend-only + runner → no advisory"

# --- Case E: docs-only change, NO runner → no advisory ------------------
repo="$(make_validator_repo)"
mkdir -p "$repo/docs"; printf '# notes\n' > "$repo/docs/notes.md"
out="$(run_validator "$repo")"
assert_not_contains "$out" "$ADV" "E: docs-only + no runner → no advisory"

# --- Case F: UI surface, runner declared via .agent0/ui-test.json -------
repo="$(make_validator_repo)"
mkdir -p "$repo/src/components"; printf 'export const B = 1;\n' > "$repo/src/components/Button.tsx"
printf '{"command":"pytest tests/e2e"}' > "$repo/.agent0/ui-test.json"
out="$(run_validator "$repo")"
assert_not_contains "$out" "$ADV" "F: UI surface + override runner → no advisory"

finish
