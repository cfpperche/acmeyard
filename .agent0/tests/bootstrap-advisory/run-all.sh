#!/usr/bin/env bash
# Bootstrap advisory scenarios for project-core.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOKS="$AGENT0_ROOT/.agent0/hooks"
TOOLS="$AGENT0_ROOT/.agent0/tools"

TMPDIR="$(mktemp -d -t bootstrap-advisory-XXXXXX)"
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
  local dir="$1" mode="$2"
  mkdir -p "$dir/.agent0/hooks" "$dir/.agent0/tools" "$dir/.agent0/context/rules" "$dir/.claude" "$dir/.codex"
  for f in startup-brief.sh reminders-readout.sh routines-readout.sh; do
    cp "$HOOKS/$f" "$dir/.agent0/hooks/$f"
    chmod +x "$dir/.agent0/hooks/$f"
  done
  cp "$HOOKS/_brief-compose.sh" "$HOOKS/_memory-hook-lib.sh" "$dir/.agent0/hooks/"
  mkdir -p "$dir/.agent0/tools/lib"
  cp "$TOOLS/status.sh" "$TOOLS/doctor.sh" "$TOOLS/project-core-sync.sh" "$dir/.agent0/tools/"
  cp "$TOOLS/lib/managed-block.sh" "$dir/.agent0/tools/lib/"
  chmod +x "$dir/.agent0/tools/status.sh" "$dir/.agent0/tools/doctor.sh" "$dir/.agent0/tools/project-core-sync.sh"
  cat > "$dir/.claude/settings.json" <<'JSON'
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"bash $CLAUDE_PROJECT_DIR/.agent0/hooks/startup-brief.sh"}]}]}}
JSON
  cat > "$dir/.codex/hooks.json" <<'JSON'
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"bash $CLAUDE_PROJECT_DIR/.agent0/hooks/startup-brief.sh"}]}]}}
JSON
  printf '# Handoff\n\n## Current State\n\n- Fixture\n\n## Active Work\n\n- None\n\n## Next Actions\n\n- Nothing actionable\n' > "$dir/.agent0/HANDOFF.md"

  case "$mode" in
    pending)
      printf '# Example\n\n## Language & Locale\n\n- Human communication: <replace>.\n' > "$dir/.agent0/project-core.md.example"
      ;;
    configured)
      printf '# Example\n\n<!-- AGENT0:PROJECT-CORE-TEMPLATE: test-v1 -->\n\n## Language & Locale\n\n- Human communication: <replace>.\n' > "$dir/.agent0/project-core.md.example"
      printf '# Configured core\n\n<!-- AGENT0:PROJECT-CORE-TEMPLATE: test-v1 -->\n\n## Language & Locale\n\n- Human communication: pt-BR.\n' > "$dir/.agent0/project-core.md"
      ;;
    none) ;;
    *) fail "unknown fixture mode: $mode" ;;
  esac
}

startup_out() {
  local dir="$1"
  printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"bootstrap"}' \
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

printf 'Scenario 1: startup/status/doctor warn while project-core bootstrap is pending\n'
pending="$TMPDIR/pending"
make_health_project "$pending" pending
p_status="$(status_out "$pending")"
p_startup="$(startup_out "$pending")"
p_doctor="$(doctor_out "$pending")"; p_doctor_rc=$?
[ "$p_doctor_rc" -eq 0 ] || fail "doctor should exit 0 on advisory-only bootstrap state" "$p_doctor"
assert_contains "$p_status" "=== bootstrap ===" "status bootstrap block appears"
assert_contains "$p_startup" "=== bootstrap ===" "startup bootstrap block appears"
assert_contains "$p_doctor" "[ advisory ] project-core" "doctor project-core advisory appears"
assert_contains "$p_doctor" "bootstrap pending" "doctor names pending bootstrap"

printf 'Scenario 2: advisories disappear after project-core is configured\n'
configured="$TMPDIR/configured"
make_health_project "$configured" configured
c_status="$(status_out "$configured")"
c_startup="$(startup_out "$configured")"
c_doctor="$(doctor_out "$configured")"; c_doctor_rc=$?
[ "$c_doctor_rc" -eq 0 ] || fail "doctor should exit 0 after project-core is configured" "$c_doctor"
assert_not_contains "$c_status" "=== bootstrap ===" "status bootstrap block disappears"
assert_not_contains "$c_startup" "=== bootstrap ===" "startup bootstrap block disappears"
assert_not_contains "$c_doctor" "bootstrap pending" "doctor pending advisory disappears"

printf 'Scenario 3: no example means no project-core bootstrap warning\n'
none="$TMPDIR/none"
make_health_project "$none" none
n_status="$(status_out "$none")"
n_startup="$(startup_out "$none")"
n_doctor="$(doctor_out "$none")"; n_doctor_rc=$?
[ "$n_doctor_rc" -eq 0 ] || fail "doctor should exit 0 with no project-core bootstrap surface" "$n_doctor"
assert_not_contains "$n_status" "=== bootstrap ===" "status silent with no example"
assert_not_contains "$n_startup" "=== bootstrap ===" "startup silent with no example"
assert_not_contains "$n_doctor" "bootstrap pending" "doctor silent with no example"

printf 'Scenario 4: sync warns pending, never creates source, then goes quiet after source exists\n'
src="$TMPDIR/source"
consumer="$TMPDIR/consumer"
mkdir -p "$src/.agent0/tools/lib" "$src/.agent0" "$src/.claude" "$consumer"
cp "$TOOLS/sync-harness.sh" "$src/.agent0/tools/sync-harness.sh"
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
printf '# Example\n\n<!-- AGENT0:PROJECT-CORE-TEMPLATE: test-v1 -->\n\n## Language & Locale\n\n- Human communication: <replace>.\n' > "$src/.agent0/project-core.md.example"

sync_out="$(bash "$src/.agent0/tools/sync-harness.sh" --apply --agent0-path="$src" "$consumer" 2>&1)"
assert_contains "$sync_out" "bootstrap-advisory: project-core source missing" "sync emits pending advisory"
assert_contains "$sync_out" "project-core-sync.sh --apply" "sync advisory points to local renderer"
[ ! -f "$consumer/.agent0/project-core.md" ] || fail "sync created real project-core source"
[ -f "$consumer/.agent0/project-core.md.example" ] || fail "sync did not copy project-core example"
ok "sync copies example without creating source"

printf '# Consumer core\n\n<!-- AGENT0:PROJECT-CORE-TEMPLATE: test-v1 -->\n\n## Language & Locale\n\n- Human communication: pt-BR.\n' > "$consumer/.agent0/project-core.md"
sync_quiet="$(bash "$src/.agent0/tools/sync-harness.sh" --check --agent0-path="$src" "$consumer" 2>&1 || true)"
assert_not_contains "$sync_quiet" "bootstrap-advisory:" "sync advisory disappears after source exists"

printf 'PASS: bootstrap-advisory\n'
