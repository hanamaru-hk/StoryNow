# 8. Save / Load System

> **Status:** Implemented.

## 8.1 Storage Layout

All persistent data lives under `user://` (Godot user data dir, `OS.get_user_data_dir()`, logged in `scripts/main.gd:6`):

```
user://
├── game_settings.json          # GameSettingsManager (language, screen, autoplay, safe_mode)
├── game_progress.json          # GameProgressManager (current_uuid/round/dialogue, tunables, game_status)
├── llm_settings.json           # LLMSettingsManager {port, timeout, context_size, fit, ngl, ngl_value, llm_model_filename}
├── image_server_settings.json  # ImageServerSettingsManager {port, timeout, low_vram, model_filename, image_width/height, prefix, suffix}
├── llm_status.json             # LLMManager {pid, running, healthy}
├── image_server_status.json    # ImageServerManager {pid, running, healthy}
└── saves/<uuid>/
    ├── scene_data.json         # Full scene JSON (LLM output + local meta)
    ├── images/
    │   └── SN_*.png            # ComfyUI outputs (history-downloaded)
    └── sounds/
        └── tts_<idx>_<hash>.wav # Sherpa TTS outputs
```

`SceneDataManager.SAVE_DIR = "user://saves"` (`scripts/scene_data_manager.gd:5`). Each `scene_data.json` includes `uuid`, `prev_uuid`, `version`, `current_round`, `current_image_index`, `image_filenames[]`, `timestamp`, plus all LLM fields (`interactions`, `choices`, `image_prompt`, `summary`, `end`, `language`, `title`).

`GameProgressManager.settings` (`scripts/game_progress_manager.gd:6`, defaults `data/default_game_progress.json`) additionally stores `player_input` (last choice text) used by `request_new_scene`.

## 8.2 SceneDataManager API

`scripts/scene_data_manager.gd:1` (autoload):

- `save() -> bool` — stamps `timestamp` (`YYYY/MM/DD HH:MM:SS`), ensures `saves/` and `saves/<uuid>/` exist, writes `scene_data.json` pretty-printed. Requires `scene_data.uuid`.
- `load_data(uuid: String) -> bool` / alias `load(uuid)` — reads and parses `saves/<uuid>/scene_data.json`, ensures `current_image_index` default 0, replaces `scene_data`.
- `scene_data: Dictionary` — current in-memory scene; modified in place by Gameplay/overlays before `save()`.

## 8.3 GameProgressManager API

`scripts/game_progress_manager.gd:1` (autoload):

- `settings: Dictionary` — merges `user://game_progress.json` over defaults on `_ready`.
- `save_settings()`, `load_settings()`, `reset_to_defaults()` (reloads `data/default_game_progress.json`).

`game_status` state machine (`scripts/gameplay.gd:113`):

| Value | Meaning |
|-------|---------|
| `new_story` | Brainstorm just created seed; Gameplay should call `request_new_story` |
| `new_scene` | Choice confirmed; next scene needs `request_new_scene` |
| `generating_image` | LLM done, ComfyUI in progress (transient) |
| `running` | Scene fully loaded and playable |
| `""` | Idle / main menu |

## 8.4 Save Triggers

- **New story** — `Brainstorm._on_start_pressed` creates seed `scene_data` + `GameProgress` and saves (`scripts/brainstorm.gd:75`).
- **New scene** — Choice confirm creates `next_uuid` + `next_scene_data` (copy of current with `prev_uuid`/`current_round+1`), saves, updates `GameProgress`.
- **Dialogue edit/add/regenerate, image generate, choice delete, image carousel save** — immediate `SceneDataManager.save()` + `GameProgressManager.save_settings()` where needed.
- No explicit "Save" button — every mutation auto-persists.

## 8.5 Load / Gallery

- **LoadGameOverlay** (`scripts/load_game_overlay.gd:1`) scans `user://saves/` dirs, reads each `scene_data.json`, sorts by `timestamp` desc, paginates (10 per page), and shows a thumbnail via `image_filenames` or a directory scan. After confirmation, **Load** sets `current_uuid`/`current_round`/`current_dialogue=0`/`game_status=running` and reloads `gameplay.tscn`. If generation requests are still queued, the confirmation warns that leaving will cancel unfinished work.
- **GalleryOverlay** (`scripts/gallery_overlay.gd:1`) uses the same data source but a 12-item, 4-column by 3-row grid. Clicking an image opens a full-screen preview whose previous/next actions follow the complete gallery order across pages. Either left- or right-click toggles the preview's bottom bar and server-status chrome. Load Scene requires both story engines to be healthy and asks for confirmation before loading the save with that image selected; queued generation changes that confirmation to an unfinished-work warning. Back returns to the grid page containing the previewed item.
- **Gameplay running** → `SceneDataManager.load_data(current_uuid)` then `_load_current_scene_image` + dialogue render (`scripts/gameplay.gd:118`).
- **Prev Scene** button loads `prev_uuid` if present, decrements `current_round`, resets dialogue index.

## 8.6 Image & TTS Persistence

- Images referenced by filename array `image_filenames` + index `current_image_index`; files live on disk — no regeneration needed on load.
- TTS wavs referenced by `interactions[i].sound_filename`; missing files trigger `TTSManager.generate_single_interaction` on next Play/autoplay attempt.
