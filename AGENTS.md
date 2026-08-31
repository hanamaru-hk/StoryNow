# AGENTS.md

This file is the working guide for AI coding agents in this repository. Keep changes focused, preserve user work, and update this file when the development workflow materially changes.

## Project at a glance

StoryNow is a Godot visual-novel client that generates story text with a local llama.cpp server, images with ComfyUI, and speech with a native Sherpa-ONNX GDExtension.

- Engine: Godot 4.7, using the GL Compatibility renderer. Treat `project.godot` as the source of truth if other documentation disagrees.
- Language: typed GDScript, plus C++ for `addons/sherpa_tts/` and PowerShell for setup helpers.
- Entry scene: `scenes/main.tscn`.
- Design documentation: begin with `docs/specs/index.md`, then read only the specs relevant to the change.
- Runtime persistence: settings and games live under `user://`; do not assume files in `saves/` are the live user data.

## Repository map

- `scripts/`: application logic, autoload managers, UI overlays, and gameplay controllers.
- `scenes/`: Godot scenes. Scene node paths, exported properties, and connected signals are contracts with their attached scripts.
- `data/`: default JSON, LLM prompt templates, ComfyUI workflow data, and music.
- `tools/`: headless checks and smoke-test scripts.
- `addons/sherpa_tts/`: native Sherpa-ONNX wrapper and its checked-in runtime DLLs.
- `server/`: local llama.cpp, ComfyUI, and Sherpa installations; ignored and machine-specific.
- `docs/specs/`: architecture and behavior specifications. Some status notes may lag behind the implementation, so verify against current code.

## Before changing code

1. Run `git status --short` and do not overwrite or revert changes you did not create.
2. Read the target script and its corresponding `.tscn`, manager, tests, and relevant spec before editing.
3. Check `project.godot` before adding or renaming an autoload.
4. Search usages with `rg` before renaming signals, node paths, dictionary keys, settings, or save fields.
5. Prefer a small change in the existing architecture over a broad rewrite.

Do not edit generated/imported content in `.godot/`, `*.uid`, or `*.import`. Do not commit machine-local models, server installations, build output, or `data/builder`; see `.gitignore`.

## Coding conventions

- Follow the surrounding GDScript style: tabs for indentation, snake_case functions and variables, PascalCase classes, `:=` where inference is clear, and explicit return types.
- Keep controllers focused. `scripts/gameplay.gd` coordinates; gameplay behavior belongs in the relevant `gameplay_*_controller.gd`, and pure scene transformation belongs in `gameplay_scene_service.gd`.
- Use existing autoload managers for shared state and services instead of creating parallel globals.
- Keep HTTP/process lifecycle and cancellation paths explicit. A cancelled or superseded request must not update UI, save state, or report a misleading error later.
- Treat external LLM and ComfyUI responses, legacy saves, and user-edited JSON as untrusted. Check types and required fields, preserve useful defaults, and return actionable errors.
- Preserve scene/save compatibility when adding dictionary fields. Use `.get(key, default)` for optional or migrated fields and avoid silently changing existing meanings.
- Use `AppPaths` and Godot `res://`/`user://` paths rather than hard-coded machine paths.
- Keep UI mutations on the main thread. Guard callbacks when nodes may have been freed or a scene may have changed.
- When changing a scene, use the Godot editor when practical. If editing `.tscn` text, make the smallest possible edit and verify the scene loads.
- Keep comments about intent and non-obvious constraints; do not narrate straightforward code.

## Prompts, settings, and localization

- Prompt fragments under `data/llm/<language>/` form a shared contract with the parsers. If output shape changes, update prompt templates, parsing/repair logic, and tests together.
- Supported languages are `en`, `zh_CN`, `zh_TW`, `yue`, and `ja`. When changing user-facing prompt behavior, verify whether all five language directories need equivalent updates.
- Preserve valid JSON in `data/default_*.json`, `data/comfyui/workflow_template.json`, and all `output_template.json` files.
- Never add secrets, API keys, absolute paths, model files, or local port overrides to committed defaults.

## External services

Normal unit and logic tests must not require llama.cpp, ComfyUI, downloaded models, or network access. Isolate request construction and response parsing so they can be tested with canned data. Only run integration or smoke checks against real services when they are already available and the task specifically needs them; do not start, stop, download, or replace large external runtimes without explicit need.

Sherpa TTS has no Python fallback. Changes under `addons/sherpa_tts/src/` require rebuilding both debug and release GDExtension targets as described in `addons/sherpa_tts/README.md`. Do not replace checked-in DLLs unless the native wrapper was intentionally rebuilt and verified.

## Validation

Use a Godot 4.7 executable available on the machine; replace `godot` below with its full path when necessary.

On the current Windows workstation, use the console executable at `C:\Users\celew\Downloads\Godot_v4.7.1-stable_win64_console.exe` for automated headless checks. Godot 4.7.1 is known to crash with native `signal 11` when launched inside the Codex sandbox on this machine, even when the project is valid. If that happens, request approval to rerun the same non-destructive Godot command outside the sandbox. Do not treat the sandbox crash as a test failure or report that validation is unavailable without attempting the approved out-of-sandbox run. When the UI offers it, request/persist approval for the executable's `--headless` command prefix so later validation can run without repeated prompts.

For pure gameplay scene logic:

```powershell
godot --headless --path . --script res://tools/test_gameplay_scene_service.gd
```

For a changed GDScript file, run a syntax check where possible:

```powershell
godot --headless --path . --check-only --script res://scripts/<changed_file>.gd
```

For changes that affect project resources or scenes, also start the project headlessly and confirm there are no parse/load errors:

```powershell
godot --headless --path . --quit
```

Some autoload or UI scripts cannot be meaningfully validated in isolation. In that case, load the affected scene or run the project and exercise the changed path. Report exactly which checks ran and which could not run. Do not claim the planned GUT suite passed: it is not currently present.

When adding pure behavior, add or extend a deterministic headless test in `tools/`. Tests should not write real user saves, depend on timing, or contact external services. Use temporary/test-specific paths and clean them up.

## Change checklist

- The project parses and affected scenes load.
- Relevant headless tests pass.
- Async cancellation, timeout, and freed-node paths were considered.
- Save/settings compatibility was preserved or intentionally migrated.
- Prompt/schema changes remain synchronized with parsing and supported languages.
- No generated files, local binaries/models, secrets, or unrelated user changes were included.
- Documentation was updated when commands, configuration, architecture, or user-visible behavior changed.

In the final handoff, summarize the behavior changed, list validation performed, and call out any integration testing that still requires local AI servers or models.
