#!/usr/bin/env bash
# Spec 058 — Scenario: paired markers + fork edited body INSIDE region → refuse + report.
# With --force: region replaced wholesale, OVERWRITTEN counter increments.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-058-19-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude" "$FORK/.claude"

cat > "$SRC/CLAUDE.md" <<'EOF'
# Agent0

## Overview

placeholder.

<!-- AGENT0:BEGIN -->

## TDD

canonical TDD body.

<!-- AGENT0:END -->
EOF

# Fork has paired markers but edited the ## TDD body INSIDE the region.
cat > "$FORK/CLAUDE.md" <<'EOF'
# MyFork

## Overview

fork overview.

<!-- AGENT0:BEGIN -->

## TDD

FORK-EDITED TDD body — operator changed this in-place.

<!-- AGENT0:END -->
EOF

printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"

# --- Phase 1: --apply (no --force) → refuse + diverged-region.md written ---
err1="$(mktemp -t spec-058-19-err1-XXXXXX)"
exit1=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>"$err1" || exit1=$?
if [ "$exit1" -eq 0 ]; then
  printf 'FAIL(1): region divergence should refuse without --force (exit non-zero)\n'
  exit 1
fi
if ! grep -q 'managed region diverged' "$err1"; then
  printf 'FAIL(1): stderr missing "managed region diverged"\n'
  cat "$err1"
  exit 1
fi
if [ ! -f "$FORK/.claude/CLAUDE.md.diverged-region.md" ]; then
  printf 'FAIL(1): diverged-region.md not written\n'
  exit 1
fi

# Fork's CLAUDE.md must be unchanged (fork-edit preserved)
if ! grep -q 'FORK-EDITED TDD body' "$FORK/CLAUDE.md"; then
  printf 'FAIL(1): fork edit overwritten despite refuse\n'
  exit 1
fi

# --- Phase 2: --apply --force → region replaced wholesale ---
err2="$(mktemp -t spec-058-19-err2-XXXXXX)"
exit2=0
bash "$TOOL" --apply --force --agent0-path="$SRC" "$FORK" >/dev/null 2>"$err2" || exit2=$?
if [ "$exit2" -ne 0 ]; then
  printf 'FAIL(2): --force expected exit 0, got %d\n' "$exit2"
  cat "$err2"
  exit 1
fi
if ! grep -q 'overwritten CLAUDE.md (region replaced under --force)' "$err2"; then
  printf 'FAIL(2): stderr missing overwritten message\n'
  cat "$err2"
  exit 1
fi
# Fork-edit is now gone
if grep -q 'FORK-EDITED TDD body' "$FORK/CLAUDE.md"; then
  printf 'FAIL(2): fork edit should be overwritten under --force\n'
  exit 1
fi
# Canonical body present
if ! grep -q 'canonical TDD body' "$FORK/CLAUDE.md"; then
  printf 'FAIL(2): canonical body not propagated under --force\n'
  exit 1
fi
# Project section preserved
if ! grep -q 'fork overview' "$FORK/CLAUDE.md"; then
  printf 'FAIL(2): fork project section (Overview body) lost\n'
  exit 1
fi

echo "PASS: 19-claude-md-region-divergence-refuse"
