#!/usr/bin/env bash
# .agent0/tools/audio.sh
#
# audio — runtime-neutral, local-first text-to-speech (synthesis). Spec 160.
# Sibling of /transcribe (recognition). Engines: Kokoro + Piper (local, free);
# fal (paid, opt-in via --remote). NOT music/SFX, NOT voice clone (deferred).
#
# Local lane: speech is synthesized ON-DEVICE (text/audio never leaves the
# machine; only weights/voices fetched once) -> manifest stayed_local:true.
# Paid lane (--remote): text is sent to fal -> stayed_local:false (stated).
#
# Usage:
#   audio.sh "<text>" [--engine kokoro|piper] [--remote] [--tier standard|premium]
#            [--asset] [--voice <name>] [--lang <code>] [--format mp3|wav]
#            [--quiet] [--json] [--exit-code]
#   audio.sh doctor | caps
#
# Result statuses (decoupled from exit code): ok | unavailable | error.
# Default exit 0 (advisory family); --exit-code maps ok=0 unavailable=2 error=3.
#
# Test/override env: AUDIO_PIPER_CMD, AUDIO_KOKORO_CMD, AUDIO_FFMPEG_BIN,
#   AUDIO_FAL_REST, AUDIO_NO_ACQUIRE, AUDIO_DRAFT_DIR, AUDIO_ASSET_DIR,
#   AUDIO_MANIFEST, AUDIO_TIERS, AUDIO_VOICE_CACHE, AUDIO_ESPEAK_OK.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# --- defaults / args ---------------------------------------------------------
SUBCMD=""; TEXT=""
ENGINE="kokoro"; REMOTE=0; TIER=""; ASSET=0
VOICE=""; LANG="en"; FORMAT="mp3"
QUIET=0; OUT_JSON=0; USE_EXIT_CODE=0

DRAFT_DIR="${AUDIO_DRAFT_DIR:-assets/generated/audio}"
ASSET_DIR="${AUDIO_ASSET_DIR:-assets/audio}"
MANIFEST="${AUDIO_MANIFEST:-assets/generated/.audio-manifest.jsonl}"
TIERS="${AUDIO_TIERS:-$HERE/../skills/audio/references/audio-tiers.yaml}"
VOICE_CACHE="${AUDIO_VOICE_CACHE:-.agent0/.runtime-state/audio}"
FAL_REST="${AUDIO_FAL_REST:-$HERE/fal-rest.sh}"

while [ $# -gt 0 ]; do
  case "$1" in
    doctor|caps) SUBCMD="$1" ;;
    --engine) shift; ENGINE="${1:-kokoro}" ;;
    --engine=*) ENGINE="${1#*=}" ;;
    --remote) REMOTE=1 ;;
    --tier) shift; TIER="${1:-}" ;;
    --tier=*) TIER="${1#*=}" ;;
    --asset) ASSET=1 ;;
    --voice) shift; VOICE="${1:-}" ;;
    --voice=*) VOICE="${1#*=}" ;;
    --lang) shift; LANG="${1:-en}" ;;
    --lang=*) LANG="${1#*=}" ;;
    --format) shift; FORMAT="${1:-mp3}" ;;
    --format=*) FORMAT="${1#*=}" ;;
    --quiet) QUIET=1 ;;
    --json) OUT_JSON=1 ;;
    --exit-code) USE_EXIT_CODE=1 ;;
    -h|--help) sed -n '3,30p' "$0"; exit 0 ;;
    -*) echo "audio: unknown flag: $1" >&2; exit 64 ;;
    *) [ -z "$TEXT" ] && TEXT="$1" || { echo "audio: unexpected arg: $1" >&2; exit 64; } ;;
  esac
  shift
done

# shared capacity kernel (spec 163) — cap_have/sha/cap_emit_exit/manifest mechanic.
# Sourced here (below the --help line range) so cap_* is defined before first use.
. "$HERE/lib/capacity.sh" 2>/dev/null || { echo "audio: missing kit library lib/capacity.sh" >&2; exit 70; }
# paid-media sub-kit (spec 164) — pm_yaml_*/pm_has_fal_key/pm_fal_key_state (pure helpers)
. "$HERE/lib/paid-media.sh" 2>/dev/null || { echo "audio: missing kit library lib/paid-media.sh" >&2; exit 70; }
CAP_TOOL="audio"

espeak_ok() {
  case "${AUDIO_ESPEAK_OK:-}" in
    1) return 0 ;;   # forced present (test)
    0) return 1 ;;   # forced absent (test)
  esac
  cap_have espeak-ng || cap_have espeak
}

# --- capability resolution ---------------------------------------------------
declare -a PIPER_CMD=() KOKORO_CMD=()

resolve_piper() {
  PIPER_CMD=()
  if [ -n "${AUDIO_PIPER_CMD:-}" ]; then read -r -a PIPER_CMD <<< "$AUDIO_PIPER_CMD"; return 0; fi
  if cap_have piper; then PIPER_CMD=(piper); return 0; fi
  if [ "${AUDIO_NO_ACQUIRE:-0}" != "1" ] && cap_have uvx; then PIPER_CMD=(uvx --from piper-tts piper); return 0; fi
  return 1
}
resolve_kokoro() {
  KOKORO_CMD=()
  if [ -n "${AUDIO_KOKORO_CMD:-}" ]; then read -r -a KOKORO_CMD <<< "$AUDIO_KOKORO_CMD"; return 0; fi
  espeak_ok || return 2   # 2 = espeak-ng missing (distinct hint)
  if [ "${AUDIO_NO_ACQUIRE:-0}" != "1" ] && cap_have uvx; then
    KOKORO_CMD=(uvx --with kokoro --with soundfile python "$HERE/audio-kokoro.py"); return 0
  fi
  return 1
}
resolve_ffmpeg() { FFMPEG_BIN="${AUDIO_FFMPEG_BIN:-}"; [ -n "$FFMPEG_BIN" ] && return 0; cap_have ffmpeg && { FFMPEG_BIN=ffmpeg; return 0; }; return 1; }

channels() { local c=""; cap_have uvx && c="$c uvx"; cap_have pip && c="$c pip"; cap_have espeak-ng && c="$c espeak-ng"; cap_have ffmpeg && c="$c ffmpeg"; echo "${c# }"; }

# --- caps / doctor -----------------------------------------------------------
if [ "$SUBCMD" = "caps" ]; then
  resolve_piper && P="${PIPER_CMD[*]}" || P=""
  resolve_kokoro && K="${KOKORO_CMD[*]}" || K=""
  esp=$(espeak_ok && echo yes || echo no)
  if cap_have jq; then
    jq -n --arg p "$P" --arg k "$K" --arg esp "$esp" --arg ch "$(channels)" --argjson fk "$(pm_has_fal_key && echo true || echo false)" \
      '{kokoro:(if $k=="" then null else $k end), piper:(if $p=="" then null else $p end),
        espeak_ng:$esp, paid_fal_key:$fk,
        channels:($ch|split(" ")|map(select(.!="")))}'
  else
    echo "{\"kokoro\":\"$K\",\"piper\":\"$P\",\"espeak_ng\":\"$esp\"}"
  fi
  exit 0
fi
if [ "$SUBCMD" = "doctor" ]; then
  echo "audio — capability check"
  if resolve_kokoro; then echo "  [ ok ] kokoro: ${KOKORO_CMD[*]}"
  elif espeak_ok; then echo "  [warn] kokoro: no uvx to auto-acquire"
  else echo "  [warn] kokoro: needs espeak-ng (apt-get install espeak-ng / brew install espeak-ng)"; fi
  if resolve_piper; then echo "  [ ok ] piper: ${PIPER_CMD[*]}"; else echo "  [warn] piper: absent — install uv to auto-acquire"; fi
  resolve_ffmpeg && echo "  [ ok ] ffmpeg: $FFMPEG_BIN" || echo "  [warn] ffmpeg: absent (mp3 encode needs it; --format wav works without)"
  key_state=$(pm_fal_key_state)
  echo "  [info] paid lane: FAL_KEY $key_state; tiers: $TIERS"
  echo "  [info] draft dir: $DRAFT_DIR (gitignored) | asset dir: $ASSET_DIR (tracked) | manifest: $MANIFEST"
  exit 0
fi

# --- manifest + exit ---------------------------------------------------------
TEXT_SHA=""; CHARS=0; OUTPUT=""; LANE=""; PROVIDER=""; PMODEL=""; COST=""; RID=""; STAYED=true
append_manifest() {  # audio's manifest schema; mechanics from cap_manifest_append
  local status="$1" line
  cap_have jq || return 0
  line="$(jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg st "$status" --arg sha "$TEXT_SHA" \
      --argjson chars "${CHARS:-0}" --arg lane "$LANE" --arg engine "$ENGINE" --arg voice "$VOICE" \
      --arg lang "$LANG" --arg out "$OUTPUT" --arg fmt "$FORMAT" --arg cls "$([ "$ASSET" = 1 ] && echo asset || echo draft)" \
      --arg prov "$PROVIDER" --arg pm "$PMODEL" --arg cost "$COST" --arg rid "$RID" --argjson local "$STAYED" \
      '{ts:$ts,status:$st,text_sha256:$sha,chars:$chars,lane:$lane,output:$out,format:$fmt,class:$cls,stayed_local:$local}
       + (if $lane=="paid" then {provider:$prov,model:$pm,cost_estimate_usd:($cost|tonumber? // null),request_id:$rid}
          else {engine:$engine,voice:$voice,language:$lang} end)')" || return 0
  cap_manifest_append "$MANIFEST" "$line"
}
# cap_emit_exit from lib/capacity.sh (cap_emit_exit). audio keeps a LOCAL fail() —
# its --json error shape is pretty (jq -n), unlike the kernel's compact cap_fail
# (a pre-existing inconsistency; normalizing it would be a behavior change → follow-up).
fail() { local st="$1" msg="$2"; append_manifest "$st"
  if [ "$OUT_JSON" -eq 1 ] && cap_have jq; then jq -n --arg s "$st" --arg m "$msg" '{status:$s,message:$m}'
  else echo "audio: status=$st"; echo "  $msg"; fi
  cap_emit_exit "$st"; }

# --- main flow ---------------------------------------------------------------
[ -n "$TEXT" ] || { echo "audio: no text. usage: audio.sh \"<text>\" [flags]" >&2; exit 64; }
TEXT_SHA="$(cap_sha256_str "$TEXT")"; CHARS=${#TEXT}
OUT_DIR="$DRAFT_DIR"; [ "$ASSET" = 1 ] && OUT_DIR="$ASSET_DIR"
mkdir -p "$OUT_DIR" 2>/dev/null || fail error "cannot create output dir: $OUT_DIR"
STEM="audio-${TEXT_SHA:0:8}"
WORKDIR="$(mktemp -d -t audio-XXXXXX)"; trap 'rm -rf "$WORKDIR"' EXIT

encode_or_place() {  # $1 = produced wav/file ; sets OUTPUT
  local src="$1" final="$OUT_DIR/$STEM.$FORMAT"
  if [ "$FORMAT" = "wav" ]; then cp "$src" "$final"
  else
    if resolve_ffmpeg; then "$FFMPEG_BIN" -nostdin -y -i "$src" "$final" >/dev/null 2>&1 || { cp "$src" "$OUT_DIR/$STEM.wav"; final="$OUT_DIR/$STEM.wav"; FORMAT=wav; }
    else cp "$src" "$OUT_DIR/$STEM.wav"; final="$OUT_DIR/$STEM.wav"; FORMAT=wav; fi
  fi
  OUTPUT="$final"
}

if [ "$REMOTE" = 1 ]; then
  # ---- paid lane (fal) ----
  LANE="paid"; STAYED=false
  pm_has_fal_key || fail unavailable "--remote needs FAL_KEY (paid lane). Set it, or use the free local lane (drop --remote)."
  [ -f "$TIERS" ] || fail error "tiers file not found: $TIERS"
  cap_have jq || fail error "jq required for the paid lane"
  [ -n "$TIER" ] || TIER="$(pm_yaml_top "$TIERS" default_tier)"
  # pull model + rate for the tier from the yaml oracle (lib/paid-media.sh, spec 164)
  PMODEL="$(pm_yaml_tier_field "$TIERS" "$TIER" model)"
  RATE="$(pm_yaml_tier_field "$TIERS" "$TIER" price_per_1k_chars)"
  [ -n "$PMODEL" ] || fail error "tier '$TIER' not found in $TIERS"
  PROVIDER="fal"
  COST="$(awk -v c="$CHARS" -v r="${RATE:-0}" 'BEGIN{u=int((c+999)/1000); if(u<1)u=1; printf "%.4f", u*r}')"
  echo "audio: paid tier=$TIER model=$PMODEL  ~\$$COST for $CHARS chars (printed BEFORE the call)"
  body="$(jq -nc --arg t "$TEXT" --arg v "$VOICE" '{text:$t} + (if $v=="" then {} else {voice:$v} end)')"
  resp="$("$FAL_REST" run --model="$PMODEL" --body="$body" 2>/dev/null)" || fail error "fal call failed (model $PMODEL)"
  url="$(printf '%s' "$resp" | jq -r '(.audio.url // .audio_url // .url // empty)' 2>/dev/null)"
  [ -n "$url" ] || fail error "fal response carried no audio url"
  RID="$(printf '%s' "$resp" | jq -r '(.request_id // empty)' 2>/dev/null)"
  dl="$WORKDIR/paid.audio"
  "$FAL_REST" download --url="$url" --output="$dl" >/dev/null 2>&1 || fail error "failed to download fal audio asset"
  encode_or_place "$dl"
else
  # ---- local lane ----
  LANE="local"; STAYED=true
  case "$ENGINE" in
    kokoro)
      [ -n "$VOICE" ] || { VOICE="af_heart"; case "$LANG" in pt*|br) VOICE="pf_dora";; esac; }
      rc=0; resolve_kokoro || rc=$?
      if [ "$rc" = 2 ]; then fail unavailable "Kokoro needs espeak-ng (a system binary). Install it: 'apt-get install espeak-ng' (Linux) or 'brew install espeak-ng' (macOS), then re-run. Or use --engine piper (self-contained)."
      elif [ "$rc" != 0 ]; then fail unavailable "Kokoro engine could not be auto-acquired (need uv). Install uv (https://docs.astral.sh/uv/) or use --engine piper."; fi
      wav="$WORKDIR/out.wav"
      "${KOKORO_CMD[@]}" --text "$TEXT" --voice "$VOICE" --lang "$LANG" --out "$wav" >/dev/null 2>&1 || fail error "Kokoro synthesis failed (voice=$VOICE lang=$LANG)"
      ;;
    piper)
      [ -n "$VOICE" ] || { VOICE="en_US-lessac-medium"; case "$LANG" in pt*|br) VOICE="pt_BR-faber-medium";; esac; }
      resolve_piper || fail unavailable "Piper engine could not be auto-acquired (need uv or 'piper' on PATH). Install uv (https://docs.astral.sh/uv/) and re-run."
      # voice model (.onnx) from HF rhasspy/piper, cached
      mkdir -p "$VOICE_CACHE" 2>/dev/null
      onnx="$VOICE_CACHE/$VOICE.onnx"
      if [ ! -f "$onnx" ] && [ "${AUDIO_NO_ACQUIRE:-0}" != "1" ] && cap_have curl; then
        # HF rhasspy/piper-voices layout is nested: <fam>/<locale>/<name>/<quality>/<voice>.onnx
        # VOICE = <locale>-<name>-<quality>, e.g. en_US-lessac-medium
        locale="${VOICE%%-*}"; rest="${VOICE#*-}"; vname="${rest%%-*}"; quality="${rest#*-}"; fam="${locale%%_*}"
        relbase="https://huggingface.co/rhasspy/piper-voices/resolve/main/$fam/$locale/$vname/$quality/$VOICE.onnx"
        echo "audio: first-run setup — fetching Piper voice '$VOICE'…" >&2
        curl -fsSL -o "$onnx" "$relbase" 2>/dev/null
        curl -fsSL -o "$onnx.json" "$relbase.json" 2>/dev/null
      fi
      [ -f "$onnx" ] || fail unavailable "Piper voice '$VOICE' not cached and could not be fetched. Pre-place $onnx (+ .json), or check connectivity."
      wav="$WORKDIR/out.wav"
      printf '%s' "$TEXT" | "${PIPER_CMD[@]}" --model "$onnx" --output_file "$wav" >/dev/null 2>&1 || fail error "Piper synthesis failed (voice=$VOICE)"
      ;;
    *) fail error "unknown --engine '$ENGINE' (allowed: kokoro, piper)";;
  esac
  [ -f "$wav" ] || fail error "engine produced no audio"
  encode_or_place "$wav"
fi

append_manifest ok
if [ "$OUT_JSON" -eq 1 ] && cap_have jq; then
  jq -n --arg out "$OUTPUT" --arg lane "$LANE" --argjson local "$STAYED" '{status:"ok",output:$out,lane:$lane,stayed_local:$local}'
else
  echo "audio: status=ok"
  echo "  lane=$LANE${LANE:+ }$([ "$LANE" = local ] && echo "engine=$ENGINE voice=$VOICE lang=$LANG" || echo "tier=$TIER model=$PMODEL cost~\$$COST")"
  echo "  wrote: $OUTPUT  (class=$([ "$ASSET" = 1 ] && echo asset || echo draft), stayed_local=$STAYED)"
fi
cap_emit_exit ok
