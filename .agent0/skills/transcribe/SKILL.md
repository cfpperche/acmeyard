---
name: transcribe
description: Local-first speech-to-text (opt-in). Use when the user wants to turn an audio OR video file into a transcript ("transcribe this call", "get the text from this recording", "subtitles for this screencast", "what was said in this mp3"). Wraps the runtime-neutral .agent0/tools/transcribe.sh (engine - whisper.cpp, MIT). Local by default - the audio/video content never leaves the machine; only model weights are fetched once. Auto-acquires the engine + a base model as invisibly as possible, degrading to a one-line hint when impossible. NOT paid media (no cost, no tiers, no key) and NOT speech synthesis (that is the sibling /audio). Flags - <file> [--format txt,srt,vtt,json,json-full,csv,lrc] [--model base] [--lang <code>] [--output <dir>] [--quiet] [--json] [--exit-code]; subcommands doctor / caps. See .agent0/context/rules/transcribe.md.
argument-hint: "<file> [--format <csv>] [--model <name>] [--lang <code>] [--output <dir>] [--quiet]"
license: MIT
compatibility: Designed for Claude Code. Core logic is the runtime-neutral bash tool `.agent0/tools/transcribe.sh` (whisper.cpp + ffmpeg + curl); the skill is a thin invocation wrapper, portable to any runtime that can run the tool. Codex CLI invokes the tool directly.
metadata:
  agent0-portability-tier: agentskills-portable
  version: "0.1"
---

# /transcribe — local-first speech-to-text

Thin wrapper over `.agent0/tools/transcribe.sh`. The tool is the engine; this skill decides when to run it and how to surface the result. See `.agent0/context/rules/transcribe.md` for the full capacity contract (local-first stance, the privacy boundary, the paid-STT reopen-trigger, non-goals).

## When to run

Run on demand when the user hands over an audio or video file and wants its text — a recorded call, a voice memo, a meeting recording, a screencast, a podcast clip. It is **not** for speech synthesis (text→audio is the sibling `/audio`), and it is **not** a paid service — there is no key, no cost, no tier.

## What to do

1. **Parse `$ARGUMENTS`** — pass them straight through to the tool. Only the file is required:
   - `<file>` — the audio or video file (video → the audio track is extracted via ffmpeg).
   - `--format <csv>` — any of `txt,srt,vtt,json,json-full,csv,lrc` (default `txt`). `srt`/`vtt` for subtitles, `json`/`json-full` for structured output.
   - `--model <name>` — whisper ggml model (default `base`, multilingual). Larger = more accurate + slower + bigger download.
   - `--lang <code>` — force a language (default: auto-detect). Don't set it unless the user names a language.
   - `--output <dir>` — override the transcripts dir (default: the gitignored `assets/transcripts/`).
   - `--quiet` — suppress the stdout echo (use for sensitive content you don't want in the session log).

2. **Invoke the tool:**
   ```bash
   bash .agent0/tools/transcribe.sh $ARGUMENTS
   ```

3. **Surface the result** — the first line is `transcribe: status=<ok|unavailable|error>`:
   - **`ok`** — relay the transcript (or, with `--quiet`, just the written paths). Name the output files.
   - **`unavailable`** — the engine/ffmpeg couldn't be found or auto-acquired. Relay the one-line acquisition hint; offer to proceed once it's in place. Do **not** treat this as an empty transcript.
   - **`error`** — an input/runtime problem (missing file, bad `--format`, engine failure). Relay the diagnostic.

4. **Privacy framing (honest by design)** — say plainly that the **audio/video stayed local** (whisper.cpp runs on-device); the only network egress is the one-time model-weights fetch. Don't overclaim "nothing touched the network".

5. **First run is not instant** — a first transcription may pay a one-time engine fetch (uvx) + a `base` model download. The tool prints a "first-run setup…" line; relay that so a slow first run doesn't read as a hang.

## Discipline

- This is a local utility, not a paid-media skill — never add a cost gate, a tier oracle, or a paid backend here. Diarization (speaker labels) is the **named reopen-trigger** for a future paid lane, not a v1 feature (see the rule).
- Transcripts default to a **gitignored** dir — they are the user's content; never auto-commit a transcript, and prefer `--quiet` for anything sensitive.

## Notes

_Consumer-extension surface — append consumer-local bullets here. Sync flags the file as customized but the conflict region is mechanically this section._

- Recurring transcription is out of scope for v1 — wire `/routine` to invoke the tool if you want a cadence.
- Engine + model are cached under `.agent0/.runtime-state/transcribe/` (gitignored); delete it to force a clean re-acquire.
