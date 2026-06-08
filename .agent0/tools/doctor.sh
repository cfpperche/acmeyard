#!/usr/bin/env bash
# Agent0 `doctor` — harness health check.
#
# Answers "is this harness wired and recoverable?" with a per-check tri-state
# (ok / advisory / broken) and a severity-based exit code. Reports + proposes,
# never fixes (mirrors vuln-audit discipline). Runtime-neutral: inspects BOTH
# .claude/settings.json and .codex/hooks.json wiring. Invoke as
# `! bash .agent0/tools/doctor.sh` (human), or directly from any runtime. (Spec 137.)
#
# Exit code: non-zero iff any check is `broken`. Advisories never fail the exit.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The harness root to inspect — honor AGENT0_PROJECT_DIR (lets doctor check an
# arbitrary checkout / fixture), else the git root of this checkout.
if [ -n "${AGENT0_PROJECT_DIR:-}" ]; then
  PROJECT_DIR="$AGENT0_PROJECT_DIR"
else
  PROJECT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$PROJECT_DIR" ] || PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

OK=0; ADVISORY=0; BROKEN=0

# check <status> <name> <detail>
check() {
  local status="$1" name="$2" detail="$3" mark
  case "$status" in
    ok)       mark='[ ok ]      '; OK=$((OK + 1)) ;;
    advisory) mark='[ advisory ]'; ADVISORY=$((ADVISORY + 1)) ;;
    broken)   mark='[ BROKEN ]  '; BROKEN=$((BROKEN + 1)) ;;
  esac
  printf '%s %-34s %s\n' "$mark" "$name" "$detail"
}

# --- core harness files (missing/non-exec → broken) -------------------------
# check_file <relpath> [exec|dir]
#   exec → must be executable AND non-empty (presence != function, dogfood D2)
#   dir  → must be a directory, not a stray file of that name (dogfood D2)
check_file() {
  local rel="$1" mode="${2:-no}" abs="$PROJECT_DIR/$1"
  if [ ! -e "$abs" ]; then
    check broken "$rel" "missing"
  elif [ "$mode" = "dir" ]; then
    if [ -d "$abs" ]; then check ok "$rel" "present"; else check broken "$rel" "exists but is not a directory"; fi
  elif [ "$mode" = "exec" ] && [ ! -x "$abs" ]; then
    check broken "$rel" "exists but not executable"
  elif [ "$mode" = "exec" ] && [ ! -s "$abs" ]; then
    check broken "$rel" "present but empty"
  else
    check ok "$rel" "present"
  fi
}

printf '=== Agent0 doctor: core files ===\n'
check_file ".agent0/hooks/startup-brief.sh" exec
check_file ".agent0/hooks/_brief-compose.sh"
check_file ".agent0/hooks/_memory-hook-lib.sh"
check_file ".agent0/hooks/reminders-readout.sh" exec
check_file ".agent0/hooks/routines-readout.sh" exec
check_file ".agent0/tools/status.sh" exec
check_file ".agent0/tools/doctor.sh" exec
check_file ".agent0/tools/project-core-sync.sh" exec
check_file ".agent0/context/rules" dir
# Handoff absence is degraded, not fatal.
if [ -f "$PROJECT_DIR/.agent0/HANDOFF.md" ]; then
  check ok ".agent0/HANDOFF.md" "present"
else
  check advisory ".agent0/HANDOFF.md" "missing — session handoff disabled"
fi
if [ -f "$PROJECT_DIR/.agent0/project-core.md" ]; then
  pc_tool="$PROJECT_DIR/.agent0/tools/project-core-sync.sh"
  if [ -x "$pc_tool" ]; then
    pc_out="$(bash "$pc_tool" --check --quiet --root "$PROJECT_DIR" 2>&1)"; pc_rc=$?
    if [ "$pc_rc" -eq 0 ]; then
      pc_example_version=""
      pc_source_version=""
      if [ -f "$PROJECT_DIR/.agent0/project-core.md.example" ]; then
        pc_example_version="$(sed -n 's/^<!-- AGENT0:PROJECT-CORE-TEMPLATE: \(.*\) -->$/\1/p' "$PROJECT_DIR/.agent0/project-core.md.example" | head -1)"
        pc_source_version="$(sed -n 's/^<!-- AGENT0:PROJECT-CORE-TEMPLATE: \(.*\) -->$/\1/p' "$PROJECT_DIR/.agent0/project-core.md" | head -1)"
      fi
      if [ -n "$pc_example_version" ] && [ "$pc_source_version" != "$pc_example_version" ]; then
        check advisory "project-core" "template review pending — review .agent0/project-core.md.example, update .agent0/project-core.md marker to $pc_example_version, run .agent0/tools/project-core-sync.sh --apply"
      else
        check ok "project-core" ".agent0/project-core.md present; mirrors up to date"
      fi
    else
      check advisory "project-core" "mirror drift — run .agent0/tools/project-core-sync.sh --apply"
    fi
  else
    check advisory "project-core" ".agent0/project-core.md present; renderer missing"
  fi
elif [ -f "$PROJECT_DIR/.agent0/project-core.md.example" ]; then
  check advisory "project-core" "bootstrap pending — copy .agent0/project-core.md.example to .agent0/project-core.md, customize it, run .agent0/tools/project-core-sync.sh --apply"
fi

# --- hook wiring (per-runtime; contract validation, not substring) -----------
# Spec 139: validate the actual SessionStart→startup-brief binding, not a bare
# substring anywhere in the file (which passes on a comment / disabled block /
# wrong event). Config absent → advisory (runtime not configured here); config
# present but no valid binding → broken (the harness claims to be wired but is
# not); bound AND target present+executable → ok. jq absent → degrade to the old
# substring behavior tagged advisory (never crash).
printf '\n=== hook wiring ===\n'
BRIEF_REL=".agent0/hooks/startup-brief.sh"
BRIEF_ABS="$PROJECT_DIR/$BRIEF_REL"
wired_check() {
  local label="$1" file="$2" abs="$PROJECT_DIR/$2" cmd
  if [ ! -f "$abs" ]; then
    check advisory "$label" "$file absent (runtime not configured here)"
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    # jq is a REQUIRED binary (the binaries block already marks its absence
    # broken → the rollup is broken regardless). Here we can only report that the
    # wiring contract is unverifiable, not assert it; advisory is honest.
    if grep -q "startup-brief" "$abs" 2>/dev/null; then
      check advisory "$label" "references startup-brief (jq required to verify the binding — jq missing → rollup broken via binaries)"
    else
      check advisory "$label" "$file present; jq required to verify the binding — jq missing → rollup broken via binaries"
    fi
    return
  fi
  # Pull every SessionStart command string; match the one binding startup-brief.
  cmd="$(jq -r '[.hooks.SessionStart[]?.hooks[]?.command // empty] | map(select(test("startup-brief"))) | .[0] // empty' "$abs" 2>/dev/null)"
  if [ -z "$cmd" ]; then
    check broken "$label" "$file present but no SessionStart hook binds startup-brief"
  elif [ ! -x "$BRIEF_ABS" ]; then
    check broken "$label" "binds startup-brief but $BRIEF_REL is missing/not executable"
  else
    check ok "$label" "SessionStart → startup-brief, target present+exec"
  fi
}
wired_check "claude SessionStart" ".claude/settings.json"
wired_check "codex hooks" ".codex/hooks.json"

# --- git hooks activation ----------------------------------------------------
printf '\n=== git hooks ===\n'
if [ -d "$PROJECT_DIR/.githooks" ]; then
  hp="$(git -C "$PROJECT_DIR" config --get core.hooksPath 2>/dev/null || true)"
  if [ "$hp" = ".githooks" ]; then
    check ok "core.hooksPath" "activated (.githooks)"
  else
    check advisory "core.hooksPath" "NOT activated — run: git config core.hooksPath .githooks"
  fi
else
  check advisory "core.hooksPath" ".githooks/ absent — no native git hooks to wire"
fi

# --- binaries (required → broken; optional → advisory) -----------------------
printf '\n=== binaries ===\n'
bin_check() {
  local bin="$1" tier="$2" note="${3:-}"
  if command -v "$bin" >/dev/null 2>&1; then
    check ok "$bin" "found"
  elif [ "$tier" = "required" ]; then
    check broken "$bin" "MISSING (required) ${note}"
  else
    check advisory "$bin" "absent (optional) ${note}"
  fi
}
bin_check git      required
bin_check jq       required "— hook payload parsing degrades without it"
bin_check python3  required "— memory/context helpers need it"
bin_check gitleaks optional "— secrets pre-commit scan"
bin_check osv-scanner optional "— vuln-audit engine"

# --- agent-browser primitive (spec 152; sole primitive since 153) -------------
# Absent binary is ADVISORY, not broken — but browser functionality is then
# UNAVAILABLE (fail-closed; NO MCP fallback — browser-primitive.md, spec 153).
printf '\n=== browser primitive ===\n'
if [ -x "$PROJECT_DIR/.agent0/tools/agent-browser.sh" ]; then
  ab_caps="$(AGENT0_PROJECT_DIR="$PROJECT_DIR" bash "$PROJECT_DIR/.agent0/tools/agent-browser.sh" caps --json 2>/dev/null || echo '{}')"
  ab_bin="$(printf '%s' "$ab_caps" | jq -r '.binary // "no"' 2>/dev/null)"
  ab_vstate="$(printf '%s' "$ab_caps" | jq -r '.version_state // "unknown"' 2>/dev/null)"
  ab_chrome="$(printf '%s' "$ab_caps" | jq -r '.chrome // ""' 2>/dev/null)"
  if [ "$ab_bin" != "yes" ]; then
    check advisory "agent-browser" "binary absent — browser functionality UNAVAILABLE (fail-closed; install agent-browser, no MCP fallback)"
  elif [ "$ab_vstate" = "drift" ]; then
    check advisory "agent-browser" "present but version differs from pinned (browser-primitive.md § version pin)"
  elif [ -z "$ab_chrome" ]; then
    check advisory "agent-browser" "present; no system Chrome — relies on bundled Chrome-for-Testing"
  else
    check ok "agent-browser" "present (pinned); chrome ${ab_chrome}"
  fi
else
  check advisory "agent-browser" "wrapper .agent0/tools/agent-browser.sh missing"
fi

# --- transcribe (spec 159; opt-in local STT) ---------------------------------
# Absent/auto-acquirable engine is ADVISORY, never broken — the skill is opt-in
# and auto-acquires on first use. Reports, never fails the harness.
printf '\n=== transcribe ===\n'
if [ -x "$PROJECT_DIR/.agent0/tools/transcribe.sh" ]; then
  tr_caps="$(bash "$PROJECT_DIR/.agent0/tools/transcribe.sh" caps 2>/dev/null || echo '{}')"
  tr_engine="$(printf '%s' "$tr_caps" | jq -r '.engine // empty' 2>/dev/null)"
  tr_ffmpeg="$(printf '%s' "$tr_caps" | jq -r '.ffmpeg // empty' 2>/dev/null)"
  tr_chan="$(printf '%s' "$tr_caps" | jq -r '(.acquisition_channels // []) | join(" ")' 2>/dev/null)"
  if [ -n "$tr_engine" ]; then
    check ok "transcribe" "engine: $tr_engine; ffmpeg: ${tr_ffmpeg:-absent}"
  elif [ -n "$tr_chan" ]; then
    check advisory "transcribe" "engine absent but auto-acquirable via:${tr_chan:+ $tr_chan} (first run fetches it)"
  else
    check advisory "transcribe" "engine absent, no acquisition channel — install uv or 'brew install whisper-cpp' to enable"
  fi
else
  check advisory "transcribe" "wrapper .agent0/tools/transcribe.sh missing"
fi

# --- audio (spec 160; opt-in local-first TTS) --------------------------------
printf '\n=== audio ===\n'
if [ -x "$PROJECT_DIR/.agent0/tools/audio.sh" ]; then
  au_caps="$(bash "$PROJECT_DIR/.agent0/tools/audio.sh" caps 2>/dev/null || echo '{}')"
  au_kok="$(printf '%s' "$au_caps" | jq -r '.kokoro // empty' 2>/dev/null)"
  au_pip="$(printf '%s' "$au_caps" | jq -r '.piper // empty' 2>/dev/null)"
  au_esp="$(printf '%s' "$au_caps" | jq -r '.espeak_ng // "no"' 2>/dev/null)"
  if [ -n "$au_pip" ] || [ -n "$au_kok" ]; then
    eng="$([ -n "$au_kok" ] && echo "kokoro" )$([ -n "$au_kok" ] && [ -n "$au_pip" ] && echo "+")$([ -n "$au_pip" ] && echo "piper")"
    check ok "audio" "engine(s): $eng; espeak-ng: $au_esp"
  else
    check advisory "audio" "no TTS engine present/acquirable — install uv (auto-acquires Piper); Kokoro also needs espeak-ng"
  fi
else
  check advisory "audio" "wrapper .agent0/tools/audio.sh missing"
fi

# --- sound (spec 161; opt-in paid-only creative audio: music + SFX) -----------
printf '\n=== sound ===\n'
if [ -x "$PROJECT_DIR/.agent0/tools/sound.sh" ]; then
  so_caps="$(bash "$PROJECT_DIR/.agent0/tools/sound.sh" caps 2>/dev/null || echo '{}')"
  so_tiers="$(printf '%s' "$so_caps" | jq -r '.tiers_present // false' 2>/dev/null)"
  so_key="$(printf '%s' "$so_caps" | jq -r '.paid_fal_key // false' 2>/dev/null)"
  if [ "$so_tiers" = "true" ]; then
    check ok "sound" "paid-only (FAL_KEY $([ "$so_key" = true ] && echo set || echo unset, opt-in); tiers oracle present)"
  else
    check advisory "sound" "tiers oracle missing (.agent0/skills/sound/references/sound-tiers.yaml) — /sound cannot resolve a model"
  fi
else
  check advisory "sound" "wrapper .agent0/tools/sound.sh missing"
fi

# --- diagram (spec 162; opt-in local/free deterministic technical visuals) ----
printf '\n=== diagram ===\n'
if [ -x "$PROJECT_DIR/.agent0/tools/diagram.sh" ]; then
  dg_caps="$(bash "$PROJECT_DIR/.agent0/tools/diagram.sh" caps 2>/dev/null || echo '{}')"
  dg_mmdc="$(printf '%s' "$dg_caps" | jq -r '.mmdc // empty' 2>/dev/null)"
  dg_chrome="$(printf '%s' "$dg_caps" | jq -r '.chrome // empty' 2>/dev/null)"
  if [ -n "$dg_mmdc" ] && [ -n "$dg_chrome" ]; then
    check ok "diagram" "mermaid render ready (mmdc: $dg_mmdc; chrome present)"
  elif [ -n "$dg_mmdc" ]; then
    check advisory "diagram" "no usable Chrome — render degrades to validation-only (install google-chrome/chromium)"
  else
    check advisory "diagram" "no Node/npx to acquire mmdc — install Node (render needs @mermaid-js/mermaid-cli)"
  fi
else
  check advisory "diagram" "wrapper .agent0/tools/diagram.sh missing"
fi

# --- rollup ------------------------------------------------------------------
printf '\n=== rollup ===\n'
if [ "$BROKEN" -gt 0 ]; then
  verdict="BROKEN"
elif [ "$ADVISORY" -gt 0 ]; then
  verdict="ADVISORY"
else
  verdict="OK"
fi
printf '%s — %d ok, %d advisory, %d broken\n' "$verdict" "$OK" "$ADVISORY" "$BROKEN"

[ "$BROKEN" -gt 0 ] && exit 1
exit 0
