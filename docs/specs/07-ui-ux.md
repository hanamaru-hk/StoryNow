# 7. UI / UX Design

## 7.1 Visual Style

- **Classic VN** — text box at bottom, character name plate, scene image fills the background.
- Character names are displayed in the name plate.
- Dialogue appears with a **typewriter effect** (character-by-character).
- *(VN renderer not yet implemented — currently only menu and settings screens exist.)*

## 7.2 Choice Presentation

- Choices appear as clickable buttons overlaid on the scene.
- *(Not yet implemented.)*

## 7.3 Main Menu

The main menu (`main.tscn`) is the app entry point with the following buttons:

| Button | Action |
|--------|--------|
| Start | Navigates to brainstorm scene |
| Load | Load a saved game *(not yet implemented)* |
| Gallery | View generated images *(not yet implemented)* |
| Game Setting | Opens Game Settings overlay |
| Image Server Setting | Opens Image Server Settings overlay |
| LLM Setting | Opens LLM Settings overlay |
| Exit | Quits the application |

## 7.4 Brainstorm Scene

The brainstorm scene (`brainstorm.tscn`) is where the player creates a story prompt:

- **Title:** "Story Background"
- **Description:** Instructions for the player
- **Text area:** Multi-line input for the story background/prompt
- **Button row:** Random, Enhance, Start, Back

## 7.5 Settings Overlays

Settings are split into three separate overlay menus, each accessible from the main menu:

### Game Settings Overlay
- Language selector (English, 简体中文, 繁體中文)
- Screen size selector (Full, 1344x768)
- Buttons: Save, Reset, Back

### LLM Settings Overlay
- Port number input (default: 48763)
- Buttons: Save, Reset, Back

### Image Server Settings Overlay
- Port number input (default: 56321)
- Buttons: Save, Reset, Back

All overlays follow an **open/save/reset/back** pattern with pending state management — changes are staged in memory and only applied on Save.

## 7.6 Server Status Overlay

- Always-on-top CanvasLayer showing two colored dots:
  - **Green** = server healthy
  - **Red** = server unhealthy
  - **Gray** = server starting
- Dots react to `ServerRuntimeManager` signals; no polling.

## 7.7 Internationalization

- Three languages supported: English, Simplified Chinese, Traditional Chinese.
- All UI labels are translated via the `I18n` singleton.
- Language can be changed in Game Settings.

## 7.8 Error Handling

- **Hard error** — if Ollama or ComfyUI is unreachable or returns an error, freeze the game and show an error message. Player can retry manually.
- No graceful degradation — errors must be resolved.
- *(Error handling UI not yet implemented for story/image generation.)*

## 7.9 Loading States

- "Generating story..." while waiting on LLM.
- "Generating illustration..." while waiting on ComfyUI.
- Spinner or simple animation during waits.
- *(Not yet implemented.)*
