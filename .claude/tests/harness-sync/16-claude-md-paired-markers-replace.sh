#!/usr/bin/env bash
# Spec 058 — Scenario: paired markers + Agent0 has new section in region → replace.
# Section divergence check returns no diverged shared sections (heading-only diff).
# Project sections above BEGIN and below END preserved verbatim.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-058-16-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude" "$FORK/.claude"

# SRC region: A, B, C (3 capacities). FORK region: A, B (2 capacities). New: C.
cat > "$SRC/CLAUDE.md" <<'EOF'
# Agent0

## Overview

agent0 overview.

<!-- AGENT0:BEGIN -->

## A

body of A.

## B

body of B.

## C

body of C.

<!-- AGENT0:END -->
EOF

cat > "$FORK/CLAUDE.md" <<'EOF'
# MyFork

## Overview

my fork overview.

## ProjectStuff

fork-authored.

<!-- AGENT0:BEGIN -->

## A

body of A.

## B

body of B.

<!-- AGENT0:END -->
EOF

printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"

actual_exit=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>&1 || actual_exit=$?
if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: --apply expected exit 0, got %d\n' "$actual_exit"
  exit 1
fi

# Fork's region must now contain section C
if ! grep -q '^## C$' "$FORK/CLAUDE.md"; then
  printf 'FAIL: section C not propagated into fork region\n'
  cat "$FORK/CLAUDE.md"
  exit 1
fi

# Project-narrative section ProjectStuff preserved (above BEGIN)
if ! grep -q '^## ProjectStuff$' "$FORK/CLAUDE.md"; then
  printf 'FAIL: project section ## ProjectStuff lost\n'
  exit 1
fi

# Fork's Overview body preserved verbatim
if ! grep -q '^my fork overview\.$' "$FORK/CLAUDE.md"; then
  printf 'FAIL: fork Overview body overwritten\n'
  exit 1
fi

# Verify ProjectStuff is ABOVE BEGIN marker
begin_line="$(grep -nE '^<!-- AGENT0:BEGIN -->$' "$FORK/CLAUDE.md" | head -1 | cut -d: -f1)"
projectstuff_line="$(grep -n '^## ProjectStuff$' "$FORK/CLAUDE.md" | head -1 | cut -d: -f1)"
if [ "$projectstuff_line" -ge "$begin_line" ]; then
  printf 'FAIL: ## ProjectStuff (line %s) should be above BEGIN (line %s)\n' "$projectstuff_line" "$begin_line"
  exit 1
fi

# Verify A,B,C all inside region (between markers)
end_line="$(grep -nE '^<!-- AGENT0:END -->$' "$FORK/CLAUDE.md" | head -1 | cut -d: -f1)"
for sec in A B C; do
  sec_line="$(grep -n "^## $sec\$" "$FORK/CLAUDE.md" | head -1 | cut -d: -f1)"
  if [ "$sec_line" -le "$begin_line" ] || [ "$sec_line" -ge "$end_line" ]; then
    printf 'FAIL: ## %s (line %s) not inside region [BEGIN=%s, END=%s]\n' "$sec" "$sec_line" "$begin_line" "$end_line"
    exit 1
  fi
done

echo "PASS: 16-claude-md-paired-markers-replace"
