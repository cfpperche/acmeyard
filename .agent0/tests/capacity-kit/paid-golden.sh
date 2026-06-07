#!/usr/bin/env bash
# .agent0/tests/capacity-kit/paid-golden.sh — PAID-surface parity gate for spec 164.
#
# Companion to golden.sh. golden.sh captures caps/doctor under whatever ambient
# FAL_KEY the runner happens to have — so it pins exactly ONE FAL_KEY state. The
# paid-media sub-kit (lib/paid-media.sh: pm_has_fal_key / pm_fal_key_state) governs
# precisely the bit that flips between states, so this gate pins BOTH: FAL_KEY unset
# AND FAL_KEY set. It also asserts the key VALUE never leaks into output.
#
# Usage:
#   paid-golden.sh capture   # write baselines (sentinel key — never the real one)
#   paid-golden.sh verify    # diff current against baselines; nonzero on drift
#
# Scope: the two .agent0/tools/ paid tools migrated in spec 164 (sound, audio).
# Determinism: caps/doctor touch no network/engine; a normalizer strips abs-path +
# temp dirs. The "set" lane uses a fixed sentinel so output is reproducible.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BASE="$HERE/golden-paid"
TOOLS="sound audio"
SENTINEL="sk-paid-golden-sentinel-DO-NOT-LEAK"

norm() { sed -e "s#$ROOT#<ROOT>#g" -e 's#/tmp/[A-Za-z0-9._-]*#<TMP>#g'; }

run_one() {  # $1=tool $2=keystate(unset|set) $3=subcmd -> normalized stdout+stderr+exit
  local tool="$1" keystate="$2" sub="$3" out rc
  if [ "$keystate" = set ]; then
    out="$(cd "$ROOT" && FAL_KEY="$SENTINEL" bash ".agent0/tools/$tool.sh" "$sub" 2>&1)"; rc=$?
  else
    out="$(cd "$ROOT" && env -u FAL_KEY bash ".agent0/tools/$tool.sh" "$sub" 2>&1)"; rc=$?
  fi
  printf '%s\n--exit:%s\n' "$out" "$rc" | norm
}

do_mode() {
  local mode="$1" fail=0
  for tool in $TOOLS; do
    [ -f "$ROOT/.agent0/tools/$tool.sh" ] || { echo "paid-golden: missing tool $tool" >&2; fail=1; continue; }
    mkdir -p "$BASE/$tool"
    for keystate in unset set; do
      for sub in caps doctor; do
        local label="$sub.$keystate" base="$BASE/$tool/$sub.$keystate.txt" got
        got="$(run_one "$tool" "$keystate" "$sub")"
        # leak guard: the key value must NEVER appear, in either mode
        if printf '%s' "$got" | grep -qF "$SENTINEL"; then
          echo "  ✗ $tool/$label — FAL_KEY VALUE LEAKED into output"; fail=1; continue
        fi
        if [ "$mode" = capture ]; then
          printf '%s\n' "$got" > "$base"; echo "  captured $tool/$label"
        else
          if [ ! -f "$base" ]; then echo "  ✗ $tool/$label — no baseline (run capture first)"; fail=1; continue; fi
          if [ "$got" = "$(cat "$base")" ]; then echo "  ✓ $tool/$label"
          else echo "  ✗ $tool/$label — DRIFT:"; diff <(cat "$base") <(printf '%s\n' "$got") | head -20; fail=1; fi
        fi
      done
    done
  done
  return $fail
}

case "${1:-}" in
  capture) echo "paid-golden: capturing baselines (FAL_KEY unset+set)…"; do_mode capture;;
  verify)  echo "paid-golden: verifying parity (both FAL_KEY states + leak guard)…"; do_mode verify || { echo "=== paid-golden: PARITY DRIFT ==="; exit 1; }; echo "=== paid-golden: parity clean ===";;
  *) echo "usage: paid-golden.sh capture|verify" >&2; exit 2;;
esac
