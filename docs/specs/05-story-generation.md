# 5. Story Generation System

## 5.1 Start Flow

1. **Settings screen** — player configures:
   - Ollama server URL (default: `http://localhost:11434`)
   - Model name (≤9B models: mistral, llama3, phi3, etc.)
   - ComfyUI server URL (default: `http://localhost:8188`)
   - Story prompt (optional)
   - Genre (optional — romance, horror, mystery, fantasy, sci-fi, etc.)
   - Player character name (optional — AI generates one if blank)
2. **Random mode** — if no prompt is provided, the AI randomly picks a genre and setting.
3. **Start button** → first scene is generated.

## 5.2 Scene Data Format (Ollama Output)

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

## 5.3 Story State Tracking

- A **structured state object** is maintained client-side and sent with every Ollama request.
- The state includes: characters, locations, plot flags, mood, tension, and a summary of recent events.
- Ollama receives the state + a rolling window of the last N scene narrations (not full history) to stay within context limits.
- The model also returns a `state_update` to evolve the state each turn.

## 5.4 Branching

- **Multiple choice** — 2-4 options presented at key story moments.
- **Freeform text input** — player can also type a custom response at any choice point.
- Both choice types are sent to Ollama to influence the next scene.
