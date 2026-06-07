#!/usr/bin/env bash
# caps/doctor never fail; flag validation; no-source usage error.
source "$(dirname "$0")/_lib.sh"; echo "05-caps-doctor-flags"
C="$(bash "$TOOL" caps)"
assert_contains "$C" '"local":true' "caps local true"
assert_contains "$C" '"paid":false' "caps paid false"
assert_contains "$C" '"source_lang":"mermaid"' "caps mermaid source lang"
bash "$TOOL" doctor >/dev/null 2>&1; assert_eq "$?" "0" "doctor exit 0"
# no source -> usage error 64
bash "$TOOL" >/dev/null 2>&1; assert_eq "$?" "64" "no source -> usage error 64"
# bad format / kind -> 64
bash "$TOOL" "flowchart TD
 A-->B" --format gif >/dev/null 2>&1; assert_eq "$?" "64" "bad --format rejected"
bash "$TOOL" "flowchart TD
 A-->B" --kind bogus >/dev/null 2>&1; assert_eq "$?" "64" "bad --kind rejected"
finish
