#!/usr/bin/env bash
# LIVE dogfood slice 2: auth-gated session save/load reuse (synthetic local host).
source "$(dirname "$0")/_lib.sh"
echo "11-dogfood-auth (live)"
need_live || { finish; exit 0; }

# pick a likely-free port to avoid collisions with a stray server
PORT=$(( 8170 + (RANDOM % 60) ))
bash "$TOOL" reset >/dev/null 2>&1
OUT="$(AUTH_PORT=$PORT timeout 90 bash "$FIXTURES/auth-slice.sh")"; RC=$?
echo "$OUT" | sed 's/^/    /'
assert_rc "$RC" 0 "auth-slice exits PASS"
assert_contains "$OUT" "AUTH-SLICE: PASS" "login + negative-control + state-reuse all hold"

finish
