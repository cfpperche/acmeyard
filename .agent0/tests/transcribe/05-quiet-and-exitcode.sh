#!/usr/bin/env bash
# Scenario: --quiet suppresses the transcript echo; --exit-code maps status to exit code.
source "$(dirname "$0")/_lib.sh"
echo "05-quiet-and-exitcode"

IN="$(mkinput call.mp3)"

# --quiet: file still written, but transcript NOT echoed.
OUT="$(bash "$TOOL" "$IN" --quiet)"
assert_contains "$OUT" "status=ok" "quiet run still ok"
assert_file "$WORK/out/call.txt" "quiet run still writes the file"
assert_not_contains "$OUT" "hello world this is a test transcript" "quiet suppresses stdout echo"

# --exit-code: ok -> 0
bash "$TOOL" "$IN" --quiet --exit-code >/dev/null 2>&1; assert_eq "$?" "0" "--exit-code ok -> 0"

# --exit-code: unavailable -> 2
unset TRANSCRIBE_WHISPER_BIN
bash "$TOOL" "$IN" --quiet --exit-code >/dev/null 2>&1; assert_eq "$?" "2" "--exit-code unavailable -> 2"

finish
