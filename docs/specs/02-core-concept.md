# 2. Core Concept

- **Genre-agnostic** — supports romance, horror, mystery, fantasy, slice-of-life, sci-fi, etc. Guardrails (`safe_*` vs `free_*`) adapt system prompts and negative prompts.
- **Round-based continuous story** — `expected_rounds` (default 20, editable in Flow Settings) controls pacing; `current_round` increments per scene. When `current_round == expected_rounds`, LLM is instructed to consider setting `end=true`.
- **AI-generated everything** — story/dialogue (`llama.cpp` via `LLMManager`), scene illustrations (ComfyUI via `ImageServerManager`), and TTS voices (Sherpa-ONNX via `TTSManager`) generated locally.
- **Classic VN gameplay** — background illustration (`%BackgroundImage`), dialogue panel with `NameLabel` / `DialogLabel` / progress counter, Prev/Next dialogue & scene, choice overlay, plot/dialogue/image inspectors (`scripts/gameplay.gd:22-48`).
- **Player agency** — choices come from LLM (`choices[].plot`) plus a free-form `CustomInput`; previously-selected choices are visually marked and persisted with `uuid`.
- **Persistence** — every scene is a self-contained folder `user://saves/<uuid>/` containing `scene_data.json`, `images/`, and `sounds/`. `GameProgressManager` tracks `current_uuid`, `current_round`, `game_status` (`new_story` / `new_scene` / `generating_image` / `running`), and generation tunables.
