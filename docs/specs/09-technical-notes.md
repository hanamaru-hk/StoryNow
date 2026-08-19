# 9. Technical Notes

## 9.1 Ollama API

- Health check endpoint: `GET http://127.0.0.1:<port>/api/tags`
- Chat endpoint: `POST http://127.0.0.1:<port>/api/chat`
- Default port: **48763** (configurable via LLM Settings overlay)
- Model: configurable, ≤9B parameter models.
- System prompt forces JSON output with the scene schema.
- Conversation history includes: system prompt + state object + last N scene exchanges.

## 9.2 ComfyUI API

- Health check endpoint: `GET http://127.0.0.1:<port>/system_stats`
- Submit workflow: `POST http://127.0.0.1:<port>/prompt`
- Default port: **56321** (configurable via Image Server Settings overlay)
- Poll for completion or use websocket for image output.
- Workflow template: `data/comfyui/workflow-template.json`
- Workflow is a txt2img SDXL-compatible pipeline with prompt injection.

### 9.2.1 Workflow Placeholders

The workflow template uses the following placeholders, to be replaced at runtime before submission:

| Placeholder | Node | Field | Description |
|---|---|---|---|
| `__MODEL_NAME__` | `1` (`CheckpointLoaderSimple`) | `inputs.ckpt_name` | Checkpoint filename (e.g. `waiIllustriousSDXL_v170.safetensors`) |
| `__POSITIVE_PROMPT__` | `3` (`CLIPTextEncode`) | `inputs.text` | Positive prompt text |
| `__NEGATIVE_PROMPT__` | `6` (`CLIPTextEncode`) | `inputs.text` | Negative prompt text |
| `__SEED__` | `2` (`KSampler`) | `inputs.seed` | Random seed for reproducibility |
| `__FILENAME_PREFIX__` | `5` (`SaveImage`) | `inputs.filename_prefix` | Output filename prefix |

### 9.2.2 Request Structure

```json
{
  "client_id": "instant-visual-novel",
  "prompt": { ... },
  "extra_data": {}
}
```

- `client_id`: identifies this app; used to filter history.
- `prompt`: the ComfyUI node graph (keyed by node ID).
- `extra_data`: reserved for future use.

## 9.3 Server Lifecycle Management

- **ServerRuntimeManager** coordinates both servers:
  - Reconciles stale persisted state on startup (resets pid/running/healthy).
  - Starts both servers on app launch.
  - Runs 15-second heartbeat health checks.
  - Adds `ServerStatusOverlay` to the scene tree.
  - Shuts down owned processes on exit (`taskkill /T /F /PID` on Windows).
- **LLMManager** / **ImageServerManager** manage individual processes:
  - Status persisted to `user://llm_status.json` / `user://image_server_status.json`.
  - Ollama started via `server/ollama/ollama.exe serve` with `OLLAMA_HOST` env var.
  - ComfyUI started via `server/ComfyUI/ComfyUI_windows_portable/python_embeded/python.exe -s ComfyUI/main.py --port <port> --windows-standalone-build --disable-auto-launch`.

## 9.4 Display

- Viewport: 1920x1080, `canvas_items` stretch mode.
- Two display modes: fullscreen, or windowed at 1344x768.
- Rendering method: GL Compatibility.
- UI elements use Godot anchors/containers for layout.

## 9.5 Image Storage

- Generated images saved to `user://generated_images/<scene_id>.png`
- Referenced by path in save data and scene data.
