#!/usr/bin/env bash
# .agent0/tests/audio/_lib.sh — shared harness for /audio scenarios.
# Fake piper + kokoro-shim + fal-rest + ffmpeg stubs injected via env, offline.

set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/audio.sh"

WORK="$(mktemp -d -t audio-test-XXXXXX)"; BIN="$WORK/bin"
mkdir -p "$BIN" "$WORK/voices" "$WORK/draft" "$WORK/asset"
trap 'rm -rf "$WORK"' EXIT

# fake piper: reads stdin text, writes stub wav at --output_file
cat > "$BIN/fake-piper" <<'STUB'
#!/usr/bin/env bash
out=""; while [ $# -gt 0 ]; do case "$1" in --output_file) shift; out="$1";; --model) shift;; esac; shift; done
cat >/dev/null; [ -n "$out" ] && printf 'RIFFwav-piper' > "$out"; exit 0
STUB
# fake kokoro shim: writes stub wav at --out
cat > "$BIN/fake-kokoro" <<'STUB'
#!/usr/bin/env bash
out=""; while [ $# -gt 0 ]; do case "$1" in --out) shift; out="$1";; --text|--voice|--lang) shift;; esac; shift; done
[ -n "$out" ] && printf 'RIFFwav-kokoro' > "$out"; exit 0
STUB
# fake fal-rest: run -> json with audio url + request_id ; download -> stub file
cat > "$BIN/fake-fal" <<'STUB'
#!/usr/bin/env bash
sub="$1"; shift
case "$sub" in
  run) echo '{"audio":{"url":"https://fake.fal/out.mp3"},"request_id":"req-test-123"}' ;;
  download) out=""; for a in "$@"; do case "$a" in --output=*) out="${a#*=}";; esac; done; [ -n "$out" ] && printf 'ID3mp3-fal' > "$out" ;;
esac
exit 0
STUB
# fake ffmpeg: write stub to last arg (the final output path)
cat > "$BIN/fake-ffmpeg" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do last="$a"; done
printf 'mp3-encoded' > "$last"; exit 0
STUB
chmod +x "$BIN"/*

# stub Piper default voices so resolve doesn't try to download
printf 'onnx' > "$WORK/voices/en_US-lessac-medium.onnx"
printf 'onnx' > "$WORK/voices/pt_BR-faber-medium.onnx"

export AUDIO_PIPER_CMD="$BIN/fake-piper"
export AUDIO_KOKORO_CMD="$BIN/fake-kokoro"
export AUDIO_FFMPEG_BIN="$BIN/fake-ffmpeg"
export AUDIO_FAL_REST="$BIN/fake-fal"
export AUDIO_NO_ACQUIRE=1
export AUDIO_DRAFT_DIR="$WORK/draft"
export AUDIO_ASSET_DIR="$WORK/asset"
export AUDIO_MANIFEST="$WORK/m.jsonl"
export AUDIO_VOICE_CACHE="$WORK/voices"
export AUDIO_TIERS="$AGENT0_ROOT/.agent0/skills/audio/references/audio-tiers.yaml"

PASS=0; FAIL=0
assert_contains(){ if printf '%s' "$1" | grep -qF -- "$2"; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3"; printf '      want: %s\n      in: %s\n' "$2" "$1" | head -c 400; echo; fi; }
assert_not_contains(){ if printf '%s' "$1" | grep -qF -- "$2"; then FAIL=$((FAIL+1)); echo "  ✗ $3 (found: $2)"; else PASS=$((PASS+1)); echo "  ✓ $3"; fi; }
assert_eq(){ if [ "$1" = "$2" ]; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3 (expected $2, got $1)"; fi; }
assert_file(){ if [ -f "$1" ]; then PASS=$((PASS+1)); echo "  ✓ $2"; else FAIL=$((FAIL+1)); echo "  ✗ $2 (missing $1)"; fi; }
finish(){ echo "  -- $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]; }
ls_one(){ ls "$1" 2>/dev/null | head -1; }
