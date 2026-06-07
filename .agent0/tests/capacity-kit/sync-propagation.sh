#!/usr/bin/env bash
# Spec 163: prove the capacity kit propagates to consumers.
#
# The 6 capacity tools now `source .agent0/tools/lib/capacity.sh`. If the lib does
# NOT sync, every consumer's tools break at source-time. The .agent0/tools|*.sh
# glob is maxdepth-1 and does NOT recurse into lib/; this test guards the
# .agent0/tools/lib|*.sh glob added in spec 163 so a lib/*.sh file reaches a
# synced consumer. (Mirrors harness-sync test 02's SRC/CONSUMER pattern.)

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/sync-harness.sh"

TMP="$(mktemp -d -t cap-kit-sync-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
SRC="$TMP/agent0"; CONSUMER="$TMP/consumer"
mkdir -p "$SRC/.agent0/tools/lib" "$SRC/.claude" "$CONSUMER/.claude"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"

# minimal SRC harness with a lib/ file (the thing that must propagate)
printf '#!/usr/bin/env bash\ncap_have() { command -v "$1" >/dev/null 2>&1; }\n' > "$SRC/.agent0/tools/lib/capacity.sh"
printf '#!/usr/bin/env bash\n# paid sub-kit (future)\n' > "$SRC/.agent0/tools/lib/paid-media.sh"
chmod +x "$SRC/.agent0/tools/lib/"*.sh
printf '{"hooks":{}}\n' > "$CONSUMER/.claude/settings.json"
printf '# CLAUDE consumer\n\n## Compact Instructions\n' > "$CONSUMER/CLAUDE.md"

PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "  ✓ $1"; }
no(){ FAIL=$((FAIL+1)); echo "  ✗ $1"; }

out="$(bash "$TOOL" --apply --agent0-path="$SRC" "$CONSUMER" 2>&1)" || true

[ -f "$CONSUMER/.agent0/tools/lib/capacity.sh" ] && ok "lib/capacity.sh propagated to consumer" || { no "lib/capacity.sh NOT propagated"; printf '%s\n' "$out" | tail -5; }
[ -f "$CONSUMER/.agent0/tools/lib/paid-media.sh" ] && ok "lib/paid-media.sh (paid sub-kit, spec 164) propagated" || no "lib/paid-media.sh NOT propagated"
[ -x "$CONSUMER/.agent0/tools/lib/capacity.sh" ] && ok "executable mode preserved on the lib" || no "lib not executable after sync"
# guard: the glob is actually registered in sync-harness
grep -q '\.agent0/tools/lib|\*\.sh' "$TOOL" && ok "tools/lib glob registered in sync-harness" || no "tools/lib glob MISSING from sync-harness"

echo "  -- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "=== sync-propagation: PASS ===" || { echo "=== sync-propagation: FAIL ==="; exit 1; }
