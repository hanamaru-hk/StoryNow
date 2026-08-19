# 12. Project Structure (Proposed)

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
├── tests/
│   ├── run_all.gd
│   ├── test_scene_parser.gd
│   ├── test_state_manager.gd
│   ├── test_save_manager.gd
│   ├── test_story_manager.gd
│   ├── test_image_manager.gd
│   └── test_helpers.gd
├── scenes/
│   ├── main.tscn              # Main game scene
│   ├── settings.tscn          # Settings/start screen
│   ├── vn_viewport.tscn       # VN display (text, image, choices)
│   └── ui/
│       ├── text_box.tscn      # Typewriter text display
│       ├── choice_button.tscn # Choice button
│       ├── name_plate.tscn    # Character name display
│       └── loading.tscn       # Loading indicator
├── scripts/
│   ├── main.gd
│   ├── settings.gd
│   ├── story_manager.gd       # Ollama integration, state management
│   ├── image_manager.gd       # ComfyUI integration, image caching
│   ├── vn_renderer.gd         # Scene display, typewriter, transitions
│   └── save_manager.gd        # Save/load logic
├── data/
│   ├── system_prompt.txt      # Ollama system prompt template
│   └── comfyui_workflow.json  # ComfyUI workflow template
├── generated_images/          # Runtime-generated images (gitignored)
├── project.godot
└── README.md
```
