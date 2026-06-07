#!/usr/bin/env bash
# Default engine (no --engine) -> kokoro; injected shim cmd resolves it.
source "$(dirname "$0")/_lib.sh"; echo "02-kokoro-default"
OUT="$(bash "$TOOL" "olá mundo" --lang pt)"; RC=$?
assert_eq "$RC" "0" "exit 0"
assert_contains "$OUT" "status=ok" "status ok"
assert_contains "$OUT" "engine=kokoro" "default engine is kokoro"
assert_contains "$OUT" "voice=pf_dora" "pt picks pf_dora default voice"
assert_contains "$(cat "$WORK/m.jsonl")" "\"engine\":\"kokoro\"" "manifest engine kokoro"
finish
