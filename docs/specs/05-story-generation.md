# 5. Story Generation System

## 5.1 Start Flow

1. **Main menu** (`scenes/main.tscn`, `scripts/main.gd:1`) — buttons: Start, Load, Gallery, Game Setting, Advanced Setting, Exit. First-launch shows `FirstTimeLanguageOverlay`.
2. **Start** → `get_tree().change_scene_to_file("res://scenes/brainstorm.tscn")`.
3. **Brainstorm scene** (`scripts/brainstorm.gd:1`, `scenes/brainstorm.tscn`) — textarea with a localized starter story + buttons: Random, Enhance, Start, Flow Settings, Back.
   - **Random** — requires `ServerRuntimeManager.llm_state == HEALTHY`; shows confirm dialog, then `LLMManager.request_random()` (`scripts/brainstorm.gd:22`).
   - **Enhance** — requires LLM healthy + non-empty input; shows a confirmation that enhancement will change the content, then calls `LLMManager.request_enhance(input)` (`scripts/brainstorm.gd:53`).
   - **Start** — requires both LLM + Image healthy; validates non-empty, creates `uuid`, seeds `SceneDataManager.scene_data = {uuid, image_filenames:[], version:"1.0", interactions:[], choices:[], image_prompt:"", summary:input, end:false, expected_rounds, current_round:1, language}`, saves, sets `GameProgressManager.settings.current_uuid/ game_status="new_story" / current_round=1`, then loads `gameplay.tscn` (`scripts/brainstorm.gd:67`).
4. **Gameplay** (`scenes/gameplay.tscn`, `scripts/gameplay.gd:1`) — on `_ready` branches on `game_status`: `new_story` → `_execute_new_story_flow`, `new_scene` → `_execute_new_scene_flow`, `running` → load & render (`scripts/gameplay.gd:113`).

## 5.2 Scene Data Format (LLM Output)

The LLM returns **raw JSON** (no Markdown) conforming to `data/llm/<lang>/common/output_template.json`:

```json
{
  "interactions": [
    { "character": "John", "dialogue": "I want an ice cream.", "sex": "male" }
  ],
  "choices": [
    { "plot": "Go to the ice cream shop" },
    { "plot": "Stay at the shop and keep working" },
    { "plot": "Ask a passing customer for advice" }
  ],
  "image_prompt": "man, mechanic",
  "summary": "John is a mechanic who often craves ice cream after a long day at the shop.",
  "end": false,
  "language": "en",
  "title": "John's Ice Cream Dilemma"
}
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `interactions` | Array of `{character, dialogue, sex}` | Ordered dialogue lines. `character` may be empty for narration; `sex` drives TTS voice selection. Supports legacy typo `characer`. `sound_filename` is added locally by `TTSManager`. |
| `choices` | Array of `{plot, uuid?}` | 1–N plot directions. When a choice is selected, its `plot` becomes `player_input` and `uuid` is later stamped to mark "previously selected". |
| `image_prompt` | String | Danbooru tag list (English, comma-separated) for ComfyUI. Prefixed at runtime with `score_9, …` and suffixed with guardrail handling. Repaired if LLM emits bare quotes. |
| `summary` | String | Compressed story state, ≤ `minimum_sentences_in_summary` sentences (default 3), simple clauses. Used as `story_background` for next scene. |
| `end` | bool | Whether story should end; LLM instructed to set true when `current_round == expected_rounds`. |
| `language` | String | `en` / `zh_CN` / `zh_TW` / `yue` / `ja` (mirrors `I18n.current_lang`). |
| `title` | String | Short scene title shown in `%TitleLabel` as `"${round}. ${title}"` (`scripts/gameplay.gd:1088`). |
| `uuid` / `prev_uuid` / `current_round` / `version` / `image_filenames` / `current_image_index` / `timestamp` | — | **Local meta** added/preserved by `Gameplay` & `SceneDataManager`; not expected from LLM but kept if present. |

Persisted per scene: `user://saves/<uuid>/scene_data.json` (includes both LLM fields and local meta).

## 5.3 Story State Tracking

- No separate state object. The **entire previous scene JSON** (especially `summary`) is the state.
- `request_new_story` builds prompt from `data/llm/<lang>/story` + `summary` + guardrail + `output_json_requirement` + `output_template` (`scripts/llm_manager.gd:278`).
- `request_new_scene` loads `prev_uuid`'s `scene_data.json` (fallback: stringified current `scene_data`), extracts `summary`, combines with `player_input` + `current_round`/`expected_rounds` into `data/llm/<lang>/scene` (`scripts/llm_manager.gd:310`).
- Tunables from `GameProgressManager.settings` inject into `output_json_requirement` via `_replace_requirement_placeholders`: `minimum_dialogues_per_scene`, `minimum_sentences_per_dialogue`, `maximum_plot_directions` (alias `minimum_plot_directions`), `minimum_sentences_in_summary`, plus `__DANBOORU_GUARDRAIL__` (`scripts/llm_manager.gd:250`).
- Retry: `Gameplay._execute_new_story_flow` / `_execute_new_scene_flow` loop indefinitely on failure, showing error dialog with Retry (signal `retry_requested`) until success (`scripts/gameplay.gd:1236-1302`).

## 5.4 Branching

- After a scene loads, `_populate_dynamic_choice_buttons` renders `choices[]` as buttons above `%CustomInput` (`scripts/gameplay.gd:287`). Previously-selected choices (those with non-empty `plot` + `uuid`) render as a highlighted `PanelContainer`.
- Each row has a **Delete** button that removes the choice from `scene_data["choices"]` and saves.
- **Next Scene** → opens `ChoiceOverlay` (custom input + choice list). Confirm delegates branch construction to `GameplaySceneService.build_choice_transition()`. A visited choice reuses its saved child UUID; a new choice atomically produces the updated parent link and a clean child scene with `prev_uuid`, incremented round, and `game_status="new_scene"` before gameplay reloads.

## 5.5 LLM Prompt Assembly

```
data/llm/<lang>/{random, enhance, story, scene}
  + common/story_background_requirement
  + common/output_json_requirement  (with __MINIMUM_*__ placeholders)
  + common/output_template.json
  + common/{safe,free}_guardrail
  + common/{safe,free}_danbooru_guardrail (via requirement)
```

`_load_prompt` (`scripts/llm_manager.gd:222`) resolves per `I18n.current_lang`. `_load_template` falls back to `en`. `_request_completion` posts to `http://127.0.0.1:<port>/v1/chat/completions` with `messages:[{role:"user", content:prompt}]`, `stream:false`, `thinking:false` (`scripts/llm_manager.gd:370`).

Response `choices[0].message.content` is returned as `text`; `title` is best-effort extracted before repair (`scripts/llm_manager.gd:418-430`).

## 5.6 Implementation Status

| Component | Status |
|-----------|--------|
| Brainstorm scene UI (Random/Enhance/Start/Flow Settings) | ✅ Implemented (`scripts/brainstorm.gd:1`, `scenes/brainstorm.tscn`) |
| LLM prompt templates (en, zh_CN, zh_TW, yue, ja) | ✅ Implemented (`data/llm/*`) |
| Random prompt generation | ✅ Implemented (`LLMManager.request_random`) |
| Prompt enhancement | ✅ Implemented (`LLMManager.request_enhance`) |
| LLM API call for new story / new scene | ✅ Implemented (`LLMManager.request_new_story/scene` + Gameplay retry loops) |
| JSON repair for malformed `image_prompt` | ✅ Implemented centrally by `GameplaySceneService.parse_generation_result()` |
| Branching / choice handling (incl. prev-selected, delete, custom input) | ✅ Implemented (`scripts/gameplay.gd:287-414`) |
| Dialogue edit / add / regenerate scene | ✅ Implemented; after confirmation the overlay closes and regeneration reuses the full `new_story` flow for round 1 or `new_scene` flow for later rounds (`scripts/plot_overlay.gd:1`) |
