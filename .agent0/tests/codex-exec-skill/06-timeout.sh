#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
echo "06-timeout"

TMPDIR="$(mktemp -d -t codex-exec-timeout-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

make_fake_codex "$TMPDIR/bin"
ARGS="$TMPDIR/args.txt"
STDIN_FILE="$TMPDIR/stdin.txt"
PID_FILE="$TMPDIR/fake.pid"
STATE="$TMPDIR/state"

set +e
CODEX_EXEC_STATE_DIR="$STATE" \
FAKE_CODEX_ARGS="$ARGS" \
FAKE_CODEX_STDIN="$STDIN_FILE" \
FAKE_CODEX_PID_FILE="$PID_FILE" \
FAKE_CODEX_PARTIAL_STDOUT="partial child stdout" \
FAKE_CODEX_PARTIAL_STDERR="partial child stderr" \
FAKE_CODEX_SLEEP=5 \
PATH="$TMPDIR/bin:$PATH" \
  bash "$AGENT0_ROOT/.agent0/skills/codex-exec/scripts/codex-exec.sh" \
    --timeout 1 \
    --progress-interval 0 \
    --slug timeout-probe \
    --task "Timeout test" > "$TMPDIR/out.txt" 2> "$TMPDIR/err.txt"
status=$?
set -e

[ "$status" -eq 124 ] && ok "timeout exits with status 124" || { no "timeout exits with status 124"; echo "      status=$status"; }
assert_contains "$TMPDIR/err.txt" "timed out after 1s" "timeout is reported on helper stderr"

RUN_DIR="$(ls -d "$STATE"/*timeout-probe 2>/dev/null | head -1)"
assert_file "$RUN_DIR/metadata.json" "metadata exists after timeout"
assert_file "$RUN_DIR/stdout.txt" "stdout artifact preserved after timeout"
assert_file "$RUN_DIR/stderr.txt" "stderr artifact preserved after timeout"
assert_contains "$RUN_DIR/stdout.txt" "partial child stdout" "partial stdout is preserved"
assert_contains "$RUN_DIR/stderr.txt" "partial child stderr" "partial stderr is preserved"
assert_contains "$RUN_DIR/metadata.json" '"timed_out": true' "metadata records timed_out true"
assert_contains "$RUN_DIR/metadata.json" '"timeout_seconds": 1' "metadata records timeout seconds"
assert_contains "$RUN_DIR/metadata.json" '"progress_interval_seconds": 0' "metadata records progress interval"
assert_contains "$RUN_DIR/metadata.json" '"exit_code": 124' "metadata records timeout exit code"
assert_contains "$STATE/runs.jsonl" '"timed_out":true' "aggregate log records timed_out true"

if [ -s "$PID_FILE" ] && ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  ok "timed-out child process is gone"
else
  no "timed-out child process is gone"
  [ -s "$PID_FILE" ] && echo "      pid=$(cat "$PID_FILE")"
fi

set +e
CODEX_EXEC_STATE_DIR="$TMPDIR/bad-timeout-state" \
FAKE_CODEX_ARGS="$TMPDIR/bad-timeout-args.txt" \
FAKE_CODEX_STDIN="$TMPDIR/bad-timeout-stdin.txt" \
PATH="$TMPDIR/bin:$PATH" \
  bash "$AGENT0_ROOT/.agent0/skills/codex-exec/scripts/codex-exec.sh" \
    --timeout 0 \
    --task "Bad timeout" > "$TMPDIR/bad-timeout.out" 2> "$TMPDIR/bad-timeout.err"
bad_timeout_status=$?
set -e

[ "$bad_timeout_status" -ne 0 ] && ok "invalid timeout exits non-zero" || no "invalid timeout exits non-zero"
assert_contains "$TMPDIR/bad-timeout.err" "invalid --timeout" "invalid timeout error is explicit"
assert_no_path "$TMPDIR/bad-timeout-args.txt" "invalid timeout blocks before invoking codex"
assert_no_path "$TMPDIR/bad-timeout-state" "invalid timeout creates no runtime state"

finish
