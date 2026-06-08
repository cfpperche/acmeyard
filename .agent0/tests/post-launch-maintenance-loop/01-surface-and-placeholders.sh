#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

fail() {
  printf 'FAIL 01-surface-and-placeholders: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

require_text() {
  local file="$1"
  local text="$2"
  rg -q --fixed-strings "$text" "$file" || fail "missing '$text' in $file"
}

rule=".agent0/context/rules/post-launch-maintenance-loop.md"
provider_map=".agent0/context/templates/post-launch-maintenance-loop/provider-map.md"
issue_template=".agent0/context/templates/post-launch-maintenance-loop/agent-issue-template.md"
checklist=".agent0/context/templates/post-launch-maintenance-loop/review-checklist.md"
example=".agent0/context/templates/post-launch-maintenance-loop/examples/sentry-linear-codex.md"
product_skill=".claude/skills/product/SKILL.md"
pipeline=".claude/skills/product/references/pipeline-coverage.md"
governance=".agent0/context/rules/agent0-governance-doctrine.md"

for file in "$rule" "$provider_map" "$issue_template" "$checklist" "$example" "$product_skill" "$pipeline" "$governance"; do
  require_file "$file"
done

require_text "$rule" "instrument-only"
require_text "$rule" "Signal source"
require_text "$rule" "Work hub"
require_text "$rule" "Agent delegate"
require_text "$rule" "Review gate"
require_text "$rule" "Feedback sink"
require_text "$rule" "manual intake or dry-run"
require_text "$rule" "no auto-merge"
require_text "$rule" "/product"

require_text "$provider_map" "Capability roles"
require_text "$provider_map" "Token and credential classes"
require_text "$provider_map" "Data classes"
require_text "$provider_map" "Trigger filters"
require_text "$provider_map" "Feedback sink routing"
require_text "$provider_map" "REPLACE_WITH_"

require_text "$issue_template" "Trusted task instructions"
require_text "$issue_template" "Untrusted incident payload"
require_text "$issue_template" "Adversarial example"
require_text "$issue_template" "REPLACE_WITH_"

require_text "$checklist" "Intake safety"
require_text "$checklist" "Code review"
require_text "$checklist" "Release gate"
require_text "$checklist" "Feedback sink"

require_text "$example" "Example recipe: Sentry -> Linear -> Codex"
require_text "$example" "Dry-run first"
require_text "$example" "not the Agent0 architecture"
require_text "$example" "REPLACE_WITH_"

require_text "$product_skill" "Optional after first release"
require_text "$pipeline" "Post-launch maintenance remains sibling infrastructure"
require_text "$governance" "Spec 169"
require_text "$governance" "instrument-only slice"

targets=(
  "$rule"
  "$provider_map"
  "$issue_template"
  "$checklist"
  "$example"
  "$product_skill"
  "$pipeline"
)

if rg -n "SENTRY_DSN=|auth_token|lin_[A-Za-z0-9]|ghp_|sk-[A-Za-z0-9]|xox[baprs]-|team_[A-Za-z0-9]|Linear team ID|github.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+" "${targets[@]}"; then
  fail "configured credential or concrete consumer id pattern found"
fi

printf 'PASS 01-surface-and-placeholders\n'
