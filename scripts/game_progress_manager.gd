extends Node

const SettingsValidator := preload("res://scripts/settings_value_validator.gd")
const SETTINGS_PATH := "user://game_progress.json"
const DEFAULT_SETTINGS_PATH := "data/default_game_progress.json"
const EXPECTED_ROUNDS := 3
const FLOW_SETTING_KEYS := [
	"minimum_dialogues_per_scene",
	"minimum_sentences_per_dialogue",
	"minimum_plot_directions",
	"maximum_plot_directions",
	"minimum_sentences_in_summary",
]
const FLOW_SETTING_DEFAULTS := {
	"minimum_dialogues_per_scene": 10,
	"minimum_sentences_per_dialogue": 2,
	"minimum_plot_directions": 3,
	"maximum_plot_directions": 3,
	"minimum_sentences_in_summary": 3,
}

var settings := {
	"current_dialogue": 0,
	"current_uuid": "",
	"current_round": 1,
	"player_input": "",
	"minimum_dialogues_per_scene": 10,
	"minimum_sentences_per_dialogue": 2,
	"minimum_plot_directions": 3,
	"minimum_sentences_in_summary": 3,
	"game_status": ""
}


func _ready() -> void:
	load_settings()


func save_settings() -> void:
	settings.erase("expected_rounds")
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
			settings.erase("expected_rounds")
			_normalize_integer_settings()


func reset_to_defaults() -> void:
	var defaults := _load_default_settings()
	if defaults.is_empty():
		return
	settings = defaults
	_normalize_integer_settings()
	save_settings()


func reset_flow_settings_to_defaults() -> void:
	var defaults := _load_default_settings()
	if defaults.is_empty():
		return
	for key in FLOW_SETTING_KEYS:
		if defaults.has(key):
			settings[key] = defaults[key]
	if settings.has("maximum_plot_directions") and defaults.has("minimum_plot_directions"):
		settings["maximum_plot_directions"] = defaults["minimum_plot_directions"]
	_normalize_integer_settings()
	save_settings()


func _load_default_settings() -> Dictionary:
	var path := AppPaths.external_path(DEFAULT_SETTINGS_PATH)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK or not json.data is Dictionary:
		return {}
	return (json.data as Dictionary).duplicate(true)


func _normalize_integer_settings() -> void:
	settings["current_dialogue"] = SettingsValidator.non_negative_integer_or_default(settings.get("current_dialogue", 0), 0)
	settings["current_round"] = SettingsValidator.positive_integer_or_default(settings.get("current_round", 1), 1)
	for key in FLOW_SETTING_KEYS:
		if settings.has(key):
			settings[key] = SettingsValidator.positive_integer_or_default(settings[key], int(FLOW_SETTING_DEFAULTS[key]))
