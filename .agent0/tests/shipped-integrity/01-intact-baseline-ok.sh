#!/usr/bin/env bash
# Baseline matches disk → single ok summary, no advisories in the section.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
D="$(mktemp -d)"; trap 'rm -r "$D"' EXIT  # OVERRIDE: test sandbox cleanup of own mktemp dir
build_sandbox "$D"
write_baseline "$D" \
  ".agent0/hooks/sample.sh:$(sha_of "$D/.agent0/hooks/sample.sh")" \
  ".agent0/tools/sample-tool.sh:$(sha_of "$D/.agent0/tools/sample-tool.sh")"
OUT="$(doctor_section "$D")"
assert_has "$OUT" "2 verified against sync baseline" "both executables verified"
assert_not_has "$OUT" "[ advisory ]" "no advisory on intact baseline"
