#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
TOTAL_FAIL=0
for t in [0-9][0-9]-*.sh; do [ -f "$t" ] || continue; bash "$t" || TOTAL_FAIL=$((TOTAL_FAIL+1)); echo; done
if [ "$TOTAL_FAIL" -eq 0 ]; then echo "=== audio: ALL SCENARIOS PASS ==="; else echo "=== audio: $TOTAL_FAIL scenario file(s) FAILED ==="; exit 1; fi
