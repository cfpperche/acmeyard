#!/usr/bin/env bash
# Spec 163: a tool whose kit lib is absent fails CLEARLY (exit 70), not cryptically.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TMP="$(mktemp -d -t cap-missingkit-XXXXXX)"; trap 'rm -rf "$TMP"' EXIT
cp "$AGENT0_ROOT/.agent0/tools/diagram.sh" "$TMP/diagram.sh"   # copy tool WITHOUT lib/
PASS=0; FAIL=0
out="$(bash "$TMP/diagram.sh" caps 2>&1)"; rc=$?
if [ "$rc" = 70 ] && printf '%s' "$out" | grep -q "missing kit library lib/capacity.sh"; then
  PASS=$((PASS+1)); echo "  ✓ missing capacity kernel → exit 70 + clear message"
else
  FAIL=$((FAIL+1)); echo "  ✗ missing capacity-kit guard (rc=$rc: $out)"
fi

# spec 164: a PAID tool with capacity.sh present but paid-media.sh ABSENT must also
# fail clean (exit 70, naming the paid lib) — not source a half-present kit silently.
TMP2="$(mktemp -d -t cap-missingpaid-XXXXXX)"; trap 'rm -rf "$TMP" "$TMP2"' EXIT
mkdir -p "$TMP2/lib"
cp "$AGENT0_ROOT/.agent0/tools/sound.sh" "$TMP2/sound.sh"
cp "$AGENT0_ROOT/.agent0/tools/lib/capacity.sh" "$TMP2/lib/capacity.sh"   # kernel present, paid-media.sh NOT
out2="$(bash "$TMP2/sound.sh" caps 2>&1)"; rc2=$?
if [ "$rc2" = 70 ] && printf '%s' "$out2" | grep -q "missing kit library lib/paid-media.sh"; then
  PASS=$((PASS+1)); echo "  ✓ missing paid sub-kit → exit 70 + clear message"
else
  FAIL=$((FAIL+1)); echo "  ✗ missing paid-media guard (rc=$rc2: $out2)"
fi
echo "  -- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "=== missing-kit-guard: PASS ===" || { echo "=== missing-kit-guard: FAIL ==="; exit 1; }
