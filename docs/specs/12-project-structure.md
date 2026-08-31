# 12. Project Structure (Current)

```
story-now/
├── docs/
│   └── specs/
│       ├── index.md
│       ├── 01-overview.md
│       ├── 02-core-concept.md
│       ├── 03-systems-architecture.md
│       ├── 04-server-dependencies.md
│       ├── 05-story-generation.md
│       ├── 06-image-generation.md
│       ├── 07-ui-ux.md
│       ├── 08-save-load.md
│       ├── 09-technical-notes.md
│       ├── 10-testing-strategy.md
│       ├── 11-open-questions.md
│       └── 12-project-structure.md
├── scenes/
│   ├── main.tscn                        # Main menu (entry point)
│   ├── brainstorm.tscn                  # Story prompt / brainstorm
│   ├── gameplay.tscn                    # VN gameplay + all overlays instanced
│   ├── advanced_settings_overlay.tscn
│   ├── plot_overlay.tscn
│   ├── first_time_language_overlay.tscn
│   ├── gallery_overlay.tscn
│   ├── game_progress_overlay.tscn
│   ├── game_settings_overlay.tscn
│   ├── gameplay_menu_overlay.tscn
│   ├── image_overlay.tscn
│   ├── image_server_settings_overlay.tscn
│   ├── llm_settings_overlay.tscn
│   ├── load_game_overlay.tscn
│   ├── summary_overlay.tscn
│   └── server_status_overlay.tscn
├── scripts/
│   ├── main.gd                          # Main menu logic
│   ├── brainstorm.gd                    # Brainstorm / prompt entry
│   ├── gameplay.gd                      # Gameplay scene coordinator and signal wiring
│   ├── gameplay_flow_controller.gd      # Startup/generation state machine and retry
│   ├── gameplay_dialogue_controller.gd  # Dialogue navigation, rendering, and TTS
│   ├── gameplay_image_controller.gd     # Image generation, loading, and selection
│   ├── gameplay_choice_controller.gd    # Choice UI and branch transitions
│   ├── gameplay_chrome_controller.gd    # Chrome visibility and background input
│   ├── gameplay_scene_service.gd        # Pure scene parsing, merge, and branch rules
│   ├── i18n.gd                          # Internationalization (en, zh_CN, zh_TW, yue, ja)
│   ├── game_settings_manager.gd         # Game settings persistence & apply (language, display, TTS)
│   ├── game_settings_overlay.gd
│   ├── advanced_settings_overlay.gd
│   ├── game_progress_manager.gd         # Global progress (uuid/round/status/tunables)
│   ├── game_progress_overlay.gd
│   ├── gameplay_menu_overlay.gd
│   ├── plot_overlay.gd                  # Edit/Add/Regenerate plot dialogue triage
│   ├── summary_overlay.gd
│   ├── image_overlay.gd                 # Prompt view / produce image
│   ├── gallery_overlay.gd
│   ├── load_game_overlay.gd
│   ├── first_time_language_overlay.gd
│   ├── server_status_overlay.gd         # Health dots + request queue
│   ├── server_runtime_manager.gd        # Coordinator (heartbeat, overlay, queue, lifecycle)
│   ├── llm_manager.gd                   # llama.cpp lifecycle + prompt assembly
│   ├── llm_settings_manager.gd
│   ├── llm_settings_overlay.gd
│   ├── image_server_manager.gd          # ComfyUI lifecycle + workflow execution
│   ├── image_server_settings_manager.gd
│   ├── image_server_settings_overlay.gd
│   ├── tts_manager.gd                   # Sherpa-ONNX offline TTS queue
│   ├── download_sherpa.ps1
│   ├── download_japanese_tts.ps1
│   └── request_timeout_circle.gd        # Circular timeout indicator
├── data/
│   ├── theme.tres
│   ├── builder/                         # Presence of any file enables builder mode when safe_mode is false
│   ├── default_game_settings.json       # Language, display, dialogue, TTS voice, and music defaults
│   ├── default_game_progress.json       # {current_dialogue/uuid/round, expected_rounds, minimum_*/maximum_*, game_status}
│   ├── default_llm_settings.json        # LLM port, timeout, context, fit, GPU layers, and model
│   ├── default_image_server_settings.json # ComfyUI port, model, timeout, image size, prompt prefix/suffix
│   ├── llama-models/
│   │   ├── cen/*.gguf
│   │   └── ab/*.gguf
│   ├── comfyui/
│   │   ├── workflow_template.json       # SDXL txt2img workflow (client_id + 7 nodes)
│   │   ├── safe_negative_prompt
│   │   └── builder_negative_prompt
│   ├── llm/
│   │   ├── en/{random,enhance,story,scene}
│   │   ├── en/common/{output_template.json, output_json_requirement, story_background_requirement, safe_guardrail, builder_guardrail, safe_danbooru_guardrail, builder_danbooru_guardrail}
│   │   ├── zh_CN/… (same)
│   │   ├── zh_TW/… (same)
│   │   ├── yue/… (same)
│   │   └── ja/… (same)
│   └── translations/translations.csv
├── assets/
│   └── images/generating.jpg            # Generating placeholder background (50% opacity)
├── saves/                               # Runtime saves mirror (dev); real saves in user://saves/
├── server/                              # AI server binaries (gitignored: server/, .godot/, *.uid/import)
│   ├── llama/llama-server.exe
│   ├── ComfyUI/
│   └── sherpa-onnx/{bin,lib,models}/
├── project.godot                        # Autoloads + main_scene + viewport/renderer
├── .gitignore
└── README.md
```

## Autoload Singletons

Registered in `project.godot:11-22`:

| Name | Script | Purpose |
|------|--------|---------|
| `I18n` | `scripts/i18n.gd` | Translations (en, zh_CN, zh_TW, yue, ja) |
| `GameSettingsManager` | `scripts/game_settings_manager.gd` | Display/TTS/safe_mode settings (`user://game_settings.json`) |
| `ImageServerSettingsManager` | `scripts/image_server_settings_manager.gd` | ComfyUI port, timeout, model, image size, and prompt prefix/suffix |
| `LLMSettingsManager` | `scripts/llm_settings_manager.gd` | llama.cpp port |
| `LLMManager` | `scripts/llm_manager.gd` | llama.cpp process + prompt/HTTP |
| `ImageServerManager` | `scripts/image_server_manager.gd` | ComfyUI process + image pipeline |
| `ServerRuntimeManager` | `scripts/server_runtime_manager.gd` | Heartbeat, queue, chrome, overlay |
| `SceneDataManager` | `scripts/scene_data_manager.gd` | Per-scene `scene_data` JSON (`user://saves/<uuid>/`) |
| `GameProgressManager` | `scripts/game_progress_manager.gd` | Global progress (`user://game_progress.json`) |
| `TTSManager` | `scripts/tts_manager.gd` | Sherpa-ONNX TTS queue |

## Previously "Not Yet Implemented" — Now Implemented

- `gameplay.gd` + focused gameplay controllers — coordinated VN display, choices, images, dialogue/TTS, chrome, and resumable generation
- `plot_overlay.gd` / `summary_overlay.gd` / `image_overlay.gd` — inspectors + edit/regenerate
- `gallery_overlay.gd` / `load_game_overlay.gd` — paginated save browsing
- `game_progress_manager.gd` / `scene_data_manager.gd` / `tts_manager.gd` — persistence & TTS
- All LLM/ComfyUI HTTP flows — story/scene/image generation with retry

## Still Planned

- `tests/` — GUT test suite (see `10-testing-strategy.md`)
- `scenes/ui/` reusable atom components (currently embedded in `gameplay.tscn`)
