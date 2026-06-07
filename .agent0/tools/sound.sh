#!/usr/bin/env bash
# .agent0/tools/sound.sh
#
# sound — runtime-neutral generation of CREATIVE AUDIO (music + SFX). Spec 161.
# Paid-only by nature: there is no light local music/SFX engine (the /image brand
# analog, NOT the local-first /audio analog). Uses fal via fal-rest.sh, a
# data-driven sound-tiers.yaml oracle, cost-print, a hybrid confirm gate, and a
# hybrid manifest. Taste-judged: one generation -> gitignored draft -> human
# promotes a keeper with --asset (no automated "done").
#
# Usage:
#   sound.sh "<prompt>" --kind music|sfx [--tier standard|premium] [--duration <sec>]
#            [--asset] [--format mp3|wav] [--confirm-cost-usd <n>] [--json] [--exit-code]
#   sound.sh doctor | caps
#
# Result statuses (decoupled from exit code): ok | unavailable | error.
# Default exit 0; --exit-code maps ok=0 unavailable=2 error=3.
#
# Test/override env: SOUND_FAL_REST, SOUND_FFMPEG_BIN, SOUND_DRAFT_DIR,
#   SOUND_ASSET_DIR, SOUND_MANIFEST, SOUND_TIERS, AGENT0_SOUND_CONFIRM_THRESHOLD.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# --- defaults / args ---------------------------------------------------------
SUBCMD=""; PROMPT=""
KIND=""; TIER=""; DURATION=""; ASSET=0; FORMAT="mp3"
CONFIRM=""; OUT_JSON=0; USE_EXIT_CODE=0

DRAFT_DIR="${SOUND_DRAFT_DIR:-assets/generated/sound}"
ASSET_DIR="${SOUND_ASSET_DIR:-assets/sound}"
MANIFEST="${SOUND_MANIFEST:-assets/generated/.sound-manifest.jsonl}"
TIERS="${SOUND_TIERS:-$HERE/../skills/sound/references/sound-tiers.yaml}"
FAL_REST="${SOUND_FAL_REST:-$HERE/fal-rest.sh}"

while [ $# -gt 0 ]; do
  case "$1" in
    doctor|caps) SUBCMD="$1" ;;
    --kind) shift; KIND="${1:-}" ;;
    --kind=*) KIND="${1#*=}" ;;
    --tier) shift; TIER="${1:-}" ;;
    --tier=*) TIER="${1#*=}" ;;
    --duration) shift; DURATION="${1:-}" ;;
    --duration=*) DURATION="${1#*=}" ;;
    --asset) ASSET=1 ;;
    --format) shift; FORMAT="${1:-mp3}" ;;
    --format=*) FORMAT="${1#*=}" ;;
    --confirm-cost-usd) shift; CONFIRM="${1:-}" ;;
    --confirm-cost-usd=*) CONFIRM="${1#*=}" ;;
    --json) OUT_JSON=1 ;;
    --exit-code) USE_EXIT_CODE=1 ;;
    -h|--help) sed -n '3,22p' "$0"; exit 0 ;;
    -*) echo "sound: unknown flag: $1" >&2; exit 64 ;;
    *) [ -z "$PROMPT" ] && PROMPT="$1" || { echo "sound: unexpected arg: $1" >&2; exit 64; } ;;
  esac
  shift
done

# shared capacity kernel (spec 163) — cap_have/sha/cap_emit_exit/cap_fail/manifest mechanic
. "$HERE/lib/capacity.sh" 2>/dev/null || { echo "sound: missing kit library lib/capacity.sh" >&2; exit 70; }
# paid-media sub-kit (spec 164) — pm_yaml_*/pm_has_fal_key/pm_fal_key_state (pure helpers)
. "$HERE/lib/paid-media.sh" 2>/dev/null || { echo "sound: missing kit library lib/paid-media.sh" >&2; exit 70; }
CAP_TOOL="sound"
# cap_have/cap_sha256_str come from lib/capacity.sh (cap_have / cap_sha256_str)

# yaml oracle readers — bodies live in lib/paid-media.sh (spec 164); these bind $TIERS
yget() { pm_yaml_tier_field "$TIERS" "$1" "$2"; }  # $1=tier $2=field
ytop() { pm_yaml_top "$TIERS" "$1"; }              # $1=top-level key

resolve_ffmpeg() { FFMPEG_BIN="${SOUND_FFMPEG_BIN:-}"; [ -n "$FFMPEG_BIN" ] && return 0; cap_have ffmpeg && { FFMPEG_BIN=ffmpeg; return 0; }; return 1; }

# --- caps / doctor -----------------------------------------------------------
if [ "$SUBCMD" = "caps" ]; then
  thr="$(ytop confirm_threshold_usd)"; thr="${AGENT0_SOUND_CONFIRM_THRESHOLD:-${thr:-0.25}}"
  if cap_have jq; then
    jq -nc --argjson fk "$(pm_has_fal_key && echo true || echo false)" --arg tiers "$TIERS" \
      --argjson tf "$([ -f "$TIERS" ] && echo true || echo false)" \
      --arg thr "$thr" --arg ff "$(resolve_ffmpeg && echo "$FFMPEG_BIN" || echo "")" \
      '{paid_only:true, paid_fal_key:$fk,
        tiers_file:$tiers, tiers_present:$tf, confirm_threshold_usd:($thr|tonumber? // null),
        ffmpeg:(if $ff=="" then null else $ff end)}'
  else
    echo "{\"paid_only\":true,\"paid_fal_key\":$(pm_has_fal_key && echo true || echo false),\"tiers_present\":$([ -f "$TIERS" ] && echo true || echo false)}"
  fi
  exit 0
fi
if [ "$SUBCMD" = "doctor" ]; then
  echo "sound — capability check (paid-only creative audio)"
  key_state=$(pm_fal_key_state)
  echo "  [info] paid lane: FAL_KEY $key_state (no free local lane — paid by nature)"
  if [ -f "$TIERS" ]; then echo "  [ ok ] tiers: $TIERS"; else echo "  [warn] tiers file missing: $TIERS"; fi
  resolve_ffmpeg && echo "  [ ok ] ffmpeg: $FFMPEG_BIN" || echo "  [warn] ffmpeg: absent (mp3 encode needs it; --format wav works without)"
  thr="$(ytop confirm_threshold_usd)"; echo "  [info] confirm threshold: \$${AGENT0_SOUND_CONFIRM_THRESHOLD:-${thr:-0.25}} (hard --confirm-cost-usd required above it)"
  echo "  [info] draft dir: $DRAFT_DIR (gitignored) | asset dir: $ASSET_DIR (tracked) | manifest: $MANIFEST"
  exit 0
fi

# --- manifest + exit ---------------------------------------------------------
PROMPT_SHA=""; OUTPUT=""; MODEL=""; COST=""; RID=""
append_manifest() {  # sound's manifest schema; mechanics from cap_manifest_append
  local status="$1" line
  cap_have jq || return 0
  line="$(jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg st "$status" \
    --arg prompt "$PROMPT" --arg sha "$PROMPT_SHA" --arg kind "$KIND" --arg tier "$TIER" \
    --arg dur "$DURATION" --arg out "$OUTPUT" --arg fmt "$FORMAT" \
    --arg cls "$([ "$ASSET" = 1 ] && echo asset || echo draft)" \
    --arg model "$MODEL" --arg cost "$COST" --arg rid "$RID" \
    '{ts:$ts,status:$st,prompt:$prompt,prompt_sha256:$sha,kind:$kind,tier:$tier,
      duration_sec:($dur|tonumber? // null),output:$out,format:$fmt,class:$cls,
      provider:"fal",model:$model,cost_estimate_usd:($cost|tonumber? // null),
      request_id:$rid,stayed_local:false}')" || return 0
  cap_manifest_append "$MANIFEST" "$line"
}
_cap_on_fail() { append_manifest "$1"; }   # cap_fail hook (sound's cap_fail is the compact kernel shape)
# cap_emit_exit + cap_fail come from lib/capacity.sh (cap_emit_exit / cap_fail; CAP_TOOL=sound)

# --- validate inputs ---------------------------------------------------------
[ -n "$PROMPT" ] || { echo "sound: no prompt. usage: sound.sh \"<prompt>\" --kind music|sfx [flags]" >&2; exit 64; }
case "$KIND" in
  music|sfx) ;;
  "") echo "sound: --kind is required (music | sfx) — music and SFX are distinct intents" >&2; exit 64 ;;
  *) echo "sound: unknown --kind '$KIND' (allowed: music, sfx)" >&2; exit 64 ;;
esac

# resolve tier from kind (sfx has one tier; music defaults to standard)
if [ "$KIND" = "sfx" ]; then
  TIER="sfx"
else
  [ -n "$TIER" ] || TIER="$(ytop default_tier_music)"; TIER="${TIER:-standard}"
fi

PROMPT_SHA="$(cap_sha256_str "$PROMPT")"

# --- paid lane only ----------------------------------------------------------
pm_has_fal_key || cap_fail unavailable "/sound is paid-only and needs FAL_KEY (no free local lane — music/SFX has no light local engine). Set FAL_KEY and retry."
[ -f "$TIERS" ] || cap_fail error "tiers file not found: $TIERS"
cap_have jq || cap_fail error "jq required (oracle parse + body build)"

MODEL="$(yget "$TIER" model)"
PROMPT_FIELD="$(yget "$TIER" prompt_field)"
DURATION_FIELD="$(yget "$TIER" duration_field)"
URL_PATH="$(yget "$TIER" output_url_path)"
PRICE="$(yget "$TIER" price)"
PRICE_UNIT="$(yget "$TIER" price_unit)"
TIER_KIND="$(yget "$TIER" kind)"
[ -n "$MODEL" ] || cap_fail error "tier '$TIER' not found in $TIERS"
[ "$TIER_KIND" = "$KIND" ] || cap_fail error "tier '$TIER' is for kind '$TIER_KIND', not '$KIND' (--tier is music-only: standard|premium)"

# duration default from oracle
[ -n "$DURATION" ] || DURATION="$(yget "$TIER" default_duration)"
DURATION="${DURATION:-5}"
case "$DURATION" in (*[!0-9.]*|'') cap_fail error "invalid --duration '$DURATION' (seconds, numeric)";; esac

# cost = price × duration-in-unit
COST="$(awk -v p="${PRICE:-0}" -v d="$DURATION" -v u="$PRICE_UNIT" 'BEGIN{
  if(u=="per_second") c=p*d; else if(u=="per_minute") c=p*(d/60); else c=p;
  printf "%.4f", c }')"

# hybrid cost gate ------------------------------------------------------------
THRESHOLD="$(ytop confirm_threshold_usd)"; THRESHOLD="${AGENT0_SOUND_CONFIRM_THRESHOLD:-${THRESHOLD:-0.25}}"
echo "sound: kind=$KIND tier=$TIER model=$MODEL  ~\$$COST for ${DURATION}s (printed BEFORE the call)"
ABOVE="$(awk -v c="$COST" -v t="$THRESHOLD" 'BEGIN{print (c>t)?1:0}')"
if [ "$ABOVE" = "1" ]; then
  OK="$(awk -v cf="${CONFIRM:-}" -v c="$COST" 'BEGIN{ if(cf=="") {print 0; exit} print (cf+0>=c)?1:0 }')"
  if [ "$OK" != "1" ]; then
    cap_fail error "estimate \$$COST exceeds the \$$THRESHOLD confirm threshold — re-run with --confirm-cost-usd $COST (or any value ≥ the estimate) to proceed."
  fi
fi

# --- generate ----------------------------------------------------------------
OUT_DIR="$DRAFT_DIR"; [ "$ASSET" = 1 ] && OUT_DIR="$ASSET_DIR"
mkdir -p "$OUT_DIR" 2>/dev/null || cap_fail error "cannot create output dir: $OUT_DIR"
STEM="sound-$KIND-${PROMPT_SHA:0:8}"
WORKDIR="$(mktemp -d -t sound-XXXXXX)"; trap 'rm -rf "$WORKDIR"' EXIT

# generic body build from the oracle fields
body="$(jq -nc --arg pf "$PROMPT_FIELD" --arg pv "$PROMPT" --arg df "$DURATION_FIELD" --argjson dv "$DURATION" '
  ({} | .[$pf]=$pv) + (if ($df=="" or $df=="null") then {} else {($df): $dv} end)')"

resp="$("$FAL_REST" run --model="$MODEL" --body="$body" 2>/dev/null)" || cap_fail error "fal call failed (model $MODEL)"
url="$(printf '%s' "$resp" | jq -r "(${URL_PATH:-.audio.url}) // empty" 2>/dev/null)"
[ -n "$url" ] || cap_fail error "fal response carried no audio url at path '${URL_PATH:-.audio.url}' (verify output_url_path in the oracle for tier '$TIER')"
RID="$(printf '%s' "$resp" | jq -r '(.request_id // empty)' 2>/dev/null)"

dl="$WORKDIR/gen.audio"
"$FAL_REST" download --url="$url" --output="$dl" >/dev/null 2>&1 || cap_fail error "failed to download fal audio asset"

# place / encode
final="$OUT_DIR/$STEM.$FORMAT"
if [ "$FORMAT" = "wav" ]; then cp "$dl" "$final"
else
  if resolve_ffmpeg; then "$FFMPEG_BIN" -nostdin -y -i "$dl" "$final" >/dev/null 2>&1 || { cp "$dl" "$OUT_DIR/$STEM.wav"; final="$OUT_DIR/$STEM.wav"; FORMAT=wav; }
  else cp "$dl" "$OUT_DIR/$STEM.wav"; final="$OUT_DIR/$STEM.wav"; FORMAT=wav; fi
fi
OUTPUT="$final"

append_manifest ok
if [ "$OUT_JSON" -eq 1 ] && cap_have jq; then
  jq -nc --arg out "$OUTPUT" --arg kind "$KIND" --arg tier "$TIER" --arg model "$MODEL" --arg cost "$COST" \
    '{status:"ok",output:$out,kind:$kind,tier:$tier,model:$model,cost_estimate_usd:($cost|tonumber? // null),stayed_local:false}'
else
  echo "sound: status=ok"
  echo "  kind=$KIND tier=$TIER model=$MODEL cost~\$$COST"
  echo "  wrote: $OUTPUT  (class=$([ "$ASSET" = 1 ] && echo asset || echo draft), stayed_local=false)"
  [ "$ASSET" = 1 ] || echo "  taste-judge: listen, then promote a keeper with --asset (or regenerate)."
fi
cap_emit_exit ok
