#!/usr/bin/env bash
# Spec 058 — Canonical motivating case: fork's region carries ORPHAN section that
# Agent0 source no longer has. After managed-block sync, orphan removed wholesale.
# Mirrors the empirical acmeyard scenario (## Prototype skill renamed away in spec 048).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-058-22-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude" "$FORK/.claude"

# Source region: A, B, C (3 sections; D was removed in a hypothetical prior rename).
cat > "$SRC/CLAUDE.md" <<'EOF'
# Agent0

## Overview

placeholder.

<!-- AGENT0:BEGIN -->

## A

body of A.

## B

body of B.

## C

body of C.

<!-- AGENT0:END -->
EOF

# Fork's region carries the orphan D between B and C (legacy state from old sync).
cat > "$FORK/CLAUDE.md" <<'EOF'
# MyFork

## Overview

my overview.

<!-- AGENT0:BEGIN -->

## A

body of A.

## B

body of B.

## D-ORPHAN

orphan body — Agent0 already removed this title.

## C

body of C.

<!-- AGENT0:END -->
EOF

printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"

err_log="$(mktemp -t spec-058-22-err-XXXXXX)"
actual_exit=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>"$err_log" || actual_exit=$?
if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: --apply expected exit 0, got %d\n' "$actual_exit"
  cat "$err_log"
  exit 1
fi

# Orphan must be gone
if grep -q '^## D-ORPHAN$' "$FORK/CLAUDE.md"; then
  printf 'FAIL: orphan ## D-ORPHAN still present after merge\n'
  cat "$FORK/CLAUDE.md"
  exit 1
fi

# Canonical sections A, B, C must all be present
for sec in A B C; do
  if ! grep -q "^## $sec\$" "$FORK/CLAUDE.md"; then
    printf 'FAIL: canonical section ## %s missing after merge\n' "$sec"
    exit 1
  fi
done

# Fork's project section preserved
if ! grep -q 'my overview' "$FORK/CLAUDE.md"; then
  printf 'FAIL: fork project section body lost\n'
  exit 1
fi

# Markers preserved exactly
if ! grep -q '^<!-- AGENT0:BEGIN -->$' "$FORK/CLAUDE.md"; then
  printf 'FAIL: BEGIN marker missing post-merge\n'
  exit 1
fi
if ! grep -q '^<!-- AGENT0:END -->$' "$FORK/CLAUDE.md"; then
  printf 'FAIL: END marker missing post-merge\n'
  exit 1
fi

echo "PASS: 22-claude-md-removes-orphan-section"
