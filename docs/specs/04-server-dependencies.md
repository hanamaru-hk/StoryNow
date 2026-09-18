# 4. Server Dependencies

| Server | Version (bundled) | Download |
|--------|-------------------|----------|
| llama.cpp | b10514 (and later) | [llama-b10514-bin-win-x64.zip](https://github.com/ggerganov/llama.cpp/releases/download/b10514/llama-b10514-bin-win-x64.zip) — extracted to `s/llama/` |
| ComfyUI | v0.33.1 (portable) | [ComfyUI_windows_portable_nvidia.7z](https://github.com/Comfy-Org/ComfyUI/releases/download/v0.33.1/ComfyUI_windows_portable_nvidia.7z) — portable root installed as `s/c/`, with `python_embeded/` renamed to `py/` and patched per the packaging guide |
| LLM model | ≤9B GGUF | `data/llama-models/cen/huihui-qwen3.5-9b-Q4_K_M.gguf` (primary, `scripts/llm_manager.gd:45`); alt `data/llama-models/ab/DeepSeek-R1-Distill-Llama-8B-Uncensored.Q4_K_M.gguf`, `data/llama-models/cen/unsloth__Qwen3.5-9B-UD-Q3_K_XL.gguf` supported |
| Sherpa-ONNX | v1.13.5 | [sherpa-onnx-v1.13.5-win-x64-shared.tar.bz2](https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.5/sherpa-onnx-v1.13.5-win-x64-shared.tar.bz2) — extracted to `s/sherpa-onnx/` (run `powershell -ExecutionPolicy Bypass -File scripts/download_sherpa.ps1`; native Godot wrapper lives in `addons/sherpa_tts/`) |
| SDXL Checkpoint | e.g. `waiIllustriousSDXL_v170.safetensors` | Placed in `s/c/ComfyUI/models/checkpoints/`; selected via `ImageServerSettingsManager.settings.model_filename` |

The local and Steam layouts both use the shortened ComfyUI paths to stay below
legacy Windows path limits; follow
[Steam package path-shortening and ComfyUI patching](../steam-package-patching.md)
when preparing or refreshing that package.

## Default Ports

Bundled servers use non-standard ports to avoid conflicts:

| Server | Default Port | Configurable Via | Persisted To |
|--------|-------------|-----------------|--------------|
| llama.cpp | 48763 | LLM Settings overlay | `user://llm_settings.json` (`data/default_llm_settings.json`) |
| ComfyUI | 56321 | Image Server Settings overlay | `user://image_server_settings.json` (`data/default_image_server_settings.json`) |

Health endpoints: `GET http://127.0.0.1:<llm_port>/health` and `GET http://127.0.0.1:<comfy_port>/system_stats` (`scripts/llm_manager.gd:72`, `scripts/image_server_manager.gd:55`).

## Binaries Layout

```
s/
├── llama/llama-server.exe (+ .dlls)
└── sherpa-onnx/
    ├── bin/sherpa-onnx-offline-tts.exe
    ├── lib/*.dll
    └── models/
        ├── vits-piper-en_US-amy-low/
        ├── vits-piper-en_US-lessac-medium/
        ├── vits-piper-zh_CN-chaowen-medium/
        ├── vits-piper-zh_CN-huayan-medium/
        ├── vits-piper-zh_CN-xiao_ya-medium/
        └── vits-cantonese-hf-xiaomaiiwn/
```

```
s/c/
├── py/python.exe
└── ComfyUI/main.py
```

```
data/llama-models/
├── cen/*.gguf
└── ab/*.gguf
```

### Sherpa-ONNX Models (Piper VITS)

Bundled under `data/sherpa-models/` (gitignored, preserved on upgrade):

- `vits-piper-en_US-amy-low` (en female — `MODEL_EN_FEMALE`)
- `vits-piper-en_US-lessac-medium` (en male — `MODEL_EN_MALE`)
- `vits-piper-zh_CN-chaowen-medium` (zh male — `MODEL_ZH_MALE`)
- `vits-piper-zh_CN-huayan-medium` (zh female/fallback — `MODEL_ZH_FEMALE`)
- `vits-cantonese-hf-xiaomaiiwn` (yue fallback)
- `vits-melo-tts-ja` (ja fallback — `MODEL_JA_FALLBACK`; install with `scripts/download_japanese_tts.ps1`)

Model selection in `scripts/tts_manager.gd:39-57` by `language` + `gender`. Each needs `*.onnx`, `tokens.txt`, and either `espeak-ng-data/` or `lexicon.txt` + `*.fst`.

Japanese TTS uses the single-speaker Japanese MeloTTS ONNX export from `MiaoMint/MeloTTS-ONNX`, pinned by revision and SHA-256 in `scripts/download_japanese_tts.ps1`. Sherpa 1.13.5 only selects its tone-aware Melo frontend for Chinese or English model metadata, so the installer changes the frontend-routing `language` metadata to `English` while retaining the Japanese `language_code`, `lang_id`, speaker, tone input, and synthesis graph. The original lexicon is preserved. MeloTTS is MIT licensed. Model files and installer build artifacts remain machine-local in gitignored directories, like the Cantonese voice.

TTS uses the native `SherpaOfflineTTS` GDExtension. The extension links to Sherpa-ONNX C API libraries and writes WAV output directly from native code.

### TTS Auto-Play

- `TTSManager` (autoload) queues non-blocking wav generation per `interactions[].dialogue` after `new_story`/`new_scene`/edit/add/regenerate.
- Attaches `sound_filename` to each interaction and saves to `user://saves/<uuid>/sounds/tts_<idx>_<hash>.wav` (`scripts/tts_manager.gd:222`).
- Auto-plays via `Gameplay/TTSPlayer` (`AudioStreamPlayer`) when `current_dialogue_index == generated idx` and `GameSettingsManager.settings.autoplay_tts == true` (interrupt previous). Also on `Prev/Next Dialogue` and `Prev Scene` reload if wav exists. The `TTSVoice` bus applies the persisted `voice_volume` and `voice_muted` Game Settings to both automatic and manual playback.
- Cantonese male uses pitch 0.7x via `TTSVoice` bus `AudioEffectPitchShift` (`scripts/gameplay.gd:4-5`).
- Japanese male uses a 0.76x pitch shift plus 0.92x playback speed (about 0.7x combined pitch); Japanese female/other dialogue uses the source voice unchanged.
- UTF-8 safe: dialogue text is passed to the native GDExtension as a Godot `String`, converted to UTF-8 in C++, and synthesized through Sherpa-ONNX without a Python subprocess.

### Builder vs Safe Mode

`GameSettingsManager.is_builder_mode()` returns `true` when `safe_mode == false` and `data/builder` contains at least one file. This switches:

- LLM guardrail: `data/llm/<lang>/common/builder_guardrail` vs `safe_guardrail`
- Danbooru guardrail: `builder_danbooru_guardrail` vs `safe_danbooru_guardrail`
- ComfyUI negative prompt: `builder_negative_prompt` vs `safe_negative_prompt`
- Image prompt editability in `ImageOverlay`
