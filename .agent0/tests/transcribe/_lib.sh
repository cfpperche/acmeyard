#!/usr/bin/env bash
# .agent0/tests/transcribe/_lib.sh
# Shared harness for transcribe scenarios.
#
# Provides FAKE whisper-cli + ffmpeg stubs injected via the engine's override
# env vars, so scenarios are deterministic and offline (no network, no model,
# no real audio). Mirrors .agent0/tests/vuln-audit/ canned-binary pattern.

set -uo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/transcribe.sh"

WORK="$(mktemp -d -t transcribe-test-XXXXXX)"
BIN="$WORK/bin"
mkdir -p "$BIN" "$WORK/models" "$WORK/out"
trap 'rm -rf "$WORK"' EXIT

# Fake whisper-cli: parse -of <prefix> + -o* flags, write canned files.
cat > "$BIN/fake-whisper" <<'STUB'
#!/usr/bin/env bash
prefix=""; declare -a exts=()
while [ $# -gt 0 ]; do
  case "$1" in
    -of) shift; prefix="$1" ;;
    -otxt) exts+=("txt") ;;
    -osrt) exts+=("srt") ;;
    -ovtt) exts+=("vtt") ;;
    -oj)   exts+=("json") ;;
    -ojf)  exts+=("json") ;;
    -ocsv) exts+=("csv") ;;
    -olrc) exts+=("lrc") ;;
    -m|-f|-l) shift ;;
  esac
  shift
done
[ -z "$prefix" ] && { echo "fake-whisper: no -of" >&2; exit 1; }
for e in "${exts[@]}"; do
  case "$e" in
    txt)  echo "hello world this is a test transcript" > "$prefix.txt" ;;
    srt)  printf '1\n00:00:00,000 --> 00:00:02,000\nhello world\n' > "$prefix.srt" ;;
    vtt)  printf 'WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nhello world\n' > "$prefix.vtt" ;;
    json) echo '{"transcription":[{"text":"hello world"}]}' > "$prefix.json" ;;
    csv)  printf 'start,end,text\n0,2000,hello world\n' > "$prefix.csv" ;;
    lrc)  printf '[00:00.00]hello world\n' > "$prefix.lrc" ;;
  esac
done
exit 0
STUB
chmod +x "$BIN/fake-whisper"

# Fake ffmpeg: write a stub WAV at the .wav output arg.
cat > "$BIN/fake-ffmpeg" <<'STUB'
#!/usr/bin/env bash
out=""
for a in "$@"; do case "$a" in *.wav) out="$a" ;; esac; done
[ -n "$out" ] && printf 'RIFF0000WAVE' > "$out"
exit 0
STUB
chmod +x "$BIN/fake-ffmpeg"

# Stub model so resolve_model is satisfied offline.
printf 'GGML-STUB' > "$WORK/models/ggml-base.bin"

export TRANSCRIBE_WHISPER_BIN="$BIN/fake-whisper"
export TRANSCRIBE_FFMPEG_BIN="$BIN/fake-ffmpeg"
export TRANSCRIBE_MODEL_DIR="$WORK/models"
export TRANSCRIBE_OUTPUT_DIR="$WORK/out"
export TRANSCRIBE_MANIFEST="$WORK/manifest.jsonl"
export TRANSCRIBE_NO_ACQUIRE=1

# Make a fake input file (content irrelevant — fake bins ignore it).
mkinput() { local f="$WORK/$1"; printf 'FAKEMEDIA' > "$f"; echo "$f"; }

PASS=0; FAIL=0
assert_contains() {
  if printf '%s' "$1" | grep -qF -- "$2"; then PASS=$((PASS+1)); echo "  ✓ $3";
  else FAIL=$((FAIL+1)); echo "  ✗ $3"; echo "      expected to contain: $2"; printf '      in: %s\n' "$1" | head -c 400; echo; fi
}
assert_not_contains() {
  if printf '%s' "$1" | grep -qF -- "$2"; then FAIL=$((FAIL+1)); echo "  ✗ $3"; echo "      expected NOT to contain: $2";
  else PASS=$((PASS+1)); echo "  ✓ $3"; fi
}
assert_eq() {
  if [ "$1" = "$2" ]; then PASS=$((PASS+1)); echo "  ✓ $3";
  else FAIL=$((FAIL+1)); echo "  ✗ $3"; echo "      expected: $2"; echo "      actual:   $1"; fi
}
assert_file() {
  if [ -f "$1" ]; then PASS=$((PASS+1)); echo "  ✓ $2"; else FAIL=$((FAIL+1)); echo "  ✗ $2 (missing: $1)"; fi
}
finish() { echo "  -- $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]; }
