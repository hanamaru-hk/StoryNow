# 5. Story Generation System

## 5.1 Start Flow

1. **Main menu** — player sees buttons: Start, Load, Gallery, Game Setting, Image Server Setting, LLM Setting, Exit.
2. **Start** → navigates to the **Brainstorm scene** (`brainstorm.tscn`).
3. **Brainstorm scene** — player enters a story background prompt in a text area, with buttons: Random, Enhance, Start, Back.
   - **Random** — lets the AI generate a random story background (not yet implemented).
   - **Enhance** — refines the current prompt using the LLM (not yet implemented).
   - **Start** — generates the first scene from the prompt (not yet implemented).
   - **Back** — returns to main menu.
4. Server settings are configured separately via overlay menus from the main screen (LLM port, Image Server port).

## 5.2 Scene Data Format (LLM Output)

The LLM returns **structured JSON** matching the template schema defined in `data/llm/<lang>/template.json`.

```json
{
  "scenePrompt": "dimly lit hallway, rain on windows, dark silhouette at the end, horror atmosphere, cinematic lighting",
  "dialog": [
    { "Alice": "Hello? Is anyone here?" },
    { "narration": "No answer came. Only the sound of dripping water." }
  ],
  "language": "en",
  "choices": [
    "Continue down the hallway",
    "Turn back and leave"
  ],
  "storyBackground": "Alice explores a haunted house on a stormy night."
}
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `scenePrompt` | String | Image generation prompt for ComfyUI |
| `dialog` | Array | Ordered list of dialogue/narration lines. Each entry is an object with either a character name key (dialogue) or `"narration"` key (narrator text). |
| `language` | String | Language code (`en`, `zh_CN`, `zh_TW`) |
| `choices` | Array | 2-4 choice strings presented to the player |
| `storyBackground` | String | The story background/prompt context |

## 5.3 Story State Tracking

- A **structured state object** is maintained client-side and sent with every LLM request.
- The state includes: characters, locations, plot flags, mood, tension, and a summary of recent events.
- LLM receives the state + a rolling window of the last N scene narrations (not full history) to stay within context limits.
- The model also returns a `state_update` to evolve the state each turn.
- *(Not yet implemented — currently only the UI for prompt entry exists.)*

## 5.4 Branching

- **Multiple choice** — 2-4 options presented at key story moments.
- Both choice types are sent to the LLM to influence the next scene.
- *(Not yet implemented.)*

## 5.5 Implementation Status

| Component | Status |
|-----------|--------|
| Brainstorm scene UI | ✅ Implemented |
| LLM prompt templates (en, zh_CN, zh_TW) | ✅ Implemented |
| Random prompt generation | ❌ Not yet implemented |
| Prompt enhancement | ❌ Not yet implemented |
| LLM API call for story generation | ❌ Not yet implemented |
| Story state management | ❌ Not yet implemented |
| Branching/choice handling | ❌ Not yet implemented |
