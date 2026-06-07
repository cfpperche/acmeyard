#!/usr/bin/env bash
# --format wav passthrough; unknown engine -> error; --exit-code mapping; doctor no secret leak.
source "$(dirname "$0")/_lib.sh"; echo "06-format-exitcode-doctor"

# wav passthrough (no ffmpeg needed)
OUT="$(bash "$TOOL" "wav please" --engine piper --format wav)"
assert_contains "$OUT" "status=ok" "wav ok"
assert_file "$(ls "$WORK/draft"/*.wav 2>/dev/null | head -1)" "wav file written"

# unknown engine -> error
OUT="$(bash "$TOOL" "x" --engine bogus)"
assert_contains "$OUT" "status=error" "unknown engine -> error"

# --exit-code mapping: ok -> 0
bash "$TOOL" "x" --engine piper --exit-code >/dev/null 2>&1; assert_eq "$?" "0" "--exit-code ok -> 0"
# unknown engine + --exit-code -> 3
bash "$TOOL" "x" --engine bogus --exit-code >/dev/null 2>&1; assert_eq "$?" "3" "--exit-code error -> 3"

# doctor must NEVER print the FAL_KEY value (regression guard for the leak fixed in build)
export FAL_KEY="SECRET-LEAK-CANARY-123"  # gitleaks:allow (fake canary — proves doctor never prints the key)
DOC="$(bash "$TOOL" doctor)"
assert_contains "$DOC" "FAL_KEY set" "doctor reports key as 'set'"
assert_not_contains "$DOC" "SECRET-LEAK-CANARY-123" "doctor NEVER prints the key value"
finish
