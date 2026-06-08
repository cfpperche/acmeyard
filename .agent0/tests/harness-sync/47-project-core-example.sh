#!/usr/bin/env bash
# Scenario: project-core example ships, but the real project-core source stays consumer-owned.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-173-47-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
CONSUMER="$TMPDIR/consumer"
CONSUMER2="$TMPDIR/consumer2"
UPSTREAM_SENTINEL="UPSTREAM-AGENT0-PROJECT-CORE-47"
CONSUMER_SENTINEL="CONSUMER-PROJECT-CORE-47"

fail() {
  printf 'FAIL (47): %s\n' "$1"
  [ -n "${2:-}" ] && printf '%s\n' "$2"
  exit 1
}

make_entrypoints() {
  local root="$1" title="$2"
  mkdir -p "$root/.agent0" "$root/.claude"
  cat > "$root/CLAUDE.md" <<EOF
# $title

<!-- AGENT0:PROJECT:BEGIN -->
# Upstream Core

$UPSTREAM_SENTINEL must not leak.
<!-- AGENT0:PROJECT:END -->

<!-- AGENT0:BEGIN -->
shared index
<!-- AGENT0:END -->
EOF

  cat > "$root/AGENTS.md" <<EOF
# $title Codex

<!-- AGENT0:PROJECT:BEGIN -->
# Upstream Core

$UPSTREAM_SENTINEL must not leak.
<!-- AGENT0:PROJECT:END -->

<!-- AGENT0:BEGIN -->
shared index
<!-- AGENT0:END -->
EOF

  printf '{"hooks":{}}\n' > "$root/.claude/settings.json"
}

make_entrypoints "$SRC" "Agent0"
printf '# Upstream real core\n\n%s\n' "$UPSTREAM_SENTINEL" > "$SRC/.agent0/project-core.md"
printf '# Example core\n\n<!-- AGENT0:PROJECT-CORE-TEMPLATE: test-v1 -->\n\n## Language & Locale\n\n- Human communication: <replace me>.\n' > "$SRC/.agent0/project-core.md.example"

# Phase 1: consumer without a real source gets the example, but no active PROJECT region.
mkdir -p "$CONSUMER/.agent0" "$CONSUMER/.claude"
out="$(bash "$TOOL" --apply --agent0-path="$SRC" "$CONSUMER" 2>&1)" || fail "apply without consumer source failed" "$out"

[ -f "$CONSUMER/.agent0/project-core.md.example" ] || fail "example was not copied" "$out"
[ ! -f "$CONSUMER/.agent0/project-core.md" ] || fail "real project-core source was wrongly created" "$out"
printf '%s' "$out" | grep -q 'bootstrap-advisory: project-core source missing' || fail "pending source did not emit bootstrap advisory" "$out"
grep -q "$UPSTREAM_SENTINEL" "$CONSUMER/AGENTS.md" && fail "upstream PROJECT region leaked into AGENTS.md" "$out"
grep -q "$UPSTREAM_SENTINEL" "$CONSUMER/CLAUDE.md" && fail "upstream PROJECT region leaked into CLAUDE.md" "$out"
grep -qF '<!-- AGENT0:PROJECT:BEGIN -->' "$CONSUMER/AGENTS.md" && fail "AGENTS.md got PROJECT markers without consumer source" "$out"
echo "  ok: phase1 example copied; real source absent; upstream project core stripped; bootstrap advisory emitted"

# Phase 2: consumer-owned source remains authoritative and mirrors into both entrypoints.
mkdir -p "$CONSUMER2/.agent0" "$CONSUMER2/.claude"
printf '# Consumer core\n\n<!-- AGENT0:PROJECT-CORE-TEMPLATE: test-v1 -->\n\n%s\n' "$CONSUMER_SENTINEL" > "$CONSUMER2/.agent0/project-core.md"
src_sha_before="$(sha256sum "$CONSUMER2/.agent0/project-core.md" | awk '{print $1}')"

out="$(bash "$TOOL" --apply --agent0-path="$SRC" "$CONSUMER2" 2>&1)" || fail "apply with consumer source failed" "$out"

[ -f "$CONSUMER2/.agent0/project-core.md.example" ] || fail "example was not copied for sourced consumer" "$out"
[ "$(sha256sum "$CONSUMER2/.agent0/project-core.md" | awk '{print $1}')" = "$src_sha_before" ] || fail "consumer source was modified" "$out"
grep -q "$CONSUMER_SENTINEL" "$CONSUMER2/AGENTS.md" || fail "consumer source not mirrored into AGENTS.md" "$out"
grep -q "$CONSUMER_SENTINEL" "$CONSUMER2/CLAUDE.md" || fail "consumer source not mirrored into CLAUDE.md" "$out"
grep -q "$UPSTREAM_SENTINEL" "$CONSUMER2/AGENTS.md" && fail "upstream PROJECT region leaked into sourced consumer AGENTS.md" "$out"
grep -q "$UPSTREAM_SENTINEL" "$CONSUMER2/CLAUDE.md" && fail "upstream PROJECT region leaked into sourced consumer CLAUDE.md" "$out"
printf '%s' "$out" | grep -q 'bootstrap-advisory:' && fail "configured source still emitted bootstrap advisory" "$out"
echo "  ok: phase2 consumer-owned source mirrors; upstream project core does not leak; bootstrap advisory silent"

echo "PASS: 47-project-core-example"
