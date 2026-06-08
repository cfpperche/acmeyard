#!/usr/bin/env bash
# Render the consumer-owned .agent0/project-core.md into CLAUDE.md and AGENTS.md.
#
# This is local derived-output maintenance, not Agent0 upstream sync. It needs
# only the current checkout: .agent0/project-core.md is the source of truth and
# AGENT0:PROJECT regions in the entrypoints are mirrors.

set -euo pipefail

MODE="check"
DRY_RUN=0
QUIET=0
ROOT_ARG=""

usage() {
  cat <<'EOF'
project-core-sync.sh - render .agent0/project-core.md into CLAUDE.md and AGENTS.md

Usage:
  project-core-sync.sh [--check|--apply] [--dry-run] [--quiet] [--root PATH]

Modes:
  --check     detect missing/stale PROJECT regions (default)
  --apply     create or re-render PROJECT regions from .agent0/project-core.md
  --dry-run   with --apply, report writes without changing files
  --quiet     suppress up-to-date lines

Exit codes:
  0  clean, or apply completed
  1  drift detected in --check, or apply refused invalid markers
  2  usage error
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --apply) MODE="apply" ;;
    --dry-run) DRY_RUN=1 ;;
    --quiet) QUIET=1 ;;
    --root=*) ROOT_ARG="${1#--root=}" ;;
    --root)
      shift
      ROOT_ARG="${1:-}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'project-core-sync: unknown arg: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ -n "$ROOT_ARG" ]; then
  ROOT="$(cd "$ROOT_ARG" && pwd)"
else
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$ROOT/.agent0/tools/lib/managed-block.sh"
if [ ! -f "$LIB" ]; then
  LIB="$SCRIPT_DIR/lib/managed-block.sh"
fi
if [ ! -f "$LIB" ]; then
  printf 'project-core-sync: missing managed-block helper library\n' >&2
  exit 2
fi
# shellcheck source=lib/managed-block.sh
. "$LIB"

SOURCE="$ROOT/.agent0/project-core.md"
MARKER="AGENT0:PROJECT"
DRIFT=0
REFUSED=0

if [ ! -f "$SOURCE" ]; then
  exit 0
fi

rendered="$(cat "$SOURCE")"
rendered_sha="$(_region_sha "$rendered")"

say() {
  if [ "$QUIET" -ne 1 ]; then
    printf '%s\n' "$1"
  fi
}

insert_region() {
  local rel="$1" dst="$2" tmp begin_line
  tmp="$(mktemp -t project-core-sync-XXXXXX)"
  begin_line="$(grep -Fxn '<!-- AGENT0:BEGIN -->' "$dst" | head -1 | cut -d: -f1 || true)"
  if [ -n "$begin_line" ]; then
    head -n "$((begin_line - 1))" "$dst" > "$tmp"
    printf '<!-- AGENT0:PROJECT:BEGIN -->\n%s\n<!-- AGENT0:PROJECT:END -->\n\n' "$rendered" >> "$tmp"
    tail -n +"$begin_line" "$dst" >> "$tmp"
  else
    cat "$dst" > "$tmp"
    printf '\n<!-- AGENT0:PROJECT:BEGIN -->\n%s\n<!-- AGENT0:PROJECT:END -->\n' "$rendered" >> "$tmp"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    rm -f "$tmp"
    say "~ project-core $rel (region created, dry-run)"
  else
    mv "$tmp" "$dst"
    say "~ project-core $rel (region created)"
  fi
}

replace_region() {
  local rel="$1" dst="$2" tmp begin_line end_line
  tmp="$(mktemp -t project-core-sync-XXXXXX)"
  begin_line="$(grep -Fxn '<!-- AGENT0:PROJECT:BEGIN -->' "$dst" | head -1 | cut -d: -f1)"
  end_line="$(grep -Fxn '<!-- AGENT0:PROJECT:END -->' "$dst" | head -1 | cut -d: -f1)"
  head -n "$((begin_line - 1))" "$dst" > "$tmp"
  printf '<!-- AGENT0:PROJECT:BEGIN -->\n%s\n<!-- AGENT0:PROJECT:END -->\n' "$rendered" >> "$tmp"
  tail -n +"$((end_line + 1))" "$dst" >> "$tmp"

  if [ "$DRY_RUN" -eq 1 ]; then
    rm -f "$tmp"
    say "~ project-core $rel (region re-rendered, dry-run)"
  else
    mv "$tmp" "$dst"
    say "~ project-core $rel (region re-rendered)"
  fi
}

sync_one() {
  local rel="$1" dst="$ROOT/$1" state cur_sha
  [ -f "$dst" ] || return 0

  state="$(detect_marker_state "$dst" "$MARKER")"
  case "$state" in
    mismatched|nested-invalid)
      if [ "$MODE" = "check" ]; then
        printf '!! project-core %s (markers %s)\n' "$rel" "$state"
        DRIFT=1
      else
        printf '!! project-core: %s has %s AGENT0:PROJECT markers - fix manually\n' "$rel" "$state" >&2
        REFUSED=1
      fi
      return 0
      ;;
    absent)
      if [ "$MODE" = "check" ]; then
        printf '~ project-core %s (region would be created)\n' "$rel"
        DRIFT=1
      else
        insert_region "$rel" "$dst"
      fi
      return 0
      ;;
    paired)
      cur_sha="$(_region_sha "$(_extract_region "$dst" "$MARKER")")"
      if [ "$cur_sha" = "$rendered_sha" ]; then
        say "= up to date $rel (project-core)"
        return 0
      fi
      if [ "$MODE" = "check" ]; then
        printf '~ stale %s (project-core - would re-render)\n' "$rel"
        DRIFT=1
      else
        replace_region "$rel" "$dst"
      fi
      ;;
  esac
}

sync_one "CLAUDE.md"
sync_one "AGENTS.md"

if [ "$REFUSED" -ne 0 ]; then
  exit 1
fi
if [ "$MODE" = "check" ] && [ "$DRIFT" -ne 0 ]; then
  exit 1
fi
exit 0
