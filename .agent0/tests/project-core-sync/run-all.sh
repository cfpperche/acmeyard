#!/usr/bin/env bash
# Local project-core renderer scenarios.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/project-core-sync.sh"
LIB="$AGENT0_ROOT/.agent0/tools/lib/managed-block.sh"

TMPDIR="$(mktemp -d -t project-core-sync-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1"
  [ -n "${2:-}" ] && printf '%s\n' "$2"
  exit 1
}

ok() {
  printf '  ok: %s\n' "$1"
}

make_entrypoint() {
  local path="$1" title="$2"
  printf '# %s\n\n<!-- AGENT0:BEGIN -->\nshared index\n<!-- AGENT0:END -->\n' "$title" > "$path"
}

make_project() {
  local dir="$1"
  mkdir -p "$dir/.agent0/tools/lib"
  cp "$TOOL" "$dir/.agent0/tools/project-core-sync.sh"
  cp "$LIB" "$dir/.agent0/tools/lib/managed-block.sh"
  chmod +x "$dir/.agent0/tools/project-core-sync.sh"
  make_entrypoint "$dir/CLAUDE.md" "Claude"
  make_entrypoint "$dir/AGENTS.md" "Agents"
  printf '# Consumer Core\n\nSENTINEL v1\n' > "$dir/.agent0/project-core.md"
}

printf 'Scenario 1: local apply creates mirrors without Agent0 path\n'
p1="$TMPDIR/p1"
make_project "$p1"
set +e
out="$(env -u AGENT0_HARNESS_PATH bash "$p1/.agent0/tools/project-core-sync.sh" --check --root "$p1" 2>&1)"; rc=$?
set -e
[ "$rc" -eq 1 ] || fail "check should report missing mirror drift" "$out"
printf '%s' "$out" | grep -q 'region would be created' || fail "check did not report create drift" "$out"
out="$(env -u AGENT0_HARNESS_PATH bash "$p1/.agent0/tools/project-core-sync.sh" --apply --root "$p1" 2>&1)" || fail "apply failed without Agent0 path" "$out"
grep -qF '<!-- AGENT0:PROJECT:BEGIN -->' "$p1/CLAUDE.md" || fail "CLAUDE.md missing PROJECT marker"
grep -qF '<!-- AGENT0:PROJECT:BEGIN -->' "$p1/AGENTS.md" || fail "AGENTS.md missing PROJECT marker"
grep -q 'SENTINEL v1' "$p1/CLAUDE.md" || fail "CLAUDE.md missing rendered source"
grep -q 'SENTINEL v1' "$p1/AGENTS.md" || fail "AGENTS.md missing rendered source"
ok "local renderer creates both entrypoint mirrors"

printf 'Scenario 2: source edits re-render stale mirrors\n'
printf '# Consumer Core\n\nSENTINEL v2\n' > "$p1/.agent0/project-core.md"
out="$(bash "$p1/.agent0/tools/project-core-sync.sh" --apply --root "$p1" 2>&1)" || fail "apply after source edit failed" "$out"
grep -q 'SENTINEL v2' "$p1/CLAUDE.md" || fail "CLAUDE.md not re-rendered from source"
grep -q 'SENTINEL v2' "$p1/AGENTS.md" || fail "AGENTS.md not re-rendered from source"
ok "source edit re-renders both mirrors"

printf 'Scenario 3: hand-edited derived region loses to source\n'
sed -i 's/SENTINEL v2/HAND EDITED MIRROR/' "$p1/AGENTS.md"
out="$(bash "$p1/.agent0/tools/project-core-sync.sh" --apply --root "$p1" 2>&1)" || fail "apply after hand edit failed" "$out"
grep -q 'HAND EDITED MIRROR' "$p1/AGENTS.md" && fail "derived hand edit survived re-render"
grep -q 'SENTINEL v2' "$p1/AGENTS.md" || fail "derived region was not restored from source"
ok "derived region is restored from source"

printf 'Scenario 4: missing source is a no-op\n'
p2="$TMPDIR/p2"
mkdir -p "$p2/.agent0/tools/lib"
cp "$TOOL" "$p2/.agent0/tools/project-core-sync.sh"
cp "$LIB" "$p2/.agent0/tools/lib/managed-block.sh"
chmod +x "$p2/.agent0/tools/project-core-sync.sh"
make_entrypoint "$p2/CLAUDE.md" "Claude"
make_entrypoint "$p2/AGENTS.md" "Agents"
out="$(bash "$p2/.agent0/tools/project-core-sync.sh" --apply --root "$p2" 2>&1)" || fail "missing-source no-op failed" "$out"
[ -z "$out" ] || fail "missing-source no-op emitted output" "$out"
grep -qF '<!-- AGENT0:PROJECT:BEGIN -->' "$p2/CLAUDE.md" && fail "missing source created PROJECT marker"
ok "missing source no-ops"

printf 'Scenario 5: edit hooks invoke the local renderer\n'
jq -e '.hooks.PostToolUse[] | select(.matcher == "Edit|Write|MultiEdit") | .hooks[]?.command | select(contains("project-core-sync.sh"))' \
  "$AGENT0_ROOT/.claude/settings.json" >/dev/null || fail "Claude PostToolUse hook missing project-core renderer"
jq -e '.hooks.PostToolUse[] | select(.matcher == "^apply_patch$") | .hooks[]?.command | select(contains("project-core-sync.sh"))' \
  "$AGENT0_ROOT/.codex/hooks.json" >/dev/null || fail "Codex PostToolUse hook missing project-core renderer"
ok "Claude and Codex edit hooks include project-core renderer"

printf 'PASS: project-core-sync\n'
