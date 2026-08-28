# 6. Image Generation System

## 6.1 ComfyUI Integration

- **One image per scene** (plus user can generate more and cycle via carousel).
- `Gameplay._execute_new_story_flow` / `_execute_new_scene_flow` calls `_generate_comfyui_image` → `ImageServerManager.generate_scene_image(image_prompt, uuid)` after LLM succeeds (`scripts/gameplay.gd:417`).
- Image prompt also editable via `ImageOverlay` (free mode) and triggers a new generation.

## 6.2 Workflow Template

`data/comfyui/workflow_template.json` — standard SDXL txt2img pipeline:

| Placeholder | Node | Field | Description |
|---|---|---|---|
| `__MODEL_FILENAME__` / `__MODEL_NAME__` | `1` (`CheckpointLoaderSimple`) | `inputs.ckpt_name` | Checkpoint filename from `ImageServerSettingsManager.settings.model_filename` (default `waiIllustriousSDXL_v170.safetensors`) |
| `__POSITIVE_PROMPT__` | `3` (`CLIPTextEncode`) | `inputs.text` | `"score_9, score_8_up, score_7_up, masterpiece, ${image_prompt}"` |
| `__NEGATIVE_PROMPT__` | `6` (`CLIPTextEncode`) | `inputs.text` | `"(white_skin:1.5), ${safe/free_negative_prompt}"` loaded in `scripts/image_server_manager.gd:170` |
| `__SEED__` | `2` (`KSampler`) | `inputs.seed` | Random 0–2147483647 |
| `__FILENAME_PREFIX__` | `5` (`SaveImage`) | `inputs.filename_prefix` | `"SN"` (`FILENAME_PREFIX`) |
| `__IMAGE_WIDTH__` / `__IMAGE_HEIGHT__` | `7` (`EmptyLatentImage`) | `inputs.width/height` | From `GameSettingsManager.settings.image_width/height` (defaults `1344` / `768`) |

### Pipeline Nodes

1. `CheckpointLoaderSimple` (1) → model + clip + vae
2. `EmptyLatentImage` (7) → latent 1344×768 (configurable)
3. `CLIPTextEncode` positive (3) / negative (6)
4. `KSampler` (2) → 25 steps, cfg 4, `dpmpp_2m_sde_gpu`, `simple` scheduler
5. `VAEDecode` (4)
6. `SaveImage` (5)

`_fix_comfy_workflow_dict` (`scripts/image_server_manager.gd:196`) normalizes `SaveImage` images slot, casts `seed`/`width`/`height`/`batch_size` and link tuples to correct types.

## 6.3 Generation Pipeline

`generate_scene_image` (`scripts/image_server_manager.gd:375`):

1. `ServerRuntimeManager.push_request("image", …, 120s)` for queue visibility.
2. Load template → replace placeholders → JSON parse → `_fix_comfy_workflow_dict`.
3. `_queue_comfy_prompt` → `POST http://127.0.0.1:<port>/prompt` → `prompt_id`.
4. `_poll_comfy_history` → `GET /history/<prompt_id>` polling (0.5s interval, ≤120 attempts) → first `images[0]` (checks `outputs["5"]` fallback).
5. `_download_comfy_image` → `GET /view?filename=&subfolder=&type=` → save to `user://saves/<uuid>/images/<filename>` (creates dirs).
6. Return `{success, save_path, filename, prompt, seed}`; `pop_request`.

On success, `Gameplay` appends `filename` to `scene_data["image_filenames"]`, sets `current_image_index` to tail, `save()`, and `_set_background_from_file` (`scripts/gameplay.gd:441`). `ImageOverlay` duplicates this flow standalone.

## 6.4 Image Display

- `%BackgroundImage` (`TextureRect`) shows the active image; default placeholder is `res://assets/images/generating.jpg` at 50% opacity. If a saved scene has no usable image file, it shows a black background with white `NO IMAGE` text using Arial Black when available, falling back to outlined Arial.
- `_load_current_scene_image` scans `user://saves/<uuid>/images/` sorted filenames, clamps `current_image_index`, loads via `Image.load(global_path)` → `ImageTexture`.
- **Image carousel:** `ImageActionOverlay` (New / Change) → `ImageChangeOverlay` with Prev/Next/Save shows `user://saves/<uuid>/images/` browsing; `current_image_index` persisted on Save (`scripts/gameplay.gd:703-775`).

## 6.5 Character Consistency

- Not a priority — accept inconsistency across scenes.

## 6.6 Implementation Status

| Component | Status |
|-----------|--------|
| ComfyUI workflow template | ✅ `data/comfyui/workflow_template.json` |
| ComfyUI server lifecycle (start/stop/health) | ✅ `scripts/image_server_manager.gd:1` |
| ComfyUI API call (queue, poll, download) | ✅ `scripts/image_server_manager.gd:375` |
| Image display + placeholder | ✅ `scripts/gameplay.gd:155-495` |
| Image carousel / change overlay | ✅ `scripts/gameplay.gd:703` + `scenes/gameplay.tscn` |
| Free-mode prompt editing | ✅ `scripts/image_overlay.gd:1` |
