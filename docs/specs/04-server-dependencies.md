# 4. Server Dependencies

| Server | Version | Download |
|--------|---------|----------|
| Ollama | v0.23.0 | [ollama-windows-amd64.zip](https://github.com/ollama/ollama/releases/download/v0.23.0/ollama-windows-amd64.zip) |
| ComfyUI | v0.33.1 | [ComfyUI_windows_portable_nvidia.7z](https://github.com/Comfy-Org/ComfyUI/releases/download/v0.33.1/ComfyUI_windows_portable_nvidia.7z) |
| Qwen | qwen3.5:9b (6.6 GB) | `ollama pull qwen3.5:9b` |

## Default Ports

The game bundles its own Ollama and ComfyUI instances and uses non-standard ports to avoid conflicts:

| Server | Default Port | Configurable Via |
|--------|-------------|-----------------|
| Ollama | 48763 | LLM Settings overlay → `user://llm_settings.json` |
| ComfyUI | 56321 | Image Server Settings overlay → `user://image_server_settings.json` |

## Binaries

Extract both into `server/`. Ollama goes into `server/ollama/`, ComfyUI into `server/ComfyUI/ComfyUI_windows_portable/`.
