# 4. Server Dependencies

| Server | Version | Download |
|--------|---------|----------|
| llama.cpp | b10514 | [llama-b10514-bin-win-x64.zip](https://github.com/ggerganov/llama.cpp/releases/download/b10514/llama-b10514-bin-win-x64.zip) |
| ComfyUI | v0.33.1 | [ComfyUI_windows_portable_nvidia.7z](https://github.com/Comfy-Org/ComfyUI/releases/download/v0.33.1/ComfyUI_windows_portable_nvidia.7z) |
| Qwen | qwen3.5:9b (6.6 GB) | GGUF file placed in `server/llama/models/` |

## Default Ports

The game bundles its own llama.cpp and ComfyUI instances and uses non-standard ports to avoid conflicts:

| Server | Default Port | Configurable Via |
|--------|-------------|-----------------|
| llama.cpp | 48763 | LLM Settings overlay → `user://llm_settings.json` |
| ComfyUI | 56321 | Image Server Settings overlay → `user://image_server_settings.json` |

## Binaries

Extract both into `server/`. llama.cpp goes into `server/llama/`, ComfyUI into `server/ComfyUI/ComfyUI_windows_portable/`.
