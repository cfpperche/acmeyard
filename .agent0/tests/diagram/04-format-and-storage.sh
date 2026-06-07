#!/usr/bin/env bash
# --format png; storage split (default out vs --out); .mmd file source path.
source "$(dirname "$0")/_lib.sh"; echo "04-format-and-storage"
# png format
bash "$TOOL" "classDiagram
 class A" --kind class --format png >/dev/null
assert_eq "$(ls "$WORK/out" | grep -c '\.png$')" "1" "--format png produces png"
# --out override (spec-owned style placement)
bash "$TOOL" "stateDiagram-v2
 [*] --> S" --kind state --out "$WORK/altout" >/dev/null
assert_eq "$(ls "$WORK/altout" | grep -c '\.svg$')" "1" "--out targets an alternate dir"
assert_eq "$(ls "$WORK/altout" | grep -c '\.mmd$')" "1" "--out also carries the source"
# file source (not inline) -> stem from basename, source NOT duplicated
echo "erDiagram
  CUSTOMER ||--o{ ORDER : places" > "$WORK/schema.mmd"
OUT="$(bash "$TOOL" "$WORK/schema.mmd" --kind erd --out "$WORK/altout" --json)"
assert_contains "$OUT" '"output"' "file-source render ok"
assert_contains "$OUT" "schema.svg" "output stem derived from source basename"
assert_contains "$OUT" "\"source\":\"$WORK/schema.mmd\"" "manifest source points at the original file"
finish
