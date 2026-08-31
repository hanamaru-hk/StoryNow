# 7. UI / UX Design

## 7.1 Visual Style

- **Classic VN** — `%BackgroundImage` fills screen; bottom `Dialogue` panel with `NameLabel`, `DialogLabel`, `DialogProgressLabel`; top bar `TitleLabel`.
- Standard buttons, text fields, and text areas use 90%-opaque light-grey surfaces with dark-blue text and rounded dark-blue frames. The main-menu buttons keep their dedicated illustrated blue shader treatment, while gallery thumbnail cards retain Godot's original dark neutral button style.
- Non-full-screen overlay content and modal panels use the reusable cut-corner, double-line gold frame from `scripts/ornate_gold_frame.gd`; full-screen backgrounds and dimming layers remain unframed.
- Dialogue advances by Prev/Next buttons and optional `DialogArea` click; the side panel includes Plot, Image, Play, Help, navigation, an Auto toggle, and Menu buttons. Auto uses a dark pressed style and advances after both the typewriter animation and current voice playback have finished, followed by a short reading pause; it pauses behind overlays and switches off when choices open. Help opens troubleshooting and minimum-system-requirements pages and remains available while the local engines start.
- Dialogue text appears with a typewriter animation while the character name updates instantly, unless **Show Dialogue Instantly** is enabled. Clicking the dialogue area or pressing Next during the animation reveals the full current line; the following action advances. Pagination `"1 / N"` is shown per dialogue.
- Chrome can be hidden: either left- or right-click on the background hides `TopBar` + `Dialogue` + `ServerStatusOverlay` (`ServerRuntimeManager.chrome_visible`); either mouse button restores them.

## 7.2 Choice Presentation

- Choices appear as dynamic buttons above `CustomInput` inside `ChoiceOverlay` (`VBoxContainer %DynamicChoiceButtons`). Previously-selected choices remain themed buttons and center their dark-yellow status marker on a separate line above choice text rendered in the active button theme color. Row height is calculated from the themed font's wrapped multiline size. The choice list uses the same wide, gold-accented scrollbar as `LoadGameOverlay` and reserves a gutter so it does not overlap row actions.
- Each row has **Delete**, followed by a confirmation prompt before the choice is permanently removed.
- Confirm validates that at least one choice exists and servers are healthy; writes `player_input` + seed `next_uuid`/`prev_uuid` into saves and reloads `gameplay.tscn`.

## 7.3 Main Menu

`scenes/main.tscn`, entry point `project.godot:run/main_scene`, logic `scripts/main.gd:1`:

The trial main menu uses `assets/images/trail-start.webp` as its static 16:9 background. The StoryNow logo treatment is shifted 700 px left from its base layout.

| Button | Action | Notes |
|--------|--------|-------|
| Start | → `brainstorm.tscn` | `scripts/main.gd:28` |
| Load | Hidden in the trial build | Underlying overlay remains available to the application |
| Gallery | Hidden in the trial build | Underlying overlay remains available to the application |
| Game Setting | Opens `GameSettingsOverlay` | via `AdvancedSettingsOverlay` indirection |
| Advanced Setting | Opens `AdvancedSettingsOverlay` | Contains Image/LLM settings shortcuts |
| Exit | `get_tree().quit()` | |

Builder mode is disabled in the trial build, so its label and builder-only controls remain hidden.

First launch (no `user://game_settings.json`) shows `FirstTimeLanguageOverlay`. Its language buttons are generated from `I18n.LANGUAGES` in a grid of up to five per row. Choosing a language applies it immediately, then shows the minimum NVIDIA/CUDA, 8 GB VRAM, and 32 GB RAM requirements. The overlay performs an instant NVIDIA adapter vendor/name check; the separator, quick-check heading, and result remain hidden when the check passes and appear with the failure result otherwise. Confirmation always remains available and completes first-time setup.

## 7.4 Brainstorm Scene

`scenes/brainstorm.tscn` / `scripts/brainstorm.gd:1`:

- **Title/Description/Placeholder** via i18n.
- **Top bar/server chrome:** gameplay-style top bar keeps the global LLM and image server status widget legible; entering the scene restores chrome hidden by the main menu.
- **Readability panel:** an opaque dark panel backs the title, description, textarea, and button row over the illustrated background.
- **Textarea** `%BackgroundInput` for story background, initialized with a localized humorous starter story.
- **Button row:** Random, Enhance, Start, Flow Settings (→ `GameProgressOverlay`), Back. Start uses the inverted primary/secondary button palette for emphasis.
- **Generation notice:** one localized, unnumbered note below the button row explains that generation time depends on the user's computer.
- **LoadingOverlay** + **ErrorDialog** + **RandomConfirmDialog** (clears text).

## 7.5 Gameplay Overlays

All are `Control` overlays instanced inside `scenes/gameplay.tscn`, each with `open()/closed` signal pattern:

- **PlotOverlay** (`scripts/plot_overlay.gd:1`) — hub (Edit/Add/Regenerate All/Summary/Back) → Edit list (indexed buttons) → Edit dialog (character/dialogue/gender fields plus delete) → Add overlay (character, gender/custom value, dialogue, left-aligned before/after controls, then the position dropdown). Confirming a new dialogue closes the overlay and returns to gameplay. Gender stores `male`, `female`, or the custom value entered for Other. Delete is blocked when only one dialogue remains. Summary opens `SummaryOverlay`; Regenerate All calls LLM in retry loop, replaces only `interactions[]`, resets `current_dialogue=0`, triggers TTS.
- **SummaryOverlay** (`scripts/summary_overlay.gd:1`) — shows and edits `summary`.
- **ImageOverlay** (`scripts/image_overlay.gd:1`) — shows/editable `image_prompt` (builder mode); **Produce** closes the overlay and requests generation through Gameplay's image controller.
- **ImageActionOverlay / ImageChangeOverlay** (`scripts/gameplay.gd:668`) — localized Image heading with New/Change actions, then a carousel (Prev/Next/Save shows `user://saves/<uuid>/images/`).
- **ChoiceOverlay** (`scripts/gameplay.gd:287`) — dynamic choice buttons + free-form `CustomInput` + Confirm/Cancel.
- **GameplayMenuOverlay** — Menu hub (Game Settings/Flow Settings/Advanced/Main Menu/Quit) bridging to other overlays. Load and Gallery are hidden in the trial build. Main Menu and Quit ask for confirmation when generation requests are still queued; confirming cancels the active generation work before leaving.
- **HelpOverlay** (`scripts/help_overlay.gd:1`) — troubleshooting guidance for engines that remain in the starting state, repeated generation retries, more accurate image prompting, and minimum system requirements. The Danbooru-tag guidance is shown only in builder mode.
- **GameProgressOverlay / GameSettingsOverlay / AdvancedSettingsOverlay / LLM/Image Server Settings overlays** — settings editors (see below).

## 7.6 Settings Overlays

| Overlay | Editable Fields | Persisted To |
|---------|----------------|--------------|
| **Game Settings** (`game_settings_overlay.gd`) | Scrollable settings form with language (en/zh_CN/zh_TW/yue/ja), screen size, autoplay/streaming toggles, instant dialogue toggle, dialogue text speed (5–120 characters/second), TTS voice volume/mute, and button sound-effect volume/mute. Background music and its controls are disabled in the trial build. | `user://game_settings.json` |
| **Flow Settings / Game Progress** (`game_progress_overlay.gd`) | Min dialogues/scene, Min sentences/dialogue, Max plot directions, Min summary sentences. The trial's three-round limit is fixed in code and is not persisted. | `user://game_progress.json` (preset `data/default_game_progress.json`) |
| **LLM Settings** (`llm_settings_overlay.gd`) | Scrollable settings form with port (1–65535, default 48763), positive timeout (default 720 seconds), non-negative context size, auto-fit, and optional GPU-layer count. Model selection is hidden and the trial model is fixed in code. | `user://llm_settings.json` |
| **Image Server Settings** (`image_server_settings_overlay.gd`) | Scrollable settings form with port (1–65535), positive timeout (default 720 seconds), Low VRAM toggle, and builder-mode-only editable positive-prompt prefix/suffix. Image width/height controls are hidden in the trial build. | `user://image_server_settings.json` |

All follow **open → edit `_pending` → Save/Reset/Back** pattern; the LLM and Image Server overlays confirm Save and Reset while warning that StoryNow must restart before changes take effect. Save merges into the manager singleton and calls `save_settings()`. All editable flow settings accept only positive integers. Invalid persisted numeric values are replaced with safe defaults when loaded or saved. Flow Settings Reset restores only the editable generation parameters and preserves runtime progress such as `current_uuid`, round, dialogue, and `game_status`; the other Reset actions reload their complete defaults.

The PlotOverlay UI regression check runs with `godot --headless --path . --scene res://tools/test_plot_overlay.tscn`.

## 7.7 Server Status Overlay

`scenes/server_status_overlay.tscn` / `scripts/server_status_overlay.gd:1` — `CanvasLayer` always-on-top top-right:

- Two colored dots: **Green** healthy, **Red** unhealthy, **Gray** starting (driven by `ServerRuntimeManager.llm_state` / `image_state` via `status_changed` signals; no polling).
- Engine-readiness and generation-retry error popups place Help between Back and Retry. Help opens the troubleshooting overlay; a failed retry accelerates the gold-arrow flash toward the status indicators, and a successful retry resumes the blocked action.
- Request queue list: rows of `kind` + `label` + timeout circle (`scripts/request_timeout_circle.gd:1`) driven by `ServerRuntimeManager.request_queue_changed`. Active LLM and image generation rows show elapsed seconds (`0s`, `1s`, …); queued ComfyUI prompts continue to show their queue position.
- Hides with chrome (`chrome_visibility_changed`).

## 7.8 Gallery / Load Overlays

- **LoadGameOverlay** (`scripts/load_game_overlay.gd:1`) — paginated `PAGE_SIZE=10` list of save dirs sorted by `timestamp` desc; each row shows thumbnail (largest image), timestamp + title, Delete and Load buttons. Loading requires confirmation. The list viewport is sized to show four save items and uses a wide, gold-accented scrollbar with clickable up/down arrows. Pagination bar shows `1 2 3 … 9 10` style.
- **GalleryOverlay** (`scripts/gallery_overlay.gd:1`) — grid `PAGE_SIZE=12`, arranged in 4 columns by 3 rows with 230×180 thumbnail buttons and the same sorting/thumbnail logic. Clicking a thumbnail opens a full-screen image preview with a bottom bar showing the story title, UTF-8 previous/next controls that follow the gallery sort order, and Load Scene/Back actions. Either left- or right-clicking the preview image toggles an immersive view that hides the bottom bar and server-status chrome. Load Scene first requires both story engines to be healthy (otherwise it shows the same readiness error as LoadGameOverlay), then requires confirmation before loading that save as `running` with the selected image active.

## 7.9 Internationalization

- Five languages: `en`, `zh_CN`, `zh_TW`, `yue`, `ja` via `I18n` singleton (`scripts/i18n.gd:1`, `_translations` dict, `set_language`, `translate`).
- All UI strings resolved via `I18n.translate(key)`; `GameSettingsManager._apply_language()` syncs `TranslationServer`.
- LLM templates per language under `data/llm/<lang>/`.

## 7.10 Error Handling

- **Hard error modal:** `Gameplay.show_error(msg, with_retry)` → `AcceptDialog %ErrorReturnDialog` with Return + optional Retry button (`scripts/gameplay.gd:1034-1200`). Retry emits `retry_requested` to resume the story/scene/regenerate loop; Return goes back to `main.tscn`.
- LLM JSON parse failures automatically retry with repair; ComfyUI failures surface as error dialogs.
- Load/Gameplay guards check `ServerRuntimeManager` health before Start/Load/Regenerate actions and show `notice_wait_llm_*` notices.

## 7.11 Loading States

- `Brainstorm` uses `%LoadingOverlay` during Random/Enhance.
- `Gameplay` uses `game_status` transitions (`generating_image` / `running`) and disables Next/Choice buttons until image/TTS ready.
- While an illustration is being generated, the trial gameplay background image displays a large localized Noto Serif Bold `Generating` label with a `.`, `..`, `...` animation. Server status dots continue to provide request-level loading feedback.
