#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
echo "07-progress"

TMPDIR="$(mktemp -d -t codex-exec-progress-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

make_fake_codex "$TMPDIR/bin"
ARGS="$TMPDIR/args.txt"
STDIN_FILE="$TMPDIR/stdin.txt"
STATE="$TMPDIR/state"

CODEX_EXEC_STATE_DIR="$STATE" \
FAKE_CODEX_ARGS="$ARGS" \
FAKE_CODEX_STDIN="$STDIN_FILE" \
FAKE_CODEX_PARTIAL_STDOUT="progress child stdout" \
FAKE_CODEX_PARTIAL_STDERR="progress child stderr" \
FAKE_CODEX_SLEEP=2 \
PATH="$TMPDIR/bin:$PATH" \
  bash "$AGENT0_ROOT/.agent0/skills/codex-exec/scripts/codex-exec.sh" \
    --timeout 5 \
    --progress-interval 1 \
    --slug progress-probe \
    --task "Progress test" > "$TMPDIR/out.txt" 2> "$TMPDIR/err.txt"

assert_contains "$TMPDIR/err.txt" "codex-exec: still running elapsed=" "progress heartbeat is emitted"
assert_contains "$TMPDIR/err.txt" "stdout_bytes=" "progress heartbeat includes stdout bytes"
assert_contains "$TMPDIR/err.txt" "stderr_bytes=" "progress heartbeat includes stderr bytes"

RUN_DIR="$(ls -d "$STATE"/*progress-probe 2>/dev/null | head -1)"
assert_contains "$RUN_DIR/metadata.json" '"timed_out": false' "metadata records timed_out false"
assert_contains "$RUN_DIR/metadata.json" '"timeout_seconds": 5' "metadata records timeout seconds"
assert_contains "$RUN_DIR/metadata.json" '"progress_interval_seconds": 1' "metadata records progress interval"
assert_contains "$RUN_DIR/metadata.json" '"elapsed_seconds":' "metadata records elapsed seconds"
assert_contains "$STATE/runs.jsonl" '"timed_out":false' "aggregate log records timed_out false"
assert_contains "$RUN_DIR/last-message.md" "fake codex last message" "successful slow run writes last message"

set +e
CODEX_EXEC_STATE_DIR="$TMPDIR/bad-progress-state" \
FAKE_CODEX_ARGS="$TMPDIR/bad-progress-args.txt" \
FAKE_CODEX_STDIN="$TMPDIR/bad-progress-stdin.txt" \
PATH="$TMPDIR/bin:$PATH" \
  bash "$AGENT0_ROOT/.agent0/skills/codex-exec/scripts/codex-exec.sh" \
    --progress-interval nope \
    --task "Bad progress" > "$TMPDIR/bad-progress.out" 2> "$TMPDIR/bad-progress.err"
bad_progress_status=$?
set -e

[ "$bad_progress_status" -ne 0 ] && ok "invalid progress interval exits non-zero" || no "invalid progress interval exits non-zero"
assert_contains "$TMPDIR/bad-progress.err" "invalid --progress-interval" "invalid progress interval error is explicit"
assert_no_path "$TMPDIR/bad-progress-args.txt" "invalid progress interval blocks before invoking codex"
assert_no_path "$TMPDIR/bad-progress-state" "invalid progress interval creates no runtime state"

finish
