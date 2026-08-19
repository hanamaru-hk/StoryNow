# 3. Systems Architecture

```
┌──────────────────────────────────────────────────┐
│                   Godot 4.x Client               │
│  ┌────────────┐  ┌──────────┐  ┌──────────────┐ │
│  │ Story Gen  │  │ Image Gen│  │  UI / VN     │ │
│  │ (Ollama)   │  │ (ComfyUI)│  │  Renderer    │ │
│  └─────┬──────┘  └────┬─────┘  └──────────────┘ │
│        │              │                          │
│        └──────┬───────┘                          │
│               │  HTTP                            │
└───────────────┼──────────────────────────────────┘
                │
    ┌───────────┴────────────┐
    │                        │
┌───▼─────┐           ┌─────▼──────┐
│ Ollama  │           │  ComfyUI   │
│ (local) │           │  (local)   │
│ ≤9B     │           │  API       │
└─────────┘           └────────────┘
```

Communication: **Direct HTTP from GDScript** to both Ollama and ComfyUI. No middleware.
