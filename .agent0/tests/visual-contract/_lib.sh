#!/usr/bin/env bash
# .agent0/tests/visual-contract/_lib.sh — shared harness for spec-155 scenarios.
#
# Most cases are LOGIC tests: offline & deterministic. Detection + advisory +
# delegation surfacing need no browser. Contract-tier orchestration uses the
# FAKE agent-browser stub (AGENT0_BROWSER_BIN) like the spec-152 suite; a live
# dogfood guards with `need_live` and SKIPs-with-pass when no browser is present.
set -uo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
DETECT="$AGENT0_ROOT/.agent0/tools/ui-impact-detect.sh"
BROWSER_TOOL="$AGENT0_ROOT/.agent0/tools/agent-browser.sh"
VALIDATOR="$AGENT0_ROOT/.agent0/validators/run.sh"
DELEG_VERIFY="$AGENT0_ROOT/.agent0/hooks/delegation-verify.sh"
FIXTURES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fixtures"

WORK="$(mktemp -d -t vc-test-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
# Top-level (NOT inside fake_bin, which runs in a $(...) subshell where an export
# would be lost): the fake agent-browser stub reads scripted JSON from here.
export VC_FAKE_STATE="$WORK"

PASS=0; FAIL=0
assert_eq() { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3 (got '$1' want '$2')"; fi; }
assert_contains() { if printf '%s' "$1" | grep -qF -- "$2"; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3 (missing '$2' in '$1')"; fi; }
assert_not_contains() { if printf '%s' "$1" | grep -qF -- "$2"; then FAIL=$((FAIL+1)); echo "  ✗ $3 (unexpected '$2' in '$1')"; else PASS=$((PASS+1)); echo "  ✓ $3"; fi; }
assert_rc() { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3 (rc got $1 want $2)"; fi; }
finish() { echo "  [$PASS pass / $FAIL fail]"; [ "$FAIL" -eq 0 ]; }

# Build a fake agent-browser stub. Records calls to $AB_CALLS_LOG. Optional
# behavior files under $WORK let a test script the binary's JSON replies:
#   $WORK/snapshot.json  → emitted for `snapshot --json`
#   $WORK/console.json   → emitted for `console --json`
# Default replies are benign (empty refs / no errors).
fake_bin() {
  local b="$WORK/bin"; mkdir -p "$b"
  cat > "$b/agent-browser" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "${AB_CALLS_LOG:-/dev/null}"
W="${VC_FAKE_STATE:-/tmp}"
case "$1" in
  --version) echo "agent-browser 0.27.1"; exit 0 ;;
esac
# locate the verb (skip leading --flags/values like --state f)
verb=""; for a in "$@"; do case "$a" in --*) ;; *) verb="$a"; break;; esac; done
case "$verb" in
  snapshot) [ -f "$W/snapshot.json" ] && cat "$W/snapshot.json" || echo '{"data":{"refs":{}}}' ;;
  console)  [ -f "$W/console.json" ]  && cat "$W/console.json"  || echo '{"data":{"messages":[]}}' ;;
  vitals)   echo '{"data":{}}' ;;
  screenshot|screen)
    # write to the path argument verify-contract passes (`screenshot <outdir/screen.png>`)
    for a in "$@"; do case "$a" in --*|screenshot|screen) ;; *) printf 'PNG' > "$a" 2>/dev/null; break;; esac; done ;;
  close) : ;;
  *) : ;;
esac
exit 0
STUB
  chmod +x "$b/agent-browser"
  echo "$b/agent-browser"
}

need_live() {
  command -v agent-browser >/dev/null 2>&1 || { echo "  ⓘ SKIP (no agent-browser binary) — logic still covered"; return 1; }
  command -v node >/dev/null 2>&1 || { echo "  ⓘ SKIP (no node)"; return 1; }
  local chrome=""
  for c in google-chrome google-chrome-stable chromium chromium-browser; do command -v "$c" >/dev/null 2>&1 && chrome="$(command -v "$c")" && break; done
  [ -n "$chrome" ] || { echo "  ⓘ SKIP (no Chrome)"; return 1; }
  export AGENT_BROWSER_EXECUTABLE_PATH="$chrome"
  return 0
}
