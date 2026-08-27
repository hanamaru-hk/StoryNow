# 4. Server Dependencies

| Server | Version (bundled) | Download |
|--------|-------------------|----------|
| llama.cpp | b10514 (and later) | [llama-b10514-bin-win-x64.zip](https://github.com/ggerganov/llama.cpp/releases/download/b10514/llama-b10514-bin-win-x64.zip) — extracted to `server/llama/` |
| ComfyUI | v0.33.1 (portable) | [ComfyUI_windows_portable_nvidia.7z](https://github.com/Comfy-Org/ComfyUI/releases/download/v0.33.1/ComfyUI_windows_portable_nvidia.7z) — extracted to `server/ComfyUI/ComfyUI_windows_portable/` |
| LLM model | ≤9B GGUF | `server/llama-models/huihui-qwen3.5-9b-Q4_K_M.gguf` (primary, `scripts/llm_manager.gd:45`); alt `DeepSeek-R1-Distill-Llama-8B-Uncensored.Q4_K_M.gguf`, `unsloth__Qwen3.5-9B-UD-Q3_K_XL.gguf` supported |
| Sherpa-ONNX | v1.13.5 | [sherpa-onnx-v1.13.5-win-x64-shared.tar.bz2](https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.5/sherpa-onnx-v1.13.5-win-x64-shared.tar.bz2) — extracted to `server/sherpa-onnx/` (run `powershell -ExecutionPolicy Bypass -File scripts/download_sherpa.ps1`; run `powershell -ExecutionPolicy Bypass -File scripts/setup_sherpa_python.ps1` for the TTS Python venv) |
| SDXL Checkpoint | e.g. `waiIllustriousSDXL_v170.safetensors` | Placed in `server/ComfyUI/ComfyUI_windows_portable/ComfyUI/models/checkpoints/`; selected via `ImageServerSettingsManager.settings.model_filename` |

## Default Ports

Bundled servers use non-standard ports to avoid conflicts:

| Server | Default Port | Configurable Via | Persisted To |
|--------|-------------|-----------------|--------------|
| llama.cpp | 48763 | LLM Settings overlay | `user://llm_settings.json` (`data/default_llm_settings.json`) |
| ComfyUI | 56321 | Image Server Settings overlay | `user://image_server_settings.json` (`data/default_image_server_settings.json`) |

Health endpoints: `GET http://127.0.0.1:<llm_port>/health` and `GET http://127.0.0.1:<comfy_port>/system_stats` (`scripts/llm_manager.gd:72`, `scripts/image_server_manager.gd:55`).

## Binaries Layout

```
server/
├── llama/llama-server.exe (+ .dlls)
├── llama-models/*.gguf
├── ComfyUI/ComfyUI_windows_portable/
│   ├── python_embeded/python.exe
│   └── ComfyUI/main.py
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

### Sherpa-ONNX Models (Piper VITS)

Bundled under `server/sherpa-onnx/models/` (gitignored, preserved on upgrade):

- `vits-piper-en_US-amy-low` (en female — `MODEL_EN_FEMALE`)
- `vits-piper-en_US-lessac-medium` (en male — `MODEL_EN_MALE`)
- `vits-piper-zh_CN-chaowen-medium` (zh male — `MODEL_ZH_MALE`)
- `vits-piper-zh_CN-huayan-medium` (zh female/fallback — `MODEL_ZH_FEMALE`)
- `vits-cantonese-hf-xiaomaiiwn` (yue fallback)

Model selection in `scripts/tts_manager.gd:39-57` by `language` + `sex`. Each needs `*.onnx`, `tokens.txt`, and either `espeak-ng-data/` or `lexicon.txt` + `*.fst`.

TTS uses `scripts/tts_helper.py` through the Sherpa-local Python venv when present: `server/sherpa-onnx/python/Scripts/python.exe tts_helper.py --vits-model <onnx> --vits-tokens <tokens> [--vits-data-dir <…> | --vits-lexicon <…> --tts-rule-fsts <…>] --output-filename <wav> --text-file <utf8.txt>`. If the venv is missing, `TTSManager` falls back to `py` / `python`.

### TTS Auto-Play

- `TTSManager` (autoload) queues non-blocking wav generation per `interactions[].dialogue` after `new_story`/`new_scene`/edit/add/regenerate.
- Attaches `sound_filename` to each interaction and saves to `user://saves/<uuid>/sounds/tts_<idx>_<hash>.wav` (`scripts/tts_manager.gd:222`).
- Auto-plays via `Gameplay/TTSPlayer` (`AudioStreamPlayer`) when `current_dialogue_index == generated idx` and `GameSettingsManager.settings.autoplay_tts == true` (interrupt previous). Also on `Prev/Next Dialogue` and `Prev Scene` reload if wav exists (`scripts/gameplay.gd:993`).
- Cantonese male uses pitch 0.7x via `TTSVoice` bus `AudioEffectPitchShift` (`scripts/gameplay.gd:4-5`).
- UTF-8 safe: writes `user://tmp_tts_<id>.txt` + `.ps1` then `powershell -File` then deletes; PowerShell prefers `server/sherpa-onnx/python/Scripts/python.exe`, falling back to `py` / `python`; process is polled via `OS.create_process` (`scripts/tts_manager.gd:272-355`).

### Free vs Safe Mode

`GameSettingsManager.is_free_mode()` (`scripts/game_settings_manager.gd:80`) returns `true` when `safe_mode == false` and file `res://data/free_mode` exists. This switches:

- LLM guardrail: `data/llm/<lang>/common/free_guardrail` vs `safe_guardrail`
- Danbooru guardrail: `free_danbooru_guardrail` vs `safe_danbooru_guardrail`
- ComfyUI negative prompt: `free_negative_prompt` (typo alias `free_negatvie_prompt`) vs `safe_negative_prompt`
- Image prompt editability in `ImageOverlay`
