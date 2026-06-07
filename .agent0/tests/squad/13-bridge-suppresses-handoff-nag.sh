#!/usr/bin/env bash
# 154 fix #2 — a bounded bridge subprocess (codex-exec / claude-exec) must suppress
# the session-handoff Stop-hook nag, so a /squad peer turn is never blocked into
# rewriting the orchestrator-owned .agent0/HANDOFF.md. The bridges set
# CLAUDE_SKIP_SESSION_HOOKS=1; session-stop.sh honors it (its existing escape hatch).
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
CODEX="$AGENT0_ROOT/.agent0/skills/codex-exec/scripts/codex-exec.sh"
CLAUDE="$AGENT0_ROOT/.agent0/skills/claude-exec/scripts/claude-exec.sh"
STOP="$AGENT0_ROOT/.agent0/hooks/session-stop.sh"
fail=0

# (a) both bridges export the suppression env before invoking the child
grep -qE 'export[[:space:]]+CLAUDE_SKIP_SESSION_HOOKS=1' "$CODEX" \
  && echo "  ✓ codex-exec exports CLAUDE_SKIP_SESSION_HOOKS=1" || { echo "  ✗ codex-exec missing the export"; fail=1; }
grep -qE 'export[[:space:]]+CLAUDE_SKIP_SESSION_HOOKS=1' "$CLAUDE" \
  && echo "  ✓ claude-exec exports CLAUDE_SKIP_SESSION_HOOKS=1" || { echo "  ✗ claude-exec missing the export"; fail=1; }

# (b) behavioral: session-stop.sh honors the skip — exits 0, emits no `block`
if [ -f "$STOP" ]; then
  out="$(CLAUDE_SKIP_SESSION_HOOKS=1 bash "$STOP" </dev/null 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -q '"decision":"block"'; then
    echo "  ✓ session-stop.sh skips (rc 0, no block) under CLAUDE_SKIP_SESSION_HOOKS=1"
  else
    echo "  ✗ session-stop.sh did not honor the skip (rc=$rc, out=$out)"; fail=1
  fi
else
  echo "  ✗ session-stop.sh not found at $STOP"; fail=1
fi

[ "$fail" -eq 0 ] && echo PASS || { echo "FAIL: bridge handoff-nag suppression"; exit 1; }
