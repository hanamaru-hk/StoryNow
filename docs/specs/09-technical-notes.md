# 9. Technical Notes

## 9.1 Ollama API

- Endpoint: `POST http://<host>:11434/api/chat`
- Model: configurable, ≤9B parameter models.
- System prompt forces JSON output with the scene schema.
- Conversation history includes: system prompt + state object + last N scene exchanges.

## 9.2 ComfyUI API

- Endpoint: `POST http://<host>:8188/prompt` (submit workflow)
- Poll for completion or use websocket for image output.
- Workflow to be determined — likely a standard txt2img SDXL/SD1.5 pipeline with prompt injection.

## 9.3 Image Storage

- Generated images saved to `user://generated_images/<scene_id>.png`
- Referenced by path in save data and scene data.

## 9.4 Responsive Scaling

- Multiple resolution support — UI elements use anchors/containers.
- Target minimum: 1280x720.
- Scene images scale to fill the window.
