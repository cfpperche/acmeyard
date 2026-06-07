#!/usr/bin/env bash
# Scenario: a video file is accepted; ffmpeg extracts the track; transcript produced.
source "$(dirname "$0")/_lib.sh"
echo "03-video-input"

IN="$(mkinput screencast.mp4)"
OUT="$(bash "$TOOL" "$IN")"; RC=$?

assert_eq "$RC" "0" "exit 0"
assert_contains "$OUT" "status=ok" "video input transcribed ok"
assert_file "$WORK/out/screencast.txt" "transcript written from video input"

finish
