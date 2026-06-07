---
paths:
  - ".agent0/skills/sound/**"
  - ".agent0/tools/sound.sh"
  - "assets/sound/**"
---

# Sound

`/sound` (engine `.agent0/tools/sound.sh`) is **creative-audio generation — music + sound effects**, **paid-only and taste-judged**. It is the creative-asset member of Agent0's audio family, alongside the recognition-side `/transcribe` (spec 159, STT) and the synthesis-side `/audio` (spec 160, TTS). The deliberate distinction: `/audio` is **local-first/free** because light on-device TTS engines exist (Kokoro/Piper); music/SFX has **no light local engine** (MusicGen is heavy/GPU), so `/sound` is openly the **`/image brand` analog** — paid, taste-judged, human-in-loop — NOT a `/audio` analog. Kept a **separate skill** (not folded into `/audio` as `--kind`) precisely so `/audio`'s local-first identity stays coherent. Graduated from the audio-family meeting's deferred music/SFX reopen-trigger (`.agent0/meetings/audio-transcribe-media-family-skills-2026-06-06T17-01-43Z/`). Spec: `docs/specs/161-sound/`.

## Paid-only by nature — no free lane

Dual-shape (vuln-audit/transcribe/audio lineage): skill `/sound` + runtime-neutral `.agent0/tools/sound.sh` (Codex/CI call it directly). The **only** lane is paid via the existing `.agent0/tools/fal-rest.sh` (synchronous `run` + `download`). There is no local fallback to pretend otherwise — when `FAL_KEY` is unset the result is `unavailable` with a one-line hint, honestly (never a crash, never a fake-local result). `stayed_local` is **always false** — every call sends the prompt to fal.

## The data-driven oracle (the key engineering decision)

Tier→model resolves from the date-stamped `sound-tiers.yaml` (no model IDs, body shapes, or url paths in code; refresh discipline mirrors `video-tiers.yaml`/`audio-tiers.yaml`). **Why data-driven, not just model-IDs-in-yaml:** body shapes AND output url paths **differ per model** — CassetteAI returns `audio_file.url` and takes `{prompt,duration}`; ElevenLabs returns `audio.url` and SFX takes `{text}`. A fixed `.audio.url`-style extraction would silently miss CassetteAI (the exact bug the `/audio` build narrowly avoided). So each tier carries everything the engine needs to be model-agnostic: `model`, `prompt_field`, `duration_field` (or null to omit), `output_url_path` (a jq path), `price`, `price_unit` (`per_second|per_minute|per_gen`), `default_duration`. The engine builds the body generically, computes `cost = price × duration_in_unit`, and extracts the url via the per-tier jq path. **New/changed model = a yaml edit, never a code change.**

- music `standard` = CassetteAI (~$0.02/min, default), `premium` = ElevenLabs Music (~$0.80/min)
- sfx = ElevenLabs Sound Effects v2 (~$0.002/sec); single tier (`--tier` is music-only)
- **`premium` (ElevenLabs Music) endpoint/body is the least-verified tier** — confirm at first real premium call; the oracle is the single edit point, and the cheap tiers (CassetteAI music, ElevenLabs SFX) are confirmed, so the skill works even if premium needs a one-line fix.

## Hybrid cost gate (the load-bearing safety)

Cost is **printed before every call** (image-style). A hard `--confirm-cost-usd ≥ estimate` is required **only when the estimate exceeds the $0.25 threshold** (env-overridable `AGENT0_SOUND_CONFIRM_THRESHOLD`). Cheap calls flow (a 5s SFX ≈ $0.01, a 30s CassetteAI track ≈ $0.01); ElevenLabs Music ($0.80/min) trips the gate. This differs from `/audio`/`/image` (print-only, no hard gate) because creative-audio clips can cost 100× a TTS call or an image — the gate prevents an accidental paid-music auto-fire.

## Taste-judged acceptance (no automated "done")

Quality is a **human listen**, like `/image brand` — there is no offline quality gate (tests prove the *contract* only: cost math, gate, manifest, url extraction, kind-required, no-key degrade). One generation → gitignored **draft** to listen to → the human promotes a keeper with `--asset` (writes the tracked dir) or **regenerates** (a new, cost-printed call). **One generation per call** — no N-candidate fan-out (N× cost contradicts the discipline; curation is listen-and-regen).

## Surface

`sound.sh "<prompt>" --kind music|sfx [--tier standard|premium] [--duration <sec>] [--asset] [--format mp3|wav] [--confirm-cost-usd <n>] [--json] [--exit-code]`, plus `doctor`/`caps`. `--kind` is **required** (music and SFX are distinct intents — mirrors `/image`'s required `--tier`). Result status `ok|unavailable|error` decoupled from exit code (default exit 0; `--exit-code` maps `ok=0 unavailable=2 error=3`).

## Storage — two output classes (mirrors /image, /audio)

- **draft** (default) → gitignored dir (`assets/generated/sound/`) — previews to audition.
- **asset** (`--asset`) → tracked dir (`assets/sound/`) — kept creative assets (committable, like `assets/brand/`).
- Models return mp3; `--format mp3` (default) re-encodes via ffmpeg if needed, `wav` passes through.
- **Manifest** → cumulative gitignored JSONL (`assets/generated/.sound-manifest.jsonl`), one line per call (success AND failure): `{ts,status,prompt,prompt_sha256,kind,tier,duration_sec,output,format,class,provider:"fal",model,cost_estimate_usd,request_id,stayed_local:false}`. `FAL_KEY` is **never** printed (`doctor` reports only `set`/`unset`) or written to the manifest.

## Privacy / licensing (honest)

The prompt is **always sent to fal** (`stayed_local:false`) — there is no local lane, stated plainly. Generated-audio **commercial-use terms are governed by the provider** (CassetteAI / ElevenLabs via fal) — check before shipping a keeper in a paid product. This is a note, not a blocker.

## Non-goals & reopen-triggers

- **A local generation lane** — no light/CPU-friendly local music/SFX engine exists; `/sound` is paid-only by design (the `/image brand` analog). Reopen if a viable light local engine appears.
- **N-candidate fan-out** — one generation per call (taste curation via listen-and-regen). Reopen-trigger: repeated manual regen friction.
- **Audio editing / mixing / mastering / stems / multitrack** — generation only, not a DAW.
- **Lyrics→sung-vocals** — model-dependent; out of v1 (text prompt → instrumental/SFX).
- **Voice cloning** — deferred family-wide (the `/audio` family decision).
- **A second paid provider beyond fal** — fal already fronts CassetteAI + ElevenLabs + others; one provider surface in v1.
- **Automated quality acceptance** — "sounds good" is a human judgment; no offline quality gate.

## Family coherence (with /transcribe + /audio)

Shared on purpose: `assets/` conventions, the gitignored hybrid-JSONL manifest style, `doctor`/`caps` + result-status-decoupled-from-exit-code, the data-driven tiers oracle for the paid lane. The split is by **output ontology + lane model**: `/transcribe` (audio→text, local), `/audio` (text→voice, local-first + optional paid), `/sound` (text→music/SFX, paid-only creative). Don't fold `/sound` into `/audio` — different lane model, cost shape, and acceptance standard.
