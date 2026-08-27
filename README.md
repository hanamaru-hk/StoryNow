# Instant Visual Novel

AI-generated visual novel — Godot client that drives local **llama.cpp**, **ComfyUI**, and native **Sherpa-ONNX** TTS. Player enters a story background (or random), then plays round-by-round with LLM-generated dialogue/choices, SDXL illustrations, and per-line TTS.

> Specs: [`docs/specs/index.md`](docs/specs/index.md) — overview, architecture, story/image/TTS, UI, save/load, technical notes.

## Quick Start

1. **Install Godot 4.3** (GL Compatibility renderer).
2. **Servers:** extract binaries into `server/`:
   - `server/llama/llama-server.exe` (llama.cpp b10514+)
   - `server/llama-models/huihui-qwen3.5-9b-Q4_K_M.gguf` (primary)
   - `server/ComfyUI/ComfyUI_windows_portable/` (+ checkpoint `waiIllustriousSDXL_v170.safetensors` under `ComfyUI/models/checkpoints/`)
   - `server/sherpa-onnx/` for TTS models and Sherpa runtime libs (`powershell -ExecutionPolicy Bypass -File scripts/download_sherpa.ps1`; native Godot wrapper lives in `addons/sherpa_tts/`)
3. **Open** `project.godot` in Godot, run. `ServerRuntimeManager` auto-starts both servers, heartbeat 8s, status dots top-right.
4. **Play:** Start → (optional Random/Enhance) → Start → Gameplay (choices → next scene). Saves under `user://saves/<uuid>/` (`OS.get_user_data_dir()`).

## Defaults & Config

| Setting | Default | Where |
|---------|---------|-------|
| LLM port | 48763 | LLM Settings → `user://llm_settings.json` |
| ComfyUI port | 56321 | Image Server Settings → `user://image_server_settings.json` |
| Checkpoint | `waiIllustriousSDXL_v170.safetensors` | Image Server Settings `model_filename` |
| Resolution | 1920×1080 viewport; images 1344×768 | Game Settings (Full / 1344×768) + `image_width`/`height` in `default_game_settings.json` |
| Rounds | expected 20 | Advanced Settings → `user://game_progress.json` |

## How It Works

- **Story:** `data/llm/<lang>/{story,scene}` + `common/` templates → `LLMManager._request_completion` → `POST /v1/chat/completions` → JSON (`interactions`/`choices`/`image_prompt`/`summary`/`title`/`end`/`language`) → repair `image_prompt` bare quotes → merge into `SceneDataManager.scene_data`.
- **Image:** `data/comfyui/workflow_template.json` placeholders replaced → `POST /prompt` → poll `/history/<id>` → `GET /view` → `user://saves/<uuid>/images/`.
- **TTS:** `TTSManager` queues Sherpa synthesis per `interactions[].dialogue` (sex+language model select), uses the native `SherpaOfflineTTS` GDExtension in `addons/sherpa_tts/`, saves `sounds/tts_<idx>_<hash>.wav`, and auto-plays on dialogue change.

Chrome hides on right-click background, restores on left-click; `ServerStatusOverlay` shows health dots + request queue.

## Project Layout

```
scenes/  main, brainstorm, gameplay (+ 12 overlays)
scripts/ managers (llm, image_server, server_runtime, game_progress, scene_data, tts, i18n, game_settings) + overlays + gameplay/brainstorm/main
data/    theme, defaults, comfyui workflow/negative prompts, llm prompts per lang
server/  llama, llama-models, ComfyUI, sherpa-onnx models/runtime libs (gitignored)
addons/  sherpa_tts native Godot TTS extension
saves/   dev mirror; runtime saves in user://saves/<uuid>/
```

Autoloads: `I18n`, `GameSettingsManager`, `LLM/Image Server SettingsManager`, `LLMManager`, `ImageServerManager`, `ServerRuntimeManager`, `SceneDataManager`, `GameProgressManager`, `TTSManager` (`project.godot`).

## i18n

`en`, `zh_CN`, `zh_TW`, `yue` — `I18n.current_lang` + `GameSettingsManager` language setting.

## Testing

Planned GUT suite (`docs/specs/10-testing-strategy.md`). CI: `godot --headless -s tests/run_all.gd` (tests not yet committed).
