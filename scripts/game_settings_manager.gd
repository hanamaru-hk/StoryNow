extends Node

const SETTINGS_PATH := "user://game_settings.json"
const DEFAULT_SETTINGS_PATH := "res://data/default_game_settings.json"

var settings := {
	"language": "en",
	"screen_size": "full",
}


func _ready() -> void:
	load_settings()
	_apply_language()
	_apply_screen_size()


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
	var file := FileAccess.open(DEFAULT_SETTINGS_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK and json.data is Dictionary:
			settings = json.data.duplicate()
			_apply_language()
			_apply_screen_size()
			save_settings()


func set_language(lang: String) -> void:
	settings["language"] = lang
	_apply_language()
	save_settings()


func set_screen_size(size: String) -> void:
	settings["screen_size"] = size
	_apply_screen_size()
	save_settings()


func _apply_language() -> void:
	I18n.set_language(settings["language"])


func _apply_screen_size() -> void:
	match settings["screen_size"]:
		"full":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"1344x768":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1344, 768))
			DisplayServer.window_set_title("Instant Visual Novel")
			var screen_size := DisplayServer.screen_get_size()
			var centered := (screen_size - Vector2i(1344, 768)) / 2
			DisplayServer.window_set_position(centered)
