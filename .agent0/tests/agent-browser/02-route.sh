#!/usr/bin/env bash
# route: primary when agent-browser is usable; otherwise unavailable:<reason>.
source "$(dirname "$0")/_lib.sh"
echo "02-route"

FAKE="$(fake_bin)"

assert_eq "$(AGENT0_BROWSER_BIN="$FAKE" bash "$TOOL" route)" "primary" "binary present ⇒ primary"
assert_eq "$(AGENT0_BROWSER_BIN="$FAKE" AGENT0_BROWSER=mcp bash "$TOOL" route)" "unavailable:mcp-removed" "explicit MCP override ⇒ unsupported route"
assert_eq "$(AGENT0_BROWSER_BIN="/nonexistent/agent-browser" bash "$TOOL" route)" "unavailable:no-binary" "no binary ⇒ unavailable"
assert_eq "$(AGENT0_BROWSER_BIN="$FAKE" AGENT0_BROWSER_NO_CHROME=1 bash "$TOOL" route)" "unavailable:no-chrome" "no chrome ⇒ unavailable"
# reserved capability-gap slot does not misfire for an unknown task
assert_eq "$(AGENT0_BROWSER_BIN="$FAKE" bash "$TOOL" route some-unknown-task)" "primary" "no declared gap ⇒ still primary"

finish
