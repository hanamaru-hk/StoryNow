# 7. UI / UX Design

## 7.1 Visual Style

- **Classic VN** — `%BackgroundImage` fills screen; bottom `Dialogue` panel with `NameLabel`, `DialogLabel`, `DialogProgressLabel`; top bar `TitleLabel`.
- Dialogue advances by Prev/Next buttons and optional `DialogArea` click; side panel holds Dialog/Image/Plot/Setting/GameplayMenu buttons (`scripts/gameplay.gd:22`).
- No typewriter animation — text swaps instantly; pagination `"1 / N"` shown per dialogue.
- Chrome can be hidden: right-click on background hides `TopBar`+`Dialogue` + `ServerStatusOverlay` (`ServerRuntimeManager.chrome_visible`), left-click restores (`scripts/gameplay.gd:503-541`).

## 7.2 Choice Presentation

- Choices appear as dynamic buttons above `CustomInput` inside `ChoiceOverlay` (`VBoxContainer %DynamicChoiceButtons`, `scripts/gameplay.gd:287`). Previously-selected choices render as yellow-tagged `PanelContainer`.
- Each row has **Delete** to remove the choice permanently.
- Confirm validates that at least one choice exists and servers are healthy; writes `player_input` + seed `next_uuid`/`prev_uuid` into saves and reloads `gameplay.tscn`.

## 7.3 Main Menu

`scenes/main.tscn`, entry point `project.godot:run/main_scene`, logic `scripts/main.gd:1`:

| Button | Action | Notes |
|--------|--------|-------|
| Start | → `brainstorm.tscn` | `scripts/main.gd:28` |
| Load | Opens `LoadGameOverlay` | `%LoadGameOverlay.open()` |
| Gallery | Opens `GalleryOverlay` | Grid of save thumbnails |
| Game Setting | Opens `GameSettingsOverlay` | via `AdvancedSettingsOverlay` indirection |
| Advanced Setting | Opens `AdvancedSettingsOverlay` | Contains Image/LLM settings shortcuts |
| Exit | `get_tree().quit()` | |

First launch (no `user://game_settings.json`) shows `FirstTimeLanguageOverlay`.

## 7.4 Brainstorm Scene

`scenes/brainstorm.tscn` / `scripts/brainstorm.gd:1`:

- **Title/Description/Placeholder** via i18n.
- **Textarea** `%BackgroundInput` for story background.
- **Button row:** Random, Enhance, Advanced (→ `GameProgressOverlay`), Start, Back.
- **LoadingOverlay** + **ErrorDialog** + **RandomConfirmDialog** (clears text).

## 7.5 Gameplay Overlays

All are `Control` overlays instanced inside `scenes/gameplay.tscn`, each with `open()/closed` signal pattern:

- **DialogueOverlay** (`scripts/dialogue_overlay.gd:1`) — hub (Edit/Add/Regenerate All/Back) → Edit list (indexed buttons) → Edit dialog (character/dialogue fields) → Add overlay (dropdown + before/after). Regenerate All calls LLM in retry loop, replaces only `interactions[]`, resets `current_dialogue=0`, triggers TTS.
- **PlotOverlay** (`scripts/plot_overlay.gd:1`) — shows `summary`; editable when free mode.
- **ImageOverlay** (`scripts/image_overlay.gd:1`) — shows/editable `image_prompt` (free mode), **Produce** calls `ImageServerManager.generate_scene_image`.
- **ImageActionOverlay / ImageChangeOverlay** (`scripts/gameplay.gd:668`) — New image vs carousel (Prev/Next/Save shows `user://saves/<uuid>/images/`).
- **ChoiceOverlay** (`scripts/gameplay.gd:287`) — dynamic choice buttons + free-form `CustomInput` + Confirm/Cancel.
- **GameplayMenuOverlay** — Menu hub (Load/Gallery/Game Settings/Advanced/Main Menu/Quit) bridging to other overlays.
- **GameProgressOverlay / GameSettingsOverlay / AdvancedSettingsOverlay / LLM/Image Server Settings overlays** — settings editors (see below).

## 7.6 Settings Overlays

| Overlay | Editable Fields | Persisted To |
|---------|----------------|--------------|
| **Game Settings** (`game_settings_overlay.gd`) | Language (en/zh_CN/zh_TW/yue), Screen size (Full/1344×768), Autoplay TTS | `user://game_settings.json` |
| **Advanced / Game Progress** (`game_progress_overlay.gd`) | Expected rounds, Min dialogues/scene, Min sentences/dialogue, Max plot directions, Min summary sentences | `user://game_progress.json` (preset `data/default_game_progress.json`) |
| **LLM Settings** (`llm_settings_overlay.gd`) | Port (default 48763) | `user://llm_settings.json` |
| **Image Server Settings** (`image_server_settings_overlay.gd`) | Port (default 56321), Model filename (`waiIllustriousSDXL_v170.safetensors`) | `user://image_server_settings.json` |

All follow **open → edit `_pending` → Save/Reset/Back** pattern; Save merges into manager singleton and calls `save_settings()`; Reset reloads defaults.

## 7.7 Server Status Overlay

`scenes/server_status_overlay.tscn` / `scripts/server_status_overlay.gd:1` — `CanvasLayer` always-on-top top-right:

- Two colored dots: **Green** healthy, **Red** unhealthy, **Gray** starting (driven by `ServerRuntimeManager.llm_state` / `image_state` via `status_changed` signals; no polling).
- Request queue list: rows of `kind` + `label` + timeout circle (`scripts/request_timeout_circle.gd:1`) driven by `ServerRuntimeManager.request_queue_changed`.
- Hides with chrome (`chrome_visibility_changed`).

## 7.8 Gallery / Load Overlays

- **LoadGameOverlay** (`scripts/load_game_overlay.gd:1`) — paginated `PAGE_SIZE=10` list of save dirs sorted by `timestamp` desc; each row shows thumbnail (largest image), timestamp + title, Load button. Pagination bar shows `1 2 3 … 9 10` style.
- **GalleryOverlay** (`scripts/gallery_overlay.gd:1`) — grid `PAGE_SIZE=16`, `GridContainer` thumbnails (230×180 buttons) with same sorting/thumbnail logic, click loads that save as `running`.

## 7.9 Internationalization

- Four languages: `en`, `zh_CN`, `zh_TW`, `yue` via `I18n` singleton (`scripts/i18n.gd:1`, `_translations` dict, `set_language`, `translate`).
- All UI strings resolved via `I18n.translate(key)`; `GameSettingsManager._apply_language()` syncs `TranslationServer`.
- LLM templates per language under `data/llm/<lang>/`.

## 7.10 Error Handling

- **Hard error modal:** `Gameplay.show_error(msg, with_retry)` → `AcceptDialog %ErrorReturnDialog` with Return + optional Retry button (`scripts/gameplay.gd:1034-1200`). Retry emits `retry_requested` to resume the story/scene/regenerate loop; Return goes back to `main.tscn`.
- LLM JSON parse failures automatically retry with repair; ComfyUI failures surface as error dialogs.
- Load/Gameplay guards check `ServerRuntimeManager` health before Start/Load/Regenerate actions and show `notice_wait_llm_*` notices.

## 7.11 Loading States

- `Brainstorm` uses `%LoadingOverlay` during Random/Enhance.
- `Gameplay` uses `game_status` transitions (`generating_image` / `running`) and disables Next/Choice buttons until image/TTS ready.
- Server status dots provide ambient loading feedback; explicit "Generating illustration..." spinner not yet added (placeholder background at 50% opacity indicates pending).
