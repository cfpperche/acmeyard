#!/usr/bin/env bash
# --asset -> tracked asset dir, draft empty, manifest class asset.
source "$(dirname "$0")/_lib.sh"; echo "03-asset-class"
OUT="$(bash "$TOOL" "keep me" --engine piper --asset)"
assert_contains "$OUT" "class=asset" "reports asset class"
assert_eq "$(ls "$WORK/asset" | wc -l | tr -d ' ')" "1" "file in tracked asset dir"
assert_eq "$(ls "$WORK/draft" | wc -l | tr -d ' ')" "0" "draft dir empty"
assert_contains "$(cat "$WORK/m.jsonl")" "\"class\":\"asset\"" "manifest class asset"
finish
