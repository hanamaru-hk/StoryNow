# 6. Image Generation System

## 6.1 ComfyUI Integration

- **One image per scene** — a single illustration per beat, not panels or character sprites.
- Godot sends an HTTP request to ComfyUI's API with the `scene_prompt` from the Ollama output.
- ComfyUI workflow: **TBD** (user has not decided — needs a txt2img workflow loaded via API, or a custom workflow JSON).
- Image is returned as a file/stream, saved locally, and displayed in the scene.

## 6.2 Image Display

- **Layered with transitions** — images are displayed full-screen as scene backgrounds with fade/slide transitions between them.
- No character sprite separation — the image IS the scene illustration.

## 6.3 Character Consistency

- **Not a priority** — accept visual inconsistency between scenes. The story quality matters more.

## 6.4 Generation Timing

- **Parallel generation** — scene text (Ollama) and scene image (ComfyUI) are generated in parallel where possible.
- Text generation happens first (we need the `scene_prompt` for ComfyUI), then image generation follows.
- Show a loading/transition state while the image generates.
