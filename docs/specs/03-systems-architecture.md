# 3. Systems Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                        Godot 4.3 Client                        │
│  ┌────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │ Story Gen  │  │  Image Gen   │  │  VN Renderer + TTS     │ │
│  │ LLMManager │  │ ImageServer  │  │  Gameplay / Overlays   │ │
│  │ (llama.cpp)│  │  Manager     │  │  TTSManager (Sherpa)   │ │
│  └─────┬──────┘  └──────┬───────┘  └──────────┬─────────────┘ │
│        │                │                     │               │
│        └────────┬───────┘                     │               │
│                 │  HTTP (HTTPRequest/Client)  │               │
│  ┌──────────────┴────────────────┐  ┌─────────┴────────────┐  │
│  │     ServerRuntimeManager      │  │ SceneData/GameProgress│  │
│  │  lifecycle, 8s heartbeat,     │  │   Managers (persist)  │  │
│  │  request queue, overlay,      │  │  user://saves/<uuid>  │  │
│  │  chrome visibility            │  │                       │  │
│  └───────────────────────────────┘  └───────────────────────┘  │
└───────────────┼────────────────────────────────────────────────┘
                │
     ┌──────────┴────────────┐
     │                       │
┌────▼─────┐           ┌─────▼──────┐         ┌──────────────┐
│llama.cpp │           │  ComfyUI   │         │ Sherpa-ONNX  │
│ (local)  │           │  (local)   │         │ offline-tts  │
│ ≤9B      │           │  API       │         │ Piper VITS   │
└──────────┘           └────────────┘         └──────────────┘
```

Communication: **Direct HTTP from GDScript** to llama.cpp (`/v1/chat/completions`, `/health`) and ComfyUI (`/prompt`, `/history/<id>`, `/view`, `/system_stats`). TTS is a local subprocess via PowerShell `.ps1` + `scripts/tts_helper.py`, preferring the Sherpa-local Python venv under `server/sherpa-onnx/python/`. No middleware.

## Key Components

| Component | File | Role |
|-----------|------|------|
| **ServerRuntimeManager** | `scripts/server_runtime_manager.gd:1` | Autoload coordinator: reconciles stale status, starts both servers, 8s heartbeat + 2s initial check, request queue (`push_request`/`pop_request`), `chrome_visibility_changed`, and `ServerStatusOverlay` injection. Owns shutdown on `NOTIFICATION_WM_CLOSE_REQUEST`. |
| **LLMManager** | `scripts/llm_manager.gd:1` | llama-server lifecycle (`status` → `user://llm_status.json`), prompt assembly (`data/llm/<lang>/{random,enhance,story,scene}` + `common/`), `_request_completion` (120s timeout), repair of malformed `image_prompt` JSON. |
| **ImageServerManager** | `scripts/image_server_manager.gd:1` | ComfyUI lifecycle (`user://image_server_status.json`), workflow templating (`data/comfyui/workflow_template.json`), `generate_scene_image` (queue → poll history → download to `user://saves/<uuid>/images/`). |
| **SceneDataManager** | `scripts/scene_data_manager.gd:1` | Per-scene persistence (`SAVE_DIR = user://saves`): `save()` / `load_data(uuid)` for `scene_data` JSON. Aliases `load(uuid)` for compatibility. |
| **GameProgressManager** | `scripts/game_progress_manager.gd:1` | Global progress (`user://game_progress.json`): `current_uuid`, `current_round`, `expected_rounds`, tunables (`minimum_dialogues_per_scene`, etc.), `game_status` state machine. |
| **TTSManager** | `scripts/tts_manager.gd:1` | Queue-based Sherpa synthesis, model selection by `language`/`sex`, PowerShell UTF-8 safe invocation, `sound_filename` attachment + `tts_generated` signal for auto-play. |
| **I18n / GameSettingsManager** | `scripts/i18n.gd:1`, `scripts/game_settings_manager.gd:1` | i18n (en, zh_CN, zh_TW, yue) + display/TTS settings (`user://game_settings.json`, `safe_mode` / `free_mode` file flag). |
| **ServerStatusOverlay** | `scripts/server_status_overlay.gd:1` | CanvasLayer always-on-top dot indicator + request queue list; listens to `ServerRuntimeManager` signals. |

## Data Flow (new story / new scene)

1. Brainstorm or Choice overlay sets `GameProgressManager.settings["game_status"] = "new_story"|"new_scene"` and `current_uuid`/`player_input`.
2. `Gameplay._ready` branches on `game_status` → `_execute_new_story_flow` / `_execute_new_scene_flow` (`scripts/gameplay.gd:113-152`).
3. LLM request → JSON parse with `_repair_llm_json_text` → merge into `SceneDataManager.scene_data` → `save()`.
4. `generate_scene_image` → save to `user://saves/<uuid>/images/` → update `image_filenames[]` / `current_image_index`.
5. `TTSManager.generate_all_for_scene` → per-interaction WAV into `…/sounds/tts_<idx>_<hash>.wav` + `sound_filename`.
