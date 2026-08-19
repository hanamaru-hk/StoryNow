# 8. Save / Load System

> **Status:** Not yet implemented. This is a design specification.

## 8.1 Save Data

Each save stores:
- Full story state object (characters, flags, mood, etc.)
- List of all previous scene narrations (for context window reconstruction)
- All `scenePrompt` values and paths to generated images
- Player choices history
- Current scene ID

## 8.2 Save Slots

- Multiple save slots (e.g., 3-5 slots).
- Auto-save at each choice point or scene transition.
- Manual save/load from a menu.

## 8.3 Image Persistence

- Generated images are saved to disk and referenced by path in the save file.
- On load, images are loaded from disk (no regeneration needed).
