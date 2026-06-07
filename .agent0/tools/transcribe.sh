#!/usr/bin/env bash
# .agent0/tools/transcribe.sh
#
# transcribe — runtime-neutral, local-first speech-to-text.
# Spec: docs/specs/159-transcribe/. Engine: whisper.cpp (MIT).
#
# Philosophy (decision-grade meeting audio-transcribe-media-family-skills):
# a LOCAL UTILITY in the vuln-audit class, NOT paid media. Provenance manifest,
# no cost apparatus. Audio/video content never leaves the machine; only the
# model weights are fetched (once). Acquisition + operation are as automated and
# invisible as possible; honest degrade to a one-line hint when impossible.
#
# Usage:
#   transcribe.sh <file> [--format <csv>] [--model <name>] [--lang <code>]
#                        [--output <dir>] [--quiet] [--json] [--exit-code]
#   transcribe.sh doctor      # human-readable tri-state of engine/ffmpeg/model
#   transcribe.sh caps        # machine-readable capability JSON
#
#   <file>          audio OR video file (video → audio track extracted via ffmpeg)
#   --format <csv>  any of: txt,srt,vtt,json,json-full,csv,lrc  (default: txt)
#   --model <name>  whisper ggml model (default: base ; multilingual)
#   --lang <code>   force language (default: auto-detect)
#   --output <dir>  transcripts dir (default: assets/transcripts, gitignored)
#   --quiet         do NOT echo the txt transcript to stdout
#   --json          emit a structured status doc on stdout (shape-only)
#   --exit-code     map result status -> exit code: ok=0 unavailable=2 error=3
#                   WITHOUT this flag the process ALWAYS exits 0 (advisory family)
#
# Result statuses (first-class, decoupled from exit code):
#   ok           transcription produced
#   unavailable  engine/ffmpeg could not be found or auto-acquired (with hint)
#   error        an input/runtime error (missing file, engine failure)
#
# Test/override env: TRANSCRIBE_WHISPER_BIN, TRANSCRIBE_FFMPEG_BIN,
#   TRANSCRIBE_MODEL_DIR, TRANSCRIBE_OUTPUT_DIR, TRANSCRIBE_MANIFEST,
#   TRANSCRIBE_NO_ACQUIRE, TRANSCRIBE_UVX_PKG, TRANSCRIBE_UVX_SCRIPT.

set -uo pipefail

# shared capacity kernel (spec 163) — cap_have / cap_emit_exit / manifest mechanic
_HERE="$(cd "$(dirname "$0")" && pwd)"
. "$_HERE/lib/capacity.sh" 2>/dev/null || { echo "transcribe: missing kit library lib/capacity.sh" >&2; exit 70; }
CAP_TOOL="transcribe"

# ---------------------------------------------------------------------------
# Defaults / args
# ---------------------------------------------------------------------------
SUBCMD=""
INPUT=""
FORMATS="txt"
MODEL="base"
LANG=""
OUTPUT_DIR="${TRANSCRIBE_OUTPUT_DIR:-assets/transcripts}"
QUIET=0
OUT_JSON=0
USE_EXIT_CODE=0

MODEL_DIR="${TRANSCRIBE_MODEL_DIR:-.agent0/.runtime-state/transcribe/models}"
MANIFEST="${TRANSCRIBE_MANIFEST:-assets/generated/.transcribe-manifest.jsonl}"
UVX_PKG="${TRANSCRIBE_UVX_PKG:-whisper.cpp-cli}"
UVX_SCRIPT="${TRANSCRIBE_UVX_SCRIPT:-whisper-cpp}"   # package 'whisper.cpp-cli' exposes 'whisper-cpp' (verified in dogfood)

while [ $# -gt 0 ]; do
  case "$1" in
    doctor|caps) SUBCMD="$1" ;;
    --format) shift; FORMATS="${1:-txt}" ;;
    --format=*) FORMATS="${1#*=}" ;;
    --model) shift; MODEL="${1:-base}" ;;
    --model=*) MODEL="${1#*=}" ;;
    --lang) shift; LANG="${1:-}" ;;
    --lang=*) LANG="${1#*=}" ;;
    --output) shift; OUTPUT_DIR="${1:-$OUTPUT_DIR}" ;;
    --output=*) OUTPUT_DIR="${1#*=}" ;;
    --quiet) QUIET=1 ;;
    --json) OUT_JSON=1 ;;
    --exit-code) USE_EXIT_CODE=1 ;;
    -h|--help) sed -n '3,38p' "$0"; exit 0 ;;
    -*) echo "transcribe: unknown flag: $1" >&2; exit 64 ;;
    *) [ -z "$INPUT" ] && INPUT="$1" || { echo "transcribe: unexpected arg: $1" >&2; exit 64; } ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------
# cap_have() comes from lib/capacity.sh (cap_have)
sha256_of() {
  if cap_have sha256sum; then sha256sum "$1" 2>/dev/null | awk '{print $1}';
  elif cap_have shasum; then shasum -a 256 "$1" 2>/dev/null | awk '{print $1}';
  else echo ""; fi
}

# WHISPER_CMD is an array (a binary path, or "uvx --from pkg script").
declare -a WHISPER_CMD=()

resolve_whisper() {
  WHISPER_CMD=()
  if [ -n "${TRANSCRIBE_WHISPER_BIN:-}" ]; then WHISPER_CMD=("$TRANSCRIBE_WHISPER_BIN"); return 0; fi
  local b
  for b in whisper-cli whisper-cpp whisper main; do
    if cap_have "$b"; then WHISPER_CMD=("$b"); return 0; fi
  done
  if [ -x "$MODEL_DIR/../bin/whisper-cli" ]; then WHISPER_CMD=("$MODEL_DIR/../bin/whisper-cli"); return 0; fi
  # Auto-acquire (ephemeral, safe): uvx runs the prebuilt CLI wheel without a
  # persistent install. Only path that is genuinely "invisible".
  if [ "${TRANSCRIBE_NO_ACQUIRE:-0}" != "1" ] && cap_have uvx; then
    WHISPER_CMD=(uvx --from "$UVX_PKG" "$UVX_SCRIPT"); return 0
  fi
  return 1
}

FFMPEG_BIN=""
resolve_ffmpeg() {
  if [ -n "${TRANSCRIBE_FFMPEG_BIN:-}" ]; then FFMPEG_BIN="$TRANSCRIBE_FFMPEG_BIN"; return 0; fi
  if cap_have ffmpeg; then FFMPEG_BIN="ffmpeg"; return 0; fi
  return 1
}

MODEL_FILE=""
resolve_model() {
  MODEL_FILE="$MODEL_DIR/ggml-${MODEL}.bin"
  [ -f "$MODEL_FILE" ] && return 0
  if [ "${TRANSCRIBE_NO_ACQUIRE:-0}" = "1" ]; then return 1; fi
  cap_have curl || return 1
  mkdir -p "$MODEL_DIR" 2>/dev/null || return 1
  echo "transcribe: first-run setup — fetching whisper '$MODEL' model (one-time)…" >&2
  if curl -fsSL -o "$MODEL_FILE.partial" \
       "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${MODEL}.bin" 2>/dev/null; then
    mv "$MODEL_FILE.partial" "$MODEL_FILE"; return 0
  fi
  rm -f "$MODEL_FILE.partial" 2>/dev/null; return 1
}

# format name -> "whisper-flag ext"
fmt_spec() {
  case "$1" in
    txt)       echo "-otxt txt" ;;
    srt)       echo "-osrt srt" ;;
    vtt)       echo "-ovtt vtt" ;;
    json)      echo "-oj json" ;;
    json-full) echo "-ojf json" ;;
    csv)       echo "-ocsv csv" ;;
    lrc)       echo "-olrc lrc" ;;
    *) echo "" ;;
  esac
}

acquisition_hint() {
  if cap_have brew; then echo "brew install whisper-cpp  (or: install uv — https://docs.astral.sh/uv/ — and re-run)";
  elif cap_have uv || cap_have uvx; then echo "uv present but the wheel could not run; try: uvx --from whisper.cpp-cli whisper-cli --help";
  else echo "install uv (one line: https://docs.astral.sh/uv/) then re-run, or 'brew install whisper-cpp' on macOS"; fi
}

# ---------------------------------------------------------------------------
# Subcommands: caps / doctor
# ---------------------------------------------------------------------------
detect_report() {
  # echoes: whisper_status ffmpeg_status model_status channels
  local ws fs ms ch=""
  if resolve_whisper; then ws="${WHISPER_CMD[*]}"; else ws=""; fi
  if resolve_ffmpeg; then fs="$FFMPEG_BIN"; else fs=""; fi
  if [ -f "$MODEL_DIR/ggml-${MODEL}.bin" ]; then ms="cached"; else ms="not-cached"; fi
  cap_have uvx && ch="$ch uvx"; cap_have pipx && ch="$ch pipx"; cap_have pip && ch="$ch pip"; cap_have brew && ch="$ch brew"
  printf '%s\t%s\t%s\t%s\n' "$ws" "$fs" "$ms" "${ch# }"
}

if [ "$SUBCMD" = "caps" ]; then
  IFS=$'\t' read -r ws fs ms ch < <(detect_report)
  if cap_have jq; then
    jq -n --arg w "$ws" --arg f "$fs" --arg m "$ms" --arg model "$MODEL" --arg ch "$ch" \
      '{engine:(if $w=="" then null else $w end), ffmpeg:(if $f=="" then null else $f end),
        model:$model, model_cache:$m, acquisition_channels:($ch|split(" ")|map(select(.!="")))}'
  else
    echo "{\"engine\":\"$ws\",\"ffmpeg\":\"$fs\",\"model\":\"$MODEL\",\"model_cache\":\"$ms\",\"acquisition_channels\":\"$ch\"}"
  fi
  exit 0
fi

if [ "$SUBCMD" = "doctor" ]; then
  IFS=$'\t' read -r ws fs ms ch < <(detect_report)
  echo "transcribe — capability check"
  if [ -n "$ws" ]; then echo "  [ ok ] whisper engine: $ws";
  elif [ -n "$ch" ]; then echo "  [warn] whisper engine: not present — auto-acquire channel(s):$([ -n "$ch" ] && echo " $ch")";
  else echo "  [warn] whisper engine: not present — $(acquisition_hint)"; fi
  if [ -n "$fs" ]; then echo "  [ ok ] ffmpeg: $fs"; else echo "  [warn] ffmpeg: not present (needed for non-WAV / video input)"; fi
  echo "  [info] default model '$MODEL': $ms  (cache: $MODEL_DIR)"
  echo "  [info] transcripts dir: $OUTPUT_DIR (gitignored)   manifest: $MANIFEST"
  exit 0   # doctor never fails the harness
fi

# ---------------------------------------------------------------------------
# Manifest + exit helpers
# ---------------------------------------------------------------------------
append_manifest() {
  # $1 status ; uses globals INPUT INHASH DURATION MODEL LANG OUTPUTS_JSON
  local status="$1" line
  if cap_have jq; then
    line="$(jq -cn \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg status "$status" \
      --arg input "$INPUT" \
      --arg hash "${INHASH:-}" \
      --arg dur "${DURATION:-}" \
      --arg engine "${WHISPER_CMD[*]:-}" \
      --arg model "$MODEL" \
      --arg lang "${LANG:-auto}" \
      --argjson outputs "${OUTPUTS_JSON:-[]}" \
      '{ts:$ts,status:$status,input:$input,input_sha256:$hash,
        duration:(if $dur=="" then null else $dur end),
        engine:$engine,model:$model,language:$lang,
        outputs:$outputs,stayed_local:true}')" || return 0
  else
    line="$(printf '{"ts":"%s","status":"%s","input":"%s","model":"%s","stayed_local":true}' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$INPUT" "$MODEL")"
  fi
  cap_manifest_append "$MANIFEST" "$line"
}

# cap_emit_exit() comes from lib/capacity.sh (cap_emit_exit)
fail() {
  # $1 status ; $2 message
  local status="$1" msg="$2"
  INHASH="${INHASH:-}"; OUTPUTS_JSON="${OUTPUTS_JSON:-[]}"
  append_manifest "$status"
  if [ "$OUT_JSON" -eq 1 ] && cap_have jq; then
    jq -n --arg s "$status" --arg m "$msg" --arg in "$INPUT" '{status:$s,input:$in,message:$m,outputs:[]}'
  else
    echo "transcribe: status=$status"
    echo "  $msg"
  fi
  cap_emit_exit "$status"
}

# ---------------------------------------------------------------------------
# Transcribe flow
# ---------------------------------------------------------------------------
INHASH=""
DURATION=""
OUTPUTS_JSON="[]"

[ -n "$INPUT" ] || { echo "transcribe: no input file. usage: transcribe.sh <file> [flags]" >&2; exit 64; }
[ -f "$INPUT" ] || fail error "input file not found: $INPUT"

INHASH="$(sha256_of "$INPUT")"

# Resolve engine (detect or auto-acquire).
if ! resolve_whisper; then
  fail unavailable "whisper engine not found and could not be auto-acquired. $(acquisition_hint)"
fi

# Resolve model (cache or fetch).
if ! resolve_model; then
  fail unavailable "whisper model '$MODEL' not cached and could not be fetched (need network + curl). Re-run with connectivity, or pre-place $MODEL_DIR/ggml-${MODEL}.bin"
fi

# Prepare a 16 kHz mono WAV (handles audio AND video; uniform path).
WORKDIR="$(mktemp -d -t transcribe-XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT
WAV="$WORKDIR/audio.wav"

if resolve_ffmpeg; then
  if ! "$FFMPEG_BIN" -nostdin -y -i "$INPUT" -ar 16000 -ac 1 -c:a pcm_s16le "$WAV" >/dev/null 2>&1; then
    fail error "ffmpeg failed to extract/transcode audio from: $INPUT"
  fi
  if cap_have ffprobe; then
    DURATION="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT" 2>/dev/null)"
  fi
else
  case "$INPUT" in
    *.wav|*.WAV) cp "$INPUT" "$WAV" ;;
    *) fail unavailable "ffmpeg not found — needed to read '$INPUT' (only raw .wav works without it). Install ffmpeg and re-run." ;;
  esac
fi

# Build the output prefix in the gitignored transcripts dir.
mkdir -p "$OUTPUT_DIR" 2>/dev/null || fail error "cannot create output dir: $OUTPUT_DIR"
base="$(basename "$INPUT")"; base="${base%.*}"
PREFIX="$OUTPUT_DIR/$base"

# Assemble whisper format flags (dedup ext collisions: json/json-full both .json).
declare -a FMT_FLAGS=()
declare -a WANT_FMTS=()
IFS=',' read -r -a _fmts <<< "$FORMATS"
for f in "${_fmts[@]}"; do
  f="$(echo "$f" | tr -d '[:space:]')"; [ -z "$f" ] && continue
  spec="$(fmt_spec "$f")"
  if [ -z "$spec" ]; then fail error "unknown --format '$f' (allowed: txt,srt,vtt,json,json-full,csv,lrc)"; fi
  FMT_FLAGS+=("${spec%% *}")
  WANT_FMTS+=("$f")
done
[ "${#FMT_FLAGS[@]}" -gt 0 ] || { FMT_FLAGS=(-otxt); WANT_FMTS=(txt); }

# Run whisper. Default to auto-detect ('-l auto') — whisper.cpp's own default is
# '-l en', which would silently punish non-English audio (meeting decision).
declare -a LANG_FLAG=(-l "${LANG:-auto}")
if ! "${WHISPER_CMD[@]}" -m "$MODEL_FILE" -f "$WAV" "${LANG_FLAG[@]}" -of "$PREFIX" "${FMT_FLAGS[@]}" >/dev/null 2>&1; then
  fail error "whisper engine failed to transcribe (engine: ${WHISPER_CMD[*]})"
fi

# Collect produced outputs.
declare -a PRODUCED=()
for f in "${WANT_FMTS[@]}"; do
  spec="$(fmt_spec "$f")"; ext="${spec##* }"
  outfile="$PREFIX.$ext"
  [ -f "$outfile" ] && PRODUCED+=("$outfile")
done
if cap_have jq; then
  OUTPUTS_JSON="$(printf '%s\n' "${PRODUCED[@]:-}" | jq -R . | jq -s 'map(select(.!=""))')"
else
  OUTPUTS_JSON="[]"
fi

# Record provenance.
append_manifest ok

# Echo txt to stdout (unless --quiet) + report.
TXT="$PREFIX.txt"
if [ "$OUT_JSON" -eq 1 ] && cap_have jq; then
  jq -n --arg in "$INPUT" --arg model "$MODEL" --argjson outputs "$OUTPUTS_JSON" \
    '{status:"ok",input:$in,model:$model,outputs:$outputs,stayed_local:true}'
else
  echo "transcribe: status=ok"
  echo "  input: $INPUT  (model: $MODEL, lang: ${LANG:-auto})"
  echo "  wrote: ${PRODUCED[*]:-(none)}"
  if [ "$QUIET" -eq 0 ] && [ -f "$TXT" ]; then
    echo "  --- transcript (txt) ---"
    cat "$TXT"
  fi
fi

cap_emit_exit ok
