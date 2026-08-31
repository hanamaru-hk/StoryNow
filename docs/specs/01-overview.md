# 1. Overview

**Title:** StoryNow
**Engine:** Godot 4.3 (GDScript 2.x, .tscn scenes, `gl_compatibility` renderer)
**Platform:** Desktop (Windows primary; Linux/macOS via same Godot export)
**Resolution:** 1920×1080 viewport, `canvas_items` stretch; windowed 1344×768 or fullscreen toggle via `GameSettingsManager`
**Audio:** Sherpa-ONNX TTS (offline, per-dialogue WAV) with auto-play via `TTSVoice` bus; voice shaping for Cantonese and Japanese male dialogue
**Saving:** Implemented — per-scene `user://saves/<uuid>/scene_data.json` + images `…/images/` + TTS `…/sounds/`; progress in `user://game_progress.json`

A visual novel where **all content is AI-generated on the fly**. The player provides a prompt (or lets the AI pick randomly), then plays through a continuous story with branching choices and AI-generated scene illustrations. Each playthrough is unique. The client bundles local `llama.cpp` and `ComfyUI` servers and orchestrates them via `ServerRuntimeManager` using direct HTTP (`HTTPRequest` / `HTTPClient`).

## Current Implementation Snapshot

- **Implemented:** Main menu → Brainstorm → Gameplay loop, LLM story/scene generation, ComfyUI image generation, TTS synthesis, save/load/gallery, server lifecycle & health overlay, i18n (en / zh_CN / zh_TW / yue / ja), Chrome hide/show.
- **Partial / evolving:** Choice persistence (previously-selected marking), image carousel per scene, dialogue overlay edit/add/regenerate.
- **Not implemented:** Automated testing suite (`tests/` planned, GUT), export/share.
