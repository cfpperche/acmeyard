#!/usr/bin/env bash
# caps: detects binary + chrome + pinned version; tri-state JSON shape.
source "$(dirname "$0")/_lib.sh"
echo "01-caps"

FAKE="$(fake_bin)"

# binary present (fake stub reports the pinned version)
OUT="$(AGENT0_BROWSER_BIN="$FAKE" bash "$TOOL" caps --json)"
assert_contains "$OUT" '"binary":"yes"' "binary detected"
assert_contains "$OUT" '"version":"0.27.1"' "version parsed from --version"
assert_contains "$OUT" '"version_state":"pinned"' "matches pinned version"

# binary absent
OUT="$(AGENT0_BROWSER_BIN="/nonexistent/agent-browser" bash "$TOOL" caps --json)"
assert_contains "$OUT" '"binary":"no"' "absent binary reported"

finish
