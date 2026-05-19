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

# ---------------------------------------------------------------------------
# CLAUDE.md managed-block helpers (spec 058)
# ---------------------------------------------------------------------------

# Detect marker state in a file. Outputs: absent | paired | mismatched | nested-invalid
detect_marker_state() {
  local file="$1"
  local begin_count end_count begin_line end_line
  if [ ! -f "$file" ]; then
    echo "absent"
    return
  fi
  begin_count="$(grep -cE '^<!-- AGENT0:BEGIN -->$' "$file" 2>/dev/null || true)"
  end_count="$(grep -cE '^<!-- AGENT0:END -->$' "$file" 2>/dev/null || true)"
  [ -z "$begin_count" ] && begin_count=0
  [ -z "$end_count" ] && end_count=0

  if [ "$begin_count" -eq 0 ] && [ "$end_count" -eq 0 ]; then
    echo "absent"
    return
  fi

  if [ "$begin_count" -eq 0 ] || [ "$end_count" -eq 0 ]; then
    echo "mismatched"
    return
  fi

  if [ "$begin_count" -gt 1 ] || [ "$end_count" -gt 1 ]; then
    echo "nested-invalid"
    return
  fi

  # Exactly 1 of each — check order
  begin_line="$(grep -nE '^<!-- AGENT0:BEGIN -->$' "$file" | head -1 | cut -d: -f1)"
  end_line="$(grep -nE '^<!-- AGENT0:END -->$' "$file" | head -1 | cut -d: -f1)"
  if [ "$begin_line" -ge "$end_line" ]; then
    echo "nested-invalid"
    return
  fi
  echo "paired"
}

# Extract content between AGENT0:BEGIN and AGENT0:END markers (exclusive).
_extract_region() {
  local file="$1"
  awk '
    /^<!-- AGENT0:END -->$/ { in_region=0 }
    in_region { print }
    /^<!-- AGENT0:BEGIN -->$/ { in_region=1 }
  ' "$file"
}

# For each H2 heading in BOTH files (intersection), compare section bodies.
# Outputs diverged section titles, one per line.
_check_section_divergence() {
  local src="$1"
  local dst="$2"
  local src_h2 dst_h2 src_sorted dst_sorted common title src_body dst_body
  src_h2="$(extract_h2 "$src")"
  dst_h2="$(extract_h2 "$dst")"
  src_sorted="$(mktemp -t sync-srch2-XXXXXX)"
  dst_sorted="$(mktemp -t sync-dsth2-XXXXXX)"
  printf '%s\n' "$src_h2" | sort -u > "$src_sorted"
  printf '%s\n' "$dst_h2" | sort -u > "$dst_sorted"
  common="$(comm -12 "$src_sorted" "$dst_sorted")"
  rm -f "$src_sorted" "$dst_sorted"

  while IFS= read -r title; do
    [ -z "$title" ] && continue
    src_body="$(extract_section "$src" "$title")"
    dst_body="$(extract_section "$dst" "$title")"
    if [ "$src_body" != "$dst_body" ]; then
      printf '%s\n' "$title"
    fi
  done <<EOF
$common
EOF
}

# Section divergence scoped to the AGENT0 region (between markers) in both files.
_check_region_divergence() {
  local src="$1"
  local dst="$2"
  local src_tmp dst_tmp out
  src_tmp="$(mktemp -t sync-srcrgn-XXXXXX)"
  dst_tmp="$(mktemp -t sync-dstrgn-XXXXXX)"
  _extract_region "$src" > "$src_tmp"
  _extract_region "$dst" > "$dst_tmp"
  out="$(_check_section_divergence "$src_tmp" "$dst_tmp")"
  rm -f "$src_tmp" "$dst_tmp"
  printf '%s' "$out"
}

# Write a unified diff of fork region vs Agent0 region to .claude/CLAUDE.md.diverged-region.md.
_write_region_divergence_report() {
  local src="$1"
  local dst="$2"
  local diverged_titles="$3"
  local out="$FORK_ROOT/.claude/CLAUDE.md.diverged-region.md"
  local title
  mkdir -p "$(dirname "$out")"
  {
    printf '# CLAUDE.md managed region divergence\n\n'
    printf '_Generated by sync-harness.sh on %s — fork region differs from Agent0 source._\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'Body of one or more Agent0-titled sections in the managed region differs\n'
    printf 'between fork and Agent0 source. Resolve by either:\n\n'
    printf '1. Moving project customizations OUTSIDE the markers (above `<!-- AGENT0:BEGIN -->`).\n'
    printf '2. Accepting Agent0 replacement via `--force` (fork region overwritten wholesale).\n\n'
    if [ -n "$diverged_titles" ]; then
      printf '## Diverged sections\n\n'
      while IFS= read -r title; do
        [ -z "$title" ] && continue
        printf -- '- `%s`\n' "$title"
      done <<EOF
$diverged_titles
EOF
      printf '\n'
    fi
    printf '## Unified diff (fork → Agent0)\n\n'
    printf '```diff\n'
    diff -u <(_extract_region "$dst") <(_extract_region "$src") || true
    printf '```\n'
  } > "$out"
}

# Generate `.claude/CLAUDE.md.migration-candidate.md` showing the wrapped layout,
# OR `.claude/CLAUDE.md.diverged-sections.md` if section bodies diverged.
# No-op when Agent0 source is not wrapped (markers are the "Agent0-managed namespace"
# delimiter — without them, we can't tell project-narrative from capacity sections).
# Respects MODE=check (no writes) and DRY_RUN=1 (no writes, advisory only).
_generate_migration_candidate() {
  local rel="CLAUDE.md"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"
  local src_state diverged_titles count title

  # Candidate generation requires Agent0 source to be wrapped — the markers
  # define what's Agent0-managed vs project-narrative. Without them, every
  # H2 in src would be treated as Agent0-owned and project headings like
  # `## Overview` would falsely trip the divergence check.
  src_state="$(detect_marker_state "$src")"
  if [ "$src_state" != "paired" ]; then
    return
  fi

  # Compare fork sections against Agent0's REGION (managed namespace only).
  local src_region_tmp
  src_region_tmp="$(mktemp -t sync-srcrgn-XXXXXX)"
  _extract_region "$src" > "$src_region_tmp"
  diverged_titles="$(_check_section_divergence "$src_region_tmp" "$dst")"

  if [ -n "$diverged_titles" ]; then
    count="$(printf '%s\n' "$diverged_titles" | grep -c . || true)"
    if [ "$MODE" = "check" ] || [ "$DRY_RUN" -eq 1 ]; then
      printf 'claude-md-migration-blocked: %s sections diverged (drift only, --check/--dry-run: no report written)\n' "$count" >&2
      rm -f "$src_region_tmp"
      DRIFT=1
      return
    fi

    local report="$FORK_ROOT/.claude/CLAUDE.md.diverged-sections.md"
    mkdir -p "$(dirname "$report")"
    {
      printf '# CLAUDE.md section divergence — migration blocked\n\n'
      printf '_Generated by sync-harness.sh on %s._\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      printf 'The fork rewrote the body of one or more Agent0-titled sections. Migration\n'
      printf 'to managed-block layout (spec 058) is blocked until these are resolved.\n\n'
      printf '## Diverged sections\n\n'
      while IFS= read -r title; do
        [ -z "$title" ] && continue
        printf -- '- `%s`\n' "$title"
      done <<EOF
$diverged_titles
EOF
      printf '\n## Resolution\n\n'
      printf '1. Per section: keep the fork edit (rename heading so it is no longer Agent0-titled),\n'
      printf '   OR accept the Agent0 body (overwrite fork edit).\n'
      printf '2. Apply the decisions in `CLAUDE.md` directly.\n'
      printf '3. Re-run sync; a fresh migration candidate is generated once divergences are gone.\n'
    } > "$report"
    printf 'claude-md-migration-blocked: %s sections diverged — see .claude/CLAUDE.md.diverged-sections.md\n' "$count" >&2
    rm -f "$src_region_tmp"
    return
  fi

  # No body divergence — generate candidate (or report-would in check/dry-run).
  if [ "$MODE" = "check" ] || [ "$DRY_RUN" -eq 1 ]; then
    printf 'claude-md-migration-advisory: would write candidate to .claude/CLAUDE.md.migration-candidate.md (--check/--dry-run: no file written)\n' >&2
    rm -f "$src_region_tmp"
    DRIFT=1
    return
  fi

  local candidate="$FORK_ROOT/.claude/CLAUDE.md.migration-candidate.md"
  mkdir -p "$(dirname "$candidate")"

  local src_region_h2 dst_h2 project_only_titles src_sha_short
  src_region_h2="$(extract_h2 "$src_region_tmp")"
  dst_h2="$(extract_h2 "$dst")"
  # Project-only sections = headings in dst NOT in Agent0's region, preserving dst order.
  if [ -z "$src_region_h2" ]; then
    project_only_titles="$dst_h2"
  else
    project_only_titles="$(printf '%s\n' "$dst_h2" | grep -Fxv -f <(printf '%s\n' "$src_region_h2") || true)"
  fi
  src_sha_short="$(sha_of "$src" | cut -c1-12)"

  {
    printf '%s\n' '<!--'
    printf 'Migration candidate generated by sync-harness.sh on %s.\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'Source: Agent0 CLAUDE.md (sha %s)\n' "$src_sha_short"
    printf '\n'
    printf 'Review this layout. If it matches your intent, run:\n'
    printf '  mv .claude/CLAUDE.md.migration-candidate.md CLAUDE.md\n'
    printf '\n'
    printf 'After ratification, subsequent syncs use the managed-block merge path: the\n'
    printf 'region between AGENT0:BEGIN and AGENT0:END is replaced wholesale on each\n'
    printf 'sync, propagating Agent0 ADDs and REMOVALs symmetrically (spec 058).\n'
    printf '%s\n\n' '-->'

    # Preamble: lines before the first ## heading in fork (file H1, intro paragraphs).
    awk '/^## / {exit} {print}' "$dst"

    # Project-only sections from fork (preserving fork's order).
    while IFS= read -r title; do
      [ -z "$title" ] && continue
      extract_section "$dst" "$title"
      printf '\n'
    done <<EOF
$project_only_titles
EOF

    # AGENT0 region (sourced from Agent0's wrapped CLAUDE.md).
    printf '%s\n' '<!-- AGENT0:BEGIN -->'
    cat "$src_region_tmp"
    printf '%s\n' '<!-- AGENT0:END -->'
  } > "$candidate"

  rm -f "$src_region_tmp"
  printf 'claude-md-migration-advisory: candidate written to .claude/CLAUDE.md.migration-candidate.md — review and `mv` to ratify\n' >&2
}

# Handle paired-marker state: replace region wholesale, refuse on body divergence.
_merge_claude_md_managed_block() {
  local rel="CLAUDE.md"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"

  if matches_force_except "$rel"; then
    printf '!! force-except %s (merge skipped)\n' "$rel" >&2
    CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
    return
  fi

  # Source must also be wrapped — fallback to legacy if not.
  local src_state
  src_state="$(detect_marker_state "$src")"
  if [ "$src_state" != "paired" ]; then
    printf '!! claude-md: Agent0 source CLAUDE.md is not wrapped (state=%s) — falling back to legacy merge\n' "$src_state" >&2
    _merge_claude_md_legacy
    return
  fi

  local src_region dst_region
  src_region="$(_extract_region "$src")"
  dst_region="$(_extract_region "$dst")"

  if [ "$src_region" = "$dst_region" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    return
  fi

  # Region differs. Check for body divergence (edits to shared section bodies).
  local diverged_titles
  diverged_titles="$(_check_region_divergence "$src" "$dst")"

  if [ -n "$diverged_titles" ] && [ "$FORCE" -ne 1 ]; then
    local count
    count="$(printf '%s\n' "$diverged_titles" | grep -c . || true)"
    if [ "$MODE" = "check" ]; then
      printf '!! customized %s (region body diverged in %s section(s))\n' "$rel" "$count"
      DRIFT=1
      return
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '!! claude-md: managed region diverged — %s section(s) body differs (dry-run: no report written)\n' "$count" >&2
      CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
      return
    fi
    _write_region_divergence_report "$src" "$dst" "$diverged_titles"
    printf '!! claude-md: managed region diverged — %s section(s) body differs (see .claude/CLAUDE.md.diverged-region.md)\n' "$count" >&2
    printf '   Move project customizations OUTSIDE markers, or accept Agent0 replacement via --force\n' >&2
    CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
    return
  fi

  if [ "$MODE" = "check" ]; then
    printf '~ would merge %s\n' "$rel"
    DRIFT=1
    return
  fi

  # Build new content: (pre-BEGIN incl marker) + src_region + (END marker onwards).
  local tmp begin_line end_line
  tmp="$(mktemp -t sync-claude-md-XXXXXX)"
  begin_line="$(grep -nE '^<!-- AGENT0:BEGIN -->$' "$dst" | head -1 | cut -d: -f1)"
  end_line="$(grep -nE '^<!-- AGENT0:END -->$' "$dst" | head -1 | cut -d: -f1)"

  head -n "$begin_line" "$dst" > "$tmp"
  if [ -n "$src_region" ]; then
    printf '%s\n' "$src_region" >> "$tmp"
  fi
  tail -n +"$end_line" "$dst" >> "$tmp"

  local forced_overwrite=0
  if [ "$FORCE" -eq 1 ] && [ -n "$diverged_titles" ]; then
    forced_overwrite=1
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    rm -f "$tmp"
    if [ "$forced_overwrite" -eq 1 ]; then
      printf '! overwritten %s (region replaced under --force, dry-run)\n' "$rel" >&2
      OVERWRITTEN=$((OVERWRITTEN + 1))
    else
      printf '~ merged %s (dry-run)\n' "$rel"
      MERGED=$((MERGED + 1))
    fi
    return
  fi

  mv "$tmp" "$dst"
  if [ "$forced_overwrite" -eq 1 ]; then
    printf '! overwritten %s (region replaced under --force)\n' "$rel" >&2
    OVERWRITTEN=$((OVERWRITTEN + 1))
  else
    printf '~ merged %s\n' "$rel"
    MERGED=$((MERGED + 1))
  fi
}

# Legacy heading-set append merge (spec 016). Fallback for unmigrated forks.
_merge_claude_md_legacy() {
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

# Dispatcher: routes by marker state in fork's CLAUDE.md.
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

  local state
  state="$(detect_marker_state "$dst")"
  case "$state" in
    paired)
      _merge_claude_md_managed_block
      ;;
    mismatched)
      printf '!! claude-md: markers mismatched — both BEGIN and END must be paired, or both absent\n' >&2
      CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
      ;;
    nested-invalid)
      printf '!! claude-md: nested or out-of-order markers — exactly one BEGIN before exactly one END required\n' >&2
      CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
      ;;
    absent|*)
      _merge_claude_md_legacy
      _generate_migration_candidate
      ;;
  esac
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
