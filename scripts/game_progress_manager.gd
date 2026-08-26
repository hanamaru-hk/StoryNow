extends Node

const SETTINGS_PATH := "user://game_progress.json"
const DEFAULT_SETTINGS_PATH := "res://data/default_game_progress.json"

var settings := {
	"current_dialogue": 0,
	"current_uuid": "",
	"expected_rounds": 1,
	"minimum_dialogues_per_scene": 10,
	"minimum_sentences_per_dialogue": 10,
	"minimum_plot_directions": 10,
	"minimum_summary_sentences": 10,
	"game_status": ""
}


func _ready() -> void:
	load_settings()


func save_settings() -> void:
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


func reset_to_defaults() -> void:
	var path := DEFAULT_SETTINGS_PATH
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK and json.data is Dictionary:
			# Preserve current_dialogue/current_uuid if existing settings had them? Reset should restore defaults.
			settings = json.data.duplicate()
			# Ensure expected_rounds default is 1 per overlay spec if default file still has 20
			if settings.has("expected_rounds") and settings["expected_rounds"] == 20:
				# Keep file value as-is unless we want to enforce 1; don't override file.
				pass
			save_settings()
