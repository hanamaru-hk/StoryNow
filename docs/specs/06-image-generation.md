# 6. Image Generation System

## 6.1 ComfyUI Integration

- **One image per scene** — a single illustration per beat, not panels or character sprites.
- Godot sends an HTTP request to ComfyUI's API with the `scenePrompt` from the LLM output.
- ComfyUI workflow: **txt2img pipeline** defined in `data/comfyui/workflow-template.json`.
- Image is returned as a file/stream, saved locally, and displayed in the scene.

## 6.2 Workflow Template

The workflow is a standard txt2img pipeline (SDXL-compatible) with the following placeholder-injected fields:

| Placeholder | Node | Field | Description |
|---|---|---|---|
| `__MODEL_NAME__` | `1` (`CheckpointLoaderSimple`) | `inputs.ckpt_name` | Checkpoint filename (e.g. `waiIllustriousSDXL_v170.safetensors`) |
| `__POSITIVE_PROMPT__` | `3` (`CLIPTextEncode`) | `inputs.text` | Positive prompt text (from `scenePrompt`) |
| `__NEGATIVE_PROMPT__` | `6` (`CLIPTextEncode`) | `inputs.text` | Negative prompt text |
| `__SEED__` | `2` (`KSampler`) | `inputs.seed` | Random seed for reproducibility |
| `__FILENAME_PREFIX__` | `5` (`SaveImage`) | `inputs.filename_prefix` | Output filename prefix |

### Pipeline Nodes

1. `CheckpointLoaderSimple` → loads model checkpoint
2. `KSampler` → samples with 25 steps, cfg=4, dpmpp_2m_sde_gpu sampler, simple scheduler
3. `CLIPTextEncode` (positive) → encodes positive prompt
4. `CLIPTextEncode` (negative) → encodes negative prompt
5. `EmptyLatentImage` → 1280x1024 latent canvas
6. `VAEDecode` → decodes latent to pixel image
7. `SaveImage` → saves output

## 6.3 Image Display

- **Layered with transitions** — images are displayed full-screen as scene backgrounds with fade/slide transitions between them.
- No character sprite separation — the image IS the scene illustration.

## 6.4 Character Consistency

- **Not a priority** — accept visual inconsistency between scenes. The story quality matters more.

## 6.5 Generation Timing

- **Sequential** — scene text (LLM) generates first (we need the `scenePrompt` for ComfyUI), then image generation follows.
- Show a loading/transition state while the image generates.

## 6.6 Implementation Status

| Component | Status |
|-----------|--------|
| ComfyUI workflow template | ✅ Implemented (`data/comfyui/workflow-template.json`) |
| ComfyUI server lifecycle (start/stop/health) | ✅ Implemented |
| ComfyUI API call for image generation | ❌ Not yet implemented |
| Image display in VN scene | ❌ Not yet implemented |
