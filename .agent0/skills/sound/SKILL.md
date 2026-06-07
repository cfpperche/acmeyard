---
name: sound
description: Generate creative audio - music and sound effects (opt-in, paid-only). Use when the user wants a generated audio asset for the project - UI SFX (clicks, whooshes, dings), a soundtrack, a demo sting, an ambient bed. Wraps the runtime-neutral .agent0/tools/sound.sh. Paid-only by nature (no light local music/SFX engine) - the /image brand analog, NOT the local-first /audio analog; tier->model resolves from a data-driven sound-tiers.yaml oracle via fal. Cost printed before every call, with a hard --confirm-cost-usd gate above $0.25. Taste-judged - one generation lands in a gitignored draft to audition, the human promotes a keeper with --asset. NOT text-to-speech (sibling /audio), NOT transcription (/transcribe), NOT editing/mixing/mastering, NOT lyrics-to-vocals, NOT voice cloning. Flags - "<prompt>" --kind music|sfx [--tier standard|premium] [--duration <sec>] [--asset] [--format mp3|wav] [--confirm-cost-usd <n>] [--json] [--exit-code]; subcommands doctor / caps. See .agent0/context/rules/sound.md.
argument-hint: "\"<prompt>\" --kind music|sfx [--tier standard|premium] [--duration <sec>] [--asset] [--confirm-cost-usd <n>]"
license: MIT
compatibility: Designed for Claude Code. Core logic is the runtime-neutral bash tool `.agent0/tools/sound.sh` (fal-rest.sh + a data-driven sound-tiers.yaml oracle + ffmpeg); the skill is a thin invocation wrapper. Codex CLI invokes the tool directly.
metadata:
  agent0-portability-tier: agentskills-portable
  version: "0.1"
---

# /sound — creative-audio generation (music + SFX)

Thin wrapper over `.agent0/tools/sound.sh`. The tool is the engine; this skill decides when to run it and how to surface the result. See `.agent0/context/rules/sound.md` for the full capacity contract (paid-only stance, the `/image brand` analogy, the hybrid cost gate, taste-judged acceptance, the data-driven oracle, non-goals).

## When to run

Run on demand when the user wants a **generated audio asset** — music or a sound effect — for a product the harness serves: UI SFX (clicks, whooshes, notification dings), a landing-page/demo soundtrack, a release sting, an ambient bed. It is **paid-only by nature** (there is no light local music/SFX engine — unlike TTS's Kokoro/Piper). It is **not** text-to-speech (text→spoken voice is the sibling `/audio`), **not** transcription (`/transcribe`), **not** audio editing/mixing, and **not** voice cloning.

## What to do

1. **Parse `$ARGUMENTS`** — pass straight through. The prompt and `--kind` are required:
   - `"<prompt>"` — the creative brief (e.g. `"lofi hip hop, mellow, rainy"`, `"UI button click, soft"`).
   - `--kind music|sfx` — **required**; music and SFX are distinct intents (mirrors `/image`'s required `--tier`). Omitting it errors.
   - `--tier standard|premium` — **music only**; `standard` = CassetteAI (~$0.02/min, the default), `premium` = ElevenLabs Music (~$0.80/min). SFX has a single tier.
   - `--duration <sec>` — clip length; sensible per-kind default otherwise (sfx ~5s, music ~30s).
   - `--asset` — promote to the **tracked** asset dir (a keeper) instead of the gitignored draft dir.
   - `--format mp3|wav` — default mp3.
   - `--confirm-cost-usd <n>` — required only when the estimate exceeds $0.25 (the hard gate); pass a value ≥ the printed estimate.

2. **Invoke the tool:**
   ```bash
   bash .agent0/tools/sound.sh "$ARGUMENTS"
   ```

3. **Surface the result** — first line `sound: status=<ok|unavailable|error>`:
   - **`ok`** — report the written path; note the class (draft/asset) and the cost. Nudge the taste-judge step: the draft is a preview to **listen to** — promote a keeper with `--asset` or regenerate.
   - **`unavailable`** — paid-only and `FAL_KEY` is unset (no free local fallback by nature). Relay the one-line hint; there is no local lane to fall back to.
   - **`error`** — input/runtime problem (missing `--kind`, cost above threshold without `--confirm-cost-usd`, fal/download failure). Relay the diagnostic; for the cost gate, re-run with the printed `--confirm-cost-usd`.

4. **Cost is always printed before the call** — surface it. This is paid every time (`stayed_local:false` always); there is no free lane. Don't generate speculatively — one generation per call, by design (no N-candidate fan-out).

5. **Taste-judged acceptance (no auto-done):** quality is a human listen, like `/image brand`. The tool never declares a keeper — it produces a draft; the human promotes with `--asset` or regenerates.

## Discipline

- Paid-only by nature — never add a fake "local lane"; if `FAL_KEY` is absent it reports `unavailable`, honestly.
- Never auto-fire a paid call above the confirm threshold — the hard `--confirm-cost-usd` gate is load-bearing.
- One generation per call — no N-variant fan-out (contradicts the cost discipline).
- Music/SFX only — TTS is `/audio`, transcription is `/transcribe`; editing/mixing/mastering, lyrics-to-vocals, and voice cloning are out of scope (see the rule).

## Notes

_Consumer-extension surface — append consumer-local bullets here._

- Tier→model + body shape + output url path + price all live in `references/sound-tiers.yaml` (the data-driven oracle); a new/changed model is a yaml edit, never a code change. Refresh when stale.
- ElevenLabs Music (premium) endpoint/body is the least-verified tier — confirm at first real premium call (the oracle is the single edit point).
- Generated-audio commercial-use terms are governed by the provider; check before shipping a keeper in a paid product.
