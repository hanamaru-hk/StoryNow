# 12. Project Structure (Current)

```
instant-visual-novel/
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
│   ├── main.tscn                  # Main menu scene (entry point)
│   ├── brainstorm.tscn            # Story prompt / brainstorm scene
│   ├── game_settings_overlay.tscn     # Game settings overlay
│   ├── image_server_settings_overlay.tscn  # Image server settings overlay
│   ├── llm_settings_overlay.tscn      # LLM settings overlay
│   └── server_status_overlay.tscn     # Server health status overlay
├── scripts/
│   ├── main.gd                    # Main menu logic
│   ├── brainstorm.gd              # Brainstorm / prompt entry scene logic
│   ├── i18n.gd                    # Internationalization (en, zh_CN, zh_TW)
│   ├── game_settings_manager.gd   # Game settings persistence & apply
│   ├── game_settings_overlay.gd   # Game settings UI overlay
│   ├── llm_manager.gd             # Ollama process lifecycle
│   ├── llm_settings_manager.gd    # LLM settings persistence
│   ├── llm_settings_overlay.gd    # LLM settings UI overlay
│   ├── image_server_manager.gd    # ComfyUI process lifecycle
│   ├── image_server_settings_manager.gd  # Image server settings persistence
│   ├── image_server_settings_overlay.gd  # Image server settings UI overlay
│   ├── server_runtime_manager.gd  # Coordinator for both servers
│   └── server_status_overlay.gd   # Status overlay (colored dots)
├── data/
│   ├── default_game_settings.json
│   ├── default_llm_settings.json
│   ├── default_image_server_settings.json
│   ├── comfyui/
│   │   └── workflow-template.json     # ComfyUI txt2img workflow
│   ├── llm/
│   │   ├── en/template.json           # English LLM prompt template
│   │   ├── zh_CN/template.json        # Simplified Chinese template
│   │   └── zh_TW/template.json        # Traditional Chinese template
│   └── translations/
│       └── translations.csv           # Translation strings
├── server/                             # AI server binaries (gitignored)
│   ├── ollama/
│   └── ComfyUI/
├── project.godot
├── .gitignore
└── README.md
```

## Autoload Singletons

Registered in `project.godot`:

| Name | Script | Purpose |
|------|--------|---------|
| `I18n` | `scripts/i18n.gd` | Internationalization |
| `GameSettingsManager` | `scripts/game_settings_manager.gd` | Game settings (language, screen size) |
| `ImageServerSettingsManager` | `scripts/image_server_settings_manager.gd` | Image server port config |
| `LLMSettingsManager` | `scripts/llm_settings_manager.gd` | LLM port config |
| `LLMManager` | `scripts/llm_manager.gd` | Ollama process lifecycle |
| `ImageServerManager` | `scripts/image_server_manager.gd` | ComfyUI process lifecycle |
| `ServerRuntimeManager` | `scripts/server_runtime_manager.gd` | Server coordinator |

## Not Yet Implemented

The following are planned but do not yet exist:

- `story_manager.gd` — LLM integration, state management
- `image_manager.gd` — ComfyUI integration, image caching
- `vn_renderer.gd` — VN display, typewriter, transitions
- `save_manager.gd` — Save/load logic
- `tests/` — Test directory (GUT framework)
- `scenes/ui/` — Reusable UI components (text_box, choice_button, name_plate, loading)
- `scenes/vn_viewport.tscn` — VN display scene
