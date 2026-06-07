#!/usr/bin/env bash
# .agent0/tools/diagram.sh
#
# diagram — runtime-neutral, deterministic technical-visual generation. Spec 162.
# Compiles a MERMAID source (file or inline text) -> SVG/PNG/PDF, LOCALLY and
# FREE. The deterministic sibling of /video --mode code and the technical-visual
# counterpart to /image (organic, paid). A /transcribe-class local utility:
# provenance manifest (NOT a cost ledger), no FAL_KEY/tiers/cost gate.
#
# Render engine: mmdc (@mermaid-js/mermaid-cli) acquired via npx (no global
# install), rendering in a SYSTEM headless Chrome via a generated puppeteer
# config (PUPPETEER_SKIP_DOWNLOAD=1 so npx pulls only the JS package). When no
# usable Chrome is found, the capacity DEGRADES (does not die): it preserves the
# tracked source + runs a Chrome-less structural validation, returning
# status=unavailable for the render step with an install hint.
#
# Usage:
#   diagram.sh <source.mmd | "<mermaid text>"> [--kind flowchart|sequence|erd|class|state|architecture]
#              [--format svg|png|pdf] [--out <dir>] [--theme default|dark|forest|neutral]
#              [--json] [--exit-code]
#   diagram.sh doctor | caps
#
# Result statuses (decoupled from exit code): ok | unavailable | error.
# Default exit 0; --exit-code maps ok=0 unavailable=2 error=3.
#
# Test/override env: DIAGRAM_MMDC (mmdc command), DIAGRAM_CHROME_BIN (browser
#   path; empty/"none" = force-absent), DIAGRAM_OUT_DEFAULT, DIAGRAM_MANIFEST.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shared capacity kernel (spec 163) — cap_have/sha/cap_emit_exit/cap_fail/manifest mechanics
. "$HERE/lib/capacity.sh" 2>/dev/null || { echo "diagram: missing kit library lib/capacity.sh" >&2; exit 70; }
CAP_TOOL="diagram"

# --- defaults / args ---------------------------------------------------------
SUBCMD=""; SOURCE=""
KIND=""; FORMAT="svg"; OUT_DIR=""; THEME=""
OUT_JSON=0; USE_EXIT_CODE=0

DEFAULT_OUT="${DIAGRAM_OUT_DEFAULT:-assets/diagrams}"
MANIFEST="${DIAGRAM_MANIFEST:-assets/generated/.diagram-manifest.jsonl}"

while [ $# -gt 0 ]; do
  case "$1" in
    doctor|caps) SUBCMD="$1" ;;
    --kind) shift; KIND="${1:-}" ;;
    --kind=*) KIND="${1#*=}" ;;
    --format) shift; FORMAT="${1:-svg}" ;;
    --format=*) FORMAT="${1#*=}" ;;
    --out) shift; OUT_DIR="${1:-}" ;;
    --out=*) OUT_DIR="${1#*=}" ;;
    --theme) shift; THEME="${1:-}" ;;
    --theme=*) THEME="${1#*=}" ;;
    --json) OUT_JSON=1 ;;
    --exit-code) USE_EXIT_CODE=1 ;;
    -h|--help) sed -n '3,28p' "$0"; exit 0 ;;
    -*) echo "diagram: unknown flag: $1" >&2; exit 64 ;;
    *) [ -z "$SOURCE" ] && SOURCE="$1" || { echo "diagram: unexpected arg: $1" >&2; exit 64 ;} ;;
  esac
  shift
done

# cap_have/sha256 come from lib/capacity.sh (cap_have / cap_sha256_file)

# mmdc command (array) — npx ephemeral acquisition by default
declare -a MMDC_CMD=()
resolve_mmdc() {
  MMDC_CMD=()
  if [ -n "${DIAGRAM_MMDC:-}" ]; then read -r -a MMDC_CMD <<< "$DIAGRAM_MMDC"; return 0; fi
  if cap_have mmdc; then MMDC_CMD=(mmdc); return 0; fi
  if cap_have npx; then MMDC_CMD=(npx -p @mermaid-js/mermaid-cli mmdc); return 0; fi
  return 1
}

# system Chrome resolution (reuse, never download)
CHROME_BIN=""
resolve_chrome() {
  CHROME_BIN=""
  if [ "${DIAGRAM_CHROME_BIN+set}" = set ]; then        # explicitly set (even to empty)
    case "$DIAGRAM_CHROME_BIN" in ""|none) return 1 ;; *) CHROME_BIN="$DIAGRAM_CHROME_BIN"; return 0 ;; esac
  fi
  local b
  for b in google-chrome google-chrome-stable chromium chromium-browser; do
    cap_have "$b" && { CHROME_BIN="$(command -v "$b")"; return 0; }
  done
  return 1
}

# Chrome-less structural validation: first meaningful line names a known Mermaid
# diagram type. Deterministic, no DOM — gives the degraded mode real teeth.
MERMAID_KEYWORDS='^(graph|flowchart|sequenceDiagram|classDiagram|erDiagram|stateDiagram(-v2)?|gantt|pie|journey|gitGraph|mindmap|timeline|quadrantChart|requirementDiagram|C4Context|C4Container|C4Component|architecture(-beta)?)\b'
mermaid_structural_ok() {  # $1 = source file
  local line
  line="$(grep -vE '^\s*$|^\s*%%' "$1" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//')"
  [ -n "$line" ] && printf '%s' "$line" | grep -Eq "$MERMAID_KEYWORDS"
}

# --- caps / doctor -----------------------------------------------------------
if [ "$SUBCMD" = "caps" ]; then
  resolve_mmdc && MM="${MMDC_CMD[*]}" || MM=""
  resolve_chrome && CH="$CHROME_BIN" || CH=""
  if cap_have jq; then
    jq -nc --arg node "$(cap_have node && node --version 2>/dev/null || echo "")" \
      --arg mmdc "$MM" --arg chrome "$CH" \
      '{paid:false, local:true, node:(if $node=="" then null else $node end),
        mmdc:(if $mmdc=="" then null else $mmdc end),
        chrome:(if $chrome=="" then null else $chrome end),
        formats:["svg","png","pdf"], source_lang:"mermaid"}'
  else
    echo "{\"local\":true,\"mmdc\":\"$MM\",\"chrome\":\"$CH\"}"
  fi
  exit 0
fi
if [ "$SUBCMD" = "doctor" ]; then
  echo "diagram — capability check (local/free deterministic technical visuals)"
  cap_have node && echo "  [ ok ] node: $(node --version 2>/dev/null)" || echo "  [warn] node: absent (mmdc render needs Node)"
  if resolve_mmdc; then echo "  [ ok ] mmdc: ${MMDC_CMD[*]}"; else echo "  [warn] mmdc: no npx to acquire @mermaid-js/mermaid-cli (install Node/npx)"; fi
  if resolve_chrome; then echo "  [ ok ] chrome: $CHROME_BIN"; else echo "  [warn] chrome: none found — render degrades to validation-only (install google-chrome/chromium)"; fi
  echo "  [info] source lang: mermaid (only, v1) | formats: svg(default)/png/pdf"
  echo "  [info] default out: $DEFAULT_OUT (tracked; --out for spec-owned docs/specs/NNN/diagrams) | manifest: $MANIFEST"
  exit 0
fi

# --- manifest + exit ---------------------------------------------------------
SOURCE_SHA=""; OUTPUT=""; SRC_TRACKED=""; ENGINE=""
append_manifest() {  # diagram's manifest schema; mechanics from cap_manifest_append
  local status="$1" line
  cap_have jq || return 0
  line="$(jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg st "$status" \
    --arg sha "$SOURCE_SHA" --arg kind "$KIND" --arg fmt "$FORMAT" \
    --arg eng "$ENGINE" --arg out "$OUTPUT" --arg src "$SRC_TRACKED" \
    '{ts:$ts,status:$st,source_sha256:$sha,kind:$kind,format:$fmt,engine:$eng,
      source:$src,output:$out,stayed_local:true}')" || return 0
  cap_manifest_append "$MANIFEST" "$line"
}
_cap_on_fail() { append_manifest "$1"; }   # cap_fail hook (kernel records via this)

# --- validate inputs ---------------------------------------------------------
[ -n "$SOURCE" ] || { echo "diagram: no source. usage: diagram.sh <source.mmd | \"<mermaid text>\"> [flags]" >&2; exit 64; }
case "$FORMAT" in svg|png|pdf) ;; *) echo "diagram: unknown --format '$FORMAT' (allowed: svg, png, pdf)" >&2; exit 64;; esac
[ -z "$KIND" ] || case "$KIND" in flowchart|sequence|erd|class|state|architecture) ;; *) echo "diagram: unknown --kind '$KIND'" >&2; exit 64;; esac

WORKDIR="$(mktemp -d -t diagram-XXXXXX)"; trap 'rm -rf "$WORKDIR"' EXIT
OUT_DIR="${OUT_DIR:-$DEFAULT_OUT}"
mkdir -p "$OUT_DIR" 2>/dev/null || cap_fail error "cannot create output dir: $OUT_DIR"

# resolve source: existing file vs inline text
if [ -f "$SOURCE" ]; then
  SRC="$SOURCE"; STEM="$(basename "$SOURCE")"; STEM="${STEM%.*}"
  SRC_TRACKED="$SOURCE"
else
  # inline text -> persist a tracked .mmd next to the output (source is the artifact)
  SOURCE_SHA="$(printf '%s' "$SOURCE" | { sha256sum 2>/dev/null || shasum -a 256 2>/dev/null; } | awk '{print $1}')"
  STEM="diagram-${KIND:-mmd}-${SOURCE_SHA:0:8}"
  SRC="$OUT_DIR/$STEM.mmd"
  printf '%s\n' "$SOURCE" > "$SRC"
  SRC_TRACKED="$SRC"
fi
[ -n "$SOURCE_SHA" ] || SOURCE_SHA="$(cap_sha256_file "$SRC")"

# structural validation (Chrome-less, deterministic)
mermaid_structural_ok "$SRC" || cap_fail error "source does not look like a Mermaid diagram (first non-comment line must name a diagram type, e.g. flowchart/sequenceDiagram/erDiagram). Source kept at: $SRC_TRACKED"

OUTPUT_PATH="$OUT_DIR/$STEM.$FORMAT"

# --- render or degrade -------------------------------------------------------
if ! resolve_chrome; then
  ENGINE="mermaid/validate"
  cap_fail unavailable "no usable Chrome/Chromium for rendering — source VALIDATED (structural) and kept at $SRC_TRACKED. Install google-chrome or chromium, then re-run to render. (Render needs headless Chrome via mmdc.)"
fi
resolve_mmdc || { ENGINE="mermaid/validate"; cap_fail unavailable "Node/npx not available to acquire mmdc — source VALIDATED and kept at $SRC_TRACKED. Install Node, then re-run."; }
ENGINE="mermaid/mmdc"

# puppeteer config reusing system chrome (no chromium download)
PCFG="$WORKDIR/puppeteer.json"
printf '{"executablePath":"%s","args":["--no-sandbox","--disable-gpu"]}\n' "$CHROME_BIN" > "$PCFG"

declare -a RENDER=("${MMDC_CMD[@]}" -i "$SRC" -o "$OUTPUT_PATH" --puppeteerConfigFile "$PCFG")
[ -n "$THEME" ] && RENDER+=(-t "$THEME")

if ! PUPPETEER_SKIP_DOWNLOAD=1 "${RENDER[@]}" >"$WORKDIR/mmdc.log" 2>&1; then
  rm -f "$OUTPUT_PATH" 2>/dev/null
  cap_fail error "mmdc render failed (likely a Mermaid syntax error). Source kept at $SRC_TRACKED. Log: $(tail -3 "$WORKDIR/mmdc.log" 2>/dev/null | tr '\n' ' ')"
fi
[ -s "$OUTPUT_PATH" ] || cap_fail error "mmdc produced no output at $OUTPUT_PATH"
OUTPUT="$OUTPUT_PATH"

append_manifest ok
if [ "$OUT_JSON" -eq 1 ] && cap_have jq; then
  jq -nc --arg out "$OUTPUT" --arg src "$SRC_TRACKED" --arg kind "$KIND" --arg fmt "$FORMAT" --arg eng "$ENGINE" \
    '{status:"ok",output:$out,source:$src,kind:$kind,format:$fmt,engine:$eng,stayed_local:true}'
else
  echo "diagram: status=ok"
  echo "  engine=$ENGINE kind=${KIND:-auto} format=$FORMAT"
  echo "  source: $SRC_TRACKED (tracked) | wrote: $OUTPUT (stayed_local=true)"
fi
cap_emit_exit ok
