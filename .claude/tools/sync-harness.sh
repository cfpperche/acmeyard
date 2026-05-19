#!/usr/bin/env bash
# .claude/tools/sync-harness.sh
# Spec 016 — one-way sync of Agent0 harness state into a fork.
# See docs/specs/016-harness-sync/ and .claude/rules/harness-sync.md (if present).

set -euo pipefail

# ---------------------------------------------------------------------------
# usage / arg parsing
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
sync-harness.sh — one-way Agent0 -> fork harness sync

Usage:
  sync-harness.sh [--check|--apply] [--dry-run] [--force]
                  [--force-except=GLOB[,GLOB...]]
                  [--agent0-path=PATH] <fork-path>

Modes:
  --check                read-only drift listing (default)
  --apply                write changes
  --dry-run              with --apply, emit decisions without writing
  --force                overwrite fork-customized files (warned)
  --force-except=GLOB    comma-separated globs; matching files keep their
                         customization (refused) even under --force

Source:
  --agent0-path=PATH   absolute path to Agent0 source repo
  AGENT0_HARNESS_PATH  env-var fallback

Target:
  <fork-path>          positional, required

Exit codes:
  0  clean (check: no drift; apply: success)
  1  drift detected (check) or customizations refused (apply without --force)
  2  usage error (missing source path, bad flags, etc.)
EOF
}

MODE="check"
DRY_RUN=0
FORCE=0
FORCE_EXCEPT=""
AGENT0_ARG=""
FORK_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check)   MODE="check" ;;
    --apply)   MODE="apply" ;;
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    --force-except=*) FORCE_EXCEPT="${1#--force-except=}" ;;
    --force-except)
      shift
      FORCE_EXCEPT="${1:-}"
      ;;
    --agent0-path=*)  AGENT0_ARG="${1#--agent0-path=}" ;;
    --agent0-path)
      shift
      AGENT0_ARG="${1:-}"
      ;;
    -h|--help) usage; exit 0 ;;
    --*)
      printf 'sync-harness: unknown flag: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [ -z "$FORK_ARG" ]; then
        FORK_ARG="$1"
      else
        printf 'sync-harness: unexpected extra positional arg: %s\n' "$1" >&2
        usage >&2
        exit 2
      fi
      ;;
  esac
  shift
done

if [ -z "$FORK_ARG" ]; then
  printf 'sync-harness: missing <fork-path>\n' >&2
  usage >&2
  exit 2
fi

# Resolve Agent0 source: explicit arg wins, then env var, then refuse.
if [ -n "$AGENT0_ARG" ]; then
  AGENT0_ROOT="$AGENT0_ARG"
elif [ -n "${AGENT0_HARNESS_PATH:-}" ]; then
  AGENT0_ROOT="$AGENT0_HARNESS_PATH"
else
  printf 'sync-harness: must specify --agent0-path=PATH or set AGENT0_HARNESS_PATH\n' >&2
  usage >&2
  exit 2
fi

FORK_ROOT="$FORK_ARG"

# Sanity: Agent0 looks like an Agent0 repo
if [ ! -d "$AGENT0_ROOT/.claude" ] || [ ! -f "$AGENT0_ROOT/CLAUDE.md" ]; then
  printf 'sync-harness: --agent0-path=%s does not look like an Agent0 repo (no .claude/ or CLAUDE.md)\n' "$AGENT0_ROOT" >&2
  exit 2
fi
if [ ! -d "$FORK_ROOT" ]; then
  printf 'sync-harness: fork path does not exist: %s\n' "$FORK_ROOT" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# manifest
# ---------------------------------------------------------------------------

# Project-local paths — MUST NOT be added to any COPY_CHECK array below.
# .claude/.browser-state/  session credentials (cookies/localStorage); project-specific,
#                           gitignored *.json, only .gitkeep sentinel travels via git.
# .claude/memory/           project knowledge; content is project-local (spec 019).
#                           The empty .gitkeep IS in COPY_CHECK_FILES — content is not.

# Recursive globs (find -type f under base dir) — encoded as "base/**"
COPY_CHECK_RECURSIVE=(
  ".claude/skills"
  ".claude/tests"
  ".claude/agents"
)

# Single-level globs (find -maxdepth 1 with name pattern) — encoded as "dir|pattern"
COPY_CHECK_GLOBS=(
  ".claude/hooks|*.sh"
  ".claude/rules|*.md"
  ".claude/tools|*.sh"
  ".claude/validators|*.sh"
  ".claude/presence|*.mjs"
)

# Literal files
COPY_CHECK_FILES=(
  ".mcp.json.example"
  ".gitleaks.toml"
  ".githooks/pre-commit"
  ".claude/memory/.gitkeep"
  ".claude/.browser-state/.gitkeep"
)

# Structured merge handled by dedicated functions below
# - .claude/settings.json
# - CLAUDE.md
# - .gitignore

# ---------------------------------------------------------------------------
# counters
# ---------------------------------------------------------------------------

COPIED=0
UP_TO_DATE=0
CUSTOMIZED_REFUSED=0
OVERWRITTEN=0
MERGED=0
DRIFT=0

# ---------------------------------------------------------------------------
# copy / check
# ---------------------------------------------------------------------------

sha_of() {
  if [ -f "$1" ]; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo ""
  fi
}

# Returns 0 if `rel` matches any glob in FORCE_EXCEPT (comma-separated), else 1.
matches_force_except() {
  local rel="$1"
  [ -z "$FORCE_EXCEPT" ] && return 1
  local IFS=','
  local pat
  for pat in $FORCE_EXCEPT; do
    [ -z "$pat" ] && continue
    case "$rel" in
      $pat) return 0 ;;
    esac
  done
  return 1
}

process_file() {
  local rel="$1"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"

  if [ ! -f "$src" ]; then
    return
  fi

  if [ ! -f "$dst" ]; then
    # Missing in fork: copy.
    if [ "$MODE" = "check" ]; then
      printf '+ would copy %s\n' "$rel"
      DRIFT=1
    else
      if [ "$DRY_RUN" -eq 1 ]; then
        printf '+ copied %s (dry-run)\n' "$rel"
      else
        mkdir -p "$(dirname "$dst")"
        cp -p "$src" "$dst"
        printf '+ copied %s\n' "$rel"
      fi
      COPIED=$((COPIED + 1))
    fi
    return
  fi

  local src_sha dst_sha
  src_sha="$(sha_of "$src")"
  dst_sha="$(sha_of "$dst")"

  if [ "$src_sha" = "$dst_sha" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    return
  fi

  # Hash mismatch: customized.
  if [ "$MODE" = "check" ]; then
    printf '!! customized %s\n' "$rel"
    DRIFT=1
    return
  fi

  if [ "$FORCE" -eq 1 ] && ! matches_force_except "$rel"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '! overwritten %s (dry-run)\n' "$rel" >&2
    else
      cp -p "$src" "$dst"
      printf '! overwritten %s\n' "$rel" >&2
    fi
    OVERWRITTEN=$((OVERWRITTEN + 1))
  else
    printf '!! customized %s\n' "$rel" >&2
    CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
  fi
}

walk_copy_check() {
  local base pattern dir relfile

  for base in "${COPY_CHECK_RECURSIVE[@]}"; do
    if [ -d "$AGENT0_ROOT/$base" ]; then
      while IFS= read -r relfile; do
        [ -n "$relfile" ] && process_file "$relfile"
      done < <(cd "$AGENT0_ROOT" && find "$base" -type f 2>/dev/null | sort)
    fi
  done

  for entry in "${COPY_CHECK_GLOBS[@]}"; do
    dir="${entry%|*}"
    pattern="${entry#*|}"
    if [ -d "$AGENT0_ROOT/$dir" ]; then
      while IFS= read -r relfile; do
        [ -n "$relfile" ] && process_file "$relfile"
      done < <(cd "$AGENT0_ROOT" && find "$dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null | sort)
    fi
  done

  for relfile in "${COPY_CHECK_FILES[@]}"; do
    process_file "$relfile"
  done
}

# ---------------------------------------------------------------------------
# settings.json structured merge
# ---------------------------------------------------------------------------

merge_settings_json() {
  local rel=".claude/settings.json"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"

  if [ ! -f "$src" ]; then
    return
  fi

  if [ ! -f "$dst" ]; then
    process_file "$rel"
    return
  fi

  local src_sha dst_sha
  src_sha="$(sha_of "$src")"
  dst_sha="$(sha_of "$dst")"
  if [ "$src_sha" = "$dst_sha" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    return
  fi

  # Compute merged JSON: union the two .hooks.* arrays, dedup by (matcher, commands).
  local tmp merged
  tmp="$(mktemp -t sync-settings-XXXXXX)"
  if ! jq -s '
    def dedup_key:
      (.matcher // "") + "|" + ((.hooks // []) | map(.command // "") | join("##"));

    . as $arr |
    {
      hooks: (
        ((($arr[0].hooks // {}) | keys) + (($arr[1].hooks // {}) | keys)) |
        unique |
        map(. as $k | {
          ($k): ((($arr[0].hooks[$k]) // []) + (($arr[1].hooks[$k]) // []) | unique_by(dedup_key))
        }) | add
      )
    }
  ' "$dst" "$src" > "$tmp" 2>/dev/null; then
    printf '!! settings.json merge failed (jq error)\n' >&2
    rm -f "$tmp"
    DRIFT=1
    return
  fi

  # Compare merged result with current fork content
  local merged_sha
  merged_sha="$(sha_of "$tmp")"
  if [ "$merged_sha" = "$dst_sha" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    rm -f "$tmp"
    return
  fi

  if [ "$MODE" = "check" ]; then
    printf '~ would merge %s\n' "$rel"
    DRIFT=1
    rm -f "$tmp"
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '~ merged %s (dry-run)\n' "$rel"
    rm -f "$tmp"
  else
    mv "$tmp" "$dst"
    printf '~ merged %s\n' "$rel"
  fi
  MERGED=$((MERGED + 1))
}

# ---------------------------------------------------------------------------
# CLAUDE.md capacity-section append
# ---------------------------------------------------------------------------

# Extract section headings ("^## <Title>") from a file, one per line.
extract_h2() {
  grep -E '^## ' "$1" || true
}

# Extract the body of a specific section (from "## Title" through to next "## " or EOF).
extract_section() {
  local file="$1"
  local title="$2"
  awk -v t="$title" '
    BEGIN { in_sec = 0 }
    /^## / {
      if (in_sec) exit
      if ($0 == t) in_sec = 1
    }
    { if (in_sec) print }
  ' "$file"
}

merge_claude_md() {
  local rel="CLAUDE.md"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"

  if [ ! -f "$src" ]; then
    return
  fi

  if [ ! -f "$dst" ]; then
    process_file "$rel"
    return
  fi

  local src_sha dst_sha
  src_sha="$(sha_of "$src")"
  dst_sha="$(sha_of "$dst")"
  if [ "$src_sha" = "$dst_sha" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    return
  fi

  local src_headings dst_headings missing_titles
  src_headings="$(extract_h2 "$src")"
  dst_headings="$(extract_h2 "$dst")"
  # Lines in src not in dst — preserve src ordering (don't sort), so inserted
  # sections appear in the same order as Agent0's CLAUDE.md.
  if [ -z "$dst_headings" ]; then
    missing_titles="$src_headings"
  else
    missing_titles="$(printf '%s\n' "$src_headings" | grep -Fxv -f <(printf '%s\n' "$dst_headings") || true)"
  fi

  if [ -z "$missing_titles" ]; then
    # CLAUDE.md is expected to diverge in fork-authored content (Overview, Stack, etc).
    # The sync's only job is to ensure capacity sections from Agent0 are present.
    # If all Agent0 sections are present, treat as up-to-date regardless of other-body drift.
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    return
  fi

  # We have missing sections to append. Build the new content.
  local tmp anchor anchor_line
  tmp="$(mktemp -t sync-claude-md-XXXXXX)"
  anchor="## Compact Instructions"
  anchor_line="$(grep -nF "$anchor" "$dst" | head -1 | cut -d: -f1 || true)"

  if [ -z "$anchor_line" ]; then
    printf '!! claude-md: missing "%s" anchor — appending at EOF\n' "$anchor" >&2
    cp "$dst" "$tmp"
    # Append each missing section
    while IFS= read -r title; do
      [ -z "$title" ] && continue
      printf '\n' >> "$tmp"
      extract_section "$src" "$title" >> "$tmp"
    done <<EOF
$missing_titles
EOF
  else
    # Split fork file: pre-anchor + anchor-onwards
    head -n $((anchor_line - 1)) "$dst" > "$tmp"
    while IFS= read -r title; do
      [ -z "$title" ] && continue
      extract_section "$src" "$title" >> "$tmp"
      printf '\n' >> "$tmp"
    done <<EOF
$missing_titles
EOF
    tail -n +$anchor_line "$dst" >> "$tmp"
  fi

  if [ "$MODE" = "check" ]; then
    printf '~ would merge %s\n' "$rel"
    DRIFT=1
    rm -f "$tmp"
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '~ merged %s (dry-run)\n' "$rel"
    rm -f "$tmp"
  else
    mv "$tmp" "$dst"
    printf '~ merged %s\n' "$rel"
  fi
  MERGED=$((MERGED + 1))
}

# ---------------------------------------------------------------------------
# .gitignore additive merge
# ---------------------------------------------------------------------------

# Agent0's .gitignore carries harness-runtime entries (audit logs, state dirs,
# lock files) that MUST exist in any fork for the harness to run cleanly. Fork's
# .gitignore is typically stack-canonical (Laravel's vendor/, Next's node_modules/,
# etc.) and conflicts with Agent0's stack-agnostic template if overwritten. This
# function appends Agent0 entries the fork is missing, preserving fork-specific
# lines untouched. Idempotent: re-runs add nothing once the fork has all Agent0
# entries. Comments and blank lines are NOT membership-keyed (entries are the
# semantic unit).

merge_gitignore() {
  local rel=".gitignore"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"
  local marker="# === Agent0 harness sync — additions ==="

  if [ ! -f "$src" ]; then
    return
  fi

  # Honor --force-except for the canonical .gitignore case (documented in
  # harness-sync.md). Even though merge is additive, the operator's intent in
  # passing --force-except='.gitignore' is "do not touch the fork's .gitignore".
  if matches_force_except "$rel"; then
    printf '!! force-except %s (merge skipped)\n' "$rel" >&2
    CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
    return
  fi

  if [ ! -f "$dst" ]; then
    process_file "$rel"
    return
  fi

  local src_sha dst_sha
  src_sha="$(sha_of "$src")"
  dst_sha="$(sha_of "$dst")"
  if [ "$src_sha" = "$dst_sha" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    return
  fi

  # Extract entries: non-comment, non-empty, trimmed. Sort for comm.
  local tmp_src_entries tmp_fork_entries tmp_missing
  tmp_src_entries="$(mktemp -t sync-gi-src-XXXXXX)"
  tmp_fork_entries="$(mktemp -t sync-gi-fork-XXXXXX)"
  tmp_missing="$(mktemp -t sync-gi-miss-XXXXXX)"

  grep -v '^[[:space:]]*#' "$src" | grep -v '^[[:space:]]*$' | awk '{$1=$1;print}' | sort -u > "$tmp_src_entries"
  grep -v '^[[:space:]]*#' "$dst" | grep -v '^[[:space:]]*$' | awk '{$1=$1;print}' | sort -u > "$tmp_fork_entries"

  # Lines in src but not in dst — these are the additions.
  comm -23 "$tmp_src_entries" "$tmp_fork_entries" > "$tmp_missing"

  if [ ! -s "$tmp_missing" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    rm -f "$tmp_src_entries" "$tmp_fork_entries" "$tmp_missing"
    return
  fi

  local missing_count
  missing_count="$(wc -l < "$tmp_missing" | awk '{print $1}')"

  if [ "$MODE" = "check" ]; then
    printf '~ would merge %s (%d entries to add)\n' "$rel" "$missing_count"
    DRIFT=1
    rm -f "$tmp_src_entries" "$tmp_fork_entries" "$tmp_missing"
    return
  fi

  # Build merged content: fork's current content + marker (if new) + missing entries.
  local tmp_merged
  tmp_merged="$(mktemp -t sync-gi-merged-XXXXXX)"
  cat "$dst" > "$tmp_merged"

  if ! grep -Fq "$marker" "$tmp_merged"; then
    {
      printf '\n%s\n' "$marker"
    } >> "$tmp_merged"
  else
    printf '\n' >> "$tmp_merged"
  fi

  while IFS= read -r line; do
    printf '%s\n' "$line" >> "$tmp_merged"
  done < "$tmp_missing"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '~ merged %s (%d entries, dry-run)\n' "$rel" "$missing_count"
    rm -f "$tmp_src_entries" "$tmp_fork_entries" "$tmp_missing" "$tmp_merged"
  else
    mv "$tmp_merged" "$dst"
    printf '~ merged %s (%d entries appended)\n' "$rel" "$missing_count"
    rm -f "$tmp_src_entries" "$tmp_fork_entries" "$tmp_missing"
  fi
  MERGED=$((MERGED + 1))
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

walk_copy_check
merge_settings_json
merge_claude_md
merge_gitignore

# Summary on stderr so stdout stays parseable per-file decisions.
{
  printf '\n'
  printf 'synced: %d copied, %d merged, %d up-to-date, %d customized-refused, %d overwritten\n' \
    "$COPIED" "$MERGED" "$UP_TO_DATE" "$CUSTOMIZED_REFUSED" "$OVERWRITTEN"
} >&2

# Exit code policy
if [ "$MODE" = "check" ]; then
  if [ "$DRIFT" -ne 0 ]; then
    exit 1
  fi
  exit 0
fi

# apply mode
if [ "$CUSTOMIZED_REFUSED" -gt 0 ]; then
  exit 1
fi

exit 0
