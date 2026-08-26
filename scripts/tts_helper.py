#!/usr/bin/env python3
"""Godot -> UTF-8 text file -> PowerShell -> Sherpa (reliable file method)
Reads UTF-8 text file and generates WAV via sherpa_onnx Python API (no Chinese in argv)
"""
import argparse
import pathlib
import sys

import sherpa_onnx
import soundfile as sf


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--vits-model", type=str, default="")
    p.add_argument("--vits-tokens", type=str, default="")
    p.add_argument("--vits-data-dir", type=str, default="")
    p.add_argument("--vits-lexicon", type=str, default="")
    p.add_argument("--tts-rule-fsts", type=str, default="")
    p.add_argument("--output-filename", type=str, required=True)
    p.add_argument("--text-file", type=str, default="")
    p.add_argument("--text", type=str, default="")
    p.add_argument("--sid", type=int, default=0)
    p.add_argument("--speed", type=float, default=1.0)
    p.add_argument("--num-threads", type=int, default=4)
    return p.parse_args()


def main():
    # Ensure stdout can handle UTF-8 on Windows cp932 consoles
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    args = parse_args()
    text = ""
    if args.text_file:
        # Godot writes UTF-8 (no BOM needed, but handle BOM)
        try:
            text = pathlib.Path(args.text_file).read_text(encoding="utf-8-sig").strip()
        except Exception as e:
            print(f"Failed to read text file {args.text_file}: {e}", file=sys.stderr)
            sys.exit(1)
    elif args.text:
        text = args.text
    else:
        print("No text provided (need --text-file or --text)", file=sys.stderr)
        sys.exit(1)

    if not text.strip():
        print("Empty text, nothing to do")
        sys.exit(0)

    # Build TTS config (mirrors offline-tts.py)
    tts_config = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            vits=sherpa_onnx.OfflineTtsVitsModelConfig(
                model=args.vits_model,
                lexicon=args.vits_lexicon,
                data_dir=args.vits_data_dir,
                tokens=args.vits_tokens,
            ),
            provider="cpu",
            debug=False,
            num_threads=args.num_threads,
        ),
        rule_fsts=args.tts_rule_fsts,
        max_num_sentences=1,
    )
    if not tts_config.validate():
        print("Invalid TTS config", file=sys.stderr)
        print(args, file=sys.stderr)
        sys.exit(1)

    tts = sherpa_onnx.OfflineTts(tts_config)
    gen_config = sherpa_onnx.GenerationConfig()
    gen_config.sid = args.sid
    gen_config.speed = args.speed

    audio = tts.generate(text, gen_config)
    if len(audio.samples) == 0:
        print("Failed to generate audio", file=sys.stderr)
        sys.exit(1)

    sf.write(args.output_filename, audio.samples, samplerate=audio.sample_rate, subtype="PCM_16")
    # Avoid cp932 encode error on Windows consoles
    safe_text = text[:80].encode("utf-8", errors="replace").decode("utf-8", errors="replace")
    print(f"Saved to {args.output_filename} ({len(audio.samples)/audio.sample_rate:.2f}s) text='{safe_text}'")


if __name__ == "__main__":
    main()
