---
name: audio
description: Text-to-speech synthesis (opt-in). Use when the user wants to turn text into spoken audio ("read this aloud", "generate a voiceover", "narrate this", "make an mp3 of this text", "TTS this"). Wraps the runtime-neutral .agent0/tools/audio.sh. Local-first + free by default - two on-device engines (Kokoro default, multilingual incl pt-BR; Piper, self-contained, 900+ EN voices); text never leaves the machine on the local lane. Optional paid upgrade via fal (--remote, ElevenLabs) for max expressiveness, with cost printed before the call. NOT speech-to-text (that is the sibling /transcribe), NOT music/SFX, NOT voice cloning (deferred). Flags - "<text>" [--engine kokoro|piper] [--remote] [--tier standard|premium] [--asset] [--voice <name>] [--lang <code>] [--format mp3|wav] [--quiet] [--json] [--exit-code]; subcommands doctor / caps. See .agent0/context/rules/audio.md.
argument-hint: "\"<text>\" [--engine kokoro|piper] [--remote] [--voice <name>] [--lang <code>] [--asset] [--format mp3|wav]"
license: MIT
compatibility: Designed for Claude Code. Core logic is the runtime-neutral bash tool `.agent0/tools/audio.sh` (Kokoro/Piper via uvx + ffmpeg + fal-rest.sh for the paid lane); the skill is a thin invocation wrapper. Codex CLI invokes the tool directly.
metadata:
  agent0-portability-tier: agentskills-portable
  version: "0.1"
---

# /audio — text-to-speech synthesis

Thin wrapper over `.agent0/tools/audio.sh`. The tool is the engine; this skill decides when to run it and how to surface the result. See `.agent0/context/rules/audio.md` for the full capacity contract (local-first stance, the espeak-ng acquisition asymmetry, the privacy boundary, the paid lane, non-goals).

## When to run

Run on demand when the user wants spoken audio from text — a voiceover, a narration, an mp3 of some text, an accessibility read-aloud. It is **not** speech-to-text (audio→text is the sibling `/transcribe`), **not** music/SFX, and **not** voice cloning.

## What to do

1. **Parse `$ARGUMENTS`** — pass straight through. Only the text is required:
   - `"<text>"` — the text to speak.
   - `--engine kokoro|piper` — local engine (default **kokoro**: multilingual incl. pt-BR, best quality; **piper**: self-contained, 900+ EN voices, the more-portable fallback).
   - `--lang <code>` — language for the voice (e.g. `pt`, `en`); default `en`. Set it when the text isn't English.
   - `--voice <name>` — a specific engine voice; sensible default per engine/lang otherwise.
   - `--remote [--tier standard|premium]` — **paid** lane via fal (ElevenLabs) for max expressiveness; needs `FAL_KEY`. Cost is printed before the call.
   - `--asset` — write to the **tracked** voiceover dir (a kept asset) instead of the gitignored draft dir.
   - `--format mp3|wav` — default mp3.

2. **Invoke the tool:**
   ```bash
   bash .agent0/tools/audio.sh "$ARGUMENTS"
   ```

3. **Surface the result** — first line `audio: status=<ok|unavailable|error>`:
   - **`ok`** — report the written path; note the class (draft/asset) and `stayed_local`.
   - **`unavailable`** — engine couldn't be found/acquired (commonly: Kokoro needs `espeak-ng`, a system binary). Relay the one-line hint; offer `--engine piper` (self-contained) as the fallback, or proceed once the dep is installed. Not an empty result.
   - **`error`** — input/runtime problem (bad `--engine`, synthesis/fal failure). Relay the diagnostic.

4. **Privacy framing (honest):** on the **local** lane the text and audio **stay on the machine** (`stayed_local:true`); only engine/voice weights are fetched once. With `--remote`, the text **is sent to fal** (`stayed_local:false`) — say so.

5. **Cost (paid lane):** the tool prints a per-character estimate **before** calling fal; surface it. The paid lane offers what local can't (ElevenLabs expressiveness) — don't reach for it when the free local voice suffices.

## Discipline

- Local-first: prefer the free on-device lane; `--remote` is an opt-in upgrade, never automatic.
- Never add a hard cost gate or paid-Kokoro tier here — local already gives Kokoro free; the paid tiers are ElevenLabs-only by design.
- Music/SFX and voice cloning are out of scope (deferred family-wide; see the rule).

## Notes

_Consumer-extension surface — append consumer-local bullets here._

- Default voices/paid body shape are verified against the actually-acquired packages; engine + voice are env/flag-overridable so a wrong default never blocks.
- Engine/voice cache lives under `.agent0/.runtime-state/audio/` (gitignored); delete to force a clean re-acquire.
