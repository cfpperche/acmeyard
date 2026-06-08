#!/usr/bin/env bash
# Scenario: missing Agent0 .claude/settings.json is no signal. The settings
# merge is skipped and baseline settings_hooks are preserved, not advanced to [].

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-172-46-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
CONSUMER="$TMPDIR/consumer"
mkdir -p "$SRC/.claude" "$CONSUMER/.claude" "$CONSUMER/.agent0"

old_context_cmd='bash $CLAUDE_PROJECT_DIR/.agent0/hooks/context-inject.sh'
old_identity="$(jq -cnr --arg cmd "$old_context_cmd" '["UserPromptSubmit", "", [$cmd]] | tojson')"

printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"

jq -cn --arg old "$old_context_cmd" '{
  hooks: {
    UserPromptSubmit: [
      {hooks:[{type:"command", command:$old}]}
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

if ! jq -e --arg old "$old_context_cmd" '.hooks.UserPromptSubmit[] | select(.hooks[].command == $old)' "$CONSUMER/.claude/settings.json" >/dev/null; then
  printf 'FAIL: missing Agent0 settings source caused consumer hook prune\n'
  jq . "$CONSUMER/.claude/settings.json"
  exit 1
fi

if ! jq -e --arg old_identity "$old_identity" '.settings_hooks[]? | select(. == $old_identity)' "$CONSUMER/.agent0/harness-sync-baseline.json" >/dev/null; then
  printf 'FAIL: missing Agent0 settings source did not preserve previous settings_hooks baseline\n'
  jq . "$CONSUMER/.agent0/harness-sync-baseline.json"
  exit 1
fi

echo "PASS: 46-settings-missing-source-preserves-baseline"
