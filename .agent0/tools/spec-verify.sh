#!/usr/bin/env bash
# .agent0/tools/spec-verify.sh — run a spec's declared verification command(s)
#
# A spec opts in to mechanical re-verification by declaring one or more
#   **Verify:** `<command>`
# lines in its tasks.md (canonical) or spec.md (fallback). This tool extracts
# those commands, runs each from the repo root, records a timestamped result
# block in the spec's notes.md under `## Verification log`, and prints a human
# or --json summary.
#
# Exit codes:
#   0  every declared command passed
#   1  at least one declared command failed
#   2  no verify command declared (notes.md is NOT modified)
#   64 usage error
#
# Runtime-neutral, markdown+shell only (no DB, no compiled CLI). The post-edit
# validator emits `spec-verify-advisory:` when a SHIPPED spec declares a verify
# command but has no passing record here — running this tool clears it.
# See .agent0/context/rules/spec-verify.md. (spec 177)

set -uo pipefail

SELF="spec-verify"
SPEC_DIR=""
OUT_JSON=0
QUIET=0

usage() { sed -n '2,21p' "$0"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --json)  OUT_JSON=1 ;;
    --quiet) QUIET=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) printf '%s: unknown flag: %s\n' "$SELF" "$1" >&2; exit 64 ;;
    *) if [ -z "$SPEC_DIR" ]; then SPEC_DIR="$1"; else printf '%s: unexpected arg: %s\n' "$SELF" "$1" >&2; exit 64; fi ;;
  esac
  shift
done

[ -n "$SPEC_DIR" ] || { printf '%s: a spec directory is required (e.g. docs/specs/NNN-slug)\n' "$SELF" >&2; exit 64; }

# Repo root: git first, then derive from this script's location (.agent0/tools → repo).
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

# Normalise the spec dir to an absolute path (accept relative-to-cwd or relative-to-root).
if [ -d "$SPEC_DIR" ]; then
  ABS_SPEC="$(cd "$SPEC_DIR" && pwd)"
elif [ -d "$ROOT/$SPEC_DIR" ]; then
  ABS_SPEC="$(cd "$ROOT/$SPEC_DIR" && pwd)"
else
  printf '%s: spec dir not found: %s\n' "$SELF" "$SPEC_DIR" >&2; exit 64
fi

SPEC_NAME="${ABS_SPEC##*/}"
REL_SPEC="docs/specs/$SPEC_NAME"
TASKS_MD="$ABS_SPEC/tasks.md"
SPEC_MD="$ABS_SPEC/spec.md"
NOTES_MD="$ABS_SPEC/notes.md"

# Extract `**Verify:** `<cmd>`` commands. tasks.md is canonical; fall back to
# spec.md so a single-file spec still works. Only the FIRST backtick-fenced span
# on each matching line is taken as the command.
extract_cmds() {
  local f="$1"
  [ -f "$f" ] || return 0
  # match lines beginning with **Verify:** then capture text between the first
  # pair of backticks.
  grep -nE '^\*\*Verify:\*\*[[:space:]]*`' "$f" 2>/dev/null \
    | sed -E 's/^[0-9]+:\*\*Verify:\*\*[[:space:]]*`([^`]*)`.*/\1/'
}

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\b'/\\b}
  s=${s//$'\f'/\\f}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

CMDS="$(extract_cmds "$TASKS_MD")"
SRC="tasks.md"
if [ -z "$CMDS" ]; then
  CMDS="$(extract_cmds "$SPEC_MD")"
  SRC="spec.md"
fi

# No declaration → exit 2, do not touch notes.md.
if [ -z "$CMDS" ]; then
  if [ "$OUT_JSON" -eq 1 ]; then
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg spec "$SPEC_NAME" \
        '{status:"no-verify-declared",spec:$spec,commands:[],passed:0,failed:0,declared:false}'
    else
      printf '{"status":"no-verify-declared","spec":"%s","commands":[],"passed":0,"failed":0,"declared":false}\n' \
        "$(json_escape "$SPEC_NAME")"
    fi
  elif [ "$QUIET" -eq 0 ]; then
    printf '%s: no verify command declared in %s — nothing to run (declare a **Verify:** `<cmd>` line)\n' "$SELF" "$REL_SPEC"
  fi
  exit 2
fi

# Run each command from the repo root; collect results.
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
PASSED=0
FAILED=0
RESULT_LINES=""   # markdown bullets for notes.md
JSON_ITEMS=""     # jq-built array elements
JSON_FALLBACK_ITEMS=""

old_ifs="$IFS"
IFS='
'
for cmd in $CMDS; do
  [ -n "$cmd" ] || continue
  if ( cd "$ROOT" && bash -c "$cmd" >/dev/null 2>&1 ); then
    res="pass"; PASSED=$((PASSED + 1))
  else
    res="fail"; FAILED=$((FAILED + 1))
  fi
  RESULT_LINES="${RESULT_LINES}- \`${cmd}\` — ${res}
"
  if command -v jq >/dev/null 2>&1; then
    item="$(jq -n --arg c "$cmd" --arg r "$res" '{command:$c,result:$r}')"
    if [ -z "$JSON_ITEMS" ]; then JSON_ITEMS="$item"; else JSON_ITEMS="$JSON_ITEMS
$item"; fi
  fi
  fallback_item="$(printf '{"command":"%s","result":"%s"}' "$(json_escape "$cmd")" "$res")"
  if [ -z "$JSON_FALLBACK_ITEMS" ]; then
    JSON_FALLBACK_ITEMS="$fallback_item"
  else
    JSON_FALLBACK_ITEMS="$JSON_FALLBACK_ITEMS,$fallback_item"
  fi
  if [ "$QUIET" -eq 0 ] && [ "$OUT_JSON" -eq 0 ]; then
    printf '  [%s] %s\n' "$res" "$cmd"
  fi
done
IFS="$old_ifs"

OVERALL="pass"
[ "$FAILED" -gt 0 ] && OVERALL="fail"
TOTAL=$((PASSED + FAILED))

# Append a result block to notes.md under `## Verification log`.
if [ ! -f "$NOTES_MD" ]; then
  printf '# %s — notes\n' "$SPEC_NAME" > "$NOTES_MD"
fi
if ! grep -qE '^## Verification log' "$NOTES_MD"; then
  printf '\n## Verification log\n' >> "$NOTES_MD"
fi
{
  printf '\n### %s — %s (%d/%d) — source: %s\n' "$TS" "$OVERALL" "$PASSED" "$TOTAL" "$SRC"
  printf '%s' "$RESULT_LINES"
} >> "$NOTES_MD"

# Output.
if [ "$OUT_JSON" -eq 1 ]; then
  if command -v jq >/dev/null 2>&1; then
    printf '%s\n' "$JSON_ITEMS" | jq -s \
      --arg spec "$SPEC_NAME" --arg status "$OVERALL" \
      --argjson passed "$PASSED" --argjson failed "$FAILED" \
      '{status:$status,spec:$spec,commands:.,passed:$passed,failed:$failed,declared:true}'
  else
    printf '{"status":"%s","spec":"%s","commands":[%s],"passed":%d,"failed":%d,"declared":true}\n' \
      "$OVERALL" "$(json_escape "$SPEC_NAME")" "$JSON_FALLBACK_ITEMS" "$PASSED" "$FAILED"
  fi
elif [ "$QUIET" -eq 0 ]; then
  printf '%s: %s — %d/%d passed (source: %s, logged to %s/notes.md)\n' \
    "$SELF" "$OVERALL" "$PASSED" "$TOTAL" "$SRC" "$REL_SPEC"
fi

[ "$FAILED" -eq 0 ] && exit 0
exit 1
