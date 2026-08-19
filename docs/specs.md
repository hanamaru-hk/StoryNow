# Instant Visual Novel - Game Specifications

## 1. Overview

**Title:** Instant Visual Novel  
**Engine:** Godot 4.x (GDScript 2.x, .tscn scenes)  
**Platform:** Desktop (Linux, Windows, macOS)  
**Resolution:** Multi-resolution (1920x1080 primary, responsive scaling)  
**Audio:** None  
**Saving:** Full save/load support (story state, choices, generated image references)

A visual novel where **all content is AI-generated on the fly**. The player provides a prompt (or lets the AI pick randomly), then plays through a continuous, infinite story with branching choices and AI-generated scene illustrations. Each playthrough is unique.

---

## 2. Core Concept

- **Genre-agnostic** — supports romance, horror, mystery, fantasy, slice-of-life, sci-fi, etc.
- **Infinite/continuous** — the story generates scene-by-scene indefinitely until a natural ending or the player stops.
- **AI-generated everything** — story, dialogue, scene descriptions, and illustrations come from Ollama and ComfyUI respectively.
- **Classic VN gameplay** — text boxes, character names, multiple-choice branching, typewriter text effect.

---

## 3. Systems Architecture

```
┌──────────────────────────────────────────────────┐
│                   Godot 4.x Client               │
│  ┌────────────┐  ┌──────────┐  ┌──────────────┐ │
│  │ Story Gen  │  │ Image Gen│  │  UI / VN     │ │
│  │ (Ollama)   │  │ (ComfyUI)│  │  Renderer    │ │
│  └─────┬──────┘  └────┬─────┘  └──────────────┘ │
│        │              │                          │
│        └──────┬───────┘                          │
│               │  HTTP                            │
└───────────────┼──────────────────────────────────┘
                │
    ┌───────────┴────────────┐
    │                        │
┌───▼─────┐           ┌─────▼──────┐
│ Ollama  │           │  ComfyUI   │
│ (local) │           │  (local)   │
│ ≤9B     │           │  API       │
└─────────┘           └────────────┘
```

Communication: **Direct HTTP from GDScript** to both Ollama and ComfyUI. No middleware.

---

## 4. Server Dependencies

| Server | Version | Download |
|--------|---------|----------|
| Ollama | v0.23.0 | [ollama-windows-amd64.zip](https://github.com/ollama/ollama/releases/download/v0.23.0/ollama-windows-amd64.zip) |
| ComfyUI | v0.33.1 | [ComfyUI_windows_portable_nvidia.7z](https://github.com/Comfy-Org/ComfyUI/releases/download/v0.33.1/ComfyUI_windows_portable_nvidia.7z) |
| Qwen | qwen3.5:9b (6.6 GB) | `ollama pull qwen3.5:9b` |

Extract both into `server/`. Ollama goes into `server/ollama/`, ComfyUI into `server/ComfyUI/`.

---

## 5. Story Generation System

### 5.1 Start Flow

1. **Settings screen** — player configures:
   - Ollama server URL (default: `http://localhost:11434`)
   - Model name (≤9B models: mistral, llama3, phi3, etc.)
   - ComfyUI server URL (default: `http://localhost:8188`)
   - Story prompt (optional)
   - Genre (optional — romance, horror, mystery, fantasy, sci-fi, etc.)
   - Player character name (optional — AI generates one if blank)
2. **Random mode** — if no prompt is provided, the AI randomly picks a genre and setting.
3. **Start button** → first scene is generated.

### 5.2 Scene Data Format (Ollama Output)

Ollama must return **structured JSON**. Enforced via system prompt.

```json
{
  "scene_id": "scene_042",
  "narrator": "The rain hammered against the windows as Alice stepped into the dimly lit hallway.",
  "dialogue": [
    { "character": "Alice", "emotion": "nervous", "text": "Hello? Is anyone here?" },
    { "character": "??? (narrator)", "emotion": "narrator", "text": "No answer came. Only the sound of dripping water." }
  ],
  "choices": [
    { "id": "a", "text": "Continue down the hallway", "leads_to": "next" },
    { "id": "b", "text": "Turn back and leave", "leads_to": "ending_leave" }
  ],
  "scene_prompt": "dimly lit hallway, rain on windows, dark silhouette at the end, horror atmosphere, cinematic lighting",
  "state_update": {
    "mood": "tense",
    "location": "haunted_house_hallway",
    "characters_present": ["Alice"],
    "plot_flags": ["found_door", "alice_is_nervous"],
    "tension_level": 7
  }
}
```

### 5.3 Story State Tracking

- A **structured state object** is maintained client-side and sent with every Ollama request.
- The state includes: characters, locations, plot flags, mood, tension, and a summary of recent events.
- Ollama receives the state + a rolling window of the last N scene narrations (not full history) to stay within context limits.
- The model also returns a `state_update` to evolve the state each turn.

### 5.4 Branching

- **Multiple choice** — 2-4 options presented at key story moments.
- **Freeform text input** — player can also type a custom response at any choice point.
- Both choice types are sent to Ollama to influence the next scene.

---

## 6. Image Generation System

### 6.1 ComfyUI Integration

- **One image per scene** — a single illustration per beat, not panels or character sprites.
- Godot sends an HTTP request to ComfyUI's API with the `scene_prompt` from the Ollama output.
- ComfyUI workflow: **TBD** (user has not decided — needs a txt2img workflow loaded via API, or a custom workflow JSON).
- Image is returned as a file/stream, saved locally, and displayed in the scene.

### 6.2 Image Display

- **Layered with transitions** — images are displayed full-screen as scene backgrounds with fade/slide transitions between them.
- No character sprite separation — the image IS the scene illustration.

### 6.3 Character Consistency

- **Not a priority** — accept visual inconsistency between scenes. The story quality matters more.

### 6.4 Generation Timing

- **Parallel generation** — scene text (Ollama) and scene image (ComfyUI) are generated in parallel where possible.
- Text generation happens first (we need the `scene_prompt` for ComfyUI), then image generation follows.
- Show a loading/transition state while the image generates.

---

## 7. UI / UX Design

### 7.1 Visual Style

- **Classic VN** — text box at bottom, character name plate, scene image fills the background.
- Character names are displayed in the name plate.
- Dialogue appears with a **typewriter effect** (character-by-character).

### 7.2 Choice Presentation

- Choices appear as clickable buttons overlaid on the scene.
- Freeform input option available alongside multiple-choice buttons.

### 7.3 Settings Screen

Full settings UI at startup:
- Server connection fields (Ollama URL, ComfyUI URL, model selection)
- Story prompt text area
- Genre dropdown
- Character name input
- Start / Load game buttons

### 7.4 Error Handling

- **Hard error** — if Ollama or ComfyUI is unreachable or returns an error, freeze the game and show an error message. Player can retry manually.
- No graceful degradation — errors must be resolved.

### 7.5 Loading States

- "Generating story..." while waiting on Ollama.
- "Generating illustration..." while waiting on ComfyUI.
- Spinner or simple animation during waits.

---

## 8. Save / Load System

### 8.1 Save Data

Each save stores:
- Full story state object (characters, flags, mood, etc.)
- List of all previous scene narrations (for context window reconstruction)
- All `scene_prompt` values and paths to generated images
- Player choices history
- Current `scene_id`

### 8.2 Save Slots

- Multiple save slots (e.g., 3-5 slots).
- Auto-save at each choice point or scene transition.
- Manual save/load from a menu.

### 8.3 Image Persistence

- Generated images are saved to disk and referenced by path in the save file.
- On load, images are loaded from disk (no regeneration needed).

---

## 9. Technical Notes

### 9.1 Ollama API

- Endpoint: `POST http://<host>:11434/api/chat`
- Model: configurable, ≤9B parameter models.
- System prompt forces JSON output with the scene schema.
- Conversation history includes: system prompt + state object + last N scene exchanges.

### 9.2 ComfyUI API

- Endpoint: `POST http://<host>:8188/prompt` (submit workflow)
- Poll for completion or use websocket for image output.
- Workflow to be determined — likely a standard txt2img SDXL/SD1.5 pipeline with prompt injection.

### 9.3 Image Storage

- Generated images saved to `user://generated_images/<scene_id>.png`
- Referenced by path in save data and scene data.

### 9.4 Responsive Scaling

- Multiple resolution support — UI elements use anchors/containers.
- Target minimum: 1280x720.
- Scene images scale to fill the window.

---

## 10. Testing Strategy (TDD)

### 10.1 Framework

- **GUT (Godot Unit Testing)** — the standard GDScript testing framework for Godot 4.x.
- Tests are GDScript files in `tests/`, prefixed with `test_`.

### 10.2 TDD Workflow

1. **Red** — write a failing test that defines expected behavior.
2. **Green** — write the minimum code to make the test pass.
3. **Refactor** — clean up while keeping tests green.

### 10.3 What to Test

| Priority | Area | Examples |
|----------|------|----------|
| High | Scene data parsing | Valid JSON → scene object, malformed JSON → error |
| High | State management | State updates correctly, rolling window truncation |
| High | Save/Load | Round-trip serialization, slot management |
| Medium | Story manager | Ollama request/response handling, prompt construction |
| Medium | Image manager | ComfyUI request construction, image path management |
| Low | UI rendering | Typewriter timing, choice button display |

### 10.4 Test Structure

```
tests/
├── test_scene_parser.gd       # Scene JSON parsing & validation
├── test_state_manager.gd      # Story state tracking & updates
├── test_save_manager.gd       # Save/load serialization
├── test_story_manager.gd      # Ollama integration logic
├── test_image_manager.gd      # ComfyUI integration logic
└── test_helpers.gd            # Shared test utilities & fixtures
```

### 10.5 Mocking External Services

- Ollama and ComfyUI are HTTP services — tests should **not** require running servers.
- Use a mock HTTP layer that returns canned JSON responses for unit tests.
- Integration tests (optional, manual) can hit real servers.

### 10.6 CI

- Run GUT tests via headless Godot: `godot --headless -s tests/run_all.gd`
- All tests must pass before merging.

---

## 11. Open Questions / TODO

- [ ] ComfyUI workflow design — standard txt2img or custom?
- [ ] Ollama system prompt design for reliable JSON output
- [ ] Scene limit / ending detection for infinite mode
- [ ] How many save slots
- [ ] Whether to support exporting/sharing stories
- [ ] Whether to support multiple languages

---

## 12. Project Structure (Proposed)

```
instant-visual-novel/
├── docs/
│   └── specs.md
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
