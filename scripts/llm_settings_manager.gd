extends Node

const SETTINGS_PATH := "user://llm_settings.json"
const DEFAULT_SETTINGS_PATH := "data/default_llm_settings.json"
const LLAMA_MODELS_DIR_CEN := "data/llama-models/cen"
const LLAMA_MODELS_DIR_AB := "data/llama-models/ab"

var settings := {
	"port": 48763,
	"timeout": 60,
	"context_size": 0,
	"llm_model_filename": "cen/unsloth__Qwen3.5-9B-UD-Q3_K_XL.gguf",
}

var available_model_filenames: Array[String] = []


func _ready() -> void:
	load_settings()
	startup_refresh_model_filename_list()
	startup_apply_first_free_mode_model()


func save_settings() -> void:
	_normalize_integer_settings()
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK and json.data is Dictionary:
			settings.merge(json.data, true)
			_normalize_integer_settings()


func reset_to_defaults() -> void:
	var file := FileAccess.open(AppPaths.external_path(DEFAULT_SETTINGS_PATH), FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK and json.data is Dictionary:
			settings = json.data.duplicate()
			_normalize_integer_settings()
			startup_refresh_model_filename_list()
			_ensure_selected_model_is_available()
			save_settings()


func startup_refresh_model_filename_list() -> void:
	available_model_filenames = _get_model_filenames_in_dir(LLAMA_MODELS_DIR_CEN, "cen")
	if GameSettingsManager.is_free_mode():
		available_model_filenames.append_array(_get_model_filenames_in_dir(LLAMA_MODELS_DIR_AB, "ab"))
	_ensure_selected_model_is_available()


func startup_apply_first_free_mode_model() -> void:
	if not GameSettingsManager.is_free_mode():
		return
	if GameSettingsManager.has_tried_free_mode_yet():
		return
	var ab_models := _get_model_filenames_in_dir(LLAMA_MODELS_DIR_AB, "ab")
	if ab_models.is_empty():
		return
	settings["llm_model_filename"] = ab_models[0]
	save_settings()
	GameSettingsManager.mark_tried_free_mode_yet()


func get_available_model_filenames() -> Array[String]:
	var models: Array[String] = []
	models.append_array(available_model_filenames)
	return models


func _get_model_filenames_in_dir(relative_dir: String, group_name: String) -> Array[String]:
	var models: Array[String] = []
	var absolute_dir := AppPaths.external_path(relative_dir)
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return models
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "gguf":
			models.append(group_name + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	models.sort()
	return models


func _ensure_selected_model_is_available() -> void:
	if available_model_filenames.is_empty():
		return
	var selected := str(settings.get("llm_model_filename", ""))
	if selected not in available_model_filenames:
		settings["llm_model_filename"] = available_model_filenames[0]


func _normalize_integer_settings() -> void:
	for key in ["port", "timeout", "context_size"]:
		if settings.has(key):
			settings[key] = str(settings[key]).to_int()
