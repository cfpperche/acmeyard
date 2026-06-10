#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

fail() {
  printf 'FAIL 02-provider-neutrality: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1"
  local text="$2"
  grep -qF -- "$text" "$file" || fail "missing '$text' in $file"
}

rule=".agent0/context/rules/post-launch-maintenance-loop.md"
provider_map=".agent0/context/templates/post-launch-maintenance-loop/provider-map.md"
issue_template=".agent0/context/templates/post-launch-maintenance-loop/agent-issue-template.md"
checklist=".agent0/context/templates/post-launch-maintenance-loop/review-checklist.md"
example=".agent0/context/templates/post-launch-maintenance-loop/examples/sentry-linear-codex.md"

require_text "$rule" "Sentry -> Linear -> Codex is a concrete example recipe only"
require_text "$rule" "Do not present it as the Agent0 architecture or a required provider stack."
require_text "$rule" "logs"
require_text "$rule" "uptime alerts"
require_text "$rule" "GitHub Issues"
require_text "$rule" "Claude"
require_text "$rule" "Cursor"
require_text "$rule" "Devin"

require_text "$provider_map" "REPLACE_WITH_ERROR_TRACKER_LOGS_ALERTS_OR_SUPPORT_QUEUE"
require_text "$provider_map" "REPLACE_WITH_LINEAR_GITHUB_ISSUES_JIRA_OR_OTHER"
require_text "$provider_map" "REPLACE_WITH_CODEX_CLAUDE_CURSOR_DEVIN_OR_OTHER"
require_text "$provider_map" "REPLACE_WITH_TEST_SDD_MEMORY_REMINDER_ROUTINE_OR_PRODUCT_VN"

require_text "$example" "Linear Sentry integration: https://linear.app/docs/sentry"
require_text "$example" "Linear agents: https://linear.app/docs/agents-in-linear"
require_text "$example" "Sentry alert rule API reference: https://docs.sentry.io/api/alerts/create-an-issue-alert-rule-for-a-project/"
require_text "$example" "Codex in Linear: https://developers.openai.com/codex/integrations/linear"

if grep -nE "https://linear|developers.openai|docs.sentry" "$provider_map" "$issue_template" "$checklist"; then
  fail "vendor docs URL leaked into provider-neutral templates"
fi

neutral_targets=("$rule" "$provider_map" "$issue_template" "$checklist")
if grep -nE "(must use|required to use|only works with|requires) (Sentry|Linear|Codex)" "${neutral_targets[@]}"; then
  fail "provider-neutral guidance contains mandatory vendor wording"
fi

printf 'PASS 02-provider-neutrality\n'
