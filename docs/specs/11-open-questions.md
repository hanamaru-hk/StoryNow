# 11. Open Questions / TODO

## Resolved

- [x] ComfyUI workflow design → txt2img SDXL pipeline (`data/comfyui/workflow_template.json`), placeholders `__MODEL_FILENAME__`, `__PREFIX__`, `__POSITIVE_PROMPT__`, `__SUFFIX__`, `__NEGATIVE_PROMPT__`, `__SEED__`, `__FILENAME_PREFIX__`, `__IMAGE_WIDTH__/__IMAGE_HEIGHT__`
- [x] Multiple languages → 5 languages (en, zh_CN, zh_TW, yue, ja) via `I18n` singleton + per-lang prompt dirs `data/llm/<lang>/`
- [x] llama.cpp system prompt for reliable JSON → `data/llm/<lang>/{story,scene,random,enhance}` + `common/output_json_requirement` + `common/output_template.json` + guardrail injection; plus runtime JSON repair for `image_prompt` bare quotes
- [x] Scene limit / ending detection → `expected_rounds` / `current_round` + `end` bool; prompt instructs LLM to set `end=true` when `current_round == expected_rounds`
- [x] How many save slots → unlimited: one folder per `uuid` under `user://saves/`, paginated Load (10) / Gallery (12) overlays
- [x] Model checkpoint selection → configurable via Image Server Settings `model_filename` (default `waiIllustriousSDXL_v170.safetensors`)
- [x] Negative prompt configuration → `data/comfyui/{safe,builder}_negative_prompt` switched by `GameSettingsManager.is_builder_mode()`
- [x] Image generation resolution → configurable via `ImageServerSettingsManager.settings.image_width/height` (defaults 1344×768), injected into `EmptyLatentImage`
- [x] Brainstorm Random / Enhance / Start flows → implemented in `scripts/brainstorm.gd:1`
- [x] Save/Load system → `SceneDataManager` + `GameProgressManager` + overlays implemented
- [x] TTS auto-play → Sherpa-ONNX Piper VITS implemented (`scripts/tts_manager.gd:1`)

## Open

- [ ] Testing suite — `tests/` + GUT framework planned (`docs/specs/10-testing-strategy.md`) but no tests yet; CI command not wired
- [ ] Exporting/sharing stories — no export UI; saves are plain JSON + images on disk
- [ ] Music / sound design beyond TTS
- [ ] Pagination UX polish for very large save collections (100+ saves → current `pages_set` + ellipsis handles up to ~tens, may need virtualized list)
- [ ] Windows-only `taskkill` / PowerShell assumption — portability to Linux/macOS (`pkill`, `pwsh` fallback exists but untested)
- [ ] Builder-mode content policy — files in `data/builder` enable the separate guardrails when `safe_mode == false`, but there is no user-facing toggle beyond `safe_mode`
- [ ] Image history limit per scene — carousel grows unbounded; no cap or cleanup
