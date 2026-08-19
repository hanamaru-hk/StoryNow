# 10. Testing Strategy (TDD)

## 10.1 Framework

- **GUT (Godot Unit Testing)** — the standard GDScript testing framework for Godot 4.x.
- Tests are GDScript files in `tests/`, prefixed with `test_`.

## 10.2 TDD Workflow

1. **Red** — write a failing test that defines expected behavior.
2. **Green** — write the minimum code to make the test pass.
3. **Refactor** — clean up while keeping tests green.

## 10.3 What to Test

| Priority | Area | Examples |
|----------|------|----------|
| High | Scene data parsing | Valid JSON → scene object, malformed JSON → error |
| High | State management | State updates correctly, rolling window truncation |
| High | Save/Load | Round-trip serialization, slot management |
| Medium | Story manager | Ollama request/response handling, prompt construction |
| Medium | Image manager | ComfyUI request construction, image path management |
| Low | UI rendering | Typewriter timing, choice button display |

## 10.4 Test Structure

> **Note:** Tests are not yet implemented. The following is the planned structure.

```
tests/
├── test_scene_parser.gd       # Scene JSON parsing & validation
├── test_state_manager.gd      # Story state tracking & updates
├── test_save_manager.gd       # Save/load serialization
├── test_story_manager.gd      # Ollama integration logic
├── test_image_manager.gd      # ComfyUI integration logic
└── test_helpers.gd            # Shared test utilities & fixtures
```

## 10.5 Mocking External Services

- Ollama and ComfyUI are HTTP services — tests should **not** require running servers.
- Use a mock HTTP layer that returns canned JSON responses for unit tests.
- Integration tests (optional, manual) can hit real servers.

## 10.6 CI

- Run GUT tests via headless Godot: `godot --headless -s tests/run_all.gd`
- All tests must pass before merging.
