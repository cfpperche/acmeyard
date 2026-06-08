#!/usr/bin/env bash
# Scenario: a legacy baseline without settings hook ownership metadata is
# ambiguous, so settings merge must not prune hooks by command-text guessing.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-172-45-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
CONSUMER="$TMPDIR/consumer"
mkdir -p "$SRC/.claude" "$CONSUMER/.claude" "$CONSUMER/.agent0"

old_context_cmd='bash $CLAUDE_PROJECT_DIR/.agent0/hooks/context-inject.sh'
startup_cmd='bash $CLAUDE_PROJECT_DIR/.agent0/hooks/startup-brief.sh'

jq -cn --arg startup "$startup_cmd" '{
  hooks: {
    SessionStart: [
      {hooks:[{type:"command", command:$startup}]}
    ]
  }
}' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"

jq -cn --arg old "$old_context_cmd" '{
  hooks: {
    UserPromptSubmit: [
      {hooks:[{type:"command", command:$old}]}
    ]
  }
}' > "$CONSUMER/.claude/settings.json"
printf '# CLAUDE consumer project\n\n## Compact Instructions\n' > "$CONSUMER/CLAUDE.md"

jq -cn '{
  agent0_commit: null,
  synced_at: "2026-06-08T00:00:00Z",
  tool_version: 1,
  files: {}
}' > "$CONSUMER/.agent0/harness-sync-baseline.json"

actual_exit=0
bash "$TOOL" --apply --agent0-path="$SRC" "$CONSUMER" >/dev/null 2>&1 || actual_exit=$?
if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: --apply expected exit 0, got %d\n' "$actual_exit"
  exit 1
fi

if ! jq -e --arg old "$old_context_cmd" '.hooks.UserPromptSubmit[] | select(.hooks[].command == $old)' "$CONSUMER/.claude/settings.json" >/dev/null; then
  printf 'FAIL: legacy-baseline merge pruned a hook without ownership metadata\n'
  jq . "$CONSUMER/.claude/settings.json"
  exit 1
fi

if ! jq -e --arg startup "$startup_cmd" '.hooks.SessionStart[] | select(.hooks[].command == $startup)' "$CONSUMER/.claude/settings.json" >/dev/null; then
  printf 'FAIL: current Agent0 hook was not merged\n'
  jq . "$CONSUMER/.claude/settings.json"
  exit 1
fi

if ! jq -e '.settings_hooks | type == "array"' "$CONSUMER/.agent0/harness-sync-baseline.json" >/dev/null; then
  printf 'FAIL: apply did not seed settings_hooks metadata in baseline\n'
  jq . "$CONSUMER/.agent0/harness-sync-baseline.json"
  exit 1
fi

echo "PASS: 45-settings-no-baseline-no-prune"
