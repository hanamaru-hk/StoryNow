# 11. Open Questions / TODO

## Resolved

- [x] ComfyUI workflow design → txt2img SDXL-compatible pipeline (`data/comfyui/workflow-template.json`)
- [x] Whether to support multiple languages → Yes, 3 languages (en, zh_CN, zh_TW) via `I18n` singleton

## Open

- [ ] llama.cpp system prompt design for reliable JSON output
- [ ] Scene limit / ending detection for infinite mode
- [ ] How many save slots
- [ ] Whether to support exporting/sharing stories
- [ ] Model checkpoint selection UI (currently hardcoded in workflow template)
- [ ] Negative prompt configuration
- [ ] Image generation resolution (currently 1280x1024 in workflow)
