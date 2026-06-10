#!/usr/bin/env bash
# Baseline entries outside the executable surface (rules/docs) are ignored
# even with wrong hashes — integrity here covers executables only.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
D="$(mktemp -d)"; trap 'rm -r "$D"' EXIT  # OVERRIDE: test sandbox cleanup of own mktemp dir
build_sandbox "$D"
write_baseline "$D" \
  ".agent0/hooks/sample.sh:$(sha_of "$D/.agent0/hooks/sample.sh")" \
  ".agent0/context/rules/sample.md:1111111111111111111111111111111111111111111111111111111111111111"
OUT="$(doctor_section "$D")"
assert_has "$OUT" "1 verified against sync baseline" "executable verified"
assert_not_has "$OUT" "sample.md" "rule entry ignored despite wrong hash"
