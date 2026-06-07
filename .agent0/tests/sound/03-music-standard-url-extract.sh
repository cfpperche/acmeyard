#!/usr/bin/env bash
# standard music (CassetteAI) flows under threshold AND its audio_file.url path
# is extracted correctly (the data-driven oracle lesson from /audio).
source "$(dirname "$0")/_lib.sh"; echo "03-music-standard-url-extract"
OUT="$(bash "$TOOL" "ambient pad" --kind music --duration 30)"; RC=$?
assert_eq "$RC" "0" "exit 0"
assert_contains "$OUT" "tier=standard" "default music tier standard"
assert_contains "$OUT" "model=cassetteai/music-generator" "CassetteAI model"
assert_contains "$OUT" "~\$0.0100 for 30s" "cost 0.02*30/60 = 0.01 (per_minute)"
assert_contains "$OUT" "status=ok" "status ok (audio_file.url extracted)"
assert_eq "$(ls "$WORK/draft" | grep -c '\.mp3$')" "1" "draft written from audio_file.url"
# body shape: music uses prompt_field=prompt + duration_field=duration
B="$(cat "$WORK/body.json")"
assert_contains "$B" '"prompt":"ambient pad"' "body uses prompt field (music)"
assert_contains "$B" '"duration":30' "body carries duration"
M="$(cat "$WORK/m.jsonl")"
assert_contains "$M" '"request_id":"req-cass-1"' "manifest CassetteAI request id"
assert_contains "$M" '"model":"cassetteai/music-generator"' "manifest CassetteAI model"
finish
