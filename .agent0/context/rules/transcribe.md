---
paths:
  - ".agent0/skills/transcribe/**"
  - ".agent0/tools/transcribe.sh"
  - "assets/transcripts/**"
---

# Transcribe

`/transcribe` (and its engine `.agent0/tools/transcribe.sh`) turns an audio **or video** file into a transcript, **locally**, on demand. It is the recognition member of Agent0's audio family — the counterpart of the synthesis-side `/audio` skill — and was shaped in the decision-grade meeting `.agent0/meetings/audio-transcribe-media-family-skills-2026-06-06T17-01-43Z/` (blind openings, 8-row anchored ledger, minority report). Engine is **whisper.cpp** (MIT).

## Not a paid-media skill — a local utility

The defining decision: `/transcribe` is **deliberately NOT** in the `/image`/`/video` paid-media family. It is a local utility in the **`vuln-audit` class** — on-demand, single-engine, runtime-neutral, reports-never-blocks, **result status decoupled from the process exit code**. There is **no cost apparatus**: no `tiers.yaml` oracle, no `--confirm-cost-usd` gate, no `FAL_KEY`, no cost-bearing manifest fields. Its manifest is **provenance**, not a cost ledger. Output direction (audio→text) and zero inference bill are why it sheds that machinery — bolting the paid-media apparatus onto it would be dead weight.

## Local-first + the privacy boundary (honest by design)

whisper.cpp runs **on-device**. The **audio/video content never leaves the machine** — the manifest records `stayed_local: true` for the content. The *only* network egress is the **one-time model-weights fetch** (from the whisper.cpp model host). Frame it that way; never overclaim "nothing touches the network".

## Maximally-invisible acquisition (founder directive)

Acquisition and operation are as automated and invisible as possible — `/transcribe call.mp3` just works on first run, acquiring the engine + the default `base` (multilingual, ~142 MiB) model itself. The acquisition is a deterministic ladder (macOS/Linux-first; Windows-native is best-effort, not the auto path):

1. an existing `whisper-cli`/`whisper-cpp`/`whisper`/`main` binary on `PATH` or the engine cache → use it;
2. **`uvx` present → run the prebuilt-wheel CLI `whisper.cpp-cli` ephemerally** (no compiler, no persistent install — the only genuinely invisible path);
3. otherwise → result status **`unavailable`** with a one-line acquisition hint (uv is a one-line install; `brew install whisper-cpp` on macOS). It **never** runs a destructive auto-install and **never** crashes.

A first run is therefore not instant (engine fetch + model download); the tool prints a `first-run setup…` line so it doesn't read as a hang.

## Surface

`bash .agent0/tools/transcribe.sh <file> [--format <csv>] [--model <name>] [--lang <code>] [--output <dir>] [--quiet] [--json] [--exit-code]`, plus `doctor` (human tri-state) and `caps` (JSON). Codex CLI / CI invoke the tool directly; Claude Code uses `/transcribe`. Default exit is always 0 (advisory family); `--exit-code` maps `ok=0 unavailable=2 error=3` for consumer-owned CI.

## Output formats — thin contract

The full native whisper.cpp transcript set is selectable — `txt` (default), `srt`, `vtt`, `json`, `json-full`, `csv`, `lrc` — as **flag passthrough** (the engine produces them; the skill just exposes the flag). The contract stays **thin**: no schema normalization, no caption rewrapping, no broadcast-quality promise; each produced file is recorded as an `outputs[]` entry and smoke-tested only for "exists + minimal parse". `-owts` (karaoke video script) is excluded — not a transcript. **`json-full` ships as raw native JSON; per-token timestamps (`--dtw`) are NOT promised in v1** — it is the one format with real marginal cost, deferred cleanly (flag-owned, not a follow-up spec).

## Storage

- Transcripts → a **dedicated gitignored dir** (`assets/transcripts/` by default) — they are the user's content; never auto-committed, `--quiet` for sensitive material.
- Provenance manifest → a **cumulative gitignored JSONL** (`assets/generated/.transcribe-manifest.jsonl`), one line per run (success AND failure): `ts, status, input, input_sha256, duration, engine, model, language, outputs[], stayed_local`.
- Engine + model cache → gitignored under `.agent0/.runtime-state/transcribe/`.

## Reopen-trigger (rule-of-three) — the paid STT lane

A paid STT backend (Deepgram/fal/OpenAI) is a **non-goal in v1**, with one named, falsifiable reopen-trigger: **diarization** (speaker labels), which whisper.cpp does not do cleanly. Bar = **three** real Agent0 transcriptions rendered unusable *specifically* for lack of diarization (or real-time streaming / domain-term boosting). At that point add a paid lane (Deepgram is the documented candidate); until then, do not build it. **Minority report from the meeting:** local-only v1 is *hypothesized* demand — if the first real dogfood is a multi-speaker recording, this trigger may fire immediately.

## Non-goals

Speaker diarization; real-time/streaming; per-token timestamps; audio editing/denoising; **TTS/synthesis/music/SFX (that is `/audio`)**; voice cloning (deferred family-wide); broadcast-quality subtitle tuning; a `faster-whisper` adapter (documented future, not v1 — keeps the first STT skill out of Python packaging); any cost apparatus.

## Forward-compat with `/audio`

`/audio` (synthesis, TTS-only v1) is the sibling spec. The two share conventions deliberately so they don't grow incompatible CLIs: the `assets/` storage location, the gitignored-JSONL manifest style, and the `doctor`/`caps` + result-status-decoupled-from-exit-code pattern. The split is by **output ontology** (text transform vs media asset), not a soft preference.
