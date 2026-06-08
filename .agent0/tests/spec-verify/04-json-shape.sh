#!/usr/bin/env bash
# Scenario: --json emits a single object with the documented keys, and the exit
# code is still correct. Skips the shape assertions if jq is absent but still
# checks the exit code (acceptance: "with jq absent the tool still exits with
# the correct code").
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/spec-verify.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
spec="$tmp/docs/specs/904-json"; mkdir -p "$spec"
printf '# 904 — json\n**Status:** draft\n' > "$spec/spec.md"
printf '**Verify:** `true`\n' > "$spec/tasks.md"

out="$(cd "$tmp" && bash "$TOOL" "$spec" --json 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: expected exit 0, got $rc"; exit 1; }

if command -v jq >/dev/null 2>&1; then
  echo "$out" | jq -e '.status=="pass" and .declared==true and .passed==1 and .failed==0 and (.commands|length)==1 and .commands[0].command=="true" and .commands[0].result=="pass" and .spec=="904-json"' >/dev/null \
    || { echo "FAIL: json shape unexpected — $out"; exit 1; }
fi

bin="$tmp/bin-no-jq"; mkdir -p "$bin"
for name in bash git dirname grep sed date; do
  ln -s "$(command -v "$name")" "$bin/$name"
done

out_nojq="$(cd "$tmp" && PATH="$bin" bash "$TOOL" "$spec" --json 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: --json without jq should preserve exit 0, got $rc — $out_nojq"; exit 1; }
case "$out_nojq" in
  '{"status":"pass","spec":"904-json","commands":'*'"declared":true}') : ;;
  *) echo "FAIL: --json without jq must still print one JSON object — $out_nojq"; exit 1 ;;
esac

none="$tmp/docs/specs/904-json-none"; mkdir -p "$none"
printf '# 904 none\n**Status:** draft\n' > "$none/spec.md"
printf '## Verification\n\n- [ ] none\n' > "$none/tasks.md"
out_nojq="$(cd "$tmp" && PATH="$bin" bash "$TOOL" "$none" --json 2>/dev/null)"; rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL: --json without jq should preserve exit 2 for none declared, got $rc — $out_nojq"; exit 1; }
case "$out_nojq" in
  '{"status":"no-verify-declared","spec":"904-json-none","commands":[],'*'"declared":false}') : ;;
  *) echo "FAIL: no-verify --json without jq must print JSON — $out_nojq"; exit 1 ;;
esac
echo "ok"
