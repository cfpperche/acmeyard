#!/usr/bin/env bash
# Scenario: settings.json merge prunes hooks known to be Agent0-owned when Agent0
# removed them upstream, while preserving consumer-owned hooks in the same event.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-172-44-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
CONSUMER="$TMPDIR/consumer"
mkdir -p "$SRC/.claude" "$CONSUMER/.claude" "$CONSUMER/.agent0"

old_context_cmd='bash $CLAUDE_PROJECT_DIR/.agent0/hooks/context-inject.sh'
consumer_cmd='bash $CLAUDE_PROJECT_DIR/.claude/hooks/consumer-prompt.sh'
startup_cmd='bash $CLAUDE_PROJECT_DIR/.agent0/hooks/startup-brief.sh'
old_identity="$(jq -cnr --arg cmd "$old_context_cmd" '["UserPromptSubmit", "", [$cmd]] | tojson')"
startup_identity="$(jq -cnr --arg cmd "$startup_cmd" '["SessionStart", "", [$cmd]] | tojson')"

jq -cn --arg startup "$startup_cmd" '{
  hooks: {
    SessionStart: [
      {hooks:[{type:"command", command:$startup}]}
    ]
  }
}' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"

jq -cn --arg old "$old_context_cmd" --arg consumer "$consumer_cmd" '{
  hooks: {
    UserPromptSubmit: [
      {hooks:[{type:"command", command:$old}]},
      {hooks:[{type:"command", command:$consumer}]}
    ]
  }
}' > "$CONSUMER/.claude/settings.json"
printf '# CLAUDE consumer project\n\n## Compact Instructions\n' > "$CONSUMER/CLAUDE.md"

jq -cn --arg old "$old_identity" '{
  agent0_commit: null,
  synced_at: "2026-06-08T00:00:00Z",
  tool_version: 1,
  files: {},
  settings_hooks: [$old]
}' > "$CONSUMER/.agent0/harness-sync-baseline.json"

actual_exit=0
bash "$TOOL" --apply --agent0-path="$SRC" "$CONSUMER" >/dev/null 2>&1 || actual_exit=$?
if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: --apply expected exit 0, got %d\n' "$actual_exit"
  exit 1
fi

if grep -q 'context-inject.sh' "$CONSUMER/.claude/settings.json"; then
  printf 'FAIL: removed Agent0-owned context-inject hook remained in settings.json\n'
  jq . "$CONSUMER/.claude/settings.json"
  exit 1
fi

if ! jq -e --arg consumer "$consumer_cmd" '.hooks.UserPromptSubmit[] | select(.hooks[].command == $consumer)' "$CONSUMER/.claude/settings.json" >/dev/null; then
  printf 'FAIL: consumer-owned UserPromptSubmit hook was not preserved\n'
  jq . "$CONSUMER/.claude/settings.json"
  exit 1
fi

if ! jq -e --arg startup "$startup_cmd" '.hooks.SessionStart[] | select(.hooks[].command == $startup)' "$CONSUMER/.claude/settings.json" >/dev/null; then
  printf 'FAIL: current Agent0 SessionStart hook was not merged\n'
  jq . "$CONSUMER/.claude/settings.json"
  exit 1
fi

if jq -e '.settings_hooks[]? | select(test("context-inject"))' "$CONSUMER/.agent0/harness-sync-baseline.json" >/dev/null; then
  printf 'FAIL: baseline still records removed context-inject settings hook\n'
  jq . "$CONSUMER/.agent0/harness-sync-baseline.json"
  exit 1
fi

if ! jq -e --arg startup_identity "$startup_identity" '.settings_hooks[]? | select(. == $startup_identity)' "$CONSUMER/.agent0/harness-sync-baseline.json" >/dev/null; then
  printf 'FAIL: baseline did not record current Agent0 settings hook identity\n'
  jq . "$CONSUMER/.agent0/harness-sync-baseline.json"
  exit 1
fi

settings_sha="$(sha256sum "$CONSUMER/.claude/settings.json" | awk '{print $1}')"
baseline_sha="$(sha256sum "$CONSUMER/.agent0/harness-sync-baseline.json" | awk '{print $1}')"
second_exit=0
second_out="$(bash "$TOOL" --apply --agent0-path="$SRC" "$CONSUMER" 2>&1)" || second_exit=$?
if [ "$second_exit" -ne 0 ]; then
  printf 'FAIL: second --apply expected exit 0, got %d\n%s\n' "$second_exit" "$second_out"
  exit 1
fi
if [ "$settings_sha" != "$(sha256sum "$CONSUMER/.claude/settings.json" | awk '{print $1}')" ]; then
  printf 'FAIL: second --apply changed settings.json after prune convergence\n%s\n' "$second_out"
  exit 1
fi
if [ "$baseline_sha" != "$(sha256sum "$CONSUMER/.agent0/harness-sync-baseline.json" | awk '{print $1}')" ]; then
  printf 'FAIL: second --apply changed baseline after prune convergence\n%s\n' "$second_out"
  exit 1
fi

echo "PASS: 44-settings-removes-agent0-hook"
