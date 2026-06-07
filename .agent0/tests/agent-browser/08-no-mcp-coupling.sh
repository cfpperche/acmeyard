#!/usr/bin/env bash
# anti-regression: first-party browser work must not route through MCP tokens.
source "$(dirname "$0")/_lib.sh"
echo "08-no-mcp-coupling"

PATTERN='mcp__playwright__|mcp__chrome-devtools__|fallback:no-binary|fallback:no-chrome|fallback:override|serve-hifi'
MATCHES="$(grep -rIn --exclude='*.example' --exclude='08-no-mcp-coupling.sh' -E "$PATTERN" \
  "$AGENT0_ROOT/.agent0/tools" \
  "$AGENT0_ROOT/.agent0/hooks" \
  "$AGENT0_ROOT/.agent0/context/rules" \
  "$AGENT0_ROOT/.claude/skills" \
  "$AGENT0_ROOT/.agent0/tests" 2>/dev/null || true)"
COUNT="$(printf '%s\n' "$MATCHES" | sed '/^$/d' | wc -l | tr -d ' ')"

assert_eq "$COUNT" "0" "no first-party MCP browser coupling tokens"
if [ "$COUNT" != "0" ]; then
  printf '%s\n' "$MATCHES" | sed 's/^/    /'
fi

finish
