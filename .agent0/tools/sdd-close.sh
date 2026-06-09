#!/usr/bin/env bash
# .agent0/tools/sdd-close.sh — static closure-consistency checker for shipped specs
#
# For each shipped (or shipped-partial) spec, report where the spec's own
# artifacts disagree with its declared status:
#   tasks-unchecked     — tasks.md still has `- [ ]` boxes
#   acceptance-unchecked— spec.md `## Acceptance criteria` still has `- [ ]` boxes
#   placeholders        — surviving `{{...}}` template placeholders in spec/tasks
#   missing-closure     — no uncommented `**Closure:**` line
#
# Read-only: writes nothing, ever. Complements spec-verify (spec 177): verify
# proves the spec's COMMAND still passes; close proves the spec's ARTIFACTS
# agree with its status. It does NOT run or duplicate `**Verify:**`.
#
# Usage:
#   sdd-close.sh [<spec-dir>] [--json] [-h]
#   no <spec-dir> → audit every docs/specs/* ; one <spec-dir> → just that spec
#
# Exit codes:
#   0  no findings (clean)
#   1  at least one finding across the targeted specs
#   64 usage error
#
# Runtime-neutral, markdown+shell only. The post-edit validator emits
# `sdd-close-advisory:` for RECENT shipped specs with findings (legacy specs are
# not nagged). See .agent0/context/rules/sdd-close.md. (spec 179)

set -uo pipefail

SELF="sdd-close"
SPEC_DIR=""
OUT_JSON=0

usage() { sed -n '2,30p' "$0"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --json) OUT_JSON=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) printf '%s: unknown flag: %s\n' "$SELF" "$1" >&2; exit 64 ;;
    *) if [ -z "$SPEC_DIR" ]; then SPEC_DIR="$1"; else printf '%s: unexpected arg: %s\n' "$SELF" "$1" >&2; exit 64; fi ;;
  esac
  shift
done

# Repo root: git first, then derive from this script's location (.agent0/tools → repo).
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

# Build the target list of spec dirs.
TARGETS=""
if [ -n "$SPEC_DIR" ]; then
  if [ -d "$SPEC_DIR" ]; then
    TARGETS="$(cd "$SPEC_DIR" && pwd)"
  elif [ -d "$ROOT/$SPEC_DIR" ]; then
    TARGETS="$(cd "$ROOT/$SPEC_DIR" && pwd)"
  else
    printf '%s: spec dir not found: %s\n' "$SELF" "$SPEC_DIR" >&2; exit 64
  fi
else
  [ -d "$ROOT/docs/specs" ] || { [ "$OUT_JSON" -eq 1 ] && printf '{"specs":[],"total_findings":0,"specs_with_findings":0}\n'; exit 0; }
  for _d in "$ROOT"/docs/specs/*/; do
    [ -d "$_d" ] || continue
    TARGETS="$TARGETS${TARGETS:+
}${_d%/}"
  done
fi

# --- finding helpers (read-only) -------------------------------------------

# Is this spec shipped or shipped-partial?
is_shipped() {
  grep -qiE '^\*\*Status:\*\*[[:space:]]*shipped(-partial)?\b' "$1" 2>/dev/null
}

# Count `- [ ]` unchecked boxes in a file (whole file).
# Note: `grep -c` prints 0 AND exits 1 on no-match, so capture stdout and
# ignore the exit code rather than `|| printf 0` (which would double-print).
count_unchecked() {
  [ -f "$1" ] || { printf '0'; return; }
  _n="$(grep -cE '^[[:space:]]*-[[:space:]]\[ \]' "$1" 2>/dev/null)"
  printf '%s' "${_n:-0}"
}

# Count `- [ ]` only within the `## Acceptance criteria` section of spec.md.
count_acceptance_unchecked() {
  [ -f "$1" ] || { printf '0'; return; }
  awk '
    /^##[[:space:]]+Acceptance criteria/ { insec=1; next }
    /^##[[:space:]]/ { if (insec) insec=0 }
    insec && /^[[:space:]]*-[[:space:]]\[ \]/ { n++ }
    END { printf "%d", n+0 }
  ' "$1"
}

# Surviving {{...}} scaffold placeholders in a file?
# Strip inline `code` spans first so a spec that merely *discusses* template
# syntax (e.g. `{{SLUG}}` in backticks) is not a false positive — only an
# unfilled placeholder sitting in bare prose counts.
has_placeholders() {
  [ -f "$1" ] || return 1
  sed 's/`[^`]*`//g' "$1" 2>/dev/null | grep -qE '\{\{'
}

# An uncommented **Closure:** line present?
has_closure() {
  grep -qE '^\*\*Closure:\*\*' "$1" 2>/dev/null
}

# --- scan -------------------------------------------------------------------

TOTAL_FINDINGS=0
SPECS_WITH_FINDINGS=0
JSON_SPECS=""
HUMAN=""

# Iterate targets (newline-delimited, bash 3.2-safe).
OLDIFS="$IFS"; IFS='
'
for SDIR in $TARGETS; do
  IFS="$OLDIFS"
  SPEC_MD="$SDIR/spec.md"
  TASKS_MD="$SDIR/tasks.md"
  [ -f "$SPEC_MD" ] || { IFS='
'; continue; }
  if ! is_shipped "$SPEC_MD"; then IFS='
'; continue; fi

  REL="docs/specs/$(basename "$SDIR")"
  status_line="$(grep -iE '^\*\*Status:\*\*' "$SPEC_MD" | head -n1 | sed -E 's/^\*\*Status:\*\*[[:space:]]*//; s/[[:space:]].*$//')"

  findings=""          # newline list of "type:detail"
  json_findings=""

  t_un="$(count_unchecked "$TASKS_MD")"
  if [ "${t_un:-0}" -gt 0 ]; then
    findings="${findings}tasks-unchecked ($t_un)
"
    json_findings="${json_findings}${json_findings:+,}{\"type\":\"tasks-unchecked\",\"count\":$t_un}"
  fi

  a_un="$(count_acceptance_unchecked "$SPEC_MD")"
  if [ "${a_un:-0}" -gt 0 ]; then
    findings="${findings}acceptance-unchecked ($a_un)
"
    json_findings="${json_findings}${json_findings:+,}{\"type\":\"acceptance-unchecked\",\"count\":$a_un}"
  fi

  if has_placeholders "$SPEC_MD" || has_placeholders "$TASKS_MD"; then
    findings="${findings}placeholders
"
    json_findings="${json_findings}${json_findings:+,}{\"type\":\"placeholders\"}"
  fi

  if ! has_closure "$SPEC_MD"; then
    findings="${findings}missing-closure
"
    json_findings="${json_findings}${json_findings:+,}{\"type\":\"missing-closure\"}"
  fi

  if [ -n "$findings" ]; then
    nf="$(printf '%s' "$findings" | grep -c .)"
    TOTAL_FINDINGS=$((TOTAL_FINDINGS + nf))
    SPECS_WITH_FINDINGS=$((SPECS_WITH_FINDINGS + 1))
    HUMAN="${HUMAN}  [${status_line}] $REL
$(printf '%s' "$findings" | sed 's/^/    - /')
"
    JSON_SPECS="${JSON_SPECS}${JSON_SPECS:+,}{\"spec\":\"$REL\",\"status\":\"$status_line\",\"findings\":[$json_findings]}"
  fi
  IFS='
'
done
IFS="$OLDIFS"

# --- output -----------------------------------------------------------------

if [ "$OUT_JSON" -eq 1 ]; then
  printf '{"specs":[%s],"total_findings":%d,"specs_with_findings":%d}\n' \
    "$JSON_SPECS" "$TOTAL_FINDINGS" "$SPECS_WITH_FINDINGS"
else
  if [ "$SPECS_WITH_FINDINGS" -eq 0 ]; then
    printf '%s: clean — no closure inconsistencies in the targeted shipped spec(s)\n' "$SELF"
  else
    printf '%s: %d finding(s) across %d shipped spec(s):\n' "$SELF" "$TOTAL_FINDINGS" "$SPECS_WITH_FINDINGS"
    printf '%s' "$HUMAN"
  fi
fi

[ "$TOTAL_FINDINGS" -eq 0 ] || exit 1
exit 0
