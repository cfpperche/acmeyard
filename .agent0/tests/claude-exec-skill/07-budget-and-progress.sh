#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
echo "07-budget-and-progress"

TMPDIR="$(mktemp -d -t claude-exec-budget-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

make_fake_claude "$TMPDIR/bin"
ARGS="$TMPDIR/args.txt"
STDIN_FILE="$TMPDIR/stdin.txt"
STATE="$TMPDIR/state"

CLAUDE_EXEC_STATE_DIR="$STATE" \
FAKE_CLAUDE_ARGS="$ARGS" \
FAKE_CLAUDE_STDIN="$STDIN_FILE" \
FAKE_CLAUDE_SLEEP=2 \
PATH="$TMPDIR/bin:$PATH" \
  bash "$AGENT0_ROOT/.agent0/skills/claude-exec/scripts/claude-exec.sh" \
    --permission-mode default \
    --max-budget-usd 0.05 \
    --timeout 5 \
    --progress-interval 1 \
    --slug budget-progress \
    --task "Budget and progress test" > "$TMPDIR/out.txt" 2> "$TMPDIR/err.txt"

assert_arg_order "$ARGS" "--max-budget-usd" "0.05" "passes max budget to claude"
assert_contains "$TMPDIR/err.txt" "still running" "emits a progress heartbeat"
assert_contains "$TMPDIR/err.txt" "elapsed=" "heartbeat includes elapsed seconds"
assert_contains "$TMPDIR/err.txt" "stdout_bytes=" "heartbeat includes stdout byte count"

RUN_DIR="$(ls -d "$STATE"/*budget-progress 2>/dev/null | head -1)"
assert_contains "$RUN_DIR/metadata.json" '"max_budget_usd": "0.05"' "metadata records max budget"
assert_contains "$RUN_DIR/metadata.json" '"timeout_seconds": 5' "metadata records timeout setting"
assert_contains "$RUN_DIR/metadata.json" '"progress_interval_seconds": 1' "metadata records progress interval"
assert_contains "$RUN_DIR/metadata.json" '"timed_out": false' "metadata records non-timeout completion"
assert_contains "$RUN_DIR/metadata.json" '"elapsed_seconds":' "metadata records elapsed seconds"
assert_contains "$STATE/runs.jsonl" '"max_budget_usd":"0.05"' "aggregate log records max budget"

set +e
CLAUDE_EXEC_STATE_DIR="$TMPDIR/bad-state" \
FAKE_CLAUDE_ARGS="$TMPDIR/bad-args.txt" \
FAKE_CLAUDE_STDIN="$TMPDIR/bad-stdin.txt" \
PATH="$TMPDIR/bin:$PATH" \
  bash "$AGENT0_ROOT/.agent0/skills/claude-exec/scripts/claude-exec.sh" \
    --permission-mode default \
    --max-budget-usd nope \
    --task "Bad budget" > "$TMPDIR/bad.out" 2> "$TMPDIR/bad.err"
bad_status=$?
set -e

[ "$bad_status" -ne 0 ] && ok "invalid budget exits non-zero" || no "invalid budget exits non-zero"
assert_contains "$TMPDIR/bad.err" "invalid --max-budget-usd" "invalid budget error is explicit"
assert_no_path "$TMPDIR/bad-args.txt" "invalid budget blocks before invoking claude"
assert_no_path "$TMPDIR/bad-state" "invalid budget creates no runtime state"

set +e
CLAUDE_EXEC_STATE_DIR="$TMPDIR/bad-progress-state" \
FAKE_CLAUDE_ARGS="$TMPDIR/bad-progress-args.txt" \
FAKE_CLAUDE_STDIN="$TMPDIR/bad-progress-stdin.txt" \
PATH="$TMPDIR/bin:$PATH" \
  bash "$AGENT0_ROOT/.agent0/skills/claude-exec/scripts/claude-exec.sh" \
    --permission-mode default \
    --progress-interval nope \
    --task "Bad progress" > "$TMPDIR/bad-progress.out" 2> "$TMPDIR/bad-progress.err"
bad_progress_status=$?
set -e

[ "$bad_progress_status" -ne 0 ] && ok "invalid progress interval exits non-zero" || no "invalid progress interval exits non-zero"
assert_contains "$TMPDIR/bad-progress.err" "invalid --progress-interval" "invalid progress interval error is explicit"
assert_no_path "$TMPDIR/bad-progress-args.txt" "invalid progress interval blocks before invoking claude"
assert_no_path "$TMPDIR/bad-progress-state" "invalid progress interval creates no runtime state"

finish
