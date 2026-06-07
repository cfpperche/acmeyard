#!/usr/bin/env bash
# .agent0/tools/lib/capacity.sh — shared KERNEL for Agent0 capacity tools. Spec 163.
#
# Sourced by the capacity tools (audio/sound/transcribe/diagram/…) so the shared
# plumbing lives + is tested once instead of being hand-copied per tool. Small,
# flat, readable — helpers, NOT a framework. Each tool still owns its own main
# control flow, arg parsing, doctor/caps domain fields, manifest *schema*, engine
# invocation, and storage policy. Companion: lib/paid-media.sh (paid sub-kit).
# Precedent: lib/managed-block.sh. Propagated to consumers via sync-harness.
#
# CONVENTION (the tool sets these globals; the kernel reads them):
#   USE_EXIT_CODE  0|1  — whether --exit-code maps status→exit
#   OUT_JSON       0|1  — whether to emit JSON
#   CAP_TOOL       str  — the tool name used in human-readable status lines
# HOOK (optional; the tool defines it to record its own manifest fields):
#   _cap_on_fail <status>  — called by cap_fail before it emits/exits
#
# Behavior is byte-identical to the per-tool copies it replaces — proven by the
# golden parity gate (.agent0/tests/capacity-kit/golden.sh).

# --- predicates / hashing (verbatim-identical across tools) ------------------
cap_have() { command -v "$1" >/dev/null 2>&1; }
cap_sha256_str()  { printf '%s' "$1" | { sha256sum 2>/dev/null || shasum -a 256 2>/dev/null; } | awk '{print $1}'; }
cap_sha256_file() { { sha256sum "$1" 2>/dev/null || shasum -a 256 "$1" 2>/dev/null; } | awk '{print $1}'; }

# --- ffmpeg resolution (parameterized: the env-override name differs per tool) -
# Sets FFMPEG_BIN and returns 0 on success. $1 = the tool's override env var name
# (e.g. AUDIO_FFMPEG_BIN). Reads it indirectly so one impl serves every tool.
cap_resolve_ffmpeg() {
  local envname="$1" override=""
  [ -n "$envname" ] && override="${!envname:-}"
  FFMPEG_BIN="$override"
  [ -n "$FFMPEG_BIN" ] && return 0
  cap_have ffmpeg && { FFMPEG_BIN=ffmpeg; return 0; }
  return 1
}

# --- status → exit mapping (verbatim-identical) ------------------------------
# Reads global USE_EXIT_CODE. Default exit 0 (the advisory-family contract).
cap_emit_exit() {
  [ "${USE_EXIT_CODE:-0}" -eq 1 ] && case "$1" in ok) exit 0;; unavailable) exit 2;; error) exit 3;; esac
  exit 0
}

# --- manifest append mechanics (shared; the tool supplies the line/fields) ----
# $1 = manifest path, $2 = a single pre-built JSONL line. Owns the discipline:
# mkdir + one-line-per-call append. The tool builds the line (its own schema +
# its own jq-presence decision); the kernel never decides fields or guards jq —
# an empty line is a no-op, so the caller's jq guard is preserved.
cap_manifest_append() {
  local mp="$1" line="$2"
  [ -n "$line" ] || return 0
  mkdir -p "$(dirname "$mp")" 2>/dev/null || return 0
  printf '%s\n' "$line" >> "$mp" 2>/dev/null
}

# --- unified failure path (status + json/text + manifest hook + exit) ---------
# Reads OUT_JSON + CAP_TOOL; calls the optional _cap_on_fail hook (tool records
# its manifest). Byte-identical to each tool's former fail().
cap_fail() {
  local st="$1" msg="$2"
  declare -F _cap_on_fail >/dev/null 2>&1 && _cap_on_fail "$st"
  if [ "${OUT_JSON:-0}" -eq 1 ] && cap_have jq; then
    jq -nc --arg s "$st" --arg m "$msg" '{status:$s,message:$m}'
  else
    echo "${CAP_TOOL:-tool}: status=$st"; echo "  $msg"
  fi
  cap_emit_exit "$st"
}
