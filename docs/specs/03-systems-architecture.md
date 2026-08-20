# 3. Systems Architecture

```
┌──────────────────────────────────────────────────┐
│                   Godot 4.x Client               │
│  ┌────────────┐  ┌──────────┐  ┌──────────────┐ │
│  │ Story Gen  │  │ Image Gen│  │  UI / VN     │ │
│  │(llama.cpp) │  │ (ComfyUI)│  │  Renderer    │ │
│  └─────┬──────┘  └────┬─────┘  └──────────────┘ │
│        │              │                          │
│        └──────┬───────┘                          │
│               │  HTTP                            │
│  ┌────────────┴────────────────┐                 │
│  │  ServerRuntimeManager       │                 │
│  │  (lifecycle, health check,  │                 │
│  │   heartbeat, status overlay)│                 │
│  └─────────────────────────────┘                 │
└───────────────┼──────────────────────────────────┘
                │
    ┌───────────┴────────────┐
    │                        │
┌───▼─────┐           ┌─────▼──────┐
│llama.cpp│           │  ComfyUI   │
│ (local) │           │  (local)   │
│ ≤9B     │           │  API       │
└─────────┘           └────────────┘
```

Communication: **Direct HTTP from GDScript** to both llama.cpp and ComfyUI. No middleware.

## Key Components

- **ServerRuntimeManager** — app-wide coordinator that starts/stops both servers, runs periodic health checks (15s interval), reconciles stale state on startup, and shuts down owned processes on exit.
- **LLMManager** / **ImageServerManager** — manage individual server process lifecycles (start, stop, health check, status persistence).
- **ServerStatusOverlay** — always-on-top CanvasLayer showing colored dots (green/red/gray) for each server's health state.
