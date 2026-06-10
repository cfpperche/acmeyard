#!/usr/bin/env bash
# No baseline (source repo / pre-first-sync) → ok n/a, never a failure.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
D="$(mktemp -d)"; trap 'rm -r "$D"' EXIT  # OVERRIDE: test sandbox cleanup of own mktemp dir
build_sandbox "$D"
OUT="$(doctor_section "$D")"
assert_has "$OUT" "no sync baseline" "n/a reported"
assert_has "$OUT" "[ ok ]" "n/a is ok, not advisory"
