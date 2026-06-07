---
paths:
  - ".agent0/skills/audio/**"
  - ".agent0/tools/audio.sh"
  - ".agent0/tools/audio-kokoro.py"
  - "assets/audio/**"
---

# Audio

`/audio` (engine `.agent0/tools/audio.sh`) is **text-to-speech synthesis**, local-first and free by default with an optional paid upgrade. It is the synthesis member of Agent0's audio family — the counterpart of the recognition-side `/transcribe` (spec 159) — shaped in the decision-grade meeting `.agent0/meetings/audio-transcribe-media-family-skills-2026-06-06T17-01-43Z/` (split by **output ontology**: synthesis produces a media asset, recognition produces text). v1 is **TTS only**. Spec: `docs/specs/160-audio/`.

## Two local engines (free, on-device) — asymmetric acquisition

Dual-shape vuln-audit/transcribe: skill `/audio` + runtime-neutral `.agent0/tools/audio.sh` (Codex/CI call it directly). Two engines are first-class co-defaults; the founder chose breadth over one-default-one-documented (accepted cost: double the acquisition/voice/test surface):

- **Kokoro** — zero-`--engine` default. Multilingual incl. **pt-BR**, Apache-2.0 weights, grade-A voices, best quality. BUT the official package is a **library, not a CLI**, and phonemization needs **espeak-ng — a system binary** `uvx` cannot install. So it is invoked via a tiny **first-party shim** `.agent0/tools/audio-kokoro.py` (run through `uvx --with kokoro --with soundfile python …`), and when `espeak-ng` is absent the lane degrades to a one-line `apt-get/brew install espeak-ng` hint (status `unavailable`), never a crash. **This is the headline acquisition risk** — Kokoro is the *quality* default but the *less* invisible one.
- **Piper** (`--engine piper`) — `pip install piper-tts` ships a native `piper` CLI and **embeds phonemization**; voices are self-contained ONNX from HF `rhasspy/piper`. Fully `uvx`-able. The **more self-contained fallback** — recommend it whenever Kokoro's espeak-ng dep can't be met.

Acquisition is otherwise the `/transcribe` posture: auto-acquire as invisibly as possible (uvx ladder; voices/weights fetched once to a gitignored cache), engines **user-installed + subprocess-invoked, never bundled** (GPL-via-subprocess = aggregation — Kokoro→espeak-ng GPL-3.0, Piper successor GPL-3.0; the HyperFrames `npx` posture).

## Paid lane (`--remote`) — offers what local can't

Opt-in, via the existing `.agent0/tools/fal-rest.sh` (synchronous `run` + `download`). The paid tiers are **ElevenLabs only**, by design: fal also hosts Kokoro, but the local lane already gives Kokoro **free** — the paid lane's job is expressiveness/70+-languages the local engines can't match. Tier→model resolves from the date-stamped `audio-tiers.yaml` oracle (no model IDs in code; refresh discipline mirrors `video-tiers.yaml`): `standard` = ElevenLabs Turbo v2.5 (~$0.05/1k chars), `premium` = ElevenLabs v3 (~$0.10/1k). Cost (`ceil(chars/1000) × rate`) is **printed before** the call (image-style cost-print; **no** hard gate and **no** per-session counter — TTS is cheap; matches `/image`/`/video` v1). Needs `FAL_KEY`.

## Privacy boundary (honest by design)

Local lane: text and audio **stay on the machine** (`stayed_local: true`); only engine/voice weights are fetched once. Paid lane: the **text is sent to fal** (`stayed_local: false`) — stated, never obscured. `FAL_KEY` is never printed (`doctor` reports only `set`/`unset`) and never written to the manifest.

## Surface

`audio.sh "<text>" [--engine kokoro|piper] [--remote] [--tier standard|premium] [--asset] [--voice <name>] [--lang <code>] [--format mp3|wav] [--quiet] [--json] [--exit-code]`, plus `doctor`/`caps`. Composable flags (the `/transcribe` style); default = local Kokoro, draft class, mp3. Result status `ok|unavailable|error` decoupled from exit code (default exit 0; `--exit-code` maps `ok=0 unavailable=2 error=3`).

## Storage — two output classes (mirrors /image)

- **draft** (default) → gitignored dir (`assets/generated/audio/`) — throwaway previews.
- **asset** (`--asset`) → tracked dir (`assets/audio/`) — kept voiceovers.
- Engines emit WAV; `--format mp3` (default) encodes via ffmpeg (already a dep), `wav` passes through.
- **Manifest** → cumulative gitignored hybrid JSONL (`assets/generated/.audio-manifest.jsonl`), one line per call (success AND failure): shared `{ts,status,text_sha256,chars,output,format,class,stayed_local}` + provenance for local (`engine,voice,language`) + cost for paid (`provider,model,cost_estimate_usd,request_id`).
- Engine/voice cache → gitignored `.agent0/.runtime-state/audio/`.

## Non-goals & reopen-triggers

- **Music / SFX generation** — deferred (paid-only, different acceptance standard); own reopen-trigger.
- **Voice cloning** — deferred family-wide (fraud/impersonation + non-commercial local-engine license); on reopen, paid-only + a first-class `--consent-attested` gate.
- **Second paid provider beyond fal** (ElevenLabs-direct) — deferred; fal already fronts ElevenLabs.
- **SSML/prosody authoring, streaming/real-time, input-language auto-detection, engine bundling, hard cost gate / budget counter** — all out of v1 (see spec Non-goals).

## Forward-compat with /transcribe

Shared on purpose so the family doesn't grow incompatible CLIs: `assets/` conventions, the gitignored hybrid-JSONL manifest style, `doctor`/`caps` + result-status-decoupled-from-exit-code. The split is by output ontology, not preference.
