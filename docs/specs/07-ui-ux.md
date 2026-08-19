# 7. UI / UX Design

## 7.1 Visual Style

- **Classic VN** — text box at bottom, character name plate, scene image fills the background.
- Character names are displayed in the name plate.
- Dialogue appears with a **typewriter effect** (character-by-character).

## 7.2 Choice Presentation

- Choices appear as clickable buttons overlaid on the scene.
- Freeform input option available alongside multiple-choice buttons.

## 7.3 Settings Screen

Full settings UI at startup:
- Server connection fields (Ollama URL, ComfyUI URL, model selection)
- Story prompt text area
- Genre dropdown
- Character name input
- Start / Load game buttons

## 7.4 Error Handling

- **Hard error** — if Ollama or ComfyUI is unreachable or returns an error, freeze the game and show an error message. Player can retry manually.
- No graceful degradation — errors must be resolved.

## 7.5 Loading States

- "Generating story..." while waiting on Ollama.
- "Generating illustration..." while waiting on ComfyUI.
- Spinner or simple animation during waits.
