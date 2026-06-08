#!/usr/bin/env bash
# Scenario: spec dirs work as absolute, relative-to-cwd, and relative-to-repo-root
# paths; usage errors return 64.
set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/spec-verify.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp"
spec="$tmp/docs/specs/912-paths"; mkdir -p "$spec" "$tmp/sub" "$tmp/docs"
printf '# 912 — paths\n**Status:** draft\n' > "$spec/spec.md"
printf '**Verify:** `test -f root-marker`\n' > "$spec/tasks.md"
printf 'root\n' > "$tmp/root-marker"

( cd "$tmp/sub" && bash "$TOOL" docs/specs/912-paths --quiet )
rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: root-relative path from cwd should exit 0, got $rc"; exit 1; }

( cd "$tmp/docs" && bash "$TOOL" specs/912-paths --quiet )
rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: cwd-relative path should exit 0, got $rc"; exit 1; }

( cd "$tmp/sub" && bash "$TOOL" "$spec" --quiet )
rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: absolute path should exit 0, got $rc"; exit 1; }

bash "$TOOL" --bogus >/dev/null 2>&1
rc=$?
[ "$rc" -eq 64 ] || { echo "FAIL: unknown flag should exit 64, got $rc"; exit 1; }
echo "ok"
