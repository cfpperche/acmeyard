#!/usr/bin/env python3
# .agent0/tools/audio-kokoro.py
#
# Minimal first-party Kokoro TTS shim invoked by audio.sh (spec 160). We ship
# this ~tiny shim instead of depending on an un-vetted third-party Kokoro CLI
# (same reasoning that made /video ship its own HyperFrames composition).
# Run via: uvx --with kokoro --with soundfile python audio-kokoro.py ...
#
# Kokoro needs espeak-ng (a SYSTEM binary) for phonemization — audio.sh checks
# for it and degrades to an install hint BEFORE invoking this shim.
#
# Pinned expectation: kokoro >= 0.9 (KPipeline API). Pre-1.0 — may drift.

import argparse
import sys


# --lang code -> Kokoro lang_code (a=American EN, b=British, p=Brazilian PT,
# e=Spanish, f=French, h=Hindi, i=Italian, j=Japanese, z=Mandarin).
LANG_MAP = {
    "en": "a", "en-us": "a", "en-gb": "b", "br": "b",
    "pt": "p", "pt-br": "p",
    "es": "e", "fr": "f", "hi": "h", "it": "i", "ja": "j", "zh": "z",
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--text", required=True)
    ap.add_argument("--voice", default="af_heart")
    ap.add_argument("--lang", default="en")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    lang_code = LANG_MAP.get(args.lang.lower(), args.lang if len(args.lang) == 1 else "a")

    try:
        import numpy as np
        import soundfile as sf
        from kokoro import KPipeline
    except Exception as e:  # import failure = unavailable, not a crash
        print(f"kokoro-shim: dependency import failed: {e}", file=sys.stderr)
        return 3

    try:
        pipeline = KPipeline(lang_code=lang_code)
        chunks = []
        for result in pipeline(args.text, voice=args.voice):
            # KPipeline yields (graphemes, phonemes, audio) per segment.
            audio = result[-1] if isinstance(result, (tuple, list)) else getattr(result, "audio", None)
            if audio is not None:
                chunks.append(np.asarray(audio, dtype="float32"))
        if not chunks:
            print("kokoro-shim: no audio produced", file=sys.stderr)
            return 3
        sf.write(args.out, np.concatenate(chunks), 24000)
    except Exception as e:
        print(f"kokoro-shim: synthesis failed: {e}", file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
