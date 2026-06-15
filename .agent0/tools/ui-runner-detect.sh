#!/usr/bin/env bash
# .agent0/tools/ui-runner-detect.sh — spec 206, retire-visual-contract-gate.
#
# Deterministic, content-free check: does this project DECLARE a UI test runner?
# It answers one question — "is there an idiomatic UI/e2e test mechanism the
# project owns?" — so the validator can emit `ui-runner-advisory:` when a rendered
# UI surface changed but no runner exists (the harness REQUIRES a runner instead
# of shipping a substitute acceptance bundle — the retired visual contract).
#
# Stack-neutral by design (mirrors typecheck-advisory's declare-the-primitive
# shape): it never runs anything and never infers from test content; it only
# checks for declarable signals. A project on a stack we don't pattern-match
# declares its runner explicitly via `.agent0/ui-test.json`.
#
# Detection signals (any one ⇒ present):
#   1. A UI/e2e script key in any package.json (root or workspace, excluding
#      node_modules): test:e2e | e2e | test:ui | e2e:<suffix> | test:browser
#   2. A known e2e config file outside node_modules:
#      playwright.config.{ts,js,mjs,cjs} | cypress.config.{ts,js,mjs,cjs}
#      | wdio.conf.{ts,js} | nightwatch.conf.{js,ts} | playwright.config (bare)
#   3. A stack-neutral override: `.agent0/ui-test.json` with a non-empty
#      "command" string (escape hatch for Python/Rust/etc.).
#
# Options:
#   --root <dir>   project root (default: git toplevel, else PWD)
#   --json         emit JSON instead of text
# Output (text):  `runner: present|absent` and `signal: <what>` (none if absent)
# Output (json):  { "runner": "present"|"absent", "signal": "<what>"|null }
# Exit: 0 = runner present, 1 = runner absent, 2 = usage error.
set -uo pipefail

root=""; json=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) root="${2:-}"; shift 2 || { echo "ui-runner-detect: --root needs a value" >&2; exit 2; } ;;
    --json) json=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "ui-runner-detect: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$root" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$root" ] || root="$PWD"
fi
[ -d "$root" ] || { echo "ui-runner-detect: root not a directory: $root" >&2; exit 2; }

signal=""

# --- Signal 3 (cheapest, most explicit): stack-neutral override. ---
override="$root/.agent0/ui-test.json"
if [ -z "$signal" ] && [ -f "$override" ]; then
  cmd=""
  if command -v jq >/dev/null 2>&1; then
    cmd="$(jq -r '.command // ""' "$override" 2>/dev/null || true)"
  else
    cmd="$(grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]+"' "$override" 2>/dev/null | head -n1 || true)"
  fi
  [ -n "$cmd" ] && signal="override:.agent0/ui-test.json"
fi

# --- Signal 2: a known e2e config file (exclude node_modules). ---
if [ -z "$signal" ]; then
  cfg="$(
    find "$root" \
      \( -name node_modules -o -name .git -o -name dist -o -name build \
         -o -name vendor -o -name .turbo -o -name .cache -o -name 'extracted-*' \) -prune -o \
      -type f \( \
        -name 'playwright.config.ts' -o -name 'playwright.config.js' -o \
        -name 'playwright.config.mjs' -o -name 'playwright.config.cjs' -o \
        -name 'playwright.config' -o \
        -name 'cypress.config.ts' -o -name 'cypress.config.js' -o \
        -name 'cypress.config.mjs' -o -name 'cypress.config.cjs' -o \
        -name 'wdio.conf.ts' -o -name 'wdio.conf.js' -o \
        -name 'nightwatch.conf.js' -o -name 'nightwatch.conf.ts' \
      \) -print 2>/dev/null | head -n1 || true
  )"
  [ -n "$cfg" ] && signal="config:${cfg#"$root"/}"
fi

# --- Signal 1: a UI/e2e script key in any package.json (exclude node_modules). ---
if [ -z "$signal" ]; then
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    # Match a SCRIPT KEY shape: "<key>": "..."; restrict keys to the UI/e2e set.
    if grep -qE '"(test:e2e|e2e|test:ui|test:browser|e2e:[a-z0-9-]+)"[[:space:]]*:' "$pkg" 2>/dev/null; then
      signal="script:${pkg#"$root"/}"
      break
    fi
  done <<EOF
$(find "$root" \( -name node_modules -o -name .git -o -name vendor -o -name .turbo -o -name .cache -o -name 'extracted-*' \) -prune -o -type f -name 'package.json' -print 2>/dev/null)
EOF
fi

if [ -n "$signal" ]; then runner="present"; else runner="absent"; fi

if [ "$json" -eq 1 ]; then
  if [ -n "$signal" ]; then
    printf '{"runner":"%s","signal":"%s"}\n' "$runner" "$signal"
  else
    printf '{"runner":"%s","signal":null}\n' "$runner"
  fi
else
  printf 'runner: %s\n' "$runner"
  printf 'signal: %s\n' "${signal:-none}"
fi

[ -n "$signal" ] && exit 0 || exit 1
