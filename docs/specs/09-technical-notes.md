# 9. Technical Notes

## 9.1 llama.cpp API

- Health: `GET http://127.0.0.1:<port>/health` (`HTTPClient`, 5s timeout, `scripts/llm_manager.gd:72`)
- Chat: `POST http://127.0.0.1:<port>/v1/chat/completions` with `{"messages":[{"role":"user","content":prompt}], "stream":false, "thinking":false, "cache_prompt":false, "chat_template_kwargs":{"enable_thinking":false}}` (`HTTPRequest`, 120s timeout, `scripts/llm_manager.gd:370`)
- Default port **48763** (configurable via LLM Settings → `user://llm_settings.json`).
- Model ≤9B GGUF invoked as `llama-server.exe -c 0 -ngl 99 -m <gguf> --port <port>` (`scripts/llm_manager.gd:42`).
- Request queue: `ServerRuntimeManager.push_request("llm","generate gameplay",120.0)` / `pop_request` for overlay display.
- JSON repair: `GameplaySceneService.parse_generation_result()` sanitizes `image_prompt` bare quotes before its second parse attempt; the request result keeps the best-effort title as a fallback.

## 9.2 ComfyUI API

- Health: `GET http://127.0.0.1:<port>/system_stats` (`scripts/image_server_manager.gd:55`)
- Submit: `POST http://127.0.0.1:<port>/prompt` with workflow dict
- History: `GET http://127.0.0.1:<port>/history/<prompt_id>` (poll 0.5s, 120 attempts, `scripts/image_server_manager.gd:274`)
- View: `GET http://127.0.0.1:<port>/view?filename=&subfolder=&type=` (binary download to `user://saves/<uuid>/images/`, `scripts/image_server_manager.gd:327`)
- Default port **56321**.
- Workflow template: `data/comfyui/workflow_template.json` (note underscore, not hyphen).
- Workflow wrapper:

```json
{
  "client_id": "story-now",
  "prompt": { "1": {...}, "2": {...}, ... },
  "extra_data": {}
}
```

### 9.2.1 Workflow Placeholders

| Placeholder | Node | Field | Replaced By |
|---|---|---|---|
| `__MODEL_FILENAME__` / `__MODEL_NAME__` | `1` CheckpointLoaderSimple | `ckpt_name` | `ImageServerSettingsManager.settings.model_filename` or `waiIllustriousSDXL_v170.safetensors` |
| `__PREFIX__` / `__SUFFIX__` | `3` CLIPTextEncode | `text` | Configurable positive-prompt prefix/suffix from `ImageServerSettingsManager` |
| `__POSITIVE_PROMPT__` | `3` CLIPTextEncode | `text` | Trimmed generated image prompt with leading/trailing commas added when missing |
| `__NEGATIVE_PROMPT__` | `6` CLIPTextEncode | `text` | `"(white_skin:1.5), ${negative_prompt}"` (builder vs safe file) |
| `__SEED__` | `2` KSampler | `seed` | random int |
| `__FILENAME_PREFIX__` | `5` SaveImage | `filename_prefix` | `"SN"` |
| `__IMAGE_WIDTH__` / `__IMAGE_HEIGHT__` | `7` EmptyLatentImage | `width/height` | `ImageServerSettingsManager.settings.image_width/height` |

### 9.2.2 Negative Prompt Files

`_load_negative_prompt()` (`scripts/image_server_manager.gd:196`) — builder vs safe switch:

- Safe: `res://data/comfyui/safe_negative_prompt` (content: `(nude:1.5), (blood:1.5)`)
- Builder: `data/comfyui/builder_negative_prompt`

### 9.2.3 Request Structure

```gdscript
var workflow_text = FileAccess.get_as_text(WORKFLOW_TEMPLATE_PATH)
workflow_text = workflow_text.replace("__MODEL_FILENAME__", …) // etc.
var workflow_dict = JSON.parse_string(workflow_text)
_fix_comfy_workflow_dict(workflow_dict, seed_val)
var prompt_id = await _queue_comfy_prompt(workflow_dict)
var image_info = await _poll_comfy_history(prompt_id)
var save_path = await _download_comfy_image(filename, subfolder, type, uuid)
```

## 9.3 Server Lifecycle Management

- **ServerRuntimeManager** (`scripts/server_runtime_manager.gd:1`):
  - `_reconcile_stale_state()` on `_ready` resets `pid=-1, running=false, healthy=false` for both managers.
  - Copies default `game_progress.json` / `game_settings.json` to `user://` if missing (handles typo `default_game_progess.json` fallback).
  - `_start_servers()` launches both via managers; records `_llm_started_this_session` / `_image_started_this_session`.
  - Heartbeat: `Timer` uses 2.0s while either service is not yet connected (`HEARTBEAT_NOT_CONNECTED_INTERVAL`) and 10.0s after both services are healthy (`HEARTBEAT_CONNECTED_INTERVAL`) + 2.0s initial delay (`INITIAL_CHECK_DELAY`), calls `health_check()` on both.
  - `ServerStatusOverlay` added deferred to `get_tree().root`.
  - `set_chrome_visible` and `request_queue` signals drive overlay.
  - On `_exit_tree` / `WM_CLOSE_REQUEST` kills owned processes via `taskkill /T /F /PID` (Windows).
- **LLMManager / ImageServerManager**: status persisted to `user://*_status.json`; started via `OS.create_process` (llama: `llama-server.exe -c 0 -ngl 99 …`; ComfyUI: `python_embeded/python.exe -s ComfyUI/main.py --port <port> --windows-standalone-build --disable-auto-launch`, plus `--lowvram` when enabled in image settings).
- Health uses `HTTPClient` raw polling with frame-await loop and timeout accounting (`get_process_delta_time()`).

## 9.4 Display

- Viewport 1920×1080, `canvas_items` stretch, `gl_compatibility` renderer (`project.godot:25-36`).
- Two display modes: fullscreen vs windowed 1344×768 centered (`GameSettingsManager._apply_screen_size`, `scripts/game_settings_manager.gd:67`).
- Theme: `res://data/theme.tres`.

## 9.5 Image & Save Storage

- `user://saves/<uuid>/images/<filename>` — ComfyUI outputs.
- `user://saves/<uuid>/sounds/tts_<idx>_<hash>.wav` — Sherpa outputs.
- `scene_data.json` references both by `image_filenames[]` + `current_image_index` and `interactions[].sound_filename`.
- Loading uses `ProjectSettings.globalize_path` + `Image.load` → `ImageTexture.create_from_image`; failure falls back to placeholder.

## 9.6 TTS Internals

- `_synthesize` (`scripts/tts_manager.gd:273`) requires the native `SherpaOfflineTTS` GDExtension, normalizes CJK punctuation, globalizes model paths, and runs synthesis on a Godot `Thread`. Rate-limited by 6s timer between queue items (`scripts/tts_manager.gd:211`).
- Model resolution by `language`/`gender` (`scripts/tts_manager.gd:39`), with `espeak-ng-data` vs `lexicon + rule.fst` branching.
- Queue dedup: same `uuid+idx` enqueued replaces previous entry (`scripts/tts_manager.gd:152`).
