#!/usr/bin/env bash
# .agent0/tests/sound/_lib.sh — shared harness for /sound scenarios (spec 161).
# Fake fal-rest + ffmpeg stubs injected via env, fully offline. The fake fal
# returns a model-dependent url shape so the per-tier output_url_path extraction
# is exercised (CassetteAI audio_file.url vs ElevenLabs audio.url).

set -uo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/sound.sh"

WORK="$(mktemp -d -t sound-test-XXXXXX)"; BIN="$WORK/bin"
mkdir -p "$BIN" "$WORK/draft" "$WORK/asset"
trap 'rm -rf "$WORK"' EXIT

# fake fal-rest: run -> json with url shape keyed on the model; download -> stub.
# Records the body it received so the body-shape assertions can read it.
cat > "$BIN/fake-fal" <<'STUB'
#!/usr/bin/env bash
sub="$1"; shift
model=""; body=""
for a in "$@"; do case "$a" in --model=*) model="${a#*=}";; --body=*) body="${a#*=}";; esac; done
case "$sub" in
  run)
    printf '%s' "$body" > "${SOUND_TEST_BODYCAP:-/dev/null}"
    case "$model" in
      *cassetteai*) echo '{"audio_file":{"url":"https://fake.fal/music.mp3"},"request_id":"req-cass-1"}' ;;
      *)            echo '{"audio":{"url":"https://fake.fal/sfx.mp3"},"request_id":"req-el-1"}' ;;
    esac ;;
  download) out=""; for a in "$@"; do case "$a" in --output=*) out="${a#*=}";; esac; done; [ -n "$out" ] && printf 'ID3-stub-audio' > "$out" ;;
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

export SOUND_FAL_REST="$BIN/fake-fal"
export SOUND_FFMPEG_BIN="$BIN/fake-ffmpeg"
export SOUND_DRAFT_DIR="$WORK/draft"
export SOUND_ASSET_DIR="$WORK/asset"
export SOUND_MANIFEST="$WORK/m.jsonl"
export SOUND_TIERS="$AGENT0_ROOT/.agent0/skills/sound/references/sound-tiers.yaml"
export SOUND_TEST_BODYCAP="$WORK/body.json"
export FAL_KEY="test-dummy-key"   # fake-fal ignores it; never the real key

PASS=0; FAIL=0
assert_contains(){ if printf '%s' "$1" | grep -qF -- "$2"; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3"; printf '      want: %s\n      in: %s\n' "$2" "$1" | head -c 400; echo; fi; }
assert_not_contains(){ if printf '%s' "$1" | grep -qF -- "$2"; then FAIL=$((FAIL+1)); echo "  ✗ $3 (found: $2)"; else PASS=$((PASS+1)); echo "  ✓ $3"; fi; }
assert_eq(){ if [ "$1" = "$2" ]; then PASS=$((PASS+1)); echo "  ✓ $3"; else FAIL=$((FAIL+1)); echo "  ✗ $3 (expected $2, got $1)"; fi; }
assert_file(){ if [ -f "$1" ]; then PASS=$((PASS+1)); echo "  ✓ $2"; else FAIL=$((FAIL+1)); echo "  ✗ $2 (missing $1)"; fi; }
finish(){ echo "  -- $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]; }
ls_one(){ ls "$1" 2>/dev/null | head -1; }
