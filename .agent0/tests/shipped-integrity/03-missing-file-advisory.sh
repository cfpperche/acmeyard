#!/usr/bin/env bash
# Baseline lists an executable absent on disk → advisory "missing on disk".
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
D="$(mktemp -d)"; trap 'rm -r "$D"' EXIT  # OVERRIDE: test sandbox cleanup of own mktemp dir
build_sandbox "$D"
write_baseline "$D" \
  ".agent0/hooks/sample.sh:$(sha_of "$D/.agent0/hooks/sample.sh")" \
  ".agent0/hooks/ghost.sh:0000000000000000000000000000000000000000000000000000000000000000"
OUT="$(doctor_section "$D")"
assert_has "$OUT" "in sync baseline but missing on disk" "missing executable flagged"
assert_has "$OUT" ".agent0/hooks/ghost.sh" "missing file named"
