#!/usr/bin/env bash
# 04-delegation — delegation close checks declared-UI evidence bundles.
source "$(dirname "$0")/_lib.sh"
echo "04-delegation (declared UI delegation evidence advisory)"

make_repo() {
  local dir="$1"
  mkdir -p "$dir/bin"
  cat > "$dir/bin/npm" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$dir/bin/npm"

  (
    cd "$dir" || exit 1
    git init -q
    printf '{"scripts":{"test":"true"}}\n' > package.json
  )
}

write_transcript() {
  local transcript="$1"
  local outdir="$2"
  local ui_line="$3"
  cat > "$transcript" <<EOF
{"type":"message","role":"user","content":"TASK: Implement a checkout flow screen
CONTEXT: docs/specs/155-visual-contract-acceptance-gate/
CONSTRAINTS: no done from static review alone
DELIVERABLE: $outdir
$ui_line
DONE_WHEN: bash .agent0/tools/agent-browser.sh verify-contract http://localhost:3000/ fixtures/checkout.json $outdir && jq -e '.overall==\"pass\"' $outdir/report.json"}
EOF
}

run_hook_case() {
  local name="$1"
  local transcript="$2"
  local repo="$WORK/$name/repo"
  local stdout_file="$WORK/$name.stdout"
  local stderr_file="$WORK/$name.stderr"
  local input_file="$WORK/$name.input.json"
  make_repo "$repo"

  jq -n \
    --arg agent_id "agent-$name" \
    --arg agent_type "implementation" \
    --arg session_id "session-$name" \
    --arg cwd "$repo" \
    --arg transcript_path "$transcript" \
    '{agent_id:$agent_id, agent_type:$agent_type, session_id:$session_id, cwd:$cwd, transcript_path:$transcript_path, stop_hook_active:false}' \
    > "$input_file"

  (
    cd "$repo" || exit 1
    PATH="$repo/bin:$PATH" AGENT0_PROJECT_DIR="$repo" CLAUDE_DELEGATION_VALIDATOR="$VALIDATOR" "$DELEG_VERIFY" < "$input_file" > "$stdout_file" 2> "$stderr_file"
  )
  CASE_RC="$?"
  CASE_STDERR="$(cat "$stderr_file")"
}

missing_dir="$WORK/missing-evidence"
missing_transcript="$WORK/missing-transcript.jsonl"
write_transcript "$missing_transcript" "$missing_dir" "UI impact: flow"
run_hook_case missing "$missing_transcript"
assert_rc "$CASE_RC" "0" "declared UI without report exits 0"
assert_contains "$CASE_STDERR" "visual-contract-advisory:" "declared UI without report emits advisory"
assert_contains "$CASE_STDERR" "declared UI task closed without a passing" "declared UI advisory names missing evidence"

passing_dir="$WORK/passing-evidence"
mkdir -p "$passing_dir"
printf '{"overall":"pass","checks":[]}\n' > "$passing_dir/report.json"
passing_transcript="$WORK/passing-transcript.jsonl"
write_transcript "$passing_transcript" "$passing_dir" "UI impact: flow"
run_hook_case passing "$passing_transcript"
assert_rc "$CASE_RC" "0" "declared UI with passing report exits 0"
assert_not_contains "$CASE_STDERR" "declared UI task closed without a passing" "passing report suppresses evidence advisory"

non_ui_dir="$WORK/non-ui-evidence"
non_ui_transcript="$WORK/non-ui-transcript.jsonl"
cat > "$non_ui_transcript" <<EOF
{"type":"message","role":"user","content":"TASK: Update backend validation
CONTEXT: internal/server/
CONSTRAINTS: no UI work
DELIVERABLE: validator summary
DONE_WHEN: bash .agent0/tests/visual-contract/01-detect.sh"}
EOF
run_hook_case non_ui "$non_ui_transcript"
assert_rc "$CASE_RC" "0" "non-UI brief exits 0"
assert_not_contains "$CASE_STDERR" "declared UI task closed without a passing" "non-UI brief emits no evidence advisory"

finish
