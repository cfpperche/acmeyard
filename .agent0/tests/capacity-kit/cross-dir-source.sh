#!/usr/bin/env bash
# .agent0/tests/capacity-kit/cross-dir-source.sh — spec 165.
#
# The load-bearing gate that let video/image join the paid kit. They are
# SKILL-DIR tools that source lib/paid-media.sh across directories, anchored on
# $PROJECT_DIR (= CLAUDE_PROJECT_DIR | git toplevel) — the same anchor they
# already use for fal-rest.sh. This pins the three things that anchor must do:
#
#   (a) REPO-ROOT resolution    — running from the repo finds the real lib
#   (b) CONSUMER-ROOT resolution — CLAUDE_PROJECT_DIR=<consumer> finds the lib
#                                  shipped to that consumer (not Agent0's)
#   (c) ABSENT-LIB clean failure — a PAID subcommand exits 70 + the kernel
#                                  message, WHILE --help still exits 0 (lazy-load:
#                                  the non-paid lanes never need the lib)
#
# Determinism: no network, no FAL_KEY. The probe is exit-code contrast —
# lib absent => 70 (load fails FIRST, before the FAL_KEY check); lib present +
# no FAL_KEY => NOT 70 (got past the load, hit the tool's own key/arg path).

set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "  ✓ $1"; }
no(){ FAIL=$((FAIL+1)); echo "  ✗ $1"; }

# paid-subcommand invocation per tool (no FAL_KEY in env)
paid_invoke() { # $1=tool $2=script
  case "$1" in
    video) env -u FAL_KEY bash "$2" prepare --tier=draft --duration=5 --confirm-cost-usd=1 "smoke" 2>&1 ;;
    image) env -u FAL_KEY bash "$2" prepare --tier=draft "smoke" 2>&1 ;;
  esac
}

for tool in video image; do
  SCRIPT="$AGENT0_ROOT/.agent0/skills/$tool/scripts/gen.sh"
  [ -f "$SCRIPT" ] || { no "$tool: gen.sh missing"; continue; }

  # (a) repo-root: real lib present → paid path gets PAST the load (rc != 70)
  out="$(cd "$AGENT0_ROOT" && paid_invoke "$tool" "$SCRIPT")"; rc=$?
  [ "$rc" != 70 ] && ok "$tool (a) repo-root: lib resolves, past load (rc=$rc)" \
    || no "$tool (a) repo-root: rc=70 — did NOT find the real lib"

  # (b) consumer-root: a SENTINEL consumer lib with OBSERVABLE behavior. It is NOT
  # a copy of the real lib — its pm_has_fal_key emits a unique marker. If the script
  # sourced the consumer lib (correct), the marker appears; if it ignored
  # CLAUDE_PROJECT_DIR and sourced the repo-root real lib, NO marker → the lane
  # catches the regression even when run from inside the Agent0 repo.
  CONS="$(mktemp -d -t xdir-cons-XXXXXX)"
  mkdir -p "$CONS/.agent0/tools/lib"
  MARK="XDIR_SENTINEL_${tool}_$$"
  cat > "$CONS/.agent0/tools/lib/paid-media.sh" <<EOF
#!/usr/bin/env bash
# sentinel paid-media.sh (test fixture) — observable proof of \$PROJECT_DIR sourcing
pm_has_fal_key() { echo "$MARK" >&2; return 1; }   # emit marker, then take the no-key path
pm_fal_key_state() { echo unset; }
pm_yaml_top() { :; }
pm_yaml_tier_field() { :; }
EOF
  out="$(CLAUDE_PROJECT_DIR="$CONS" paid_invoke "$tool" "$SCRIPT")"; rc=$?
  if printf '%s' "$out" | grep -q "$MARK"; then
    ok "$tool (b) consumer-root: sourced the SENTINEL lib from CLAUDE_PROJECT_DIR (marker observed)"
  else
    no "$tool (b) consumer-root: sentinel marker NOT observed — did not source the consumer lib (rc=$rc)"
  fi

  # (c1) absent-lib consumer: paid subcommand → exit 70 + kernel message
  CONS2="$(mktemp -d -t xdir-nolib-XXXXXX)"
  mkdir -p "$CONS2/.agent0/tools"   # tools/ exists, lib/ does NOT
  out="$(CLAUDE_PROJECT_DIR="$CONS2" paid_invoke "$tool" "$SCRIPT")"; rc=$?
  if [ "$rc" = 70 ] && printf '%s' "$out" | grep -q "missing kit library lib/paid-media.sh"; then
    ok "$tool (c1) absent-lib: paid path exits 70 + clear message"
  else
    no "$tool (c1) absent-lib: rc=$rc out=$out"
  fi

  # (c2) absent-lib consumer: --help STILL exits 0 (lazy-load preserves non-paid lane)
  out="$(CLAUDE_PROJECT_DIR="$CONS2" env -u FAL_KEY bash "$SCRIPT" --help 2>&1)"; rc=$?
  [ "$rc" = 0 ] && ok "$tool (c2) absent-lib: --help still exits 0" \
    || no "$tool (c2) absent-lib: --help rc=$rc (lazy-load broken)"

  rm -rf "$CONS" "$CONS2"
done

echo "  -- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "=== cross-dir-source: PASS ===" || { echo "=== cross-dir-source: FAIL ==="; exit 1; }
