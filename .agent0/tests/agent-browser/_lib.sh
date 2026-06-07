#!/usr/bin/env bash
# .agent0/tests/agent-browser/_lib.sh — shared harness for spec-152 scenarios.
#
# Two test modes:
#  - LOGIC cases run offline & deterministic via a FAKE agent-browser stub on a
#    temp PATH (set AGENT0_BROWSER_BIN to it). No real browser needed.
#  - LIVE cases (dogfood) need the REAL agent-browser + a Chrome + node; they
#    guard with `need_live` and SKIP-with-pass when the binary is absent (so a
#    consumer fork that hasn't opted in still passes the suite).
set -uo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/agent-browser.sh"
FIXTURES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fixtures"

WORK="$(mktemp -d -t ab-test-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
# audit + policy live under WORK so cases never touch the real project state
export AGENT0_PROJECT_DIR="$WORK/proj"
mkdir -p "$AGENT0_PROJECT_DIR/.agent0"

PASS=0; FAIL=0

# Build a fake agent-browser stub and echo its path. Honors --version; records
# every invocation to $WORK/ab-calls.log; exits 0 otherwise.
fake_bin() {
  local b="$WORK/bin"; mkdir -p "$b"
  cat > "$b/agent-browser" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "${AB_CALLS_LOG:-/dev/null}"
case "$1" in
  --version) echo "agent-browser 0.27.1" ;;
  close) : ;;
  *) : ;;
esac
exit 0
STUB
  chmod +x "$b/agent-browser"
  echo "$b/agent-browser"
}

# Live-mode guard: real agent-browser + chrome + node, else skip-with-pass.
need_live() {
  command -v agent-browser >/dev/null 2>&1 || { echo "  ⓘ SKIP (no agent-browser binary) — non-live logic still covered"; return 1; }
  command -v node >/dev/null 2>&1 || { echo "  ⓘ SKIP (no node)"; return 1; }
  local chrome=""
  for c in google-chrome google-chrome-stable chromium chromium-browser; do command -v "$c" >/dev/null 2>&1 && chrome="$(command -v "$c")" && break; done
  [ -n "$chrome" ] || { echo "  ⓘ SKIP (no Chrome)"; return 1; }
  export AGENT_BROWSER_EXECUTABLE_PATH="$chrome"
  return 0
}

assert_eq() { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3 (got '$1' want '$2')"; fi; }
assert_contains() { if printf '%s' "$1" | grep -qF -- "$2"; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3 (missing '$2' in '$1')"; fi; }
assert_rc() { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3 (rc got $1 want $2)"; fi; }
finish() { echo "  [$PASS pass / $FAIL fail]"; [ "$FAIL" -eq 0 ]; }
