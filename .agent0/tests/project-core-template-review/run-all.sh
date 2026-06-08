#!/usr/bin/env bash
# Project-core template review advisory scenarios.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOKS="$AGENT0_ROOT/.agent0/hooks"
TOOLS="$AGENT0_ROOT/.agent0/tools"

TMPDIR="$(mktemp -d -t project-core-template-review-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1"
  [ -n "${2:-}" ] && printf '%s\n' "$2"
  exit 1
}

ok() {
  printf '  ok: %s\n' "$1"
}

make_health_project() {
  local dir="$1" source_marker="$2" example_marker="$3"
  mkdir -p "$dir/.agent0/hooks" "$dir/.agent0/tools/lib" "$dir/.agent0/context/rules" "$dir/.claude" "$dir/.codex"
  for f in startup-brief.sh reminders-readout.sh routines-readout.sh; do
    cp "$HOOKS/$f" "$dir/.agent0/hooks/$f"
    chmod +x "$dir/.agent0/hooks/$f"
  done
  cp "$HOOKS/_brief-compose.sh" "$HOOKS/_memory-hook-lib.sh" "$dir/.agent0/hooks/"
  cp "$TOOLS/status.sh" "$TOOLS/doctor.sh" "$TOOLS/project-core-sync.sh" "$dir/.agent0/tools/"
  cp "$TOOLS/lib/managed-block.sh" "$dir/.agent0/tools/lib/"
  chmod +x "$dir/.agent0/tools/status.sh" "$dir/.agent0/tools/doctor.sh" "$dir/.agent0/tools/project-core-sync.sh"
  printf '# Handoff\n\n## Current State\n\n- Fixture\n\n## Active Work\n\n- None\n\n## Next Actions\n\n- Nothing actionable\n' > "$dir/.agent0/HANDOFF.md"
  printf '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"bash $CLAUDE_PROJECT_DIR/.agent0/hooks/startup-brief.sh"}]}]}}\n' > "$dir/.claude/settings.json"
  printf '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"bash $CLAUDE_PROJECT_DIR/.agent0/hooks/startup-brief.sh"}]}]}}\n' > "$dir/.codex/hooks.json"
  printf '# Example\n\n<!-- AGENT0:PROJECT-CORE-TEMPLATE: %s -->\n\n## Language & Locale\n\n- Human communication: <replace>.\n' "$example_marker" > "$dir/.agent0/project-core.md.example"
  if [ -n "$source_marker" ]; then
    printf '# Source\n\n<!-- AGENT0:PROJECT-CORE-TEMPLATE: %s -->\n\n## Language & Locale\n\n- Human communication: pt-BR.\n' "$source_marker" > "$dir/.agent0/project-core.md"
  else
    printf '# Source\n\n## Language & Locale\n\n- Human communication: pt-BR.\n' > "$dir/.agent0/project-core.md"
  fi
  printf '# Claude\n\n<!-- AGENT0:PROJECT:BEGIN -->\n%s\n<!-- AGENT0:PROJECT:END -->\n\n<!-- AGENT0:BEGIN -->\nshared\n<!-- AGENT0:END -->\n' "$(cat "$dir/.agent0/project-core.md")" > "$dir/CLAUDE.md"
  printf '# Agents\n\n<!-- AGENT0:PROJECT:BEGIN -->\n%s\n<!-- AGENT0:PROJECT:END -->\n\n<!-- AGENT0:BEGIN -->\nshared\n<!-- AGENT0:END -->\n' "$(cat "$dir/.agent0/project-core.md")" > "$dir/AGENTS.md"
}

startup_out() {
  local dir="$1"
  printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"template-review"}' \
    | AGENT0_PROJECT_DIR="$dir" bash "$HOOKS/startup-brief.sh" 2>/dev/null
}

status_out() {
  local dir="$1"
  AGENT0_PROJECT_DIR="$dir" bash "$TOOLS/status.sh" 2>/dev/null
}

doctor_out() {
  local dir="$1"
  AGENT0_PROJECT_DIR="$dir" bash "$TOOLS/doctor.sh" 2>/dev/null
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  printf '%s' "$haystack" | grep -qF "$needle" || fail "$label missing [$needle]" "$haystack"
  ok "$label"
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    fail "$label unexpectedly contained [$needle]" "$haystack"
  fi
  ok "$label"
}

printf 'Scenario 1: startup/status/doctor warn when configured source lacks current template marker\n'
pending="$TMPDIR/pending"
make_health_project "$pending" "" "test-v2"
p_status="$(status_out "$pending")"
p_startup="$(startup_out "$pending")"
p_doctor="$(doctor_out "$pending")"; p_doctor_rc=$?
[ "$p_doctor_rc" -eq 0 ] || fail "doctor should exit 0 on template review advisory" "$p_doctor"
assert_contains "$p_status" "=== project-core ===" "status template-review block appears"
assert_contains "$p_startup" "template review pending" "startup template-review text appears"
assert_contains "$p_doctor" "template review pending" "doctor template-review advisory appears"
assert_contains "$p_doctor" "test-v2" "doctor names current template id"

printf 'Scenario 2: matching source marker is quiet\n'
quiet="$TMPDIR/quiet"
make_health_project "$quiet" "test-v2" "test-v2"
q_status="$(status_out "$quiet")"
q_startup="$(startup_out "$quiet")"
q_doctor="$(doctor_out "$quiet")"; q_doctor_rc=$?
[ "$q_doctor_rc" -eq 0 ] || fail "doctor should exit 0 when template marker matches" "$q_doctor"
assert_not_contains "$q_status" "=== project-core ===" "status template-review block disappears"
assert_not_contains "$q_startup" "template review pending" "startup template-review text disappears"
assert_not_contains "$q_doctor" "template review pending" "doctor template-review advisory disappears"

printf 'Scenario 3: bootstrap state takes precedence over template review\n'
boot="$TMPDIR/bootstrap"
make_health_project "$boot" "test-v1" "test-v2"
rm "$boot/.agent0/project-core.md"
b_status="$(status_out "$boot")"
assert_contains "$b_status" "=== bootstrap ===" "bootstrap block appears when source missing"
assert_not_contains "$b_status" "=== project-core ===" "template-review block suppressed when source missing"

printf 'Scenario 4: sync emits template-review advisory after copying example\n'
src="$TMPDIR/source"
consumer="$TMPDIR/consumer"
mkdir -p "$src/.agent0/tools/lib" "$src/.agent0" "$src/.claude" "$consumer/.agent0"
cp "$TOOLS/sync-harness.sh" "$src/.agent0/tools/sync-harness.sh"
cp "$TOOLS/project-core-sync.sh" "$src/.agent0/tools/project-core-sync.sh"
cp "$TOOLS/lib/managed-block.sh" "$src/.agent0/tools/lib/managed-block.sh"
cat > "$src/CLAUDE.md" <<'EOF'
# Source

<!-- AGENT0:BEGIN -->
shared
<!-- AGENT0:END -->
EOF
cat > "$src/AGENTS.md" <<'EOF'
# Source Codex

<!-- AGENT0:BEGIN -->
shared
<!-- AGENT0:END -->
EOF
printf '{"hooks":{}}\n' > "$src/.claude/settings.json"
printf '# Example\n\n<!-- AGENT0:PROJECT-CORE-TEMPLATE: test-v2 -->\n\n## Language & Locale\n\n- Human communication: <replace>.\n' > "$src/.agent0/project-core.md.example"
printf '# Consumer source\n\n## Language & Locale\n\n- Human communication: pt-BR.\n' > "$consumer/.agent0/project-core.md"

sync_out="$(bash "$src/.agent0/tools/sync-harness.sh" --apply --agent0-path="$src" "$consumer" 2>&1)" || fail "sync apply failed" "$sync_out"
assert_contains "$sync_out" "project-core-advisory: template review pending" "sync emits template-review advisory"
assert_contains "$sync_out" "test-v2" "sync advisory names current template id"
grep -qF '<!-- AGENT0:PROJECT-CORE-TEMPLATE: test-v2 -->' "$consumer/.agent0/project-core.md.example" || fail "example was not copied with current marker"
grep -qF '<!-- AGENT0:PROJECT-CORE-TEMPLATE: test-v2 -->' "$consumer/.agent0/project-core.md" && fail "sync wrongly auto-updated source marker"
ok "sync copies example and preserves unreviewed source"

printf 'PASS: project-core-template-review\n'
