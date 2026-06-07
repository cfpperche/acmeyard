#!/usr/bin/env bash
# .agent0/tests/diagram/_lib.sh — shared harness for /diagram scenarios (spec 162).
# Fake mmdc + controllable chrome presence injected via env, fully offline.

set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/diagram.sh"

WORK="$(mktemp -d -t diagram-test-XXXXXX)"; BIN="$WORK/bin"
mkdir -p "$BIN" "$WORK/out" "$WORK/altout"
trap 'rm -rf "$WORK"' EXIT

# fake mmdc: parse -i/-o, write a stub render to -o (extension-agnostic). Echoes
# the puppeteer config path it was given so config-reuse can be asserted.
cat > "$BIN/fake-mmdc" <<'STUB'
#!/usr/bin/env bash
inp=""; out=""; pcfg=""
while [ $# -gt 0 ]; do case "$1" in
  -i) shift; inp="$1";; -o) shift; out="$1";;
  --puppeteerConfigFile) shift; pcfg="$1";; -t) shift;;
esac; shift; done
[ -n "$out" ] && printf '<svg>fake-render of %s</svg>' "$(basename "$inp")" > "$out"
echo "fake-mmdc rendered $inp -> $out (cfg=$pcfg)"
exit 0
STUB
chmod +x "$BIN"/*

export DIAGRAM_MMDC="$BIN/fake-mmdc"
export DIAGRAM_CHROME_BIN="$BIN/fake-chrome"   # non-empty = chrome "present"
export DIAGRAM_OUT_DEFAULT="$WORK/out"
export DIAGRAM_MANIFEST="$WORK/m.jsonl"

PASS=0; FAIL=0
assert_contains(){ if printf '%s' "$1" | grep -qF -- "$2"; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3"; printf '      want: %s\n      in: %s\n' "$2" "$1" | head -c 400; echo; fi; }
assert_not_contains(){ if printf '%s' "$1" | grep -qF -- "$2"; then FAIL=$((FAIL+1)); echo "  ✗ $3 (found: $2)"; else PASS=$((PASS+1)); echo "  ✓ $3"; fi; }
assert_eq(){ if [ "$1" = "$2" ]; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3 (expected $2, got $1)"; fi; }
finish(){ echo "  -- $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]; }
ls_one(){ ls "$1" 2>/dev/null | head -1; }
