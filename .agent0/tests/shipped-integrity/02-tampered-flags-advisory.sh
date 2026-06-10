#!/usr/bin/env bash
# A hook modified after sync → advisory naming the file, advisory summary.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
D="$(mktemp -d)"; trap 'rm -r "$D"' EXIT  # OVERRIDE: test sandbox cleanup of own mktemp dir
build_sandbox "$D"
write_baseline "$D" \
  ".agent0/hooks/sample.sh:$(sha_of "$D/.agent0/hooks/sample.sh")" \
  ".agent0/tools/sample-tool.sh:$(sha_of "$D/.agent0/tools/sample-tool.sh")"
printf 'echo tampered\n' >> "$D/.agent0/hooks/sample.sh"
OUT="$(doctor_section "$D")"
assert_has "$OUT" "differs from last-sync baseline" "tamper detected"
assert_has "$OUT" ".agent0/hooks/sample.sh" "flagged file named"
assert_has "$OUT" "1 verified, 1 diverged/missing" "summary counts divergence"
assert_not_has "$OUT" "[ BROKEN ]" "advisory severity, never broken"
