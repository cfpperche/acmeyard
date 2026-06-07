#!/usr/bin/env bash
# .agent0/tests/capacity-kit/golden.sh — behavior-parity gate for spec 163.
#
# Captures each capacity tool's deterministic PLUMBING surface (caps / doctor /
# usage-error / bad-flag — the exact surface the shared kit owns) and diffs
# before-vs-after the kit extraction. Zero behavior change = clean verify.
# The deep engine paths stay covered by each tool's own offline suite; golden
# adds exact stdout/stderr/exit capture so plumbing drift can't slip past
# thought-of assertions.
#
# Usage:
#   golden.sh capture   # write baselines (run BEFORE extraction)
#   golden.sh verify    # diff current against baselines (run AFTER); nonzero on drift
#
# Determinism: fixtures avoid network/engines and any timestamp/temp-path output.
# A normalizer still strips the repo abs-path + any stray temp dirs for safety.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BASE="$HERE/golden"
TOOLS="audio sound transcribe diagram"

# fixture: "<label>:::<args>" run against $ROOT/.agent0/tools/<tool>.sh
fixtures() {
  cat <<'EOF'
caps:::caps
doctor:::doctor
help:::--help
noargs:::
badflag:::--definitely-not-a-flag
EOF
}

norm() { sed -e "s#$ROOT#<ROOT>#g" -e 's#/tmp/[A-Za-z0-9._-]*#<TMP>#g'; }

run_one() {  # $1=tool $2=args... (already split) -> captures stdout+stderr+exit, normalized
  local tool="$1"; shift
  local out rc
  # FAL_KEY is pinned UNSET so the paid tools' caps/doctor are hermetic regardless of
  # the runner's ambient key (spec 164 — the set state is pinned by paid-golden.sh).
  out="$(cd "$ROOT" && env -u FAL_KEY bash ".agent0/tools/$tool.sh" "$@" 2>&1)"; rc=$?
  printf '%s\n--exit:%s\n' "$out" "$rc" | norm
}

do_mode() {
  local mode="$1" fail=0
  for tool in $TOOLS; do
    [ -f "$ROOT/.agent0/tools/$tool.sh" ] || { echo "golden: missing tool $tool" >&2; continue; }
    mkdir -p "$BASE/$tool"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      local label="${line%%:::*}" args="${line#*:::}"
      local got base="$BASE/$tool/$label.txt"
      # shellcheck disable=SC2086
      got="$(run_one "$tool" $args)"
      if [ "$mode" = capture ]; then
        printf '%s\n' "$got" > "$base"
        echo "  captured $tool/$label"
      else
        if [ ! -f "$base" ]; then echo "  ✗ $tool/$label — no baseline (run capture first)"; fail=1; continue; fi
        if [ "$got" = "$(cat "$base")" ]; then echo "  ✓ $tool/$label"
        else echo "  ✗ $tool/$label — DRIFT:"; diff <(cat "$base") <(printf '%s\n' "$got") | head -20; fail=1; fi
      fi
    done < <(fixtures)
  done
  return $fail
}

case "${1:-}" in
  capture) echo "golden: capturing baselines…"; do_mode capture;;
  verify)  echo "golden: verifying parity…"; do_mode verify || { echo "=== golden: PARITY DRIFT ==="; exit 1; }; echo "=== golden: parity clean ===";;
  *) echo "usage: golden.sh capture|verify" >&2; exit 2;;
esac
