# 4. Server Dependencies

| Server | Version | Download |
|--------|---------|----------|
| llama.cpp | b10514 | [llama-b10514-bin-win-x64.zip](https://github.com/ggerganov/llama.cpp/releases/download/b10514/llama-b10514-bin-win-x64.zip) |
| ComfyUI | v0.33.1 | [ComfyUI_windows_portable_nvidia.7z](https://github.com/Comfy-Org/ComfyUI/releases/download/v0.33.1/ComfyUI_windows_portable_nvidia.7z) |
| Qwen | qwen3.5:9b (6.6 GB) | GGUF file placed in `server/llama/models/` |
| Sherpa-ONNX | v1.13.5 | [sherpa-onnx-v1.13.5-win-x64-shared.tar.bz2](https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.5/sherpa-onnx-v1.13.5-win-x64-shared.tar.bz2) |

## Default Ports

The game bundles its own llama.cpp and ComfyUI instances and uses non-standard ports to avoid conflicts:

| Server | Default Port | Configurable Via |
|--------|-------------|-----------------|
| llama.cpp | 48763 | LLM Settings overlay → `user://llm_settings.json` |
| ComfyUI | 56321 | Image Server Settings overlay → `user://image_server_settings.json` |

## Binaries

Extract both into `server/`. llama.cpp goes into `server/llama/`, ComfyUI into `server/ComfyUI/ComfyUI_windows_portable/`, Sherpa-ONNX into `server/sherpa-onnx/` (run `powershell -ExecutionPolicy Bypass -File scripts/download_sherpa.ps1`).

### Sherpa-ONNX Models (Piper VITS)

Bundled under `server/sherpa-onnx/models/` (gitignored, preserved on upgrade):
- `vits-piper-en_US-amy-low` (en female)
- `vits-piper-en_US-lessac-medium` (en male)
- `vits-piper-zh_CN-chaowen-medium` (zh male)
- `vits-piper-zh_CN-huayan-medium` (zh female / fallback)
TTS CLI: `server/sherpa-onnx/bin/sherpa-onnx-offline-tts.exe --vits-model <onnx> --vits-tokens <tokens> --vits-data-dir <espeak-ng-data> --output-filename <wav> "text"`

### TTS Auto-Play

- `TTSManager` (autoload) queues non-blocking wav generation per `interactions[].dialogue` after `new_story`/`new_scene`/edit/add/regenerate.
- Attaches `sound_filename` to each interaction and saves to `user://saves/<uuid>/sounds/tts_<idx>_<hash>.wav`.
- Auto-plays via `Gameplay/TTSPlayer` (AudioStreamPlayer) when `current_dialogue_index == generated idx` and `GameSettingsManager.settings.autoplay_tts == true` (interrupt previous).
- Also auto-plays on `Prev/Next Dialogue` and `Prev Scene` (scene reload) if wav exists.
- UTF-8 safe: writes PowerShell `.ps1` then `powershell -File` then deletes.
