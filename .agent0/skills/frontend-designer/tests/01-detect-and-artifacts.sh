#!/usr/bin/env bash
# Test for frontend-designer.sh deterministic subcommands (no bats; plain bash).
# Run: bash .agent0/skills/frontend-designer/tests/01-detect-and-artifacts.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
FD="$ROOT/.agent0/skills/frontend-designer/scripts/frontend-designer.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok()   { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }
assert_contains() { # <haystack> <needle> <label>
  case "$1" in *"$2"*) ok "$3";; *) bad "$3 (missing: $2)";; esac; }

echo "== caps =="
out="$(bash "$FD" caps 2>&1)"
assert_contains "$out" "rg:"            "caps reports rg"
assert_contains "$out" "jq:"            "caps reports jq"
assert_contains "$out" "agent-browser:" "caps reports agent-browser"

echo "== detect: Next + Tailwind + shadcn =="
P1="$TMP/next-app"; mkdir -p "$P1"
cat > "$P1/package.json" <<'JSON'
{ "name":"x","dependencies":{"next":"15.0.0","react":"19.0.0"},"devDependencies":{"tailwindcss":"4.0.0"} }
JSON
: > "$P1/tailwind.config.ts"
echo '{ "style":"new-york" }' > "$P1/components.json"   # shadcn marker
: > "$P1/bun.lockb"
out="$(bash "$FD" detect "$P1" 2>&1)"
assert_contains "$out" "framework: next"        "detect framework=next"
assert_contains "$out" "tailwind"               "detect design_system has tailwind"
assert_contains "$out" "shadcn"                 "detect design_system has shadcn"
assert_contains "$out" "package_manager: bun"   "detect pm=bun"
assert_contains "$out" "browser_renderable: yes" "detect next is browser-renderable"

echo "== detect: plain HTML, no design system =="
P2="$TMP/plain"; mkdir -p "$P2"; : > "$P2/index.html"
out="$(bash "$FD" detect "$P2" 2>&1)"
assert_contains "$out" "design_system: none"     "detect no design system"
assert_contains "$out" "browser_renderable: yes" "detect plain html renderable"

echo "== detect: Expo (native) =="
P3="$TMP/expo-app"; mkdir -p "$P3"
cat > "$P3/package.json" <<'JSON'
{ "name":"m","dependencies":{"expo":"52.0.0","react-native":"0.76.0"} }
JSON
out="$(bash "$FD" detect "$P3" 2>&1)"
assert_contains "$out" "framework: expo"        "detect framework=expo"

echo "== detect --json is valid json =="
out="$(bash "$FD" detect "$P1" --json 2>&1)"
echo "$out" | jq -e . >/dev/null 2>&1 && ok "detect --json valid" || bad "detect --json valid"

echo "== artifacts-dir: spec dir vs docs/design =="
P4="$TMP/proj"; mkdir -p "$P4/docs/specs/042-thing"
out="$(bash "$FD" artifacts-dir "$P4" --spec 042 --surface dashboard 2>&1)"
assert_contains "$out" "docs/specs/042-thing" "artifacts-dir resolves spec dir"
out="$(bash "$FD" artifacts-dir "$P4" --surface dashboard 2>&1)"
assert_contains "$out" "docs/design/dashboard" "artifacts-dir falls back to docs/design/<surface>"

echo "== scaffold-docs writes both docs =="
bash "$FD" scaffold-docs "$P4" --surface dashboard >/dev/null 2>&1
[ -f "$P4/docs/design/dashboard/reference-research.md" ] && ok "reference-research.md written" || bad "reference-research.md written"
[ -f "$P4/docs/design/dashboard/design-direction.md" ]  && ok "design-direction.md written"  || bad "design-direction.md written"
grep -q "dashboard" "$P4/docs/design/dashboard/design-direction.md" 2>/dev/null && ok "surface substituted" || bad "surface substituted"

echo "== verify fails closed when agent-browser unavailable =="
# Stub agent-browser that reports unavailable for route.
STUB="$TMP/ab-stub.sh"
cat > "$STUB" <<'SH'
#!/usr/bin/env bash
case "$1" in route) echo "unavailable:no-binary";; *) exit 4;; esac
SH
chmod +x "$STUB"
echo '{"required":[],"max_console_errors":0}' > "$TMP/fixture.json"
FD_AGENT_BROWSER="$STUB" bash "$FD" verify "http://localhost:3000" "$TMP/fixture.json" "$TMP/out" >/dev/null 2>&1
rc=$?
[ "$rc" -ne 0 ] && ok "verify fail-closed nonzero rc ($rc)" || bad "verify fail-closed nonzero rc"
out="$(FD_AGENT_BROWSER="$STUB" bash "$FD" verify "http://localhost:3000" "$TMP/fixture.json" "$TMP/out" 2>&1)"
assert_contains "$out" "BLOCKER" "verify prints BLOCKER (never a pass)"

echo "== verify usage error on bad args =="
bash "$FD" verify >/dev/null 2>&1; [ $? -eq 3 ] && ok "verify usage rc=3" || bad "verify usage rc=3"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
