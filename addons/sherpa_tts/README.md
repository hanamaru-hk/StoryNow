# Sherpa TTS GDExtension

Native Godot wrapper for the Sherpa-ONNX offline TTS C API.

## Build

From `addons/sherpa_tts`:

```powershell
git clone https://github.com/godotengine/godot-cpp.git godot-cpp
scons platform=windows target=template_release arch=x86_64
scons platform=windows target=template_debug arch=x86_64
```

The build links against the existing local Sherpa package under `s/sherpa-onnx`
and copies the required runtime DLLs into `addons/sherpa_tts/bin`.

`scripts/tts_manager.gd` requires `SherpaOfflineTTS`; there is no Python TTS
fallback path.
